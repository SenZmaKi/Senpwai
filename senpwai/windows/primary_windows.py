from typing import Callable, cast

from PyQt6.QtCore import Qt
from PyQt6.QtGui import QAction, QGuiApplication, QIcon, QScreen
from PyQt6.QtWidgets import (
    QApplication,
    QHBoxLayout,
    QMainWindow,
    QMenu,
    QStackedWidget,
    QSystemTrayIcon,
    QVBoxLayout,
    QWidget,
)
from senpwai.utils.class_utils import SETTINGS, Anime, AnimeDetails
from senpwai.utils.static_utils import (
    ABOUT_ICON_PATH,
    DOWNLOADS_ICON_PATH,
    MINIMISED_TO_TRAY_ARG,
    SEARCH_ICON_PATH,
    SENPWAI_ICON_PATH,
    SETTINGS_ICON_PATH,
    TASK_COMPLETE_ICON_PATH,
    UPDATE_ICON_PATH,
)
from senpwai.utils.widget_utils import Icon, IconButton


class MainWindow(QMainWindow):
    def __init__(self, app: QApplication):
        super().__init__()
        self.set_bckg_img = lambda img_path: self.setStyleSheet(
            f"QMainWindow{{border-image: url({img_path}) 0 0 0 0 stretch stretch;}}"
        )
        self.app = app
        self.center_window()
        self.senpwai_icon = QIcon(SENPWAI_ICON_PATH)
        self.search_window = SearchWindow(self)
        self.download_window = DownloadWindow(self)
        self.tray_icon = TrayIcon(self)
        self.tray_icon.show()
        self.settings_window = SettingsWindow(self)
        self.about_window = AboutWindow(self)
        CheckIfUpdateAvailableThread(self, self.handle_update_check_result).start()
        self.stacked_windows = QStackedWidget(self)
        # The widget that is added first is implicitly set as the current widget
        self.stacked_windows.addWidget(self.search_window)
        self.set_bckg_img(self.search_window.bckg_img_path)
        self.stacked_windows.addWidget(self.download_window)
        self.stacked_windows.addWidget(self.settings_window)
        self.stacked_windows.addWidget(self.about_window)
        self.setCentralWidget(self.stacked_windows)
        self.setup_chosen_anime_window_thread = None
        self.download_window.start_auto_download()
        self.app.aboutToQuit.connect(self.tray_icon.hide)

    def show_with_settings(self, args: list[str]):
        if MINIMISED_TO_TRAY_ARG in args:
            if SETTINGS.start_in_fullscreen:
                self.setWindowState(self.windowState() | Qt.WindowState.WindowMaximized)
            return self.hide()
        elif SETTINGS.start_in_fullscreen:
            self.showMaximized()
        else:
            self.showNormal()
            self.center_window()
            self.setWindowState(Qt.WindowState.WindowActive)

    def show(self):
        self.activateWindow()
        if Qt.WindowState.WindowMaximized in self.windowState():
            return self.showMaximized()
        self.showNormal()
        self.center_window()

    def handle_update_check_result(self, result: tuple[bool, str, str, str]):
        is_available, download_url, file_name, update_info = result
        if not is_available:
            return
        self.update_window = UpdateWindow(self, download_url, file_name, update_info)
        self.stacked_windows.addWidget(self.update_window)
        update_icon = NavBarButton(UPDATE_ICON_PATH, self.switch_to_update_window)
        self.search_window.nav_bar_layout.addWidget(update_icon)

    def switch_to_update_window(self):
        self.switch_to_window(self.update_window)

    def center_window(self) -> None:
        screen_geometry = cast(
            QScreen, QGuiApplication.primaryScreen()
        ).availableGeometry()
        x = (screen_geometry.width() - self.width()) // 2
        self.move(x, 0)

    def setup_and_switch_to_chosen_anime_window(self, anime: Anime, site: str):
        # This if statement prevents error: "QThread: Destroyed while thread is still running" that happens when more than one thread is spawned
        # When a user clicks more than one ResultButton quickly causing the reference to the original thread to be overwridden hence garbage collected/destroyed
        if not self.setup_chosen_anime_window_thread:
            self.search_window.loading.start()
            self.search_window.bottom_section_stacked_widgets.setCurrentWidget(
                self.search_window.loading
            )
            self.setup_chosen_anime_window_thread = MakeAnimeDetailsThread(
                self, anime, site
            )
            self.setup_chosen_anime_window_thread.finished.connect(
                lambda anime_details: self.make_chosen_anime_window(anime_details)
            )
            self.setup_chosen_anime_window_thread.start()

    def make_chosen_anime_window(self, anime_details: AnimeDetails):
        self.setup_chosen_anime_window_thread = None
        self.search_window.bottom_section_stacked_widgets.setCurrentWidget(
            self.search_window.results_widget
        )
        self.search_window.loading.stop()
        chosen_anime_window = ChosenAnimeWindow(self, anime_details)
        self.stacked_windows.addWidget(chosen_anime_window)
        self.set_bckg_img(chosen_anime_window.bckg_img_path)
        self.stacked_windows.setCurrentWidget(chosen_anime_window)
        self.setup_chosen_anime_window_thread = None

    def switch_to_pahe(self, anime_title: str, initiator: QWidget):
        self.search_window.search_bar.setText(anime_title)
        self.search_window.pahe_search_button.animateClick()
        self.switch_to_search_window()
        self.stacked_windows.removeWidget(initiator)
        initiator.deleteLater()

    def switch_to_gogo(self, anime_title: str, initiator: QWidget):
        self.search_window.search_bar.setText(anime_title)
        self.search_window.gogo_search_button.animateClick()
        self.switch_to_search_window()
        self.stacked_windows.removeWidget(initiator)
        initiator.deleteLater()

    def switch_to_window(self, target_window: QWidget):
        target_window = cast(AbstractWindow, target_window)
        if self.stacked_windows.currentWidget() != target_window:
            self.set_bckg_img(target_window.bckg_img_path)
            self.stacked_windows.setCurrentWidget(target_window)

    def switch_to_search_window(self):
        self.switch_to_window(self.search_window)
        self.search_window.search_bar.setFocus()
        self.search_window.on_focus()

    def switch_to_download_window(self):
        self.switch_to_window(self.download_window)

    def switch_to_settings_window(self):
        self.switch_to_window(self.settings_window)

    def switch_to_about_window(self):
        self.switch_to_window(self.about_window)

    def create_and_switch_to_no_ffmpeg_window(self, anime_details: AnimeDetails):
        no_ffmpeg_window = NoFFmpegWindow(self, anime_details)
        self.stacked_windows.addWidget(no_ffmpeg_window)
        self.switch_to_window(no_ffmpeg_window)


class TrayIcon(QSystemTrayIcon):
    def __init__(self, main_window: MainWindow):
        super().__init__(main_window.senpwai_icon, main_window)
        self.task_complete_icon = QIcon(TASK_COMPLETE_ICON_PATH)
        self.main_window = main_window
        self.setToolTip("Senpwai")
        self.activated.connect(self.on_tray_icon_click)
        self.context_menu = QMenu("Senpwai", main_window)
        check_for_new_episodes_action = QAction(
            "Check for new episodes", self.context_menu
        )
        check_for_new_episodes_action.triggered.connect(
            main_window.download_window.start_auto_download
        )
        search_action = QAction("Search", self.context_menu)
        search_action.triggered.connect(main_window.switch_to_search_window)
        search_action.triggered.connect(main_window.show)
        downloads_action = QAction("Downloads", self.context_menu)
        downloads_action.triggered.connect(main_window.switch_to_download_window)
        downloads_action.triggered.connect(main_window.show)
        quit_action = QAction("Quit", self.context_menu)
        quit_action.triggered.connect(main_window.app.quit)
        self.context_menu.addAction(check_for_new_episodes_action)
        self.context_menu.addAction(search_action)
        self.context_menu.addAction(downloads_action)
        self.context_menu.addAction(quit_action)
        self.messageClicked.connect(main_window.show)
        self.setContextMenu(self.context_menu)

    def focus_or_hide_window(self):
        if not self.main_window.isVisible():
            return self.main_window.show()
        self.main_window.hide()

    def on_tray_icon_click(self, reason: QSystemTrayIcon.ActivationReason):
        if reason == QSystemTrayIcon.ActivationReason.Context:
            self.context_menu.show()
        elif reason == QSystemTrayIcon.ActivationReason.Trigger:
            self.focus_or_hide_window()

    def make_notification(
        self,
        title: str,
        msg: str,
        sth_completed: bool,
        onclick: Callable[[], None] | None = None,
    ):
        if SETTINGS.allow_notifications:
            if onclick:
                self.messageClicked.connect(onclick)
            if sth_completed:
                return self.showMessage(title, msg, self.task_complete_icon, 5000)
            self.showMessage(title, msg, msecs=5000)


class NavBarButton(IconButton):
    def __init__(self, icon_path: str, switch_to_window_callable: Callable):
        super().__init__(Icon(50, 50, icon_path), 1.15)
        self.clicked.connect(switch_to_window_callable)
        self.setStyleSheet(
            """
                           QPushButton {
                                    border-radius: 21px;
                                    background-color: black;
                              }"""
        )


class AbstractWindow(QWidget):
    def __init__(self, main_window: MainWindow, bckg_img_path: str):
        super().__init__(main_window)
        self.bckg_img_path = bckg_img_path
        self.full_layout = QHBoxLayout()
        nav_bar_widget = QWidget()
        self.nav_bar_layout = QVBoxLayout()

        self.search_window_button = NavBarButton(
            SEARCH_ICON_PATH, main_window.switch_to_search_window
        )
        self.download_window_button = NavBarButton(
            DOWNLOADS_ICON_PATH, main_window.switch_to_download_window
        )
        self.settings_window_button = NavBarButton(
            SETTINGS_ICON_PATH, main_window.switch_to_settings_window
        )
        self.about_window_button = NavBarButton(
            ABOUT_ICON_PATH, main_window.switch_to_about_window
        )
        self.nav_bar_buttons = [
            self.search_window_button,
            self.download_window_button,
            self.settings_window_button,
            self.about_window_button,
        ]
        for button in self.nav_bar_buttons:
            self.nav_bar_layout.addWidget(button)
        self.nav_bar_layout.setAlignment(Qt.AlignmentFlag.AlignTop)
        nav_bar_widget.setLayout(self.nav_bar_layout)
        self.full_layout.addWidget(nav_bar_widget)


class AbstractTemporaryWindow(AbstractWindow):
    def __init__(self, main_window: MainWindow, bckg_img_path: str):
        super().__init__(main_window, bckg_img_path)
        for button in self.nav_bar_buttons:
            button.clicked.connect(
                lambda: main_window.stacked_windows.removeWidget(self)
            )
            button.clicked.connect(self.deleteLater)


# These modules imports must be placed here otherwise an ImportError is experienced cause
# They import MainWindow and Window resulting to a circular import, so we have to define MainWindow and Window first before importing them
from senpwai.windows.about_window import AboutWindow
from senpwai.windows.chosen_anime_window import ChosenAnimeWindow, MakeAnimeDetailsThread
from senpwai.windows.download_window import DownloadWindow
from senpwai.windows.misc_windows import (
    CheckIfUpdateAvailableThread,
    NoFFmpegWindow,
    UpdateWindow,
)
from senpwai.windows.search_window import SearchWindow
from senpwai.windows.settings_window import SettingsWindow
