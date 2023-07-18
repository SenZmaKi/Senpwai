from PyQt6.QtGui import QGuiApplication, QIcon
from PyQt6.QtWidgets import QMainWindow, QWidget, QSystemTrayIcon, QStackedWidget
from PyQt6.QtCore import QPoint
from shared.global_vars_and_funcs import senpwai_icon_path, bckg_image_path
from shared.shared_classes_and_widgets import Anime, AnimeDetails


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.set_bckg_img = lambda img_path: self.setStyleSheet(
            f"MainWindow{{border-image: url({img_path}) 0 0 0 0 stretch stretch;}}")
        self.set_default_bck_img = lambda: self.set_bckg_img(bckg_image_path)
        self.set_default_bck_img()
        # Places window at the center of the screen
        center_point = QGuiApplication.primaryScreen().availableGeometry().center()
        window_position = QPoint(center_point.x(
        ) - self.rect().center().x(), center_point.y() - self.rect().center().y())
        self.move(window_position)
        self.tray_icon = QSystemTrayIcon(QIcon(senpwai_icon_path), self)
        self.tray_icon.show()
        self.download_window = DownloadWindow(self)
        from windows.search_window import SearchWindow
        self.search_window = SearchWindow(self)
        self.settings_window = SettingsWindow(self)
        self.stacked_windows = QStackedWidget(self)
        self.stacked_windows.addWidget(self.search_window)
        self.stacked_windows.addWidget(self.download_window)
        self.stacked_windows.addWidget(self.settings_window)
        self.stacked_windows.setCurrentWidget(self.settings_window)
        self.setCentralWidget(self.stacked_windows)
        self.setup_chosen_anime_window_thread = None

        # For testing purposes, the anime id changes after a while so check on animepahe if it doesn't work
        # self.setup_and_switch_to_chosen_anime_window(Anime("Senyuu.", "https://animepahe.ru/api?m=release&id=a8aa3a2e-e5da-2619-fce4-e829b65fef29", "a8aa3a2e-e5da-2619-fce4-e829b65fef29"), pahe_name)
        # self.setup_and_switch_to_chosen_anime_window(Anime("Blue Lock", "https://gogoanime.hu/category/blue-lock", None), gogo_name)

    def center_window(self) -> None:
        screen_geometry = QGuiApplication.primaryScreen().geometry()
        x = (screen_geometry.width() - self.width()) // 2
        y = (screen_geometry.height() - self.height()) // 2
        self.move(x, y)

    def setup_and_switch_to_chosen_anime_window(self, anime: Anime, site: str):
        # This if statement prevents error: "QThread: Destroyed while thread is still running" that happens when more than one thread is spawned when a set a user clicks more than one ResultButton causing the original thread to be reassigned hence get destroyed
        if not self.setup_chosen_anime_window_thread:
            self.search_window.loading.start()
            self.search_window.bottom_section_stacked_widgets.setCurrentWidget(
                self.search_window.loading)
            self.setup_chosen_anime_window_thread = SetupChosenAnimeWindowThread(
                self, anime, site)
            self.setup_chosen_anime_window_thread.finished.connect(
                lambda anime_details: self.handle_finished_drawing_window_widgets(anime_details))
            self.setup_chosen_anime_window_thread.start()

    def handle_finished_drawing_window_widgets(self, anime_details: AnimeDetails):
        self.setup_chosen_anime_window_thread = None
        self.search_window.loading.stop()
        self.search_window.bottom_section_stacked_widgets.setCurrentWidget(
            self.search_window.results_widget)
        chosen_anime_window = ChosenAnimeWindow(self, anime_details)
        self.stacked_windows.addWidget(chosen_anime_window)
        self.stacked_windows.setCurrentWidget(chosen_anime_window)
        self.setup_chosen_anime_window_thread = None

    def switch_to_pahe(self, anime_title: str, initiator: QWidget):
        self.stacked_windows.setCurrentWidget(self.search_window)
        self.stacked_windows.removeWidget(initiator)
        self.stacked_windows.removeWidget(initiator)
        self.search_window.search_bar.setText(anime_title)
        self.search_window.pahe_search_button.animateClick()

    def create_and_switch_to_captcha_block_window(self, anime_title: str, download_page_links: list[str]) -> None:
        captcha_block_window = CaptchaBlockWindow(
            self, anime_title, download_page_links)
        self.stacked_windows.addWidget(captcha_block_window)
        self.stacked_windows.setCurrentWidget(captcha_block_window)

    def create_and_switch_to_no_supported_browser_window(self, anime_title: str):
        no_supported_browser_window = NoDefaultBrowserWindow(self, anime_title)
        self.stacked_windows.addWidget(no_supported_browser_window)
        self.stacked_windows.setCurrentWidget(no_supported_browser_window)

# Note these modules be placed here otherwise an ImportError is experienced cause they  import MainWindow resulting to a circular import, so we have to define MainWindow first before importing them
from windows.settings_window import SettingsWindow
from windows.chosen_anime_window import ChosenAnimeWindow, SetupChosenAnimeWindowThread
from windows.miscallaneous_windows import NoDefaultBrowserWindow, CaptchaBlockWindow
from windows.download_window import DownloadWindow