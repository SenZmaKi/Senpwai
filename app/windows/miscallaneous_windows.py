from PyQt6.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QPushButton
from PyQt6.QtCore import Qt, QThread, pyqtSignal, pyqtSlot
from windows.main_actual_window import MainWindow, TemporaryWindow
from shared.global_vars_and_funcs import chopper_crying_path, PAHE_NORMAL_COLOR, PAHE_HOVER_COLOR, PAHE_PRESSED_COLOR, GOGO_NORMAL_COLOR, GOGO_HOVER_COLOR, GOGO_PRESSED_COLOR, GITHUB_REPO_URL, github_api_releases_entry_point, APP_NAME, github_icon_path, update_bckg_image_path
from shared.global_vars_and_funcs import RED_NORMAL_COLOR, RED_HOVER_COLOR, RED_PRESSED_COLOR, set_minimum_size_policy, settings, KEY_GOGO_DEFAULT_BROWSER, CHROME, EDGE, chopper_crying_path, VERSION, KEY_DOWNLOAD_FOLDER_PATHS, open_folder
from shared.shared_classes_and_widgets import StyledButton, StyledLabel, network_error_retry_wrapper, FolderButton, IconButton
from shared.app_and_scraper_shared import ffmpeg_is_installed
from windows.download_window import ProgressBar
from typing import cast, Callable
from webbrowser import open_new_tab
from shared.app_and_scraper_shared import IBYTES_TO_MBS_DIVISOR, Download
import requests
import sys
import os
import subprocess


class SthCrashedWindow(TemporaryWindow):
    def __init__(self, main_window: MainWindow, crash_info_text: str, widgets_to_add: list[QWidget]):
        super().__init__(main_window, chopper_crying_path)
        info_label = StyledLabel(font_size=25)
        info_label.setText(crash_info_text)
        set_minimum_size_policy(info_label)
        self.main_layout = QVBoxLayout()
        self.main_layout.addWidget(
            info_label, alignment=Qt.AlignmentFlag.AlignCenter)
        self.buttons_layout = QHBoxLayout()
        list(map(self.buttons_layout.addWidget, widgets_to_add))
        buttons_widget = QWidget()
        buttons_widget.setLayout(self.buttons_layout)
        self.main_layout.addWidget(buttons_widget)
        main_widget = QWidget()
        main_widget.setLayout(self.main_layout)
        self.full_layout.addWidget(main_widget, Qt.AlignmentFlag.AlignHCenter)
        self.setLayout(self.full_layout)


class FailedGettingDirectDownloadLinksWindow(SthCrashedWindow):
    def __init__(self, main_window: MainWindow, anime_title: str, info_text: str, widgets_to_add: list[QWidget]) -> None:
        switch_to_anime_pahe_button = StyledButton(
            None, 25, "black", PAHE_NORMAL_COLOR, PAHE_HOVER_COLOR, PAHE_PRESSED_COLOR)
        switch_to_anime_pahe_button.setText("Switch to Animepahe")
        set_minimum_size_policy(switch_to_anime_pahe_button)
        switch_to_anime_pahe_button.clicked.connect(
            lambda: main_window.switch_to_pahe(anime_title, self))
        switch_to_anime_pahe_button.clicked.connect(
            lambda: main_window.stacked_windows.removeWidget(self)
        )
        change_default_browser_button = SwitchToSettingsWindowButton(
            "Change Gogo default browser", self, main_window)
        switch_to_hls_mode_button = SwitchToSettingsWindowButton(
            "Switch to HLS mode", self, main_window)
        super().__init__(main_window, info_text, [
            switch_to_anime_pahe_button, change_default_browser_button, switch_to_hls_mode_button, *widgets_to_add])


class SwitchToSettingsWindowButton(StyledButton):
    def __init__(self, button_text: str, window: SthCrashedWindow, main_window: MainWindow):
        super().__init__(None, 25, "black", RED_NORMAL_COLOR,
                         RED_HOVER_COLOR, RED_PRESSED_COLOR)
        self.clicked.connect(main_window.switch_to_settings_window)
        self.clicked.connect(
            lambda: main_window.stacked_windows.removeWidget(window))
        self.clicked.connect(window.deleteLater)
        self.setText(button_text)
        set_minimum_size_policy(self)


class CaptchaBlockWindow(FailedGettingDirectDownloadLinksWindow):
    def __init__(self, main_window: MainWindow, anime_title: str, download_page_links: list[str]) -> None:
        main_window.set_bckg_img(chopper_crying_path)
        info_text = (
            f"Captcha block detected, this only ever happens with Gogoanime in Normal mode.\nChanging your Gogo default browser setting may help.\nYour current Gogo default browser is {cast(str, settings[KEY_GOGO_DEFAULT_BROWSER]).capitalize()}.\nYou can also try using HLS mode instead of Normal mode.")
        open_browser_with_links_button = StyledButton(
            None, 25, "black", GOGO_NORMAL_COLOR, GOGO_HOVER_COLOR, GOGO_PRESSED_COLOR)
        open_browser_with_links_button.setText("Download in browser")
        open_browser_with_links_button.clicked.connect(lambda: list(
            map(open_new_tab, download_page_links)))  # type: ignore
        set_minimum_size_policy(open_browser_with_links_button)
        super().__init__(main_window, anime_title,
                         info_text, [open_browser_with_links_button])


class NoDefaultBrowserWindow(FailedGettingDirectDownloadLinksWindow):
    def __init__(self, main_window: MainWindow, anime_title: str):
        gogo_default_browser = cast(str, settings[KEY_GOGO_DEFAULT_BROWSER])
        info_text = f"Sumimasen, downloaading from Gogoanime in Normal mode requires you have either: \n\t\tChrome, Edge or Firefox installed.\nYour current Gogo default browser is {gogo_default_browser.capitalize()} but I couldn't find it installed.\nYou can also try using HLS mode instead of Normal mode."
        download_browser_button = StyledButton(
            None, 25, "black", GOGO_NORMAL_COLOR, GOGO_HOVER_COLOR, GOGO_PRESSED_COLOR)
        if gogo_default_browser == CHROME:
            download_browser_button.setText("Download Chrome")
            download_browser_button.clicked.connect(lambda: open_new_tab(
                "https://www.google.com/chrome"))  # type: ignore
        elif gogo_default_browser == EDGE:
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


class NoFFmpegWindow(SthCrashedWindow):
    def __init__(self, main_window: MainWindow):
        info_text = "Sumanai, in order to use HLS mode you need to have FFmpeg\ninstalled and properly added to path."
        install_ffmepg_button = StyledButton(
            None, 25, "black", GOGO_NORMAL_COLOR, GOGO_HOVER_COLOR, GOGO_PRESSED_COLOR)
        install_ffmepg_button.setText("Install FFmpeg")
        set_minimum_size_policy(install_ffmepg_button)
        install_ffmepg_button.clicked.connect(
            lambda: TryInstallingFFmpegThread(self).start())
        switch_to_normal_mode = SwitchToSettingsWindowButton(
            "Switch to Normal mode", self, main_window)
        super().__init__(main_window, info_text, [
            install_ffmepg_button, switch_to_normal_mode])


class TryInstallingFFmpegThread(QThread):
    def __init__(self, no_ffmpeg_window: NoFFmpegWindow):
        super().__init__(no_ffmpeg_window)

    def run(self):
        if sys.platform == "win32":
            try:
                subprocess.run("winget install Gyan.FFmpeg",
                               creationflags=subprocess.CREATE_NEW_CONSOLE)
            except FileNotFoundError:
                pass
            if not ffmpeg_is_installed():
                open_new_tab(
                    "https://www.hostinger.com/tutorials/how-to-install-ffmpeg#How_to_Install_FFmpeg_on_Windows")

        elif sys.platform == "linux":
            try:
                subprocess.run("sudo apt-get update && sudo apt-get install ffmpeg", shell=True)
            except FileNotFoundError:
                pass
            if not ffmpeg_is_installed():
                open_new_tab(
                    "https://www.hostinger.com/tutorials/how-to-install-ffmpeg#How_to_Install_FFmpeg_on_Linux")
        else:
            open_new_tab(
                "https://www.hostinger.com/tutorials/how-to-install-ffmpeg#How_to_Install_FFmpeg_on_macOS")


class UpdateWindow(TemporaryWindow):
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
                self, 30, "black", RED_NORMAL_COLOR, RED_HOVER_COLOR, RED_PRESSED_COLOR, 20)
            self.update_button.setText("UPDATE")
            set_minimum_size_policy(self.update_button)
            download_widget = QWidget()
            self.download_layout = QVBoxLayout()
            self.download_layout.addWidget(
                self.update_button, alignment=Qt.AlignmentFlag.AlignCenter)
            main_layout.addWidget(download_widget)
            download_widget.setLayout(self.download_layout)
            self.download_folder = os.path.join(
                cast(list[str], settings[KEY_DOWNLOAD_FOLDER_PATHS])[0], "New Senpwai-setup")
            if not os.path.isdir(self.download_folder):
                os.mkdir(self.download_folder)
            prev_file_path = os.path.join(
                self.download_folder, f"{APP_NAME}-setup.exe")
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
                f"\n{os_name} detected, you will have to build from source to update to the new version.\nThere is a guide on the README.md in the Github Repository.\n")
            set_minimum_size_policy(info_label)
            main_layout.addWidget(info_label)
            github_button = IconButton(300, 100, github_icon_path, 1.1)
            github_button.clicked.connect(
                lambda: open_new_tab(GITHUB_REPO_URL))  # type: ignore
            github_button.setToolTip(GITHUB_REPO_URL)
            main_layout.addWidget(
                github_button, alignment=Qt.AlignmentFlag.AlignCenter)

        main_widget.setLayout(main_layout)
        main_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.full_layout.addWidget(main_widget, Qt.AlignmentFlag.AlignHCenter)
        self.setLayout(self.full_layout)

    @pyqtSlot(int)
    def receive_total_size(self, size: int):
        self.progress_bar = ProgressBar(
            self, "Downloading", "new version setup", size, "MB", IBYTES_TO_MBS_DIVISOR)
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
        download = Download(self.download_url, f"{APP_NAME}-setup", self.download_folder,
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
        latest_version_json = network_error_retry_wrapper(
            lambda: (requests.get(github_api_releases_entry_point))).json()[0]
        latest_version_tag = latest_version_json["tag_name"]
        latest_version_number = latest_version_tag.replace(
            ".", "").replace("v", "")
        current_version_number = VERSION.replace(".", "").replace("v", "")
        platform_flag = self.check_platform()
        # For testing purposes, change to {app_name}-setup.exe before deploying to production
        target_asset_name = f"{APP_NAME}-setup.exe"
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
