from typing import TYPE_CHECKING, cast

from PyQt6.QtCore import QSize, Qt, QThread, QTimer, pyqtSignal
from PyQt6.QtGui import QPixmap
from PyQt6.QtWidgets import (
    QHBoxLayout,
    QLabel,
    QScrollBar,
    QSpacerItem,
    QVBoxLayout,
    QWidget,
)
from senpwai.common.classes import SETTINGS, Anime, AnimeDetails
from senpwai.common.scraper import AiringStatus
from senpwai.common.static import (
    CHOSEN_ANIME_WINDOW_BCKG_IMAGE_PATH,
    DUB,
    GOGO,
    GOGO_HOVER_COLOR,
    GOGO_NORMAL_COLOR,
    PAHE_EXTRA_COLOR,
    Q_360,
    Q_480,
    Q_720,
    Q_1080,
    RED_NORMAL_COLOR,
    RED_PRESSED_COLOR,
    SUB,
)
from senpwai.common.widgets import (
    DualStateButton,
    ErrorLabel,
    FolderPickerButton,
    GogoNormOrHlsButton,
    HorizontalLine,
    NumberInput,
    QualityButton,
    ScrollableSection,
    StyledButton,
    StyledLabel,
    SubDubButton,
    set_minimum_size_policy,
)

from senpwai.windows.download import DownloadWindow
from senpwai.windows.settings import SettingsWindow
from senpwai.windows.abstracts import AbstractTemporaryWindow
from senpwai.scrapers import gogo

# https://stackoverflow.com/questions/39740632/python-type-hinting-without-cyclic-imports/3957388#39757388
if TYPE_CHECKING:
    from senpwai.windows.main import MainWindow


class SummaryLabel(StyledLabel):
    def __init__(self, summary: str):
        super().__init__(font_size=18)
        self.setText(summary)
        self.setWordWrap(True)


class HavedEpisodes(StyledLabel):
    def __init__(
        self,
    ):
        super().__init__(font_size=18)

    def update_text(
        self,
        start: int | None,
        end: int | None,
        haved_count: int | None,
        total_episode_count: int,
    ) -> None:
        if not haved_count:
            self.setText("You have no episodes of this anime")
        elif haved_count >= total_episode_count:
            self.setText("You have all the current episodes of this anime, weeeeb")
        else:
            self.setText(
                f"You have {haved_count} episodes from {start} to {end}"
            ) if haved_count != 1 else self.setText(
                f"You have {haved_count} episode from {start} to {end}"
            )
        set_minimum_size_policy(self)


class MakeAnimeDetailsThread(QThread):
    finished = pyqtSignal(AnimeDetails)

    def __init__(self, window: "MainWindow", anime: Anime, site: str):
        super().__init__(window)
        self.anime = anime
        self.site = site
        self.window = window

    def run(self):
        self.finished.emit(AnimeDetails(self.anime, self.site))


class ChosenAnimeWindow(AbstractTemporaryWindow):
    def __init__(self, main_window: "MainWindow", anime_details: AnimeDetails):
        super().__init__(main_window, CHOSEN_ANIME_WINDOW_BCKG_IMAGE_PATH)
        self.main_window = main_window
        self.anime_details = anime_details

        main_layout = QHBoxLayout()
        left_widgets_widget = QWidget()
        left_widgets_layout = QVBoxLayout()
        poster = Poster(self.anime_details.metadata.get_poster_bytes())
        left_widgets_layout.addWidget(poster)
        left_widgets_widget.setLayout(left_widgets_layout)
        bottom_widgets = QWidget()
        bottom_layout = QVBoxLayout()
        bottom_widgets.setLayout(bottom_layout)
        bottom_top_widget = QWidget()
        bottom_top_layout = QHBoxLayout()
        bottom_top_widget.setLayout(bottom_top_layout)
        release_year = StyledLabel(None, 21, "black")
        release_year.setText(str(anime_details.metadata.release_year))
        set_minimum_size_policy(release_year)
        bottom_top_layout.addWidget(release_year)
        airing_status = StyledLabel(None, 21, "blue")
        airing_status.setText(anime_details.metadata.airing_status.value)
        set_minimum_size_policy(airing_status)
        bottom_top_layout.addWidget(airing_status)
        self.episode_count = EpisodeCount(str(self.anime_details.episode_count))
        set_minimum_size_policy(self.episode_count)
        bottom_top_layout.addWidget(self.episode_count)
        bottom_bottom_widget = QWidget()
        bottom_bottom_layout = QHBoxLayout()
        bottom_bottom_widget.setLayout(bottom_bottom_layout)
        for genre in anime_details.metadata.genres[:3]:
            g_wid = StyledLabel(None, 21, PAHE_EXTRA_COLOR)
            g_wid.setText(genre)
            set_minimum_size_policy(g_wid)
            bottom_bottom_layout.addWidget(g_wid)
        left_widgets_layout.addWidget(bottom_top_widget)
        left_widgets_layout.addWidget(bottom_bottom_widget)
        set_minimum_size_policy(left_widgets_widget)
        main_layout.addWidget(left_widgets_widget)
        right_widgets_widget = QWidget()
        right_widgets_layout = QVBoxLayout()
        title = Title(self.anime_details.anime.title)
        right_widgets_layout.addWidget(title)
        line_under_title = HorizontalLine(parent=self)
        line_under_title.setFixedHeight(10)
        right_widgets_layout.addWidget(line_under_title)
        summary_label = SummaryLabel(self.anime_details.metadata.summary)
        summary_layout = QVBoxLayout()
        summary_layout.addWidget(summary_label)
        summary_widget = ScrollableSection(summary_layout)
        summary_widget.setMaximumHeight(300)
        right_widgets_layout.addWidget(summary_widget)

        sub_or_dub = DUB if gogo.title_is_dub(self.anime_details.anime.title) else SUB
        self.sub_button = SubDubButton(self, sub_or_dub, 18)
        set_minimum_size_policy(self.sub_button)
        self.dub_button = None
        self.sub_button.clicked.connect(lambda: self.update_sub_or_dub(SUB))
        if SETTINGS.sub_or_dub == SUB:
            self.sub_button.set_picked_status(True)
        if self.anime_details.dub_available:
            self.dub_button = SubDubButton(self, DUB, 18)
            set_minimum_size_policy(self.dub_button)
            self.dub_button.clicked.connect(lambda: self.update_sub_or_dub(DUB))
            if SETTINGS.sub_or_dub == DUB:
                self.dub_button.set_picked_status(True)
            self.dub_button.clicked.connect(
                lambda: self.sub_button.set_picked_status(False)
            )
            self.sub_button.clicked.connect(
                lambda: cast(SubDubButton, self.dub_button).set_picked_status(False)
            )
        else:
            self.sub_button.set_picked_status(True)
            self.anime_details.sub_or_dub = SUB
        first_row_of_buttons_widget = QWidget()
        first_row_of_buttons_layout = QHBoxLayout()
        first_row_of_buttons_layout.addWidget(self.sub_button)
        if self.dub_button:
            first_row_of_buttons_layout.addWidget(self.dub_button)
        first_row_of_buttons_layout.addSpacerItem(QSpacerItem(20, 0))
        self.button_1080 = QualityButton(self, Q_1080, 18)
        self.button_720 = QualityButton(self, Q_720, 18)
        self.button_480 = QualityButton(self, Q_480, 18)
        self.button_360 = QualityButton(self, Q_360, 18)
        self.quality_buttons_list = [
            self.button_1080,
            self.button_720,
            self.button_480,
            self.button_360,
        ]

        for button in self.quality_buttons_list:
            set_minimum_size_policy(button)
            first_row_of_buttons_layout.addWidget(button)
            quality = button.quality
            button.clicked.connect(
                lambda _, quality=quality: self.update_quality(quality)
            )
            if quality == SETTINGS.quality:
                button.set_picked_status(True)
        first_row_of_buttons_layout.addSpacerItem(QSpacerItem(20, 0))
        if anime_details.site == GOGO:
            self.norm_button = GogoNormOrHlsButton(self, "norm", 18)
            self.hls_button = GogoNormOrHlsButton(self, "hls", 18)
            self.norm_button.clicked.connect(
                lambda _: self.update_is_hls_download(False)
            )
            self.hls_button.clicked.connect(lambda _: self.update_is_hls_download(True))
            set_minimum_size_policy(self.norm_button)
            set_minimum_size_policy(self.hls_button)
            if anime_details.is_hls_download:
                self.hls_button.set_picked_status(True)
            else:
                self.norm_button.set_picked_status(True)
            first_row_of_buttons_layout.addWidget(self.norm_button)
            first_row_of_buttons_layout.addWidget(self.hls_button)

        first_row_of_buttons_layout.setAlignment(Qt.AlignmentFlag.AlignLeft)
        first_row_of_buttons_widget.setLayout(first_row_of_buttons_layout)
        right_widgets_layout.addWidget(first_row_of_buttons_widget)

        second_row_of_buttons_widget = QWidget()
        second_row_of_buttons_layout = QHBoxLayout()

        def get_start_episode() -> str:
            start_episode = (
                str((self.anime_details.haved_end) + 1)
                if (
                    self.anime_details.haved_end
                    and self.anime_details.haved_end < self.anime_details.episode_count
                )
                else "1"
            )
            return start_episode

        input_size = QSize(80, 40)
        if anime_details.metadata.airing_status != AiringStatus.UPCOMING:
            self.start_episode_input = NumberInput(21)
            self.start_episode_input.setFixedSize(input_size)
            self.start_episode_input.setPlaceholderText("START")
            self.start_episode_input.setText(get_start_episode())
            self.end_episode_input = NumberInput(21)
            self.end_episode_input.setPlaceholderText("STOP")
            self.end_episode_input.setFixedSize(input_size)
            self.download_button = DownloadButton(
                self, self.main_window.download_window, self.anime_details
            )
            set_minimum_size_policy(self.download_button)
            second_row_of_buttons_layout.addWidget(self.start_episode_input)
            second_row_of_buttons_layout.addWidget(self.end_episode_input)
            second_row_of_buttons_layout.addWidget(self.download_button)
            QTimer.singleShot(0, self.download_button.setFocus)
        including_error_label_widget = QWidget()
        including_error_label_layout = QVBoxLayout()
        self.error_label = ErrorLabel(18, 6)
        self.error_label.hide()
        including_error_label_layout.addWidget(self.error_label)
        second_row_of_buttons_widget.setLayout(second_row_of_buttons_layout)
        second_row_of_buttons_layout.setAlignment(Qt.AlignmentFlag.AlignLeft)
        including_error_label_layout.addWidget(second_row_of_buttons_widget)
        including_error_label_widget.setLayout(including_error_label_layout)
        right_widgets_layout.addWidget(including_error_label_widget)

        third_row_of_labels_widget = QWidget()
        third_row_of_labels_layout = QHBoxLayout()

        haved_episodes = HavedEpisodes()
        haved_episodes.update_text(
            self.anime_details.haved_start,
            self.anime_details.haved_end,
            self.anime_details.haved_count,
            self.anime_details.episode_count,
        )
        third_row_of_labels_layout.addWidget(haved_episodes)

        def set_custom_anime_folder(folder: str) -> None:
            self.anime_details.set_anime_folder_path(folder)
            if (
                index := SETTINGS.get_custom_anime_folder_index(
                    self.anime_details.anime.title
                )
                != -1
            ):
                SETTINGS.remove_custom_anime_folder(index)
            SETTINGS.add_custom_anime_folder(
                self.anime_details.anime.title, self.anime_details.anime_folder_path
            )
            haved_episodes.update_text(
                self.anime_details.haved_start,
                self.anime_details.haved_end,
                self.anime_details.haved_count,
                self.anime_details.episode_count,
            )
            self.start_episode_input.setText(get_start_episode())

        folder_button = FolderPickerButton(
            100,
            100,
            path=self.anime_details.anime_folder_path,
            picker_dialog_title="Choose anime folder",
            picker_success_callback=set_custom_anime_folder,
            picker_error_callback=self.error,
        )
        third_row_of_labels_layout.addSpacerItem(QSpacerItem(20, 0))
        third_row_of_labels_layout.addWidget(folder_button)
        track_button = TrackButton(
            anime_details.anime.title, self, self.main_window.settings_window
        )
        if anime_details.anime.title in SETTINGS.tracked_anime:
            track_button.change_status()
        set_minimum_size_policy(track_button)
        third_row_of_labels_layout.addSpacerItem(QSpacerItem(20, 0))
        third_row_of_labels_layout.addWidget(track_button)
        third_row_of_labels_layout.setAlignment(Qt.AlignmentFlag.AlignLeft)
        third_row_of_labels_widget.setLayout(third_row_of_labels_layout)
        right_widgets_layout.addWidget(third_row_of_labels_widget)
        right_widgets_widget.setLayout(right_widgets_layout)
        main_layout.addWidget(right_widgets_widget)
        main_widget = ScrollableSection(main_layout)
        bar = cast(QScrollBar, main_widget.horizontalScrollBar())
        bar.setValue(bar.maximum())
        self.full_layout.addWidget(main_widget)
        self.setLayout(self.full_layout)
        # For testing purposes
        # self.download_button.animateClick()

    def update_quality(self, quality: str):
        self.anime_details.quality = quality
        for button in self.quality_buttons_list:
            if button.quality != quality:
                button.set_picked_status(False)

    def update_is_hls_download(self, is_hls_download: bool):
        self.anime_details.is_hls_download = is_hls_download
        if is_hls_download:
            self.norm_button.set_picked_status(False)
        else:
            self.hls_button.set_picked_status(False)

    def update_sub_or_dub(self, sub_or_dub: str):
        self.anime_details.sub_or_dub = sub_or_dub
        if sub_or_dub == DUB:
            self.sub_button.set_picked_status(False)
        elif self.dub_button is not None:
            self.dub_button.set_picked_status(False)

    def error(self, error_message: str):
        self.error_label.setText(error_message)
        self.error_label.update()
        set_minimum_size_policy(self.error_label)
        self.error_label.show()


class TrackButton(DualStateButton):
    def __init__(
        self,
        anime_title: str,
        chosen_anime_window: ChosenAnimeWindow,
        settings: SettingsWindow,
    ):
        self.anime_title = anime_title
        self.off_tooltip = f"Add {self.anime_title} to your tracked anime list\nfor automatic downloading of new episodes"
        self.add_to_settings = lambda: settings.tracked_anime.add_anime(anime_title)
        self.remove_from_settings = lambda: settings.tracked_anime.remove_anime(
            anime_title
        )
        self.set = False
        super().__init__(
            chosen_anime_window,
            18,
            "white",
            RED_PRESSED_COLOR,
            RED_NORMAL_COLOR,
            "TRACK",
            "UNTRACK",
        )
        self.setToolTip(self.off_tooltip)

    def change_status(self):
        super().change_status()
        if self.on:
            self.setToolTip(f"Remove {self.anime_title} from your tracked anime list")
            return self.add_to_settings()
        self.remove_from_settings()
        self.setToolTip(self.off_tooltip)


class DownloadButton(StyledButton):
    def __init__(
        self,
        chosen_anime_window: ChosenAnimeWindow,
        download_window: DownloadWindow,
        anime_details: AnimeDetails,
    ):
        super().__init__(
            chosen_anime_window,
            21,
            "white",
            "green",
            GOGO_NORMAL_COLOR,
            GOGO_HOVER_COLOR,
        )
        self.chosen_anime_window = chosen_anime_window
        self.download_window = download_window
        self.main_window = chosen_anime_window.main_window
        self.anime_details = anime_details
        self.clicked.connect(self.handle_download_button_clicked)
        self.setText("DOWNLOAD")

    def handle_download_button_clicked(self):
        invalid_input = False
        episode_count = self.anime_details.episode_count
        start_episode = self.chosen_anime_window.start_episode_input.text()
        end_episode = self.chosen_anime_window.end_episode_input.text()
        predicted_start_point = self.anime_details.haved_end
        predicted_start_point = (
            predicted_start_point + 1 if predicted_start_point is not None else 1
        )
        error = self.chosen_anime_window.error
        if episode_count == 0:
            error("This anime has no episodes yet on this site.")
            invalid_input = True
        if "0" == start_episode or "0" == end_episode:
            error("What am I supposed to do with a zero?")
            invalid_input = True
        if not start_episode:
            start_episode = 1
            self.chosen_anime_window.start_episode_input.setText("1")
        if not end_episode:
            end_episode = episode_count
            self.chosen_anime_window.end_episode_input.setText("")
        start_episode = int(start_episode)
        end_episode = int(end_episode)

        if (
            predicted_start_point <= episode_count
            and start_episode > episode_count
            and not invalid_input
        ):
            error(
                "Start episode cannot be greater than the number of episodes the anime has."
            )
            invalid_input = True
            start_episode = predicted_start_point
            self.chosen_anime_window.start_episode_input.setText(
                str(predicted_start_point)
            )

        if (end_episode < start_episode) and not invalid_input:
            error("Stop episode cannot be less than start episode, hontoni baka ga.")
            invalid_input = True
            end_episode = episode_count
            self.chosen_anime_window.end_episode_input.setText("")

        elif (end_episode > episode_count) and not invalid_input:
            error(
                "Oe oe oe mate, stop episode cannot be greater than the number of episodes this anime has."
            )
            end_episode = episode_count
            self.chosen_anime_window.end_episode_input.setText("")
            invalid_input = True

        if not invalid_input:
            self.anime_details.set_lacked_episodes(start_episode, end_episode)
            if not self.anime_details.lacked_episodes:
                if self.anime_details.filler_episodes:
                    error(
                        "Bakayorou, you already have all the canon episodes within the provided range!!!"
                    )
                else:
                    error(
                        "Bakayorou, you already have all episodes within the provided range!!!"
                    )
                invalid_input = True

        if invalid_input:
            return self.chosen_anime_window.episode_count.brighten()
        self.main_window.stacked_windows.setCurrentWidget(
            self.main_window.download_window
        )
        self.download_window.initiate_download_pipeline(self.anime_details)
        self.main_window.stacked_windows.removeWidget(self.chosen_anime_window)
        self.chosen_anime_window.deleteLater()


class EpisodeCount(StyledLabel):
    def __init__(self, count: str):
        super().__init__(None, 21, "rgba(255, 50, 0, 250)")
        eps_str = "episode" if count == "1" else "episodes"
        self.setText(f"{count} {eps_str}")
        self.normal_style_sheet = self.styleSheet()
        self.setWordWrap(True)
        self.bright_stylesheet = (
            self.normal_style_sheet
            + """
            QLabel {
                color: black;
                background-color: rgba(255, 0, 0, 255);
                border: 2px solid black;
                    }
                    """
        )

    def brighten(self):
        self.setStyleSheet(self.bright_stylesheet)

        def revert_styles():
            return self.setStyleSheet(self.normal_style_sheet)

        timer = QTimer(self)
        timer.timeout.connect(revert_styles)
        timer.start(6 * 1000)


class Poster(QLabel):
    def __init__(self, image: bytes):
        super().__init__()
        size_x = 350
        size_y = 500
        pixmap = QPixmap()
        pixmap.loadFromData(image)
        pixmap = pixmap.scaled(size_x, size_y, Qt.AspectRatioMode.IgnoreAspectRatio)

        self.move(50, 60)
        self.setPixmap(pixmap)
        self.setFixedSize(size_x, size_y)
        self.setStyleSheet(
            """
                        QLabel {
                        background-color: rgba(255, 160, 0, 255);
                        border-radius: 10px;
                        padding: 5px;
                        border: 2px solid black;
                        }
                        """
        )


class Title(StyledLabel):
    def __init__(self, title: str):
        super().__init__(None, 40, PAHE_EXTRA_COLOR, 20, "black")
        self.setText(title.upper())
        self.setWordWrap(True)
