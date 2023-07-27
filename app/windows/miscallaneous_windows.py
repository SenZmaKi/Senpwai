from PyQt6.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QPushButton
from PyQt6.QtCore import Qt, QThread, pyqtSignal, pyqtSlot
from windows.main_actual_window import MainWindow, Window
from shared.global_vars_and_funcs import chopper_crying_path, pahe_normal_color, pahe_hover_color, pahe_pressed_color, gogo_normal_color, gogo_hover_color, gogo_pressed_color, github_repo_url, github_api_releases_entry_point, app_name, github_icon_path, update_bckg_image_path
from shared.global_vars_and_funcs import red_normal_color, red_hover_color, red_pressed_color, set_minimum_size_policy, settings, key_gogo_default_browser, chrome_name, edge_name, chopper_crying_path, version, key_download_folder_paths, open_folder
from shared.shared_classes_and_widgets import StyledButton, StyledLabel, network_monad, FolderButton, IconButton
from windows.download_window import ProgressBar
from typing import cast, Callable
from webbrowser import open_new_tab
from shared.app_and_scraper_shared import ibytes_to_mbs_divisor, Download
import requests
import sys
import os

# I Was trying out Debian support so you may find control flow that treats Debian seperately from Linux in general
class FailedGettingDirectDownloadLinksWindow(Window):
    def __init__(self, main_window: MainWindow, anime_title: str, info_text: str, buttons_unique_to_window: list[QPushButton]) -> None:
        super().__init__(main_window, chopper_crying_path)
        main_window.set_bckg_img(chopper_crying_path)
        info_label = StyledLabel(font_size=30)
        info_label.setText(info_text)
        set_minimum_size_policy(info_label)
        main_layout = QVBoxLayout()
        buttons_layout = QHBoxLayout()
        buttons_widget = QWidget()
        switch_to_anime_pahe_button = StyledButton(
            None, 25, "black", pahe_normal_color, pahe_hover_color, pahe_pressed_color)
        switch_to_anime_pahe_button.setText("Switch to animepahe")
        set_minimum_size_policy(switch_to_anime_pahe_button)
        switch_to_anime_pahe_button.clicked.connect(
            lambda: main_window.switch_to_pahe(anime_title, self))
        switch_to_anime_pahe_button.clicked.connect(
            lambda: main_window.stacked_windows.removeWidget(self)
        )
        switch_to_anime_pahe_button.clicked.connect(self.deleteLater)
        change_default_browser_button = StyledButton(
            None, 25, "black", red_normal_color, red_hover_color, red_pressed_color)
        change_default_browser_button.setText("Change gogo default browser")
        change_default_browser_button.clicked.connect(
            main_window.switch_to_settings_window)
        change_default_browser_button.clicked.connect(
            lambda: main_window.stacked_windows.removeWidget(self)
        )
        change_default_browser_button.clicked.connect(self.deleteLater)
        set_minimum_size_policy(change_default_browser_button)
        buttons_layout.addWidget(switch_to_anime_pahe_button)
        buttons_layout.addWidget(change_default_browser_button)
        list(map(buttons_layout.addWidget, buttons_unique_to_window))
        buttons_widget.setLayout(buttons_layout)
        main_layout.addWidget(
            info_label, alignment=Qt.AlignmentFlag.AlignCenter)
        main_layout.addWidget(buttons_widget)
        main_widget = QWidget()
        main_widget.setLayout(main_layout)
        self.full_layout.addWidget(main_widget, Qt.AlignmentFlag.AlignHCenter)
        self.setLayout(self.full_layout)


class CaptchaBlockWindow(FailedGettingDirectDownloadLinksWindow):
    def __init__(self, main_window: MainWindow, anime_title: str, download_page_links: list[str]) -> None:
        main_window.set_bckg_img(chopper_crying_path)
        info_text = (
            f"Captcha block detected, this only ever happens with Gogoanime\nChanging your Gogo default browser setting may help\nYour current Gogo default browser is {settings[key_gogo_default_browser].capitalize()}")
        open_browser_with_links_button = StyledButton(
            None, 25, "black", gogo_normal_color, gogo_hover_color, gogo_pressed_color)
        open_browser_with_links_button.setText("Download in browser")
        open_browser_with_links_button.clicked.connect(lambda: list(
            map(open_new_tab, download_page_links)))  # type: ignore
        set_minimum_size_policy(open_browser_with_links_button)
        super().__init__(main_window, anime_title,
                         info_text, [open_browser_with_links_button])


class NoDefaultBrowserWindow(FailedGettingDirectDownloadLinksWindow):
    def __init__(self, main_window: MainWindow, anime_title: str):
        gogo_default_browser = cast(str, settings[key_gogo_default_browser])
        info_text = f"Sumimasen, downloaading from Gogoanime requires you have either: \n\t\tChrome, Edge or Firefox installed\nYour current Gogo default browser is {gogo_default_browser.capitalize()} but I couldn't find it installed"
        download_browser_button = StyledButton(
            None, 25, "black", gogo_normal_color, gogo_hover_color, gogo_pressed_color)
        if gogo_default_browser == chrome_name:
            download_browser_button.setText("Download Chrome")
            download_browser_button.clicked.connect(lambda: open_new_tab(
                "https://www.google.com/chrome"))  # type: ignore
        elif gogo_default_browser == edge_name:
            download_browser_button.setText("Download Edge")
            download_browser_button.clicked.connect(lambda: open_new_tab(
                "https://www.microsoft.com/edge/download"))  # type: ignore
        else:
            download_browser_button.setText("Download Firefox")
            download_browser_button.clicked.connect(lambda: open_new_tab(
                "https://www.mozilla.org/firefox"))  # type: ignore
        set_minimum_size_policy(download_browser_button)
        super().__init__(main_window, anime_title,
                         info_text, [download_browser_button])


class UpdateWindow(Window):
    def __init__(self, main_window: MainWindow, download_url: str, platform_flag: int):
        super().__init__(main_window, update_bckg_image_path)
        main_widget = QWidget()
        main_layout = QVBoxLayout()
        self.progress_bar: ProgressBar | None = None
        info_label = StyledLabel(font_size=24)
        if platform_flag == 1:
            info_label.setText(
                "\nI will download the new version then open the folder it's in.\nThen it's up to you to run the setup to install it.\nClick the button below to update.\n")
            set_minimum_size_policy(info_label)
            main_layout.addWidget(
                info_label, alignment=Qt.AlignmentFlag.AlignCenter)
            self.update_button = StyledButton(
                self, 30, "black", red_normal_color, red_hover_color, red_pressed_color, 20)
            self.update_button.setText("UPDATE")
            set_minimum_size_policy(self.update_button)
            download_widget = QWidget()
            self.download_layout = QVBoxLayout()
            self.download_layout.addWidget(
                self.update_button, alignment=Qt.AlignmentFlag.AlignCenter)
            main_layout.addWidget(download_widget)
            download_widget.setLayout(self.download_layout)
            self.download_folder = os.path.join(
                settings[key_download_folder_paths][0], "New Senpwai-setup")
            if not os.path.isdir(self.download_folder):
                os.mkdir(self.download_folder)
            prev_file_path = os.path.join(
                self.download_folder, f"{app_name}-setup.exe")
            if os.path.exists(prev_file_path):
                os.unlink(prev_file_path)
            self.update_button.clicked.connect(DownloadUpdateThread(
                main_window, self, download_url, self.download_folder).start)

        else:
            if platform_flag == 3:
                os_name = "Mac OS"
            else:
                os_name = "Linux OS"
            info_label.setText(
                f"\n{os_name} detected, you will have to build from source to update to the new version.\nThere is a guide on the README.md in the github repo.\n")
            set_minimum_size_policy(info_label)
            main_layout.addWidget(info_label)
            github_button = IconButton(300, 100, github_icon_path, 1.1)
            github_button.clicked.connect(
                lambda: open_new_tab(github_repo_url))  # type: ignore
            github_button.setToolTip(github_repo_url)
            main_layout.addWidget(
                github_button, alignment=Qt.AlignmentFlag.AlignCenter)

        main_widget.setLayout(main_layout)
        main_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.full_layout.addWidget(main_widget, Qt.AlignmentFlag.AlignHCenter)
        self.setLayout(self.full_layout)

    @pyqtSlot(int)
    def receive_total_size(self, size: int):
        self.progress_bar = ProgressBar(
            self, "Downloading", "new version setup", size, "MB", ibytes_to_mbs_divisor)
        self.download_layout.addWidget(self.progress_bar)
        self.download_layout.addWidget(FolderButton(
            self.download_folder, 120, 120), alignment=Qt.AlignmentFlag.AlignCenter)
        self.update_button.hide()
        self.update_button.deleteLater()


class DownloadUpdateThread(QThread):
    update_bar = pyqtSignal(int)
    total_size = pyqtSignal(int)

    def __init__(self, main_window: MainWindow, update_window: UpdateWindow, download_url: str, download_folder: str):
        super().__init__(main_window)
        self.download_url = download_url
        self.total_size.connect(update_window.receive_total_size)
        self.update_window = update_window
        self.download_folder = download_folder

    def run(self):
        total_size = int(cast(str, requests.get(
            self.download_url, stream=True).headers["content-length"]))
        self.total_size.emit(total_size)
        self.update_window.progress_bar
        while not self.update_window.progress_bar:
            continue
        self.update_bar.connect(self.update_window.progress_bar.update_bar)
        download = Download(self.download_url, f"{app_name}-setup", self.download_folder,
                            self.update_bar.emit, ".exe")
        self.update_window.progress_bar.pause_callback = download.pause_or_resume
        self.update_window.progress_bar.cancel_callback = download.cancel
        download.start_download()
        open_folder(self.download_folder)




class CheckIfUpdateAvailableThread(QThread):
    finished = pyqtSignal(tuple)

    def __init__(self, main_window: MainWindow, finished_callback: Callable):
        super().__init__(main_window)
        self.finished.connect(finished_callback)

    def run(self):
        self.finished.emit(self.update_available())

    def update_available(self) -> tuple[bool, str, int]:
        latest_version_json = network_monad(
            lambda: (requests.get(github_api_releases_entry_point))).json()[0]
        latest_version_tag = latest_version_json["tag_name"]
        latest_version_number = latest_version_tag.replace(
            ".", "").replace("v", "")
        current_version_number = version.replace(".", "").replace("v", "")
        platform_flag = self.check_platform()
        # For testing purposes, change to {app_name}-setup.exe before deploying to production
        target_asset_name = f"{app_name}-setup.exe"
        download_url = ""
        for asset in latest_version_json["assets"]:
            if asset["name"] == target_asset_name:
                download_url = asset["browser_download_url"]
        return (int(latest_version_number) > int(current_version_number), download_url, platform_flag)

    def check_platform(self) -> int:
        if sys.platform == "win32":
            return 1
        elif sys.platform == "linux":
            return 2
        return 3
