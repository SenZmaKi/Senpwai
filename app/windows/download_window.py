from PyQt6.QtGui import QIcon
from PyQt6.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QSystemTrayIcon
from PyQt6.QtCore import QObject, QThread, QMutex, pyqtSignal, pyqtSlot
from shared.global_vars_and_funcs import settings, key_make_download_complete_notification, key_max_simulataneous_downloads
from shared.global_vars_and_funcs import set_minimum_size_policy, download_complete_icon_path
from shared.global_vars_and_funcs import pahe_name, gogo_name, dub, downlaod_window_bckg_image_path
from shared.app_and_scraper_shared import Download, ibytes_to_mbs_divisor, network_monad
from windows.main_actual_window import MainWindow, Window
from shared.shared_classes_and_widgets import StyledLabel, StyledButton, ScrollableSection, DownloadProgressBar, ProgressBar, AnimeDetails, FolderButton
from typing import Callable, cast
from selenium.common.exceptions import WebDriverException
import os
import requests
from scrapers import gogo
from scrapers import pahe


class DownloadedEpisodeCount(StyledLabel):
    def __init__(self, parent, total_episodes: int, tray_icon: QSystemTrayIcon, anime_title: str,
                 download_complete_icon: QIcon, anime_folder_path: str):
        super().__init__(parent, 30)
        self.total_episodes = total_episodes
        self.current_episodes = 0
        self.tray_icon = tray_icon
        if settings[key_make_download_complete_notification]:
            self.tray_icon.messageClicked.connect(
                lambda: os.startfile(anime_folder_path))
        self.anime_title = anime_title
        self.download_complete_icon = download_complete_icon
        self.setText(f"{0}/{total_episodes} eps")
        self.show()

    def download_complete_notification(self):
        self.tray_icon.showMessage(
            "Download Complete", self.anime_title, self.download_complete_icon)

    def is_complete(self) -> bool:
        return self.current_episodes >= self.total_episodes

    def is_cancelled(self) -> bool:
        return self.total_episodes <= 0

    def update(self, added_episode_count: int):
        self.current_episodes += added_episode_count
        self.setText(f"{self.current_episodes}/{self.total_episodes} eps")
        if self.is_complete and not self.is_cancelled:
            self.download_complete_notification()
        super().update()
        set_minimum_size_policy(self)


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


class DownloadWindow(Window):
    def __init__(self, main_window: MainWindow):
        super().__init__(main_window, downlaod_window_bckg_image_path)
        self.main_window = main_window
        self.download_complete_icon = QIcon(download_complete_icon_path)
        self.tray_icon = main_window.tray_icon
        main_layout = QVBoxLayout()
        progress_bars_widget = QWidget()
        self.progress_bars_layout = QVBoxLayout()
        """
            Careful now DONT CHANGE THE ORDERING BELOW
            Without maintaining a reference to ScrollableSection by assigning it to a variable, the garbage COllector deletes it and since it's the last known father
            to self.progress_bars_layout, self.progress_bars_layout also gets deleted resulting to a RuntimeError. 
            The same behaviour is experienced if we assign ScrollableSection to a variable but make the assignment after we call progress_bars_widget.setLayout(self.progress_bars_layout), 
            since the last known father is the what the variable but it gets out of scope when we leave the __init__ hence the same crash just that it happens later on when we try to reference self.progress_bars_layout
        """
        _ = ScrollableSection(self.progress_bars_layout)
        progress_bars_widget.setLayout(self.progress_bars_layout)
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
        main_layout.addWidget(top_section_widget)
        main_layout.addWidget(progress_bars_widget)
        main_widget = QWidget()
        main_widget.setLayout(main_layout)
        self.full_layout.addWidget(main_widget)
        self.setLayout(self.full_layout)

    def get_episode_page_links(self, anime_details: AnimeDetails):
        if anime_details.site == pahe_name:
            episode_page_progress_bar = ProgressBar(
                None, "Getting episode page links", "", pahe.get_total_episode_page_count(anime_details.anime.page_link), "pgs")
            self.progress_bars_layout.insertWidget(
                0, episode_page_progress_bar)
            return GetEpisodePageLinksThread(self, anime_details, anime_details.start_download_episode, anime_details.end_download_episode,
                                             lambda eps_links: self.get_download_page_links(eps_links, anime_details), episode_page_progress_bar.update).start()
        if anime_details.site == gogo_name and anime_details.sub_or_dub == dub and anime_details.dub_available:
            anime_details.anime.page_link = gogo.get_dub_anime_page_link(
                anime_details.anime.title)
        GetEpisodePageLinksThread(self, anime_details, anime_details.start_download_episode, anime_details.end_download_episode,
                                  lambda eps_links: self.get_download_page_links(eps_links, anime_details), lambda x: None).start()

    def get_download_page_links(self, episode_page_links: list[str], anime_details: AnimeDetails):
        episode_page_links = [episode_page_links[eps-anime_details.start_download_episode]
                              for eps in anime_details.predicted_episodes_to_download]
        download_page_progress_bar = ProgressBar(
            self, "Fetching download page links", "", len(episode_page_links), "eps")
        self.progress_bars_layout.insertWidget(0, download_page_progress_bar)
        GetDownloadPageThread(self, anime_details.site, episode_page_links, lambda down_pge_lnk, down_info: self.get_direct_download_links(
            down_pge_lnk, down_info, anime_details), download_page_progress_bar.update).start()

    def get_direct_download_links(self, download_page_links: list[str], download_info: list[list[str]], anime_details: AnimeDetails):
        direct_download_links_progress_bar = ProgressBar(
            self, "Retrieving direct download links", "", len(download_page_links), "eps")
        self.progress_bars_layout.insertWidget(
            0, direct_download_links_progress_bar)
        GetDirectDownloadLinksThread(self, download_page_links, download_info, anime_details, lambda status: self.check_link_status(status, anime_details, download_page_links),
                                     direct_download_links_progress_bar.update).start()

    def check_link_status(self, status: int, anime_details: AnimeDetails, download_page_links: list[str]):
        if status == 1:
            self.calculate_download_size(anime_details)
        elif status == 2:
            self.main_window.create_and_switch_to_no_supported_browser_window(
                anime_details.anime.title)
        elif status == 3:
            self.main_window.create_and_switch_to_captcha_block_window(
                anime_details.anime.title, download_page_links)

    def calculate_download_size(self, anime_details: AnimeDetails):
        if anime_details.site == gogo_name:
            calculating_download_size_progress_bar = ProgressBar(
                self, "Calcutlating total download size", "", len(anime_details.direct_download_links), "eps")
            self.progress_bars_layout.insertWidget(
                0, calculating_download_size_progress_bar)
            CalculateDownloadSizes(self, anime_details, lambda: self.start_download(
                anime_details), calculating_download_size_progress_bar.update).start()
        elif anime_details.site == pahe_name:
            CalculateDownloadSizes(self, anime_details, lambda: self.start_download(
                anime_details), lambda x: None).start()

    def start_download(self, anime_details: AnimeDetails):
        if not anime_details.anime_folder_path:
            anime_details.anime_folder_path = os.path.join(
                anime_details.chosen_default_download_path, anime_details.sanitised_title)
            os.mkdir(anime_details.anime_folder_path)
        anime_progress_bar = DownloadProgressBar(
            None, "Downloading", anime_details.anime.title, anime_details.total_download_size, "MB", 1, False)
        anime_progress_bar.bar.setMinimumHeight(50)
        self.first_row_of_progress_bar_layout.addWidget(anime_progress_bar)
        downloaded_episode_count = DownloadedEpisodeCount(None, len(anime_details.predicted_episodes_to_download), self.tray_icon,
                                                          anime_details.anime.title, self.download_complete_icon, anime_details.anime_folder_path)

        def download_is_active(): return not downloaded_episode_count.is_complete(
        ) or not downloaded_episode_count.is_cancelled()
        set_minimum_size_policy(downloaded_episode_count)
        folder_button = FolderButton(
            cast(str, anime_details.anime_folder_path), 120, 120, None)
        self.current_download = DownloadManagerThread(
            self, anime_details, anime_progress_bar, downloaded_episode_count)
        pause_button = PauseAllButton(download_is_active)
        pause_button.pause_callback = self.current_download.pause_or_resume
        pause_button.download_is_active = download_is_active
        set_minimum_size_policy(pause_button)
        cancel_button = CancelAllButton()
        cancel_button.cancel_callback = self.current_download.cancel
        set_minimum_size_policy(cancel_button)
        self.second_row_of_buttons_layout.addWidget(downloaded_episode_count)
        self.second_row_of_buttons_layout.addWidget(pause_button)
        self.second_row_of_buttons_layout.addWidget(cancel_button)
        self.second_row_of_buttons_layout.addWidget(folder_button)
        self.current_download.start()

    @pyqtSlot(str, int, dict)
    def receive_download_progress_bar_details(self, episode_title: str, episode_size: int, progress_bars: dict[str, DownloadProgressBar]):
        bar = DownloadProgressBar(
            None, "Downloading", episode_title, episode_size, "MB", ibytes_to_mbs_divisor)
        progress_bars[episode_title] = bar
        self.progress_bars_layout.insertWidget(0, bar)


class DownloadManagerThread(QThread):
    send_progress_bar_details = pyqtSignal(str, int, dict)
    update_anime_progress_bar = pyqtSignal(int)

    def __init__(self, download_window: DownloadWindow, anime_details: AnimeDetails, anime_progress_bar: DownloadProgressBar, downloaded_episode_count: DownloadedEpisodeCount) -> None:
        super().__init__(download_window)
        self.anime_progress_bar = anime_progress_bar
        self.download_window = download_window
        self.downloaded_episode_count = downloaded_episode_count
        self.anime_details = anime_details
        self.update_anime_progress_bar.connect(anime_progress_bar.update)
        self.send_progress_bar_details.connect(
            download_window.receive_download_progress_bar_details)
        self.progress_bars: dict[str, DownloadProgressBar] = {}
        self.prev_bar = None
        self.mutex = QMutex()
        self.paused = False
        self.cancelled = False

    def pause_or_resume(self):
        if not self.cancelled:
            self.paused = not self.paused
            for bar in self.progress_bars.values():
                bar.pause_button.click()
            self.anime_progress_bar.pause_or_resume()

    def cancel(self):
        if not self.paused and not self.cancelled:
            self.cancelled = True
            for key in self.progress_bars.keys():
                self.progress_bars[key].cancel_button.click()
            self.anime_progress_bar.cancel()

    # The total size for animepahe isn't accurate, below is to appropriately handle updating the anime_progress_bar if site is animepahe
    @pyqtSlot(int)
    def handle_updating_anime_progress_bar(self, added: int):
        added_rounded = round(added / ibytes_to_mbs_divisor)
        self.update_anime_progress_bar.emit(added_rounded)

    @pyqtSlot(str)
    def pop_from_progress_bars(self, episode_title: str):
        self.progress_bars.pop(episode_title)

    @pyqtSlot(bool)
    def update_downloaded_episode_count(self, is_cancelled: bool):
        if not is_cancelled:
            self.downloaded_episode_count.update(1)
        else:
            self.downloaded_episode_count.total_episodes -= 1
            self.downloaded_episode_count.update(0)
    # Gogo's direct download link sometimes doesn't work, it returns a 302 status code meaning the resource has been moved, this attempts to redirect to that link
    # It is applied to Pahe too just in case

    def gogo_check_if_valid_link(self, link: str) -> requests.Response | None:
        response = cast(requests.Response, network_monad(
            lambda: requests.get(link, stream=True)))
        if response.status_code in [301, 302, 307, 308]:
            possible_valid_redirect_link = response.headers.get("location", "")
            return self.gogo_check_if_valid_link(possible_valid_redirect_link) if possible_valid_redirect_link != "" else None
        try:
            response.headers['content-length']
        except KeyError:
            response = None

        return response

    def get_exact_episode_size(self, link: str) -> int:
        response = self.gogo_check_if_valid_link(link)
        return int(response.headers['content-length']) if response else 0

    def run(self):
        for idx, link in enumerate(self.anime_details.direct_download_links):
            while len(self.progress_bars) == settings[key_max_simulataneous_downloads]:
                continue
            download_size = self.get_exact_episode_size(link)
            if download_size == 0:
                continue
            while self.paused:
                continue
            if self.cancelled:
                break
            episode_title = f"{self.anime_details.sanitised_title} Episode {self.anime_details.predicted_episodes_to_download[idx]}"
            self.mutex.lock()
            self.send_progress_bar_details.emit(
                episode_title, download_size, self.progress_bars)
            self.mutex.unlock()
            while episode_title not in self.progress_bars:
                continue
            DownloadThread(self, link, episode_title, download_size, self.anime_details.site, cast(str, self.anime_details.anime_folder_path),
                           self.progress_bars[episode_title], episode_title, self.pop_from_progress_bars,
                           self.anime_progress_bar, self.handle_updating_anime_progress_bar, self.update_downloaded_episode_count, self.mutex).start()


class DownloadThread(QThread):
    update_bar = pyqtSignal(int)
    finished = pyqtSignal(str)
    update_downloaded_episode_count = pyqtSignal(bool)

    def __init__(self, parent: DownloadManagerThread, link: str, title: str, size: int, site: str, download_folder: str,  progress_bar: DownloadProgressBar,
                 displayed_episode_title: str, finished_callback: Callable, anime_progress_bar: ProgressBar, handle_updating_anime_progress_bar: Callable,
                 update_downloaded_episode_count_callback: Callable, mutex: QMutex) -> None:
        super().__init__(parent)
        self.link = link
        self.title = title
        self.size = size
        self.download_folder = download_folder
        self.site = site
        self.progress_bar = progress_bar
        self.displayed_episode_title = displayed_episode_title
        self.finished.connect(finished_callback)
        self.anime_progress_bar = anime_progress_bar
        self.update_bar.connect(handle_updating_anime_progress_bar)
        self.update_bar.connect(self.progress_bar.update)
        self.update_downloaded_episode_count.connect(
            update_downloaded_episode_count_callback)
        self.mutex = mutex
        self.download: Download | None = None
        self.is_cancelled = False

    def cancel(self):
        if self.download:
            self.download.cancel()
            new_maximum = self.anime_progress_bar.bar.maximum() - round(self.size /
                                                                        ibytes_to_mbs_divisor)
            if new_maximum > 0:
                self.anime_progress_bar.bar.setMaximum(new_maximum)
            new_value = round(self.anime_progress_bar.bar.value(
            ) - round(self.progress_bar.bar.value() / ibytes_to_mbs_divisor))
            if new_value < 0:
                new_value = 0
            self.anime_progress_bar.bar.setValue(new_value)
            self.is_cancelled = True

    def run(self):
        self.download = Download(
            self.link, self.title, self.download_folder, lambda x: self.update_bar.emit(x))
        self.progress_bar.pause_callback = self.download.pause_or_resume
        self.progress_bar.cancel_callback = self.cancel
        self.download.start_download()

        self.mutex.lock()
        self.finished.emit(self.displayed_episode_title)
        self.update_downloaded_episode_count.emit(self.is_cancelled)
        self.mutex.unlock()


class GetEpisodePageLinksThread(QThread):
    finished = pyqtSignal(list)
    update_bar = pyqtSignal(int)

    def __init__(self, parent, anime_details: AnimeDetails, start_episode: int, end_episode: int, finished_callback: Callable, progress_update_callback: Callable):
        super().__init__(parent)
        self.anime_details = anime_details
        self.finished.connect(
            lambda episode_page_links: finished_callback(episode_page_links))
        self.start_episode = start_episode
        self.end_index = end_episode
        self.update_bar.connect(progress_update_callback)

    def run(self):
        if self.anime_details.site == pahe_name:
            episode_page_links = pahe.get_episode_page_links(self.start_episode, self.end_index, self.anime_details.anime.page_link, cast(
                str, self.anime_details.anime.id), lambda x: self.update_bar.emit(x))
            self.finished.emit(episode_page_links)
        elif self.anime_details.site == gogo_name:
            episode_page_links = gogo.generate_episode_page_links(
                self.start_episode, self.end_index, self.anime_details.anime.page_link)
            self.finished.emit(episode_page_links)


class GetDownloadPageThread(QThread):
    finished = pyqtSignal(list, list)
    update_bar = pyqtSignal(int)

    def __init__(self, parent, site: str, episode_page_links: list[str], finished_callback: Callable, progress_update_callback: Callable):
        super().__init__(parent)
        self.site = site
        self.episode_page_links = episode_page_links
        self.finished.connect(lambda download_page_links, download_info: finished_callback(
            download_page_links, download_info))
        self.update_bar.connect(progress_update_callback)

    def run(self):
        if self.site == pahe_name:
            download_page_links, download_info = pahe.get_pahewin_download_page_links_and_info(
                self.episode_page_links, lambda x: self.update_bar.emit(x))
            self.finished.emit(download_page_links, download_info)
        elif self.site == gogo_name:
            download_page_links = gogo.get_download_page_links(
                self.episode_page_links, lambda x: self.update_bar.emit(x))
            self.finished.emit(download_page_links, [])


class GetDirectDownloadLinksThread(QThread):
    finished = pyqtSignal(int)
    update_bar = pyqtSignal(int)

    def __init__(self, download_window: DownloadWindow, download_page_links: list[str] | list[list[str]], download_info: list[list[str]], anime_details: AnimeDetails,
                 finished_callback: Callable, progress_update_callback: Callable):
        super().__init__(download_window)
        self.download_window = download_window
        self.download_page_links = download_page_links
        self.download_info = download_info
        self.anime_details = anime_details
        self.finished.connect(finished_callback)
        self.update_bar.connect(progress_update_callback)

    def run(self):
        if self.anime_details.site == pahe_name:
            bound_links, bound_info = pahe.bind_sub_or_dub_to_link_info(self.anime_details.sub_or_dub, cast(
                list[list[str]], self.download_page_links), self.download_info)
            bound_links, bound_info = pahe.bind_quality_to_link_info(
                self.anime_details.quality, bound_links, bound_info)
            self.anime_details.download_info = bound_info
            self.anime_details.direct_download_links = pahe.get_direct_download_links(
                bound_links, lambda x: self.update_bar.emit(x))
            self.finished.emit(1)
        if self.anime_details.site == gogo_name:
            try:
                # For testing purposes
                # raise WebDriverException
                # raise TimeoutError
                self.anime_details.direct_download_links = gogo.get_direct_download_link_as_per_quality(cast(list[str], self.download_page_links), self.anime_details.quality,
                                                                                                        gogo.setup_headless_browser(self.anime_details.browser), lambda x: self.update_bar.emit(x))
                self.finished.emit(1)
            except Exception as exception:
                if isinstance(exception, WebDriverException):
                    self.finished.emit(2)
                elif isinstance(exception, TimeoutError):
                    self.finished.emit(3)


class CalculateDownloadSizes(QThread):
    finished = pyqtSignal()
    update_bar = pyqtSignal(int)

    def __init__(self, parent: QObject, anime_details: AnimeDetails, finished_callback: Callable, progress_update_callback: Callable):
        super().__init__(parent)
        self.progress_update_callback = progress_update_callback
        self.anime_details = anime_details
        self.finished.connect(finished_callback)
        self.update_bar.connect(progress_update_callback)

    def run(self):
        if self.anime_details.site == gogo_name:
            self.anime_details.total_download_size = gogo.calculate_download_total_size(
                self.anime_details.direct_download_links, lambda x: self.update_bar.emit(x), True)
        elif self.anime_details.site == pahe_name:
            self.anime_details.total_download_size = pahe.calculate_total_download_size(
                self.anime_details.download_info)
        self.finished.emit()
