from PyQt6.QtGui import QIcon
from PyQt6.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QSystemTrayIcon, QSpacerItem
from PyQt6.QtCore import Qt, QThread, QMutex, pyqtSignal, pyqtSlot
from shared.global_vars_and_funcs import settings, KEY_MAKE_DOWNLOAD_COMPLETE_NOTIFICATION, KEY_MAX_SIMULTANEOUS_DOWNLOADS, KEY_GOGO_NORM_OR_HLS_MODE
from shared.global_vars_and_funcs import set_minimum_size_policy, download_complete_icon_path, remove_from_queue_icon_path, move_up_queue_icon_path, move_down_queue_icon_path
from shared.global_vars_and_funcs import PAHE, GOGO, DUB, downlaod_window_bckg_image_path, open_folder
from shared.app_and_scraper_shared import Download, IBYTES_TO_MBS_DIVISOR, network_error_retry_wrapper, PausableAndCancellableFunction, ffmpeg_is_installed
from windows.main_actual_window import MainWindow, Window
from shared.shared_classes_and_widgets import StyledLabel, StyledButton, ScrollableSection, ProgressBar, AnimeDetails, FolderButton, OutlinedLabel, IconButton, HorizontalLine, ErrorLabel
from typing import Callable, cast
from selenium.common.exceptions import WebDriverException
import os
import requests
from scrapers import gogo
from scrapers import pahe
from threading import Event


class CurrentAgainstTotal(StyledLabel):
    def __init__(self, total: int, units: str, font_size=30, parent: QWidget | None = None):
        super().__init__(parent, font_size)
        self.total = total
        self.current = 0
        self.units = units
        # This is to ensure that even DownloadedEpisodeCount overwrides update_count, the parent's update count still gets called during parent class initialisation
        CurrentAgainstTotal.update_count(self, 0)

    def update_count(self, added: int):
        self.current += added
        self.setText(f"{self.current}/{self.total} {self.units}")
        set_minimum_size_policy(self)
        self.update()


class HlsEstimatedSize(CurrentAgainstTotal):
    def __init__(self, download_window, total_episode_count: int):
        super().__init__(0, "MBs", parent=download_window)
        self.download_window = cast(Download, download_window)
        self.total_episode_count = total_episode_count
        self.current_episode_count = 0
        self.sizes_for_each_eps: list[int] = []

    def update_count(self, added: int):
        if added == 0:
            self.total -= self.current
            self.total_episode_count -= 1
        else:
            self.sizes_for_each_eps.append(added)
        count = len(self.sizes_for_each_eps)
        if count > 0:
            new_current = sum(self.sizes_for_each_eps)
            self.current = new_current
            self.total = round((new_current / count) *
                               self.total_episode_count)
        super().update_count(0)


class DownloadedEpisodeCount(CurrentAgainstTotal):
    def __init__(self, download_window, total_episodes: int, tray_icon: QSystemTrayIcon, anime_title: str,
                 download_complete_icon: QIcon, anime_folder_path: str):
        self.download_window = cast(DownloadWindow, download_window)
        self.download_window = download_window
        self.tray_icon = tray_icon
        self.anime_folder_path = anime_folder_path
        self.tray_icon.messageClicked.connect(
            lambda: open_folder(self.anime_folder_path))
        self.anime_title = anime_title
        self.download_complete_icon = download_complete_icon
        self.cancelled = False
        super().__init__(total_episodes, "eps", 30, download_window)

    def reinitialise(self, new_total: int, new_anime_title: str, new_anime_folder_path: str):
        self.cancelled = False
        self.current = 0
        self.total = new_total
        self.anime_folder_path = new_anime_folder_path
        self.anime_title = new_anime_title
        super().update_count(0)

    def download_complete_notification(self):
        self.tray_icon.showMessage(
            "Download Complete", self.anime_title, self.download_complete_icon)

    def is_complete(self) -> bool:
        return self.current >= self.total

    def update_count(self, added_episode_count: int):
        super().update_count(added_episode_count)
        complete = self.is_complete()
        if complete and self.total != 0 and cast(bool, settings[KEY_MAKE_DOWNLOAD_COMPLETE_NOTIFICATION]):
            self.download_complete_notification()
        if complete or self.cancelled:
            self.start_next_download()

    def start_next_download(self):
        queued_downloads_count = len(
            self.download_window.download_queue.get_queued_downloads())
        if queued_downloads_count > 1:
            self.download_window.start_download()


class CancelAllButton(StyledButton):
    def __init__(self, parent: QWidget | None = None):
        super().__init__(parent, 25, "white", "red", "#ED2B2A", "#990000")
        self.setText("CANCEL")
        self.cancel_callback: Callable = lambda: None
        self.clicked.connect(self.cancel)
        self.show()

    def cancel(self):
        self.cancel_callback()


class PauseAllButton(StyledButton):
    def __init__(self, download_is_active: Callable, parent: QWidget | None = None):
        super().__init__(parent, 25, "white", "#FFA41B", "#FFA756", "#F86F03")
        self.setText("PAUSE")
        self.pause_callback: Callable = lambda: None
        self.download_is_active = download_is_active
        self.not_paused_style_sheet = self.styleSheet()
        styles_to_overwride = """
                QPushButton {
                background-color: #FFA756;
            }
            QPushButton:hover {
                background-color: #FFA41B;
            }
            QPushButton:pressed {
                background-color: #F86F03;
            }
            """
        self.paused_style_sheet = self.not_paused_style_sheet + styles_to_overwride
        self.setStyleSheet(self.not_paused_style_sheet)
        self.paused = False
        self.clicked.connect(self.pause_or_resume)
        self.show()

    def pause_or_resume(self):
        if self.download_is_active():
            self.paused = not self.paused
            self.pause_callback()
            if self.paused:
                self.setText("RESUME")
                self.setStyleSheet(self.paused_style_sheet)

            elif not self.paused:
                self.setText("PAUSE")
                self.setStyleSheet(self.not_paused_style_sheet)
            self.update()
            set_minimum_size_policy(self)


class QueuedDownload(QWidget):
    def __init__(self, anime_details: AnimeDetails, progress_bar: ProgressBar, download_queue):
        super().__init__()
        label = StyledLabel(font_size=20)
        self.anime_details = anime_details
        self.progress_bar = progress_bar
        label.setText(anime_details.anime.title)
        set_minimum_size_policy(label)
        download_queue = cast(DownloadQueue, download_queue)
        self.main_layout = QHBoxLayout()
        icon_sizes = 35
        self.up_button = IconButton(
            icon_sizes, icon_sizes, move_up_queue_icon_path, 1.1)
        self.up_button.clicked.connect(
            lambda: download_queue.move_queued_download(self, "up"))
        self.down_button = IconButton(
            icon_sizes, icon_sizes, move_down_queue_icon_path, 1.1)
        self.down_button.clicked.connect(
            lambda: download_queue.move_queued_download(self, "down"))
        self.remove_button = IconButton(
            icon_sizes, icon_sizes, remove_from_queue_icon_path, 1.1)
        self.remove_button.clicked.connect(
            lambda: download_queue.remove_queued_download(self))
        self.main_layout.addWidget(label)
        self.main_layout.addWidget(self.up_button)
        self.main_layout.addWidget(self.down_button)
        self.main_layout.addWidget(self.remove_button)
        self.main_layout.setAlignment(Qt.AlignmentFlag.AlignLeft)
        self.setLayout(self.main_layout)


class DownloadQueue(QWidget):
    def __init__(self):
        super().__init__()
        label = OutlinedLabel(None, 1, 25)
        label.setStyleSheet("""
            OutlinedLabel {
                color: #4169e1;
                font-size: 25px;
                font-family: "Berlin Sans FB Demi";
                    }
                    """)
        label.setText("Download queue")
        main_layout = QVBoxLayout()
        main_layout.addWidget(label)
        self.queued_downloads_layout = QVBoxLayout()
        self.queued_downloads_scrollable = ScrollableSection(
            self.queued_downloads_layout)
        line = HorizontalLine()
        line.setFixedHeight(6)
        main_layout.addWidget(line)
        main_layout.addWidget(self.queued_downloads_scrollable)
        self.setLayout(main_layout)

    def remove_buttons_from_queued_download(self, queued_download: QueuedDownload):
        queued_download.main_layout.removeWidget(queued_download.up_button)
        queued_download.main_layout.removeWidget(queued_download.down_button)
        queued_download.main_layout.removeWidget(queued_download.remove_button)
        queued_download.up_button.deleteLater()
        queued_download.down_button.deleteLater()
        queued_download.remove_button.deleteLater()

    def add_queued_download(self, anime_details: AnimeDetails, progress_bar: ProgressBar):
        self.queued_downloads_layout.addWidget(
            QueuedDownload(anime_details, progress_bar, self))

    def move_queued_download(self, to_move: QueuedDownload, up_or_down="up"):
        queued_downloads = self.get_queued_downloads()
        for idx, queued in enumerate(queued_downloads):
            if queued == to_move:
                if up_or_down == "up" and idx-1 > 0:
                    self.queued_downloads_layout.removeWidget(to_move)
                    self.queued_downloads_layout.insertWidget(idx-1, to_move)
                elif up_or_down == "down" and idx+1 < len(queued_downloads):
                    self.queued_downloads_layout.removeWidget(to_move)
                    self.queued_downloads_layout.insertWidget(idx+1, to_move)

    def remove_queued_download(self, queued_download: QueuedDownload):
        for widget in self.get_queued_downloads():
            if widget == queued_download:
                self.queued_downloads_layout.removeWidget(widget)
                widget.deleteLater()

    def get_or_pop_first_queued_download(self, pop=False) -> QueuedDownload:
        first_queued_download = cast(
            QueuedDownload, self.queued_downloads_layout.itemAt(0).widget())
        if pop:
            self.queued_downloads_layout.removeWidget(first_queued_download)
        return first_queued_download

    def get_queued_downloads(self) -> list[QueuedDownload]:
        count = self.queued_downloads_layout.count()
        return [cast(QueuedDownload, self.queued_downloads_layout.itemAt(index).widget()) for index in range(count)]


class DownloadWindow(Window):
    def __init__(self, main_window: MainWindow):
        super().__init__(main_window, downlaod_window_bckg_image_path)
        self.main_window = main_window
        self.download_complete_icon = QIcon(download_complete_icon_path)
        self.tray_icon = main_window.tray_icon
        self.main_layout = QVBoxLayout()
        self.progress_bars_layout = QVBoxLayout()
        progress_bars_scrollable = ScrollableSection(self.progress_bars_layout)
        top_section_widget = QWidget()
        top_section_layout = QVBoxLayout()
        top_section_widget.setLayout(top_section_layout)
        first_row_of_progress_bar_widget = QWidget()
        self.first_row_of_progress_bar_layout = QHBoxLayout()
        first_row_of_progress_bar_widget.setLayout(
            self.first_row_of_progress_bar_layout)
        second_row_of_buttons_widget = QWidget()
        self.second_row_of_buttons_layout = QHBoxLayout()
        second_row_of_buttons_widget.setLayout(
            self.second_row_of_buttons_layout)
        top_section_layout.addWidget(first_row_of_progress_bar_widget)
        top_section_layout.addWidget(second_row_of_buttons_widget)
        self.main_layout.addWidget(top_section_widget)
        self.main_layout.addWidget(progress_bars_scrollable)
        main_widget = QWidget()
        main_widget.setLayout(self.main_layout)
        self.full_layout.addWidget(main_widget)
        self.setLayout(self.full_layout)
        self.download_queue = DownloadQueue()
        self.first_download_since_app_start = True
        self.current_anime_progress_bar: ProgressBar | None = None
        self.hls_download_note: StyledLabel | None = None
        self.hls_est_size: HlsEstimatedSize | None = None
        self.pause_button: PauseAllButton
        self.cancel_button: CancelAllButton
        self.folder_button: FolderButton
        self.downloaded_episode_count: DownloadedEpisodeCount

        # For testing purposes
        # from shared.shared_classes_and_widgets import Anime
        # from shared.global_vars_and_funcs import key_download_folder_paths
        # anime_details = AnimeDetails(Anime("Senyuu.", "https://animepahe.ru/api?m=release&id=37d42404-faa1-9362-64e2-975d2d8aa797",
        #                                     "37d42404-faa1-9362-64e2-975d2d8aa797"), pahe_name)
        # anime_details.anime_folder_path = settings[key_download_folder_paths][0] + "\\Senyuu."
        # anime_details.direct_download_links = ["https://eu-11.files.nextcdn.org/get/11/04/ab6a4a7cc486a31252b930e5391312e9782f4b928d6fb181c80d0a5aeba93fe7?file=AnimePahe_Senyuu._-_01_BD_360p_Final8.mp4&token=o_zmo_Pppl7eTIar9gZVFg&expires=1689874721"]
        # anime_details.predicted_episodes_to_download = [1]
        # anime_details.total_download_size = 5
        # self.queue_download(anime_details)

    def initiate_download_pipeline(self, anime_details: AnimeDetails):
        self.get_episode_page_links(anime_details)

    def get_episode_page_links(self, anime_details: AnimeDetails):
        count = pahe.get_total_episode_page_count(
            anime_details.anime.page_link) if anime_details.site == PAHE else 0
        episode_page_progress_bar = ProgressBar(
            None, "Getting episode page links", "", count, "pgs", 1)
        if anime_details.site == PAHE:
            self.progress_bars_layout.insertWidget(
                0, episode_page_progress_bar)
            return GetEpisodePageLinksThread(self, anime_details, anime_details.start_download_episode, anime_details.end_download_episode,
                                             lambda eps_links: self.get_download_page_links(eps_links, anime_details), episode_page_progress_bar).start()
        if anime_details.site == GOGO and anime_details.sub_or_dub == DUB and anime_details.dub_available:
            anime_details.anime.page_link = gogo.get_dub_anime_page_link(
                anime_details.anime.title)
        finished_callback = self.get_hls_links if anime_details.is_hls_download else self.get_download_page_links
        GetEpisodePageLinksThread(self, anime_details, anime_details.start_download_episode, anime_details.end_download_episode,
                                  lambda eps_links: finished_callback(eps_links, anime_details), episode_page_progress_bar).start()

    def get_download_page_links(self, episode_page_links: list[str], anime_details: AnimeDetails):
        if episode_page_links == []:
            return
        episode_page_links = [episode_page_links[eps-anime_details.start_download_episode]
                              for eps in anime_details.predicted_episodes_to_download]
        download_page_progress_bar = ProgressBar(
            self, "Fetching download page links", "", len(episode_page_links), "eps", 1)
        self.progress_bars_layout.insertWidget(0, download_page_progress_bar)
        GetDownloadPageThread(self, anime_details.site, episode_page_links, lambda down_pge_lnk, down_info: self.get_direct_download_links(
            down_pge_lnk, down_info, anime_details), download_page_progress_bar).start()

    def get_hls_links(self, episode_page_links: list[str], anime_details: AnimeDetails):
        if not ffmpeg_is_installed():
            return self.main_window.create_and_switch_to_no_ffmpeg_window()
        if episode_page_links == []:
            return
        episode_page_links = [episode_page_links[eps-anime_details.start_download_episode]
                              for eps in anime_details.predicted_episodes_to_download]
        hls_links_progress_bar = ProgressBar(
            self, "Fetching hls links, this may take a while", "", len(episode_page_links), "eps", 1)
        self.progress_bars_layout.insertWidget(0, hls_links_progress_bar)
        GetHlsLinksThread(self, episode_page_links, anime_details,
                          hls_links_progress_bar, lambda: self.queue_download(anime_details)).start()

    def get_direct_download_links(self, download_page_links: list[str], download_info: list[list[str]], anime_details: AnimeDetails):
        if download_page_links == []:
            return
        direct_download_links_progress_bar = ProgressBar(
            self, "Retrieving direct download links, this may take a while", "", len(download_page_links), "eps", 1)
        self.progress_bars_layout.insertWidget(
            0, direct_download_links_progress_bar)
        GetDirectDownloadLinksThread(self, download_page_links, download_info, anime_details, lambda status: self.check_link_status(status, anime_details, download_page_links),
                                     direct_download_links_progress_bar).start()

    def check_link_status(self, status: int, anime_details: AnimeDetails, download_page_links: list[str]):
        if status == 1 and anime_details.direct_download_links != []:
            self.calculate_download_size(anime_details)
        elif status == 2:
            self.main_window.create_and_switch_to_no_supported_browser_window(
                anime_details.anime.title)
        elif status == 3:
            self.main_window.create_and_switch_to_captcha_block_window(
                anime_details.anime.title, download_page_links)
        else:
            return

    def calculate_download_size(self, anime_details: AnimeDetails):
        calculating_download_size_progress_bar = ProgressBar(
            self, "Calcutlating total download size", "", len(anime_details.direct_download_links), "eps", 1)
        if anime_details.site == GOGO:
            self.progress_bars_layout.insertWidget(
                0, calculating_download_size_progress_bar)
            CalculateDownloadSizes(self, anime_details, lambda: self.queue_download(
                anime_details), calculating_download_size_progress_bar).start()
        elif anime_details.site == PAHE:
            CalculateDownloadSizes(self, anime_details, lambda: self.queue_download(
                anime_details),  calculating_download_size_progress_bar).start()

    def queue_download(self, anime_details: AnimeDetails):
        # Verification that the download about to be queued is valid in that the progress of the previous function wasn't cancelled resulting to a premature callback
        if anime_details.is_hls_download and len(anime_details.direct_download_links) == 0:
            return
        if not anime_details.is_hls_download and anime_details.total_download_size == 0:
            return

        if not anime_details.anime_folder_path:
            anime_details.anime_folder_path = os.path.join(
                anime_details.chosen_default_download_path, anime_details.sanitised_title)
            os.mkdir(anime_details.anime_folder_path)
        if anime_details.is_hls_download:
            anime_progress_bar = ProgressBar(
                self, "Downloading[HLS]", anime_details.anime.title, len(anime_details.direct_download_links), "eps", 1, False)
        else:
            anime_progress_bar = ProgressBar(
                self, "Downloading", anime_details.anime.title, anime_details.total_download_size, "MB", 1, False)
        anime_progress_bar.bar.setMinimumHeight(50)

        self.download_queue.add_queued_download(
            anime_details, anime_progress_bar)
        if self.first_download_since_app_start:
            self.downloaded_episode_count = DownloadedEpisodeCount(
                self, 0, self.tray_icon, anime_details.anime.title,
                self.download_complete_icon, anime_details.anime_folder_path)

            set_minimum_size_policy(self.downloaded_episode_count)
            self.folder_button = FolderButton(
                cast(str, ''), 120, 120, None)

            def download_is_active() -> bool: return not (self.downloaded_episode_count.is_complete()
                                                          or self.downloaded_episode_count.cancelled)
            self.pause_button = PauseAllButton(download_is_active, self)
            self.cancel_button = CancelAllButton(self)
            set_minimum_size_policy(self.pause_button)
            set_minimum_size_policy(self.cancel_button)
            space = QSpacerItem(50, 0)
            self.second_row_of_buttons_layout.addWidget(
                self.downloaded_episode_count)
            self.second_row_of_buttons_layout.addSpacerItem(space)
            self.second_row_of_buttons_layout.addWidget(self.pause_button)
            self.second_row_of_buttons_layout.addWidget(self.cancel_button)
            self.second_row_of_buttons_layout.addSpacerItem(space)
            self.second_row_of_buttons_layout.addWidget(self.folder_button)
            self.second_row_of_buttons_layout.addSpacerItem(space)
            self.second_row_of_buttons_layout.addWidget(self.download_queue)
        if not self.pause_button.download_is_active():
            self.start_download()

    def clean_out_previous_download(self):
        if self.first_download_since_app_start:
            self.first_download_since_app_start = False
        else:
            self.download_queue.get_or_pop_first_queued_download(pop=True)
        if self.current_anime_progress_bar:
            self.current_anime_progress_bar.deleteLater()
            self.first_row_of_progress_bar_layout.removeWidget(
                self.current_anime_progress_bar)
        if self.hls_download_note and self.hls_est_size:
            self.hls_download_note.deleteLater()
            self.hls_download_note = None
            self.hls_est_size.deleteLater()
            self.hls_est_size = None

    def start_download(self):
        self.clean_out_previous_download()
        current_queued = self.download_queue.get_or_pop_first_queued_download()
        self.download_queue.remove_buttons_from_queued_download(current_queued)
        anime_details = current_queued.anime_details
        is_hls_download = anime_details.is_hls_download
        if is_hls_download:
            self.hls_download_note = StyledLabel(self, 17)
            self.hls_download_note.setText(
                "This download is in HLS mode so you can't pause ongoing episode downloads\nand the progress bars only show progress of the episode download completion.")
            set_minimum_size_policy(self.hls_download_note)
            self.hls_est_size = HlsEstimatedSize(
                self, len(anime_details.direct_download_links))
            self.second_row_of_buttons_layout.insertWidget(
                0, self.hls_est_size)
            self.main_layout.insertWidget(
                1, self.hls_download_note, alignment=Qt.AlignmentFlag.AlignHCenter)
        self.current_anime_progress_bar = current_queued.progress_bar
        self.downloaded_episode_count.reinitialise(len(
            anime_details.direct_download_links), anime_details.anime.title, cast(str, anime_details.anime_folder_path))
        self.first_row_of_progress_bar_layout.addWidget(
            self.current_anime_progress_bar)
        current_download_manager_thread = DownloadManagerThread(
            self, anime_details, self.current_anime_progress_bar, self.downloaded_episode_count)
        self.pause_button.pause_callback = current_download_manager_thread.pause_or_resume
        self.cancel_button.cancel_callback = current_download_manager_thread.cancel
        self.folder_button.folder_path = cast(
            str, anime_details.anime_folder_path)
        current_download_manager_thread.start()

    @pyqtSlot(str, int, dict, bool)
    def receive_download_progress_bar_details(self, episode_title: str, episode_size: int, progress_bars: dict[str, ProgressBar], is_hls_download: bool):
        if is_hls_download:
            bar = ProgressBar(
                None, "Downloading[HLS]", episode_title, 1, "ep", 1)
            bar.pause_or_resume = lambda: None
        else:
            bar = ProgressBar(
                None, "Downloading", episode_title, episode_size, "MB", IBYTES_TO_MBS_DIVISOR)
        progress_bars[episode_title] = bar
        self.progress_bars_layout.insertWidget(0, bar)


class DownloadManagerThread(QThread, PausableAndCancellableFunction):
    send_progress_bar_details = pyqtSignal(str, int, dict, bool)
    update_anime_progress_bar = pyqtSignal(int)

    def __init__(self, download_window: DownloadWindow, anime_details: AnimeDetails, anime_progress_bar: ProgressBar, downloaded_episode_count: DownloadedEpisodeCount) -> None:
        QThread.__init__(self, download_window)
        PausableAndCancellableFunction.__init__(self)
        self.anime_progress_bar = anime_progress_bar
        self.download_window = download_window
        self.downloaded_episode_count = downloaded_episode_count
        self.anime_details = anime_details
        self.update_anime_progress_bar.connect(anime_progress_bar.update_bar)
        self.send_progress_bar_details.connect(
            download_window.receive_download_progress_bar_details)
        self.progress_bars: dict[str, ProgressBar] = {}
        self.ongoing_downloads_count = 0
        self.download_slot_available = Event()
        self.download_slot_available.set()
        self.prev_bar = None
        self.mutex = QMutex()
        self.cancelled = False

    def pause_or_resume(self):
        if not self.anime_details.is_hls_download and not self.cancelled:
            for bar in self.progress_bars.values():
                bar.pause_button.click()
            self.anime_progress_bar.pause_or_resume()
        PausableAndCancellableFunction.pause_or_resume(self)

    def cancel(self):
        if self.resume.is_set() and not self.cancelled:
            for bar in self.progress_bars.values():
                bar.cancel_button.click()
            self.downloaded_episode_count.cancelled = True
            self.anime_progress_bar.cancel()
            PausableAndCancellableFunction.cancel(self)

    @pyqtSlot(int)
    def handle_updating_anime_progress_bar(self, added: int):
        # Rounded cause download size is accurate to MBs in animepahe but the same is applied to gogoanime to make everything more streamlined
        if self.anime_details.is_hls_download:
            self.update_anime_progress_bar.emit(added)
        else:
            added_rounded = round(added / IBYTES_TO_MBS_DIVISOR)
            self.update_anime_progress_bar.emit(added_rounded)

    @pyqtSlot(str)
    def clean_up_finished_download(self, episode_title: str):
        self.progress_bars.pop(episode_title)
        self.ongoing_downloads_count -= 1
        if self.ongoing_downloads_count < cast(int, settings[KEY_MAX_SIMULTANEOUS_DOWNLOADS]):
            self.download_slot_available.set()

    @pyqtSlot(bool, str)
    def update_eps_count_and_size(self, is_cancelled: bool, eps_file_path: str):
        hls_est_size = self.download_window.hls_est_size
        if is_cancelled:
            if not self.downloaded_episode_count.cancelled:
                self.downloaded_episode_count.total -= 1
            self.downloaded_episode_count.update_count(0)
            if hls_est_size:
                hls_est_size.update_count(0)
        else:
            self.downloaded_episode_count.update_count(1)
            if hls_est_size:
                eps_size = round(os.path.getsize(
                    eps_file_path) / IBYTES_TO_MBS_DIVISOR)
                hls_est_size.update_count(eps_size)
    # Gogo's direct download link sometimes doesn't work, it returns a 302 status code meaning the resource has been moved, this attempts to redirect to that link
    # It is applied to Pahe too just in case and to make everything streamlined

    def gogo_check_if_valid_link(self, link: str) -> tuple[str, requests.Response | None]:
        response = cast(requests.Response, network_error_retry_wrapper(
            lambda: requests.get(link, stream=True)))
        if response.status_code in (301, 302, 307, 308):
            possible_valid_redirect_link = response.headers.get("location", "")
            return self.gogo_check_if_valid_link(possible_valid_redirect_link) if possible_valid_redirect_link != "" else (link, None)
        try:
            response.headers['content-length']
        except KeyError:
            response = None

        return link, response

    def get_exact_episode_size(self, link: str) -> tuple[str, int]:
        link, response = self.gogo_check_if_valid_link(link)
        return (link, int(response.headers['content-length'])) if response else (link, 0)

    def run(self):
        for idx, link in enumerate(self.anime_details.direct_download_links):
            self.download_slot_available.wait()
            episode_number = str(
                self.anime_details.predicted_episodes_to_download[idx]).zfill(2)
            episode_title = f"{self.anime_details.sanitised_title} E{episode_number}"
            if self.anime_details.is_hls_download:
                download_size = 1
            else:
                link, download_size = self.get_exact_episode_size(link)
                if download_size == 0:
                    continue
            self.resume.wait()
            if self.cancelled:
                break
            self.mutex.lock()
            self.send_progress_bar_details.emit(
                episode_title, download_size, self.progress_bars, self.anime_details.is_hls_download)
            self.mutex.unlock()
            while episode_title not in self.progress_bars:
                continue
            episode_progress_bar = self.progress_bars[episode_title]
            if self.anime_details.is_hls_download:
                episode_progress_bar.pause_button.hide()
            # This is specifcally at this point instead of at the top cause of the above http request made in self.get_exact_episode_size such that if a user pauses or cancels as the request is in progress the pause will be captured
            DownloadThread(self, link, episode_title, download_size, self.anime_details.site, self.anime_details.is_hls_download, self.anime_details.quality, cast(str, self.anime_details.anime_folder_path),
                           episode_progress_bar, self.clean_up_finished_download,
                           self.anime_progress_bar, self.handle_updating_anime_progress_bar, self.update_eps_count_and_size, self.mutex).start()
            self.ongoing_downloads_count += 1
            if self.ongoing_downloads_count >= cast(int, settings[KEY_MAX_SIMULTANEOUS_DOWNLOADS]):
                self.download_slot_available.clear()


class DownloadThread(QThread):
    update_bars = pyqtSignal(int)
    finished = pyqtSignal(str)
    update_eps_count_and_hls_sizes = pyqtSignal(bool, str)

    def __init__(self, parent: DownloadManagerThread, link: str, title: str, size: int, site: str, is_hls_download: bool, hls_quality: str, download_folder: str,  progress_bar: ProgressBar,
                 finished_callback: Callable, anime_progress_bar: ProgressBar, handle_updating_anime_progress_bar: Callable,
                 update_eps_count_and_hls_sizes: Callable, mutex: QMutex) -> None:
        super().__init__(parent)
        self.link = link
        self.title = title
        self.size = size
        self.download_folder = download_folder
        self.site = site
        self.hls_quality = hls_quality
        self.is_hls_download = is_hls_download
        self.progress_bar = progress_bar
        self.finished.connect(finished_callback)
        self.anime_progress_bar = anime_progress_bar
        self.update_bars.connect(handle_updating_anime_progress_bar)
        self.update_bars.connect(self.progress_bar.update_bar)
        self.update_eps_count_and_hls_sizes.connect(
            update_eps_count_and_hls_sizes)
        self.mutex = mutex
        self.download: Download
        self.is_cancelled = False

    def cancel(self):
        self.download.cancel()
        divisor = 1 if self.is_hls_download else IBYTES_TO_MBS_DIVISOR
        new_maximum = self.anime_progress_bar.bar.maximum() - round(self.size /
                                                                    divisor)
        if new_maximum > 0:
            self.anime_progress_bar.bar.setMaximum(new_maximum)
        new_value = round(self.anime_progress_bar.bar.value(
        ) - round(self.progress_bar.bar.value() / divisor))
        if new_value < 0:
            new_value = 0
        self.anime_progress_bar.bar.setValue(new_value)
        self.is_cancelled = True

    def run(self):
        if self.is_hls_download:
            self.download = Download(
                self.link, self.title, self.download_folder, is_hls_download=True, hls_quality=self.hls_quality
            )
        else:
            self.download = Download(
                self.link, self.title, self.download_folder, lambda x: self.update_bars.emit(x))
            self.progress_bar.pause_callback = self.download.pause_or_resume
        self.progress_bar.cancel_callback = self.cancel

        self.download.start_download()
        self.mutex.lock()
        if self.is_hls_download and not self.is_cancelled:
            self.update_bars.emit(1)
        self.finished.emit(self.title)
        self.update_eps_count_and_hls_sizes.emit(
            self.is_cancelled, self.download.file_path)
        self.mutex.unlock()


class GetEpisodePageLinksThread(QThread):
    finished = pyqtSignal(list)
    update_bar = pyqtSignal(int)

    def __init__(self, parent, anime_details: AnimeDetails, start_episode: int, end_episode: int, finished_callback: Callable, progress_bar: ProgressBar):
        super().__init__(parent)
        self.anime_details = anime_details
        self.finished.connect(
            lambda episode_page_links: finished_callback(episode_page_links))
        self.start_episode = start_episode
        self.progress_bar = progress_bar
        self.end_index = end_episode
        self.update_bar.connect(progress_bar.update_bar)

    def run(self):
        if self.anime_details.site == PAHE:
            obj = pahe.GetEpisodePageLinks()
            self.progress_bar.pause_callback = obj.pause_or_resume
            self.progress_bar.cancel_callback = obj.cancel
            self.finished.emit(obj.get_episode_page_links(self.start_episode, self.end_index, self.anime_details.anime.page_link, cast(
                str, self.anime_details.anime.id), lambda x: self.update_bar.emit(x)))
        elif self.anime_details.site == GOGO:
            episode_page_links = gogo.generate_episode_page_links(
                self.start_episode, self.end_index, self.anime_details.anime.page_link)
            self.finished.emit(episode_page_links)


class GetHlsLinksThread(QThread):
    finished = pyqtSignal()
    update_bar = pyqtSignal(int)

    def __init__(self, parent, episode_page_links: list[str], anime_details: AnimeDetails, progress_bar: ProgressBar, finished_callback: Callable):
        super().__init__(parent)
        self.anime_details = anime_details
        self.episode_page_links = episode_page_links
        self.progress_bar = progress_bar
        self.finished.connect(finished_callback)
        self.update_bar.connect(self.progress_bar.update_bar)

    def run(self):
        obj = gogo.GetHlsLinks()
        self.progress_bar.pause_callback = obj.pause_or_resume
        self.progress_bar.cancel_callback = obj.cancel
        self.anime_details.direct_download_links = obj.get_hls_links(
            self.episode_page_links, self.update_bar.emit)
        self.finished.emit()


class GetDownloadPageThread(QThread):
    finished = pyqtSignal(list, list)
    update_bar = pyqtSignal(int)

    def __init__(self, parent, site: str, episode_page_links: list[str], finished_callback: Callable, progress_bar: ProgressBar):
        super().__init__(parent)
        self.site = site
        self.episode_page_links = episode_page_links
        self.finished.connect(lambda download_page_links, download_info: finished_callback(
            download_page_links, download_info))
        self.progress_bar = progress_bar
        self.update_bar.connect(progress_bar.update_bar)

    def run(self):
        if self.site == PAHE:
            obj = pahe.GetPahewinDownloadPage()
            self.progress_bar.pause_callback = obj.pause_or_resume
            self.progress_bar.cancel_callback = obj.cancel
            self.finished.emit(
                *obj.get_pahewin_download_page_links_and_info(self.episode_page_links, self.update_bar.emit))
        elif self.site == GOGO:
            obj = gogo.GetDownloadPageLinks()
            self.progress_bar.pause_callback = obj.pause_or_resume
            self.progress_bar.cancel_callback = obj.cancel
            self.finished.emit(obj.get_download_page_links(
                self.episode_page_links, lambda x: self.update_bar.emit(x)), [])


class GetDirectDownloadLinksThread(QThread):
    finished = pyqtSignal(int)
    update_bar = pyqtSignal(int)

    def __init__(self, download_window: DownloadWindow, download_page_links: list[str] | list[list[str]], download_info: list[list[str]], anime_details: AnimeDetails,
                 finished_callback: Callable, progress_bar: ProgressBar):
        super().__init__(download_window)
        self.download_window = download_window
        self.download_page_links = download_page_links
        self.download_info = download_info
        self.anime_details = anime_details
        self.finished.connect(finished_callback)
        self.progress_bar = progress_bar
        self.update_bar.connect(progress_bar.update_bar)

    def run(self):
        if self.anime_details.site == PAHE:
            bound_links, bound_info = pahe.bind_sub_or_dub_to_link_info(self.anime_details.sub_or_dub, cast(
                list[list[str]], self.download_page_links), self.download_info)
            bound_links, bound_info = pahe.bind_quality_to_link_info(
                self.anime_details.quality, bound_links, bound_info)
            self.anime_details.download_info = bound_info
            obj = pahe.GetDirectDownloadLinks()
            self.progress_bar.pause_callback = obj.pause_or_resume
            self.progress_bar.cancel_callback = obj.cancel
            self.anime_details.direct_download_links = obj.get_direct_download_links(
                bound_links, lambda x: self.update_bar.emit(x))
            self.finished.emit(1)
        elif self.anime_details.site == GOGO:
            driver = None
            try:
                # For testing purposes
                # raise WebDriverException
                # raise TimeoutError
                driver = gogo.setup_headless_browser(
                    self.anime_details.browser)
                obj = gogo.GetDirectDownloadLinks()
                self.progress_bar.pause_callback = obj.pause_or_resume
                self.progress_bar.cancel_callback = obj.cancel
                self.anime_details.direct_download_links = obj.get_direct_download_link_as_per_quality(cast(list[str], self.download_page_links), self.anime_details.quality,
                                                                                                       driver, lambda x: self.update_bar.emit(x))
                self.finished.emit(1)
            except Exception as exception:
                if isinstance(exception, WebDriverException):
                    self.finished.emit(2)
                elif isinstance(exception, TimeoutError):
                    self.finished.emit(3)
            finally:
                if driver:
                    driver.quit()


class CalculateDownloadSizes(QThread):
    finished = pyqtSignal()
    update_bar = pyqtSignal(int)

    def __init__(self, parent: QWidget, anime_details: AnimeDetails, finished_callback: Callable, progress_bar: ProgressBar):
        super().__init__(parent)
        self.anime_details = anime_details
        self.finished.connect(finished_callback)
        self.progress_bar = progress_bar
        self.update_bar.connect(progress_bar.update_bar)

    def run(self):
        if self.anime_details.site == GOGO:
            obj = gogo.CalculateTotalDowloadSize()
            self.progress_bar.pause_callback = obj.pause_or_resume
            self.progress_bar.cancel_callback = obj.cancel
            self.anime_details.total_download_size = obj.calculate_total_download_size(
                self.anime_details.direct_download_links, lambda x: self.update_bar.emit(x), True)
        elif self.anime_details.site == PAHE:
            self.anime_details.total_download_size = pahe.calculate_total_download_size(
                self.anime_details.download_info)
        self.finished.emit()
