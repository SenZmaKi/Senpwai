import os
from threading import Event
import time
from typing import Callable, cast, TYPE_CHECKING
from PyQt6.QtCore import QMutex, Qt, QThread, QTimer, pyqtSignal
from PyQt6.QtWidgets import (
    QHBoxLayout,
    QLayoutItem,
    QSpacerItem,
    QSystemTrayIcon,
    QVBoxLayout,
    QWidget,
)
from senpwai.common.tracker import check_tracked_anime
from senpwai.scrapers import gogo, pahe
from senpwai.common.classes import SETTINGS, AnimeDetails, get_max_part_size
from senpwai.common.scraper import (
    IBYTES_TO_MBS_DIVISOR,
    Download,
    ProgressFunction,
    ffmpeg_is_installed,
)
from senpwai.common.static import (
    CANCEL_ICON_PATH,
    DOWNLOAD_WINDOW_BCKG_IMAGE_PATH,
    DUB,
    MOVE_DOWN_QUEUE_ICON_PATH,
    MOVE_UP_QUEUE_ICON_PATH,
    PAHE,
    PAUSE_ICON_PATH,
    REMOVE_FROM_QUEUE_ICON_PATH,
    RESUME_ICON_PATH,
    open_folder,
)
from senpwai.common.widgets import (
    PYQT_MAX_INT,
    FolderButton,
    HorizontalLine,
    Icon,
    IconButton,
    OutlinedLabel,
    ProgressBarWithButtons,
    ProgressBarWithoutButtons,
    ScrollableSection,
    StyledButton,
    StyledLabel,
    set_minimum_size_policy,
)


from senpwai.windows.abstracts import AbstractWindow

# https://stackoverflow.com/questions/39740632/python-type-hinting-without-cyclic-imports/3957388#39757388
if TYPE_CHECKING:
    from senpwai.windows.main import MainWindow


class CurrentAgainstTotal(StyledLabel):
    def __init__(
        self, total: int, units: str, font_size=30, parent: QWidget | None = None
    ):
        super().__init__(parent, font_size)
        self.total = total
        self.current = 0
        self.units = units
        # This is to ensure that even when DownloadedEpisodeCount overwrides update_count, the parent's update count still gets called during parent class initialisation
        CurrentAgainstTotal.update_count(self, 0)

    def update_count(self, added: int):
        self.current += added
        total = self.total if self.total else "?"
        self.setText(f"{self.current}/{total} {self.units}")
        set_minimum_size_policy(self)
        self.update()


class HlsEstimatedSize(CurrentAgainstTotal):
    def __init__(self, download_window: "DownloadWindow", total_episode_count: int):
        super().__init__(0, "MBs", parent=download_window)
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
            self.total = round((new_current / count) * self.total_episode_count)
        super().update_count(0)


class DownloadedEpisodeCount(CurrentAgainstTotal):
    def __init__(
        self,
        download_window: "DownloadWindow",
        total_episodes: int,
        anime_title: str,
        anime_folder_path: str,
    ):
        self.download_window = download_window
        self.anime_folder_path = anime_folder_path
        self.anime_title = anime_title
        self.cancelled = False
        super().__init__(total_episodes, "eps", 30, download_window)

    def reinitialise(
        self, new_total: int, new_anime_title: str, new_anime_folder_path: str
    ):
        self.cancelled = False
        self.current = 0
        self.total = new_total
        self.anime_folder_path = new_anime_folder_path
        self.anime_title = new_anime_title
        super().update_count(0)

    def is_complete(self) -> bool:
        return self.current >= self.total

    def update_count(self, added: int):
        super().update_count(added)
        complete = self.is_complete()
        if complete and self.total != 0 and SETTINGS.allow_notifications:
            self.download_window.main_window.tray_icon.make_notification(
                "Download Complete",
                self.anime_title,
                True,
                lambda: open_folder(self.anime_folder_path),
            )
        if complete or self.cancelled:
            self.start_next_download()

    def start_next_download(self):
        queued_downloads_count = len(
            self.download_window.download_queue.get_queued_downloads()
        )
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
    def __init__(
        self,
        anime_details: AnimeDetails,
        progress_bar: ProgressBarWithoutButtons,
        download_queue: "DownloadQueue",
    ):
        super().__init__()
        label = StyledLabel(font_size=14)
        self.anime_details = anime_details
        self.progress_bar = progress_bar
        label.setText(anime_details.sanitised_title)
        set_minimum_size_policy(label)
        self.main_layout = QHBoxLayout()
        self.up_button = IconButton(download_queue.up_icon, 1.1, self)
        self.up_button.clicked.connect(
            lambda: download_queue.move_queued_download(self, "up")
        )
        self.down_button = IconButton(download_queue.down_icon, 1.1, self)
        self.down_button.clicked.connect(
            lambda: download_queue.move_queued_download(self, "down")
        )
        self.remove_button = IconButton(download_queue.remove_icon, 1.1, self)
        self.remove_button.clicked.connect(
            lambda: download_queue.remove_queued_download(self)
        )
        self.main_layout.addWidget(label)
        self.main_layout.addWidget(self.up_button)
        self.main_layout.addWidget(self.down_button)
        self.main_layout.addWidget(self.remove_button)
        self.main_layout.setAlignment(Qt.AlignmentFlag.AlignLeft)
        self.setLayout(self.main_layout)


class DownloadQueue(QWidget):
    def __init__(self, download_window: QWidget):
        super().__init__(download_window)
        label = OutlinedLabel(None, 1, 25)
        label.setStyleSheet(
            f"""
            OutlinedLabel {{
                color: #4169e1;
                font-size: 25px;
                font-family: {SETTINGS.font_family};
                    }}
                    """
        )
        label.setText("Download queue")
        main_layout = QVBoxLayout()
        main_layout.addWidget(label)
        self.queued_downloads_layout = QVBoxLayout()
        self.queued_downloads_scrollable = ScrollableSection(
            self.queued_downloads_layout
        )
        line = HorizontalLine(parent=self)
        line.setFixedHeight(6)
        main_layout.addWidget(line)
        main_layout.addWidget(self.queued_downloads_scrollable)
        self.setLayout(main_layout)
        self.up_icon = Icon(30, 30, MOVE_UP_QUEUE_ICON_PATH)
        self.down_icon = Icon(30, 30, MOVE_DOWN_QUEUE_ICON_PATH)
        self.remove_icon = Icon(30, 30, REMOVE_FROM_QUEUE_ICON_PATH)

    def remove_buttons_from_queued_download(self, queued_download: QueuedDownload):
        queued_download.main_layout.removeWidget(queued_download.up_button)
        queued_download.main_layout.removeWidget(queued_download.down_button)
        queued_download.main_layout.removeWidget(queued_download.remove_button)
        queued_download.up_button.deleteLater()
        queued_download.down_button.deleteLater()
        queued_download.remove_button.deleteLater()

    def add_queued_download(
        self, anime_details: AnimeDetails, progress_bar: ProgressBarWithoutButtons
    ):
        self.queued_downloads_layout.addWidget(
            QueuedDownload(anime_details, progress_bar, self),
            alignment=Qt.AlignmentFlag.AlignTop,
        )

    def move_queued_download(self, to_move: QueuedDownload, up_or_down="up"):
        queued_downloads = self.get_queued_downloads()
        for idx, queued in enumerate(queued_downloads):
            if queued == to_move:
                if up_or_down == "up" and idx - 1 > 0:
                    self.queued_downloads_layout.removeWidget(to_move)
                    self.queued_downloads_layout.insertWidget(idx - 1, to_move)
                elif up_or_down == "down" and idx + 1 < len(queued_downloads):
                    self.queued_downloads_layout.removeWidget(to_move)
                    self.queued_downloads_layout.insertWidget(idx + 1, to_move)

    def remove_queued_download(self, queued_download: QueuedDownload):
        for widget in self.get_queued_downloads():
            if widget == queued_download:
                self.queued_downloads_layout.removeWidget(widget)
                widget.deleteLater()

    def get_first_queued_download(self) -> QueuedDownload:
        first_queued_download = cast(
            QueuedDownload,
            cast(QLayoutItem, self.queued_downloads_layout.itemAt(0)).widget(),
        )
        return first_queued_download

    def remove_first_queued_download(self):
        wid = self.get_first_queued_download()
        self.queued_downloads_layout.removeWidget(wid)
        wid.deleteLater()

    def get_queued_downloads(self) -> list[QueuedDownload]:
        count = self.queued_downloads_layout.count()
        return [
            cast(
                QueuedDownload,
                cast(QLayoutItem, self.queued_downloads_layout.itemAt(index)).widget(),
            )
            for index in range(count)
        ]


class DownloadWindow(AbstractWindow):
    def __init__(self, main_window: "MainWindow"):
        super().__init__(main_window, DOWNLOAD_WINDOW_BCKG_IMAGE_PATH)
        self.main_window = main_window
        self.main_layout = QVBoxLayout()
        self.progress_bars_layout = QVBoxLayout()
        progress_bars_scrollable = ScrollableSection(self.progress_bars_layout)
        top_section_widget = QWidget()
        top_section_layout = QVBoxLayout()
        top_section_widget.setLayout(top_section_layout)
        first_row_of_progress_bar_widget = QWidget()
        self.first_row_of_progress_bar_layout = QHBoxLayout()
        first_row_of_progress_bar_widget.setLayout(
            self.first_row_of_progress_bar_layout
        )
        second_row_of_buttons_widget = QWidget()
        self.second_row_of_buttons_layout = QHBoxLayout()
        second_row_of_buttons_widget.setLayout(self.second_row_of_buttons_layout)
        top_section_layout.addWidget(first_row_of_progress_bar_widget)
        top_section_layout.addWidget(second_row_of_buttons_widget)
        self.main_layout.addWidget(top_section_widget)
        self.main_layout.addWidget(progress_bars_scrollable)
        main_widget = ScrollableSection(self.main_layout)
        self.full_layout.addWidget(main_widget)
        self.setLayout(self.full_layout)
        self.first_download_since_app_start = True
        self.current_anime_progress_bar: ProgressBarWithoutButtons
        self.hls_est_size: HlsEstimatedSize | None = None
        self.download_queue: DownloadQueue
        self.pause_button: PauseAllButton
        self.cancel_button: CancelAllButton
        self.folder_button: FolderButton
        self.downloaded_episode_count: DownloadedEpisodeCount
        self.tracked_download_timer = QTimer(self)
        self.tracked_download_timer.timeout.connect(self.start_tracked_download)
        self.setup_tracked_download_timer()
        self.tracked_download_thread: TrackedDownloadThread | None = None

    def is_downloading(self) -> bool:
        if self.first_download_since_app_start:
            return False
        if (
            self.downloaded_episode_count.is_complete()
            or self.downloaded_episode_count.cancelled
        ):
            return False
        return True

    def setup_tracked_download_timer(self):
        self.tracked_download_timer.stop()
        # Converting from hours to milliseconds
        tracking_interval_ms = SETTINGS.tracking_interval_hrs * 1000 * 60 * 60
        if tracking_interval_ms > PYQT_MAX_INT:
            tracking_interval_ms = PYQT_MAX_INT
        self.tracked_download_timer.start(tracking_interval_ms)

    def clean_out_tracked_download_thread(self):
        self.tracked_download_thread = None

    def start_tracked_download(self):
        # We only spawn a new thread if one wasn't already running to avoid overwriding the reference to the previous one causing it to get garbage collected/destroyed
        # Cause it can cause this error "QThread: Destroyed while thread is still running"
        if SETTINGS.tracked_anime and not self.tracked_download_thread:
            self.tracked_download_thread = TrackedDownloadThread(
                self,
                SETTINGS.tracked_anime,
                self.main_window.tray_icon,
                self.clean_out_tracked_download_thread,
            )
            self.tracked_download_thread.start()

    def initiate_download_pipeline(self, anime_details: AnimeDetails):
        if self.first_download_since_app_start:
            self.pause_icon = Icon(30, 30, PAUSE_ICON_PATH)
            self.resume_icon = Icon(30, 30, RESUME_ICON_PATH)
            self.cancel_icon = Icon(30, 30, CANCEL_ICON_PATH)
            self.download_queue = DownloadQueue(self)

        if anime_details.site == PAHE:
            return PaheGetEpisodePageInfo(
                self,
                anime_details.lacked_episodes[0],
                anime_details.lacked_episodes[-1],
                anime_details,
                self.pahe_get_episode_page_links,
            ).start()
        self.gogo_get_download_page_links(anime_details)

    def pahe_get_episode_page_links(
        self,
        anime_details: AnimeDetails,
        episode_pages_info: pahe.EpisodePagesInfo,
    ):
        episode_page_progress_bar = ProgressBarWithButtons(
            None,
            "Getting episode page links",
            "",
            episode_pages_info.total,
            "pgs",
            1,
            self.pause_icon,
            self.resume_icon,
            self.cancel_icon,
        )
        self.progress_bars_layout.insertWidget(0, episode_page_progress_bar)
        PaheGetEpisodePageLinksThread(
            self,
            anime_details,
            anime_details.lacked_episodes[0],
            anime_details.lacked_episodes[-1],
            episode_pages_info,
            self.pahe_get_download_page_links,
            episode_page_progress_bar,
        ).start()

    def gogo_get_download_page_links(self, anime_details: AnimeDetails):
        next_func = (
            self.gogo_get_hls_links
            if anime_details.is_hls_download
            else self.get_direct_download_links
        )
        return GogoGetDownloadPageLinksThread(self, anime_details, next_func).start()

    def pahe_get_download_page_links(
        self, anime_details: AnimeDetails, episode_page_links: list[str]
    ):
        episode_page_links = anime_details.get_lacked_links(episode_page_links)
        download_page_progress_bar = ProgressBarWithButtons(
            self,
            "Fetching download page links",
            "",
            len(episode_page_links),
            "eps",
            1,
            self.pause_icon,
            self.resume_icon,
            self.cancel_icon,
        )
        self.progress_bars_layout.insertWidget(0, download_page_progress_bar)
        PaheGetDownloadPageThread(
            self,
            anime_details,
            episode_page_links,
            self.get_direct_download_links,
            download_page_progress_bar,
        ).start()

    def gogo_get_hls_links(
        self, anime_details: AnimeDetails, episode_page_links: list[str]
    ):
        if not ffmpeg_is_installed():
            return self.main_window.create_and_switch_to_no_ffmpeg_window(anime_details)
        hls_links_progress_bar = ProgressBarWithButtons(
            self,
            "Retrieving hls links, this may take a while",
            "",
            len(episode_page_links),
            "eps",
            1,
            self.pause_icon,
            self.resume_icon,
            self.cancel_icon,
        )
        self.progress_bars_layout.insertWidget(0, hls_links_progress_bar)
        GetHlsLinksThread(
            self,
            episode_page_links,
            anime_details,
            hls_links_progress_bar,
            self.gogo_get_hls_matched_quality_links,
        ).start()

    def gogo_get_hls_matched_quality_links(
        self, anime_details: AnimeDetails, hls_links: list[str]
    ):
        match_progress_bar = ProgressBarWithButtons(
            self,
            "Matching quality to links",
            "",
            len(hls_links),
            "eps",
            1,
            self.pause_icon,
            self.resume_icon,
            self.cancel_icon,
        )
        self.progress_bars_layout.insertWidget(0, match_progress_bar)
        GogoHlsGetMatchedQualityLinksThread(
            self,
            hls_links,
            anime_details,
            match_progress_bar,
            self.gogo_hls_get_segments_urls,
        ).start()

    def gogo_hls_get_segments_urls(
        self, anime_details: AnimeDetails, matched_links: list[str]
    ):
        segments_progress_bar = ProgressBarWithButtons(
            self,
            "Getting segment links",
            "",
            len(matched_links),
            "eps",
            1,
            self.pause_icon,
            self.resume_icon,
            self.cancel_icon,
        )
        self.progress_bars_layout.insertWidget(0, segments_progress_bar)
        GogoHlsGetSegmentsUrlsThread(
            self,
            matched_links,
            anime_details,
            segments_progress_bar,
            self.queue_download,
        ).start()

    def get_direct_download_links(
        self,
        anime_details: AnimeDetails,
        download_page_links: list[str],
        download_info: list[list[str]],
    ):
        direct_download_links_progress_bar = ProgressBarWithButtons(
            self,
            "Retrieving direct download links, this may take a while",
            "",
            len(download_page_links),
            "eps",
            1,
            self.pause_icon,
            self.resume_icon,
            self.cancel_icon,
        )
        self.progress_bars_layout.insertWidget(0, direct_download_links_progress_bar)
        GetDirectDownloadLinksThread(
            self,
            download_page_links,
            download_info,
            anime_details,
            self.queue_download,
            direct_download_links_progress_bar,
        ).start()

    def queue_download(self, anime_details: AnimeDetails):
        anime_details.validate_anime_folder_path()
        if anime_details.is_hls_download:
            total_segments = sum(
                len(link_or_segs_urls)
                for link_or_segs_urls in anime_details.ddls_or_segs_urls
            )
            anime_progress_bar = ProgressBarWithoutButtons(
                self,
                "Downloading[HLS]",
                anime_details.sanitised_title,
                total_segments,
                "segs",
                1,
                False,
            )
        else:
            anime_progress_bar = ProgressBarWithoutButtons(
                self,
                "Downloading",
                anime_details.shortened_title,
                anime_details.total_download_size_mbs,
                "MB",
                1,
                False,
            )
        anime_progress_bar.bar.setMinimumHeight(50)

        self.download_queue.add_queued_download(anime_details, anime_progress_bar)
        if self.first_download_since_app_start:
            self.downloaded_episode_count = DownloadedEpisodeCount(
                self, 0, anime_details.sanitised_title, anime_details.anime_folder_path
            )

            set_minimum_size_policy(self.downloaded_episode_count)
            self.folder_button = FolderButton(
                anime_details.anime_folder_path, 100, 100, None
            )

            def download_is_active() -> bool:
                return not (
                    self.downloaded_episode_count.is_complete()
                    or self.downloaded_episode_count.cancelled
                )

            self.pause_button = PauseAllButton(download_is_active, self)
            self.cancel_button = CancelAllButton(self)
            set_minimum_size_policy(self.pause_button)
            set_minimum_size_policy(self.cancel_button)
            self.second_row_of_buttons_layout.addWidget(self.downloaded_episode_count)
            self.second_row_of_buttons_layout.addSpacerItem(QSpacerItem(50, 0))
            self.second_row_of_buttons_layout.addWidget(self.pause_button)
            self.second_row_of_buttons_layout.addWidget(self.cancel_button)
            self.second_row_of_buttons_layout.addSpacerItem(QSpacerItem(50, 0))
            self.second_row_of_buttons_layout.addWidget(self.folder_button)
            self.second_row_of_buttons_layout.addSpacerItem(QSpacerItem(50, 0))
            self.second_row_of_buttons_layout.addWidget(self.download_queue)
        if not self.pause_button.download_is_active():
            self.start_download()

    def clean_out_previous_download(self):
        if self.first_download_since_app_start:
            self.first_download_since_app_start = False
            return
        self.download_queue.remove_first_queued_download()
        self.first_row_of_progress_bar_layout.removeWidget(
            self.current_anime_progress_bar
        )
        self.current_anime_progress_bar.deleteLater()
        if self.hls_est_size:
            self.hls_est_size.deleteLater()
            self.hls_est_size = None

    def start_download(self):
        self.clean_out_previous_download()
        current_queued = self.download_queue.get_first_queued_download()
        self.download_queue.remove_buttons_from_queued_download(current_queued)
        anime_details = current_queued.anime_details
        is_hls_download = anime_details.is_hls_download
        if is_hls_download:
            self.hls_est_size = HlsEstimatedSize(
                self, len(anime_details.ddls_or_segs_urls)
            )
            self.second_row_of_buttons_layout.insertWidget(0, self.hls_est_size)
        self.current_anime_progress_bar = current_queued.progress_bar
        self.downloaded_episode_count.reinitialise(
            len(anime_details.ddls_or_segs_urls),
            anime_details.sanitised_title,
            cast(str, anime_details.anime_folder_path),
        )
        self.first_row_of_progress_bar_layout.addWidget(self.current_anime_progress_bar)
        current_download_manager_thread = DownloadManagerThread(
            self,
            anime_details,
            self.current_anime_progress_bar,
            self.downloaded_episode_count,
        )
        self.pause_button.pause_callback = (
            current_download_manager_thread.pause_or_resume
        )
        self.cancel_button.cancel_callback = current_download_manager_thread.cancel
        self.folder_button.set_folder_path(anime_details.anime_folder_path)
        current_download_manager_thread.start()

    def make_episode_progress_bar(
        self,
        episode_title: str,
        shortened_episode_title: str,
        episode_size_or_segs: int,
        progress_bars: dict[str, ProgressBarWithButtons],
        is_hls_download: bool,
    ):
        if is_hls_download:
            bar = ProgressBarWithButtons(
                None,
                "Downloading[HLS]",
                shortened_episode_title,
                episode_size_or_segs,
                "segs",
                1,
                self.pause_icon,
                self.resume_icon,
                self.cancel_icon,
            )
        else:
            bar = ProgressBarWithButtons(
                None,
                "Downloading",
                shortened_episode_title,
                episode_size_or_segs,
                "MB",
                IBYTES_TO_MBS_DIVISOR,
                self.pause_icon,
                self.resume_icon,
                self.cancel_icon,
            )
        progress_bars[episode_title] = bar
        self.progress_bars_layout.insertWidget(0, bar)


class DownloadManagerThread(QThread, ProgressFunction):
    send_progress_bar_details = pyqtSignal(str, str, int, dict, bool)
    update_anime_progress_bar_signal = pyqtSignal(int)

    def __init__(
        self,
        download_window: DownloadWindow,
        anime_details: AnimeDetails,
        anime_progress_bar: ProgressBarWithoutButtons,
        downloaded_episode_count: DownloadedEpisodeCount,
    ) -> None:
        QThread.__init__(self, download_window)
        ProgressFunction.__init__(self)
        self.anime_progress_bar = anime_progress_bar
        self.download_window = download_window
        self.downloaded_episode_count = downloaded_episode_count
        self.anime_details = anime_details
        self.update_anime_progress_bar_signal.connect(anime_progress_bar.update_bar)
        self.send_progress_bar_details.connect(
            download_window.make_episode_progress_bar
        )
        self.progress_bars: dict[str, ProgressBarWithButtons] = {}
        self.ongoing_downloads_count = 0
        self.download_slot_available = Event()
        self.download_slot_available.set()
        self.prev_bar = None
        self.mutex = QMutex()
        self.cancelled = False

    def pause_or_resume(self):
        if not self.cancelled:
            for bar in self.progress_bars.values():
                bar.pause_button.click()
            self.anime_progress_bar.pause_or_resume()
        ProgressFunction.pause_or_resume(self)

    def cancel(self):
        if self.resume.is_set() and not self.cancelled:
            for bar in self.progress_bars.values():
                bar.cancel_button.click()
            self.downloaded_episode_count.cancelled = True
            self.anime_progress_bar.cancel()
            ProgressFunction.cancel(self)

    def update_anime_progress_bar(self, added: int):
        if self.anime_details.is_hls_download:
            self.update_anime_progress_bar_signal.emit(added)
        else:
            added_rounded = round(added / IBYTES_TO_MBS_DIVISOR)
            self.update_anime_progress_bar_signal.emit(added_rounded)

    def clean_up_finished_download(self, episode_title: str):
        self.progress_bars.pop(episode_title)
        self.ongoing_downloads_count -= 1
        if self.ongoing_downloads_count < SETTINGS.max_simultaneous_downloads:
            self.download_slot_available.set()

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
                eps_size = round(os.path.getsize(eps_file_path) / IBYTES_TO_MBS_DIVISOR)
                hls_est_size.update_count(eps_size)

    def run(self):
        ddls_or_segs_urls = self.anime_details.ddls_or_segs_urls
        for idx, ddl_or_seg_urls in enumerate(ddls_or_segs_urls):
            self.download_slot_available.wait()
            shortened_episode_title = self.anime_details.episode_title(idx, True)
            episode_title = self.anime_details.episode_title(idx, False)
            if self.anime_details.is_hls_download:
                episode_size_or_segs = len(ddl_or_seg_urls)
            elif self.anime_details.download_sizes_bytes:
                episode_size_or_segs = self.anime_details.download_sizes_bytes[idx]
            else:
                (
                    episode_size_or_segs,
                    ddl_or_seg_urls,
                ) = Download.get_total_download_size(cast(str, ddl_or_seg_urls))

            # This is specifcally at this point instead of at the top cause of the above http request made in
            # self.get_exact_episode_size such that if a user pauses or cancels as the request is in progress the input will be captured
            self.resume.wait()
            if self.cancelled:
                break
            self.mutex.lock()
            self.send_progress_bar_details.emit(
                episode_title,
                shortened_episode_title,
                episode_size_or_segs,
                self.progress_bars,
                self.anime_details.is_hls_download,
            )
            self.mutex.unlock()
            while episode_title not in self.progress_bars:
                time.sleep(0.01)
                continue
            episode_progress_bar = self.progress_bars[episode_title]
            DownloadThread(
                self,
                ddl_or_seg_urls,
                episode_title,
                episode_size_or_segs,
                self.anime_details.site,
                self.anime_details.is_hls_download,
                self.anime_details.quality,
                self.anime_details.anime_folder_path,
                episode_progress_bar,
                self.clean_up_finished_download,
                self.anime_progress_bar,
                self.update_anime_progress_bar,
                self.update_eps_count_and_size,
                self.mutex,
            ).start()
            self.ongoing_downloads_count += 1
            if self.ongoing_downloads_count >= SETTINGS.max_simultaneous_downloads:
                self.download_slot_available.clear()


class DownloadThread(QThread):
    update_bars = pyqtSignal(int)
    finished = pyqtSignal(str)
    update_eps_count_and_hls_sizes = pyqtSignal(bool, str)

    def __init__(
        self,
        parent: DownloadManagerThread,
        ddl_or_seg_urls: str | list[str],
        title: str,
        size: int,
        site: str,
        is_hls_download: bool,
        hls_quality: str,
        download_folder: str,
        progress_bar: ProgressBarWithButtons,
        finished_callback: Callable,
        anime_progress_bar: ProgressBarWithoutButtons,
        update_anime_progress_bar: Callable,
        update_eps_count_and_hls_sizes: Callable,
        mutex: QMutex,
    ) -> None:
        super().__init__(parent)
        self.ddl_or_seg_urls = ddl_or_seg_urls
        self.title = title
        self.download_size = size
        self.download_folder = download_folder
        self.site = site
        self.hls_quality = hls_quality
        self.is_hls_download = is_hls_download
        self.progress_bar = progress_bar
        self.anime_progress_bar = anime_progress_bar
        self.update_bars.connect(self.progress_bar.update_bar)
        self.update_bars.connect(update_anime_progress_bar)
        self.finished.connect(finished_callback)
        self.update_eps_count_and_hls_sizes.connect(update_eps_count_and_hls_sizes)
        self.mutex = mutex
        self.download: Download
        self.is_cancelled = False

    def cancel(self):
        self.download.cancel()
        divisor = 1 if self.is_hls_download else IBYTES_TO_MBS_DIVISOR
        new_maximum = self.anime_progress_bar.bar.maximum() - round(
            self.download_size / divisor
        )
        if new_maximum > 0:
            self.anime_progress_bar.bar.setMaximum(new_maximum)
        new_value = round(
            self.anime_progress_bar.bar.value()
            - round(self.progress_bar.bar.value() / divisor)
        )
        if new_value < 0:
            new_value = 0
        self.anime_progress_bar.bar.setValue(new_value)
        self.is_cancelled = True

    def run(self):
        max_part_size = get_max_part_size(
            self.download_size, self.site, self.is_hls_download
        )
        self.download = Download(
            self.ddl_or_seg_urls,
            self.title,
            self.download_folder,
            self.download_size,
            lambda x: self.update_bars.emit(x),
            is_hls_download=self.is_hls_download,
            max_part_size=max_part_size,
        )
        self.progress_bar.pause_callback = self.download.pause_or_resume
        self.progress_bar.cancel_callback = self.cancel

        self.download.start_download()
        self.mutex.lock()
        self.finished.emit(self.title)
        self.update_eps_count_and_hls_sizes.emit(
            self.is_cancelled, self.download.file_path
        )
        self.mutex.unlock()


class GogoGetDownloadPageLinksThread(QThread):
    finished = pyqtSignal(AnimeDetails, list, list)
    hls_finished = pyqtSignal(AnimeDetails, list)

    def __init__(
        self,
        download_window: DownloadWindow,
        anime_details: AnimeDetails,
        callback: Callable[[AnimeDetails, list[str], list[list[str]]], None]
        | Callable[[AnimeDetails, list[str]], None],
    ):
        super().__init__(download_window)
        self.anime_details = anime_details
        self.hls_finished.connect(callback)
        self.finished.connect(callback)

    def run(self):
        if self.anime_details.sub_or_dub == DUB:
            (
                self.anime_details.anime_page_content,
                self.anime_details.anime.page_link,
            ) = gogo.get_anime_page_content(self.anime_details.dub_page_link)
        anime_id = gogo.extract_anime_id(self.anime_details.anime_page_content)
        download_page_links = gogo.get_download_page_links(
            self.anime_details.lacked_episodes[0],
            self.anime_details.lacked_episodes[-1],
            anime_id,
        )
        download_page_links = self.anime_details.get_lacked_links(
            download_page_links
        )
        if self.anime_details.is_hls_download:
            self.hls_finished.emit(self.anime_details, download_page_links)
        else:
            self.finished.emit(self.anime_details, download_page_links, [])


class PaheGetEpisodePageInfo(QThread):
    finished = pyqtSignal(AnimeDetails, pahe.EpisodePagesInfo)

    def __init__(
        self,
        download_window: DownloadWindow,
        start_episode: int,
        end_episode: int,
        anime_details: AnimeDetails,
        finished_callback: Callable[[AnimeDetails, pahe.EpisodePagesInfo], None],
    ):
        super().__init__(download_window)
        self.start_episode = start_episode
        self.end_episode = end_episode
        self.anime_details = anime_details
        self.finished.connect(finished_callback)

    def run(self):
        self.finished.emit(
            self.anime_details,
            pahe.get_episode_pages_info(
                self.anime_details.anime.page_link, self.start_episode, self.end_episode
            ),
        )


class PaheGetEpisodePageLinksThread(QThread):
    finished = pyqtSignal(AnimeDetails, list)
    update_bar = pyqtSignal(int)

    def __init__(
        self,
        parent,
        anime_details: AnimeDetails,
        start_episode: int,
        end_episode: int,
        episode_pages_info: pahe.EpisodePagesInfo,
        finished_callback: Callable[[AnimeDetails, list[str]], None],
        progress_bar: ProgressBarWithButtons,
    ):
        super().__init__(parent)
        self.anime_details = anime_details
        self.finished.connect(finished_callback)
        self.start_episode = start_episode
        self.episode_pages_info = episode_pages_info
        self.end_episode = end_episode
        self.progress_bar = progress_bar
        self.update_bar.connect(progress_bar.update_bar)

    def run(self):
        obj = pahe.GetEpisodePageLinks()
        self.progress_bar.pause_callback = obj.pause_or_resume
        self.progress_bar.cancel_callback = obj.cancel
        episode_page_links = obj.get_episode_page_links(
            self.start_episode,
            self.end_episode,
            self.episode_pages_info,
            self.anime_details.anime.page_link,
            cast(str, self.anime_details.anime.id),
            lambda x: self.update_bar.emit(x),
        )
        if not obj.cancelled:
            self.finished.emit(self.anime_details, episode_page_links)


class GetHlsLinksThread(QThread):
    finished = pyqtSignal(AnimeDetails, list)
    update_bar = pyqtSignal(int)

    def __init__(
        self,
        parent,
        episode_page_links: list[str],
        anime_details: AnimeDetails,
        progress_bar: ProgressBarWithButtons,
        finished_callback: Callable[[AnimeDetails, list[str]], None],
    ):
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
        hls_links = obj.get_hls_links(self.episode_page_links, self.update_bar.emit)
        if not obj.cancelled:
            self.finished.emit(self.anime_details, hls_links)


class GogoHlsGetMatchedQualityLinksThread(QThread):
    finished = pyqtSignal(AnimeDetails, list)
    update_bar = pyqtSignal(int)

    def __init__(
        self,
        parent,
        hls_links: list[str],
        anime_details: AnimeDetails,
        progress_bar: ProgressBarWithButtons,
        finished_callback: Callable[[AnimeDetails, list[str]], None],
    ):
        super().__init__(parent)
        self.hls_links = hls_links
        self.anime_details = anime_details
        self.progress_bar = progress_bar
        self.finished.connect(finished_callback)
        self.update_bar.connect(self.progress_bar.update_bar)

    def run(self):
        obj = gogo.GetHlsMatchedQualityLinks()
        self.progress_bar.pause_callback = obj.pause_or_resume
        self.progress_bar.cancel_callback = obj.cancel
        matched_links = obj.get_hls_matched_quality_links(
            self.hls_links, self.anime_details.quality, self.update_bar.emit
        )
        if not obj.cancelled:
            self.finished.emit(self.anime_details, matched_links)


class GogoHlsGetSegmentsUrlsThread(QThread):
    finished = pyqtSignal(AnimeDetails)
    update_bar = pyqtSignal(int)

    def __init__(
        self,
        parent,
        matched_links: list[str],
        anime_details: AnimeDetails,
        progress_bar: ProgressBarWithButtons,
        finished_callback: Callable[[AnimeDetails], None],
    ):
        super().__init__(parent)
        self.matched_links = matched_links
        self.anime_details = anime_details
        self.progress_bar = progress_bar
        self.finished.connect(finished_callback)
        self.update_bar.connect(self.progress_bar.update_bar)

    def run(self):
        obj = gogo.GetHlsSegmentsUrls()
        self.progress_bar.pause_callback = obj.pause_or_resume
        self.progress_bar.cancel_callback = obj.cancel
        self.anime_details.ddls_or_segs_urls = obj.get_hls_segments_urls(
            self.matched_links, self.update_bar.emit
        )
        if not obj.cancelled:
            self.finished.emit(self.anime_details)


class PaheGetDownloadPageThread(QThread):
    finished = pyqtSignal(AnimeDetails, list, list)
    update_bar = pyqtSignal(int)

    def __init__(
        self,
        parent,
        anime_details: AnimeDetails,
        episode_page_links: list[str],
        finished_callback: Callable[[AnimeDetails, list, list], None],
        progress_bar: ProgressBarWithButtons,
    ):
        super().__init__(parent)
        self.anime_details = anime_details
        self.episode_page_links = episode_page_links
        self.finished.connect(finished_callback)
        self.progress_bar = progress_bar
        self.update_bar.connect(progress_bar.update_bar)

    def run(self):
        obj = pahe.GetPahewinPageLinks()
        self.progress_bar.pause_callback = obj.pause_or_resume
        self.progress_bar.cancel_callback = obj.cancel
        d_page, d_info = obj.get_pahewin_page_links_and_info(
            self.episode_page_links, self.update_bar.emit
        )
        if not obj.cancelled:
            return self.finished.emit(self.anime_details, d_page, d_info)


class GetDirectDownloadLinksThread(QThread):
    finished = pyqtSignal(AnimeDetails)
    update_bar = pyqtSignal(int)

    def __init__(
        self,
        download_window: DownloadWindow,
        download_page_links: list[str] | list[list[str]],
        download_info: list[list[str]],
        anime_details: AnimeDetails,
        finished_callback: Callable[[AnimeDetails], None],
        progress_bar: ProgressBarWithButtons,
    ):
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
            bound_links, bound_info = pahe.bind_sub_or_dub_to_link_info(
                self.anime_details.sub_or_dub,
                cast(list[list[str]], self.download_page_links),
                self.download_info,
            )
            bound_links, bound_info = pahe.bind_quality_to_link_info(
                self.anime_details.quality, bound_links, bound_info
            )
            self.anime_details.download_info = bound_info
            obj = pahe.GetDirectDownloadLinks()
            self.progress_bar.pause_callback = obj.pause_or_resume
            self.progress_bar.cancel_callback = obj.cancel
            self.anime_details.ddls_or_segs_urls = obj.get_direct_download_links(
                bound_links, lambda x: self.update_bar.emit(x)
            )
            self.anime_details.total_download_size_mbs = (
                pahe.calculate_total_download_size(bound_info)
            )
        else:
            obj = gogo.GetDirectDownloadLinks()
            self.progress_bar.pause_callback = obj.pause_or_resume
            self.progress_bar.cancel_callback = obj.cancel
            (
                self.anime_details.ddls_or_segs_urls,
                download_sizes,
            ) = obj.get_direct_download_links(
                cast(list[str], self.download_page_links),
                self.anime_details.quality,
                lambda x: self.update_bar.emit(x),
            )
            self.anime_details.download_sizes_bytes = download_sizes
            self.anime_details.total_download_size_mbs = (
                sum(download_sizes) // IBYTES_TO_MBS_DIVISOR
            )

        if not obj.cancelled and len(self.anime_details.ddls_or_segs_urls) < len(
            self.download_page_links
        ):
            link_name = (
                "hls" if self.anime_details.is_hls_download else "direct download"
            )
            self.download_window.main_window.tray_icon.make_notification(
                "Error",
                f"Failed to retrieve some {link_name} links for {self.anime_details.sanitised_title}",
                False,
                None,
            )
        if not self.anime_details.ddls_or_segs_urls:
            return
        if not obj.cancelled:
            self.finished.emit(self.anime_details)


class TrackedDownloadThread(QThread):
    initate_download_pipeline = pyqtSignal(AnimeDetails)
    clean_out_tracked_download_thread_signal = pyqtSignal()

    def __init__(
        self,
        download_window: DownloadWindow,
        titles: list[str],
        tray_icon: QSystemTrayIcon,
        clean_out_tracked_download_thread_slot: Callable[[], None],
    ):
        super().__init__(download_window)
        self.anime_titles = titles
        self.download_window = download_window
        self.initate_download_pipeline.connect(
            self.download_window.initiate_download_pipeline
        )
        self.tray_icon = tray_icon
        self.clean_out_tracked_download_thread_signal.connect(
            clean_out_tracked_download_thread_slot
        )

    def run(self):
        check_tracked_anime(
            lambda title: self.download_window.main_window.settings_window.tracked_anime.remove_anime(
                title
            ),
            lambda sanitised_title: self.download_window.main_window.tray_icon.make_notification(
                "Finished Tracking",
                f"You have the final episode of {sanitised_title} and it has finished airing so I have removed it from your tracking list",
                True,
            ),
            lambda sanitised_title: self.download_window.main_window.tray_icon.make_notification(
                "Error",
                f"Failed to find dub for {sanitised_title}",
                False,
                None,
            ),
            lambda anime_details: self.initate_download_pipeline.emit(anime_details),
            lambda queued_anime_titles: self.download_window.main_window.tray_icon.make_notification(
                "Queued new episodes",
                queued_anime_titles,
                False,
                self.download_window.main_window.switch_to_download_window,
            ),
            True,
        )
        self.clean_out_tracked_download_thread_signal.emit()
