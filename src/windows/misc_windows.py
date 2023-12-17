import os
import subprocess
import sys
from typing import Any, Callable
from webbrowser import open_new_tab

from PyQt6.QtCore import Qt, QThread, pyqtSignal
from PyQt6.QtWidgets import QHBoxLayout, QVBoxLayout, QWidget
from shared.class_utils import AnimeDetails, update_available
from shared.scraper_utils import (
    CLIENT,
    FFMPEG_LINUX_INSTALLATION_GUIDE,
    FFMPEG_MAC_INSTALLATION_GUIDE,
    FFMPEG_WINDOWS_INSTALLATION_GUIDE,
    IBYTES_TO_MBS_DIVISOR,
    RESOURCE_MOVED_STATUS_CODES,
    Download,
    ffmpeg_is_installed,
)
from shared.static_utils import (
    APP_NAME,
    CANCEL_ICON_PATH,
    CHOPPER_CRYING_PATH,
    GITHUB_API_LATEST_RELEASE_ENDPOINT,
    GITHUB_ICON_PATH,
    GITHUB_REPO_URL,
    GOGO_HOVER_COLOR,
    GOGO_NORMAL_COLOR,
    GOGO_PRESSED_COLOR,
    PAUSE_ICON_PATH,
    RED_HOVER_COLOR,
    RED_NORMAL_COLOR,
    RED_PRESSED_COLOR,
    RESUME_ICON_PATH,
    SRC_DIRECTORY,
    UPDATE_BCKG_IMAGE_PATH,
    VERSION,
)
from shared.widget_utils import (
    Icon,
    IconButton,
    StyledButton,
    StyledLabel,
    StyledTextBrowser,
    Title,
    set_minimum_size_policy,
)

from windows.download_window import ProgressBarWithButtons
from windows.primary_windows import AbstractTemporaryWindow, AbstractWindow, MainWindow


class MiscWindow(AbstractTemporaryWindow):
    def __init__(self, main_window: MainWindow, misc_info_text: str):
        super().__init__(main_window, CHOPPER_CRYING_PATH)
        self.info_label = StyledLabel(font_size=25)
        self.info_label.setText(misc_info_text)
        set_minimum_size_policy(self.info_label)
        self.main_layout = QVBoxLayout()
        self.main_layout.addWidget(
            self.info_label, alignment=Qt.AlignmentFlag.AlignCenter
        )
        self.buttons_layout = QHBoxLayout()
        buttons_widget = QWidget()
        buttons_widget.setLayout(self.buttons_layout)
        self.main_layout.addWidget(buttons_widget)
        main_widget = QWidget()
        main_widget.setLayout(self.main_layout)
        self.full_layout.addWidget(main_widget, Qt.AlignmentFlag.AlignHCenter)
        self.setLayout(self.full_layout)


class NewVersionInfoWindow(MiscWindow):
    def __init__(self, main_window: MainWindow, info_text: str):
        super().__init__(main_window, info_text)
        title = Title(f"Version {VERSION} Changes")
        set_minimum_size_policy(title)
        self.main_layout.insertWidget(0, title, alignment=Qt.AlignmentFlag.AlignHCenter)


class NoFFmpegWindow(MiscWindow):
    def __init__(self, main_window: MainWindow, anime_details: AnimeDetails):
        self.main_window = main_window
        info_text = "Sumanai, in order to use HLS mode you need to have\nFFmpeg installed and properly added to path"
        super().__init__(main_window, info_text)
        super().__init__(main_window, info_text)
        install_ffmepg_button = StyledButton(
            None, 25, "black", GOGO_NORMAL_COLOR, GOGO_HOVER_COLOR, GOGO_PRESSED_COLOR
        )
        if sys.platform == "win32" or sys.platform == "linux":
            install_ffmepg_button.setText("Automatically Install FFmpeg")
        else:
            install_ffmepg_button.setText("Install FFmpeg")
        set_minimum_size_policy(install_ffmepg_button)
        install_ffmepg_button.clicked.connect(
            lambda: TryInstallingFFmpegThread(self, anime_details).start()
        )
        anime_details.is_hls_download = False
        download_in_normal_mode = StyledButton(
            None, 25, "black", RED_NORMAL_COLOR, RED_HOVER_COLOR, RED_PRESSED_COLOR
        )
        download_in_normal_mode.clicked.connect(
            lambda: main_window.download_window.initiate_download_pipeline(
                anime_details
            )
        )
        download_in_normal_mode.clicked.connect(self.download_window_button.click)
        download_in_normal_mode.setText("Download in Normal mode")
        set_minimum_size_policy(download_in_normal_mode)
        self.buttons_layout.addWidget(download_in_normal_mode)
        self.buttons_layout.addWidget(install_ffmepg_button)


class TryInstallingFFmpegThread(QThread):
    initiate_download_pipeline = pyqtSignal(AnimeDetails)
    switch_to_download_window = pyqtSignal()

    def __init__(self, no_ffmpeg_window: NoFFmpegWindow, anime_details: AnimeDetails):
        super().__init__(no_ffmpeg_window)
        self.initiate_download_pipeline.connect(
            no_ffmpeg_window.main_window.download_window.initiate_download_pipeline
        )
        self.anime_details = anime_details
        self.switch_to_download_window.connect(
            no_ffmpeg_window.download_window_button.click
        )
        self.no_ffmpeg_window = no_ffmpeg_window

    def start_download(self):
        self.anime_details.is_hls_download = True
        self.initiate_download_pipeline.emit(self.anime_details)
        self.switch_to_download_window.emit()

    def run(self):
        if sys.platform == "win32":
            try:
                subprocess.run(
                    "winget install Gyan.FFmpeg",
                    creationflags=subprocess.CREATE_NEW_CONSOLE,
                )
            # I should probably catch the specific exceptions but I'm too lazy to figure out all the possible exceptions
            except Exception:
                pass
            if ffmpeg_is_installed():
                self.no_ffmpeg_window.main_window.tray_icon.make_notification(
                    "Successfully Installed", "FFmpeg", True, None
                )
                self.start_download()
            # Incase the installation was scuffed
            else:
                self.no_ffmpeg_window.main_window.tray_icon.make_notification(
                    "Installation Failed",
                    "Failed to automatically install FFmpeg, opening a guide on your browser uWu",
                    False,
                )
                open_new_tab(FFMPEG_WINDOWS_INSTALLATION_GUIDE)
        elif sys.platform == "linux":
            try:
                subprocess.run(
                    "sudo apt-get update && sudo apt-get install ffmpeg", shell=True
                )
            except Exception:
                pass
            if ffmpeg_is_installed():
                self.no_ffmpeg_window.main_window.tray_icon.make_notification(
                    "Successfully Installed", "FFmpeg", True, None
                )
                self.start_download()
            else:
                self.no_ffmpeg_window.main_window.tray_icon.make_notification(
                    "Failed to Automatically Install", "FFmpeg", False
                )
                open_new_tab(FFMPEG_LINUX_INSTALLATION_GUIDE)

        else:
            try:
                subprocess.run("brew install ffmpeg", shell=True)
            except Exception:
                pass
            if ffmpeg_is_installed():
                self.no_ffmpeg_window.main_window.tray_icon.make_notification(
                    "Successfully Installed", "FFmpeg", True, None
                )
                self.start_download()
            else:
                self.no_ffmpeg_window.main_window.tray_icon.make_notification(
                    "Failed to Automatically Install", "FFmpeg", False
                )
                open_new_tab(FFMPEG_MAC_INSTALLATION_GUIDE)


class UpdateWindow(AbstractWindow):
    def __init__(
        self,
        main_window: MainWindow,
        download_url: str,
        file_name: str,
        update_info: str,
    ):
        super().__init__(main_window, UPDATE_BCKG_IMAGE_PATH)
        main_widget = QWidget()
        main_layout = QVBoxLayout()
        self.progress_bar: ProgressBarWithButtons | None = None
        before_click_label = StyledLabel(font_size=20)
        before_click_label.setWordWrap(True)
        update_info_text_browser = StyledTextBrowser(font_size=20)
        update_info_text_browser.setMarkdown(update_info)
        update_info_text_browser.setMinimumWidth(500)
        update_info_text_browser.setMinimumHeight(300)


        main_layout.addWidget(
            update_info_text_browser, alignment=Qt.AlignmentFlag.AlignCenter
        )
        if sys.platform == "win32":
            before_click_label.setText(
                "Before you click the update button, ensure you don't have any active downloads cause Senpwai will restart"
            )
            set_minimum_size_policy(before_click_label)
            main_layout.addWidget(
                before_click_label, alignment=Qt.AlignmentFlag.AlignCenter
            )
            self.update_button = StyledButton(
                self,
                24,
                "black",
                RED_NORMAL_COLOR,
                RED_HOVER_COLOR,
                RED_PRESSED_COLOR,
                20,
            )
            self.update_button.setText("DOWNLOAD AND INSTALL UPDATE")
            set_minimum_size_policy(self.update_button)
            download_widget = QWidget()
            self.download_layout = QVBoxLayout()
            self.download_layout.addWidget(
                self.update_button, alignment=Qt.AlignmentFlag.AlignCenter
            )
            main_layout.addWidget(download_widget)
            download_widget.setLayout(self.download_layout)
            self.update_button.clicked.connect(
                DownloadUpdateThread(main_window, self, download_url, file_name).start
            )

        else:
            if sys.platform == "darwin":
                os_name = "Mac OS"
            else:
                os_name = "Linux OS"
            before_click_label.setText(
                f"\n{os_name} detected, you will have to build from source to update to the new version.\nThere is a guide on the README.md in the Github Repository.\n"
            )
            set_minimum_size_policy(before_click_label)
            main_layout.addWidget(before_click_label)
            github_button = IconButton(Icon(300, 100, GITHUB_ICON_PATH), 1.1)
            github_button.clicked.connect(lambda: open_new_tab(GITHUB_REPO_URL))
            github_button.setToolTip(GITHUB_REPO_URL)
            main_layout.addWidget(github_button, alignment=Qt.AlignmentFlag.AlignCenter)

        main_widget.setLayout(main_layout)
        main_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.full_layout.addWidget(main_widget, Qt.AlignmentFlag.AlignHCenter)
        self.setLayout(self.full_layout)

    def receive_total_size(self, size: int):
        pause_icon = Icon(40, 40, PAUSE_ICON_PATH)
        resume_icon = Icon(40, 40, RESUME_ICON_PATH)
        cancel_icon = Icon(40, 40, CANCEL_ICON_PATH)
        self.progress_bar = ProgressBarWithButtons(
            self,
            "Downloading",
            "update",
            size,
            "MB",
            IBYTES_TO_MBS_DIVISOR,
            pause_icon,
            resume_icon,
            cancel_icon,
            lambda: None,
            lambda: None,
        )
        self.download_layout.addWidget(self.progress_bar)
        self.update_button.hide()
        self.update_button.deleteLater()


class DownloadUpdateThread(QThread):
    update_bar = pyqtSignal(int)
    total_size = pyqtSignal(int)
    quit_app = pyqtSignal()

    def __init__(
        self,
        main_window: MainWindow,
        update_window: UpdateWindow,
        download_url: str,
        file_name: str,
    ):
        super().__init__(main_window)
        self.quit_app.connect(main_window.app.quit)
        self.download_url = download_url
        self.total_size.connect(update_window.receive_total_size)
        self.update_window = update_window
        self.file_name = file_name

    def run(self):
        response = CLIENT.get(self.download_url, stream=True)
        if response.status_code in RESOURCE_MOVED_STATUS_CODES:
            self.download_url = response.headers["Location"]
            response = CLIENT.get(self.download_url, stream=True)
        total_size = int(response.headers["Content-Length"])
        self.total_size.emit(total_size)
        self.update_window.progress_bar
        while not self.update_window.progress_bar:
            continue
        self.update_bar.connect(self.update_window.progress_bar.update_bar)
        file_name_no_ext, ext = os.path.splitext(self.file_name)
        download = Download(
            self.download_url,
            file_name_no_ext,
            SRC_DIRECTORY,
            self.update_bar.emit,
            ext,
        )
        self.update_window.progress_bar.pause_callback = download.pause_or_resume
        self.update_window.progress_bar.cancel_callback = download.cancel
        download.start_download()
        if not download.cancelled:
            subprocess.Popen([os.path.join(SRC_DIRECTORY, self.file_name), "/silent", "/update"])
            self.quit_app.emit()


class CheckIfUpdateAvailableThread(QThread):
    finished = pyqtSignal(tuple)

    def __init__(
        self,
        main_window: MainWindow,
        finished_callback: Callable[[tuple[bool, str, str, str]], Any],
    ):
        super().__init__(main_window)
        self.finished.connect(finished_callback)

    def run(self):
        self.finished.emit(update_available(GITHUB_API_LATEST_RELEASE_ENDPOINT, APP_NAME, VERSION))