from PyQt6.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout
from PyQt6.QtCore import Qt, QThread, pyqtSignal, pyqtSlot
from windows.main_actual_window import MainWindow, TemporaryWindow, Window
from shared.global_vars_and_funcs import chopper_crying_path, GOGO_NORMAL_COLOR, GOGO_HOVER_COLOR, GOGO_PRESSED_COLOR, GITHUB_REPO_URL, github_api_releases_entry_point, APP_NAME, github_icon_path, update_bckg_image_path
from shared.global_vars_and_funcs import RED_NORMAL_COLOR, RED_HOVER_COLOR, RED_PRESSED_COLOR, set_minimum_size_policy, settings, KEY_GOGO_DEFAULT_BROWSER, CHROME, EDGE, chopper_crying_path, VERSION, KEY_DOWNLOAD_FOLDER_PATHS, open_folder, pause_icon_path, resume_icon_path, cancel_icon_path
from shared.shared_classes_and_widgets import StyledButton, StyledLabel, FolderButton, IconButton, AnimeDetails, Icon
from shared.app_and_scraper_shared import ffmpeg_is_installed, network_error_retry_wrapper
from windows.download_window import ProgressBarWithButtons
from typing import cast, Callable, Any
from webbrowser import open_new_tab
from shared.app_and_scraper_shared import IBYTES_TO_MBS_DIVISOR, Download
import requests
import sys
import os
import subprocess
import re


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
        for w in widgets_to_add:
            self.buttons_layout.addWidget(w)
        buttons_widget = QWidget()
        buttons_widget.setLayout(self.buttons_layout)
        self.main_layout.addWidget(buttons_widget)
        main_widget = QWidget()
        main_widget.setLayout(self.main_layout)
        self.full_layout.addWidget(main_widget, Qt.AlignmentFlag.AlignHCenter)
        self.setLayout(self.full_layout)


class SwitchToSettingsWindowButton(StyledButton):
    def __init__(self, button_text: str, window: SthCrashedWindow, main_window: MainWindow):
        super().__init__(None, 25, "black", GOGO_NORMAL_COLOR,
                         GOGO_HOVER_COLOR, GOGO_PRESSED_COLOR)
        self.clicked.connect(main_window.switch_to_settings_window)
        self.clicked.connect(
            lambda: main_window.stacked_windows.removeWidget(window))
        self.clicked.connect(window.deleteLater)
        self.setText(button_text)
        set_minimum_size_policy(self)


class NoDefaultBrowserWindow(SthCrashedWindow):
    def __init__(self, main_window: MainWindow, anime_details: AnimeDetails) -> None:
        change_default_browser_button = SwitchToSettingsWindowButton(
            "Change Gogo default browser", self, main_window)
        gogo_default_browser = cast(str, settings[KEY_GOGO_DEFAULT_BROWSER])
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
        anime_details.is_hls_download = True
        download_in_hls_mode_button = RetryDownloadButton(
            None,  main_window, "Download in HLS mode", anime_details, ffmpeg_is_installed, main_window.create_and_switch_to_no_ffmpeg_window)
        set_minimum_size_policy(download_browser_button)
        set_minimum_size_policy(download_in_hls_mode_button)
        super().__init__(main_window, f"Sumimasen, downloaading from Gogoanime in Normal mode requires you have either: \n\t\tChrome, Edge or Firefox installed\nYour current Gogo default browser is {gogo_default_browser.capitalize()} but I couldn't find it installed\nYou can also try using HLS mode instead of Normal mode",
                         [change_default_browser_button, download_in_hls_mode_button])
        download_in_hls_mode_button.parent_window = self


class NoFFmpegWindow(SthCrashedWindow):
    def __init__(self, main_window: MainWindow, anime_details: AnimeDetails):
        self.main_window = main_window
        info_text = "Sumanai, in order to use HLS mode you need to have\nFFmpeg installed and properly added to path"
        install_ffmepg_button = StyledButton(
            None, 25, "black", GOGO_NORMAL_COLOR, GOGO_HOVER_COLOR, GOGO_PRESSED_COLOR)
        if sys.platform == "win32" or sys.platform == "linux":
            install_ffmepg_button.setText("Automatically Install FFmpeg")
        else:
            install_ffmepg_button.setText("Install FFmpeg")
        set_minimum_size_policy(install_ffmepg_button)
        install_ffmepg_button.clicked.connect(
            lambda: TryInstallingFFmpegThread(self, main_window, anime_details).start())
        anime_details.is_hls_download = False
        download_in_normal_mode = RetryDownloadButton(
            None, main_window, "Download in Normal mode", anime_details, None)
        set_minimum_size_policy(download_in_normal_mode)
        super().__init__(main_window, info_text, [
            install_ffmepg_button, download_in_normal_mode])
        download_in_normal_mode.parent_window = self


class RetryDownloadButton(StyledButton):
    initiate_download_pipeline = pyqtSignal(AnimeDetails)
    switch_to_download_window = pyqtSignal()
    remove_parent_window_from_stacked_windows_signal = pyqtSignal()
    switch_to_alt_window_signal = pyqtSignal()
    delete_parent_window_signal = pyqtSignal()

    def __init__(self, parent_window: NoDefaultBrowserWindow | NoFFmpegWindow | None, main_window: MainWindow, button_text: str, anime_details: AnimeDetails, is_downloadable: Callable[[], bool] | None, alt_window_switcher: Callable[[AnimeDetails], Any] = lambda a: None):
        super().__init__(parent_window, 25, "black",
                         RED_NORMAL_COLOR, RED_HOVER_COLOR, RED_PRESSED_COLOR)
        self.parent_window = parent_window
        self.setText(button_text)
        self.main_window = main_window
        self.anime_details = anime_details
        self.initiate_download_pipeline.connect(
            main_window.download_window.initiate_download_pipeline)
        self.switch_to_download_window.connect(
            main_window.switch_to_download_window)
        self.is_downloadable = is_downloadable
        self.switch_to_alt_window_signal.connect(lambda: alt_window_switcher(anime_details))
        self.remove_parent_window_from_stacked_windows_signal.connect(
            lambda: main_window.stacked_windows.removeWidget(self.parent_window))  # type: ignore
        self.clicked.connect(self.start_download)

    def clean_out_parent_window(self, switch_to_down: bool=True):
        self.delete_parent_window_signal.connect(self.parent_window.deleteLater) #type: ignore
        if switch_to_down:
            self.switch_to_download_window.emit()
        self.remove_parent_window_from_stacked_windows_signal.emit()
        self.delete_parent_window_signal.emit()

    def start_download(self):
        if self.is_downloadable and not self.is_downloadable():
            self.switch_to_alt_window_signal.emit()
            return self.clean_out_parent_window(False)
        self.initiate_download_pipeline.emit(self.anime_details)
        self.switch_to_download_window.emit()


class TryInstallingFFmpegThread(QThread):
    initiate_download_pipeline = pyqtSignal(AnimeDetails)
    switch_to_download_window = pyqtSignal()
    remove_noffmpeg_from_stacked_windows_signal = pyqtSignal()
    delete_noffmpeg_signal = pyqtSignal()

    def __init__(self, no_ffmpeg_window: NoFFmpegWindow, main_window: MainWindow, anime_details: AnimeDetails):
        super().__init__(no_ffmpeg_window)
        self.initiate_download_pipeline.connect(
            no_ffmpeg_window.main_window.download_window.initiate_download_pipeline)
        self.anime_details = anime_details
        self.switch_to_download_window.connect(
            main_window.switch_to_download_window)
        self.remove_noffmpeg_from_stacked_windows_signal.connect(
            lambda: main_window.stacked_windows.removeWidget(no_ffmpeg_window))
        self.no_ffmpeg_window = no_ffmpeg_window
        self.delete_noffmpeg_signal.connect(no_ffmpeg_window.deleteLater)

    def start_download(self):
        self.anime_details.is_hls_download = True
        self.initiate_download_pipeline.emit(self.anime_details)
        self.switch_to_download_window.emit()
        self.remove_noffmpeg_from_stacked_windows_signal.emit()
        self.delete_noffmpeg_signal.emit()

    def run(self):
        if sys.platform == "win32":
            try:
                subprocess.run("winget install Gyan.FFmpeg",
                               creationflags=subprocess.CREATE_NEW_CONSOLE)
            except:
                pass
            if ffmpeg_is_installed():
                self.no_ffmpeg_window.main_window.tray_icon.make_notification(
                    "Successfully Installed", "FFmpeg", True, None)
                self.start_download()
            else:
                open_new_tab(
                    "https://www.hostinger.com/tutorials/how-to-install-ffmpeg#How_to_Install_FFmpeg_on_Windows")
        elif sys.platform == "linux":
            try:
                subprocess.run(
                    "sudo apt-get update && sudo apt-get install ffmpeg", shell=True)
            except:
                pass
            if ffmpeg_is_installed():
                self.no_ffmpeg_window.main_window.tray_icon.make_notification(
                    "Successfully Installed", "FFmpeg", True, None)
                self.start_download()
            else:
                open_new_tab(
                    "https://www.hostinger.com/tutorials/how-to-install-ffmpeg#How_to_Install_FFmpeg_on_Linux")

        else:
            open_new_tab(
                "https://www.hostinger.com/tutorials/how-to-install-ffmpeg#How_to_Install_FFmpeg_on_macOS")


class UpdateWindow(Window):
    def __init__(self, main_window: MainWindow, download_url: str, file_name: str, platform_flag: int):
        super().__init__(main_window, update_bckg_image_path)
        main_widget = QWidget()
        main_layout = QVBoxLayout()
        self.progress_bar: ProgressBarWithButtons | None = None
        info_label = StyledLabel(font_size=24)
        info_label.setWordWrap(True)
        if platform_flag == 1:
            info_label.setText(
                "\nSenpwai will download the new version then open the folder it's in.\nThen it's up to you to close the current version\nand run the new version setup to install it.\nClick the button below to start the download.\n")
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
                self.download_folder, file_name)
            if os.path.exists(prev_file_path):
                os.unlink(prev_file_path)
            self.update_button.clicked.connect(DownloadUpdateThread(
                main_window, self, download_url, self.download_folder, file_name).start)

        else:
            if platform_flag == 3:
                os_name = "Mac OS"
            else:
                os_name = "Linux OS"
            info_label.setText(
                f"\n{os_name} detected, you will have to build from source to update to the new version.\nThere is a guide on the README.md in the Github Repository.\n")
            set_minimum_size_policy(info_label)
            main_layout.addWidget(info_label)
            github_button = IconButton(Icon(300, 100, github_icon_path), 1.1)
            github_button.clicked.connect(
                lambda: open_new_tab(GITHUB_REPO_URL))  # type: ignore
            github_button.setToolTip(GITHUB_REPO_URL)
            main_layout.addWidget(
                github_button, alignment=Qt.AlignmentFlag.AlignCenter)

        main_widget.setLayout(main_layout)
        main_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.full_layout.addWidget(main_widget, Qt.AlignmentFlag.AlignHCenter)
        self.setLayout(self.full_layout)

    def receive_total_size(self, size: int):
        pause_icon = Icon(40, 40, pause_icon_path)
        resume_icon = Icon(40, 40, resume_icon_path)
        cancel_icon = Icon(40, 40, cancel_icon_path)
        self.progress_bar = ProgressBarWithButtons(
            self, "Downloading", "new version setup", size, "MB", IBYTES_TO_MBS_DIVISOR, pause_icon, resume_icon, cancel_icon, lambda: None, lambda: None)
        self.download_layout.addWidget(self.progress_bar)
        self.download_layout.addWidget(FolderButton(
            self.download_folder, 100, 100), alignment=Qt.AlignmentFlag.AlignCenter)
        self.update_button.hide()
        self.update_button.deleteLater()


class DownloadUpdateThread(QThread):
    update_bar = pyqtSignal(int)
    total_size = pyqtSignal(int)

    def __init__(self, main_window: MainWindow, update_window: UpdateWindow, download_url: str, download_folder: str, file_name: str):
        super().__init__(main_window)
        self.download_url = download_url
        self.total_size.connect(update_window.receive_total_size)
        self.update_window = update_window
        self.download_folder = download_folder
        self.file_name = file_name
        self.make_notification = main_window.tray_icon.make_notification

    def run(self):
        total_size = int(network_error_retry_wrapper(lambda: (str, requests.get(
            self.download_url, stream=True).headers["content-length"])))
        self.total_size.emit(total_size)
        self.update_window.progress_bar
        while not self.update_window.progress_bar:
            continue
        self.update_bar.connect(self.update_window.progress_bar.update_bar)
        file_name, ext = self.file_name.split(".")
        ext = "." + ext
        download = Download(self.download_url, file_name, self.download_folder,
                            self.update_bar.emit, ext)
        self.update_window.progress_bar.pause_callback = download.pause_or_resume
        self.update_window.progress_bar.cancel_callback = download.cancel
        download.start_download()
        if not download.cancelled:
            def o(): return open_folder(self.download_folder)
            self.make_notification("Download Complete",
                                   "New Senpwai version setup", True, o)
            o()


class CheckIfUpdateAvailableThread(QThread):
    finished = pyqtSignal(tuple)

    def __init__(self, main_window: MainWindow, finished_callback: Callable[[tuple[bool, str, str, int, str]], Any]):
        super().__init__(main_window)
        self.finished.connect(finished_callback)

    def run(self):
        self.finished.emit(self.update_available())

    def update_available(self) -> tuple[bool, str, str, int, str]:
        latest_version_json = network_error_retry_wrapper(
            lambda: (requests.get(github_api_releases_entry_point))).json()[0]
        latest_version_tag = latest_version_json["tag_name"]
        ver_regex = re.compile(r'(\d+(\.\d+)*)')
        match = cast(re.Match, ver_regex.search(latest_version_tag))
        latest_version = match.group(1)
        platform_flag = self.check_platform()
        target_asset_names = [f"{APP_NAME}-setup.exe", f"{APP_NAME}-setup.msi",
                              f"{APP_NAME}-installer.exe", f"{APP_NAME}-installer.msi"]
        download_url = ""
        asset_name = ""
        curr_s = VERSION.split(".")
        new_s = latest_version.split(".")
        update_available = False
        for c, n in zip(curr_s, new_s):
            if int(c) < int(n):
                update_available = True
        if update_available:
            for asset in latest_version_json["assets"]:
                if asset["name"] in target_asset_names:
                    download_url = asset["browser_download_url"]
                    asset_name = asset["name"]
                    break
        return (update_available, download_url, asset_name,  platform_flag, latest_version)

    def check_platform(self) -> int:
        if sys.platform == "win32":
            return 1
        elif sys.platform == "linux":
            return 2
        return 3
