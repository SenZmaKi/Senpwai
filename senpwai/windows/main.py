from typing import Callable, cast

from PyQt6.QtCore import QThread, QTimer, Qt
from PyQt6.QtGui import QAction, QCloseEvent, QGuiApplication, QIcon, QScreen
from PyQt6.QtWidgets import (
    QApplication,
    QMainWindow,
    QMenu,
    QStackedWidget,
    QSystemTrayIcon,
    QWidget,
    QMessageBox,
)
from common.selenium import DRIVER_MANAGER
from senpwai.common.classes import SETTINGS, Anime, AnimeDetails, UpdateInfo
from senpwai.common.static import (
    MINIMISED_TO_TRAY_ARG,
    OS,
    SENPWAI_ICON_PATH,
    TASK_COMPLETE_ICON_PATH,
    UPDATE_ICON_PATH,
)

from senpwai.common.widgets import YesOrNoMessageBox
from senpwai.windows.about import AboutWindow
from senpwai.windows.abstracts import AbstractWindow
from senpwai.windows.chosen_anime import ChosenAnimeWindow, MakeAnimeDetailsThread
from senpwai.windows.download import DownloadWindow
from senpwai.windows.misc import (
    CheckIfUpdateAvailableThread,
    NoFFmpegWindow,
    UpdateWindow,
)
from senpwai.windows.search import SearchWindow
from senpwai.windows.settings import SettingsWindow
from senpwai.windows.abstracts import NavBarButton


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
        self.setup_chosen_anime_window_thread: QThread | None = None
        self.download_window.start_auto_download()

    def closeEvent(self, a0: QCloseEvent | None) -> None:
        if not a0:
            return
        if self.download_window.is_downloading():
            is_yes = YesOrNoMessageBox(self,
                "You have ongoing downloads, are you sure you want to exit?",
                False,
                QMessageBox.Icon.Warning,
            ).execute()
            if not is_yes:
                a0.ignore()
                return
        DRIVER_MANAGER.close_driver()
        a0.accept()

    def show_with_settings(self, args: list[str]):
        if MINIMISED_TO_TRAY_ARG in args:
            if SETTINGS.start_in_fullscreen:
                self.setWindowState(self.windowState() | Qt.WindowState.WindowMaximized)
            self.hide()
        elif SETTINGS.start_in_fullscreen:
            self.showMaximized()
            # HACK: For whatever reason on linux I have to do this monkeypatch even after
            # calling self.showMaximized(), sometimes it still doesn't work, gyaaah
            if OS.is_linux:
                QTimer(self).singleShot(1, self.showMaximized)
        else:
            self.showNormal()
            self.center_window()
            self.setWindowState(Qt.WindowState.WindowActive)

    def show_(self):
        self.activateWindow()
        if Qt.WindowState.WindowMaximized in self.windowState():
            self.showMaximized()
        elif Qt.WindowState.WindowFullScreen in self.windowState():
            self.showFullScreen()
        else:
            self.showNormal()

    def handle_update_check_result(self, update_info: UpdateInfo):
        if not update_info.is_update_available:
            return
        self.update_window = UpdateWindow(
            self,
            update_info.download_url,
            update_info.file_name,
            update_info.release_notes,
        )
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
        if self.setup_chosen_anime_window_thread is None:
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

    def switch_to_window(self, target_window: AbstractWindow):
        if self.stacked_windows.currentWidget() != target_window:
            self.set_bckg_img(target_window.bckg_img_path)
            self.stacked_windows.setCurrentWidget(target_window)

    def switch_to_search_window(self):
        self.switch_to_window(self.search_window)
        self.search_window.search_bar.setFocus()
        self.search_window.set_focus()

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
        search_action.triggered.connect(main_window.show_)
        downloads_action = QAction("Downloads", self.context_menu)
        downloads_action.triggered.connect(main_window.switch_to_download_window)
        downloads_action.triggered.connect(main_window.show_)
        exit_action = QAction("Exit", self.context_menu)
        exit_action.triggered.connect(main_window.app.quit)
        self.context_menu.addAction(check_for_new_episodes_action)
        self.context_menu.addAction(search_action)
        self.context_menu.addAction(downloads_action)
        self.context_menu.addAction(exit_action)
        self.messageClicked.connect(main_window.show_)
        self.setContextMenu(self.context_menu)

    def focus_or_hide_window(self):
        if not self.main_window.isVisible():
            self.main_window.show_()
            return
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
