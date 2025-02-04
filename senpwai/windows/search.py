import random
import time
from typing import TYPE_CHECKING, Any, cast

from PyQt6.QtCore import QEvent, QObject, Qt, QThread, QTimer, pyqtSignal
from PyQt6.QtGui import QKeyEvent
from PyQt6.QtWidgets import (
    QHBoxLayout,
    QLayoutItem,
    QLineEdit,
    QScrollBar,
    QStackedWidget,
    QVBoxLayout,
    QWidget,
)
from senpwai.scrapers import gogo, pahe
from senpwai.common.classes import Anime
from senpwai.common.scraper import CLIENT
from senpwai.common.classes import SETTINGS
from senpwai.common.static import (
    ANILIST_API_ENTRYPOINY,
    BUNSHIN_POOF_AUDIO_PATH,
    GIGACHAD_AUDIO_PATH,
    GOGO,
    GOGO_HOVER_COLOR,
    GOGO_NORMAL_COLOR,
    GOGO_PRESSED_COLOR,
    IS_CHRISTMAS,
    KAGE_BUNSHIN_AUDIO_PATH,
    L_ANIME,
    LOADING_ANIMATION_PATH,
    MERRY_CHRISMASU_AUDIO_PATH,
    PAHE,
    PAHE_HOVER_COLOR,
    PAHE_NORMAL_COLOR,
    PAHE_PRESSED_COLOR,
    RANDOM_MACOT_ICON_PATH,
    ANIME_NOT_FOUND_PATH,
    SEARCH_WINDOW_BCKG_IMAGE_PATH,
    SEN_ANILIST_ID,
    SEN_FAVOURITE_AUDIO_PATH,
    ONE_PIECE_REAL_AUDIO_PATH,
    TOKI_WA_UGOKI_DASU_AUDIO_PATH,
    W_ANIME,
    WHAT_DA_HELL_AUDIO_PATH,
    ZA_WARUDO_AUDIO_PATH,
)
from senpwai.common.widgets import (
    AnimationAndText,
    AudioPlayer,
    Icon,
    IconButton,
    OutlinedButton,
    ScrollableSection,
    StyledButton,
    set_minimum_size_policy,
)

from senpwai.windows.abstracts import AbstractWindow

# https://stackoverflow.com/questions/39740632/python-type-hinting-without-cyclic-imports/3957388#39757388
if TYPE_CHECKING:
    from senpwai.windows.main import MainWindow


class SearchWindow(AbstractWindow):
    def __init__(self, main_window: "MainWindow"):
        super().__init__(main_window, SEARCH_WINDOW_BCKG_IMAGE_PATH)
        self.main_window = main_window
        main_widget = QWidget()
        main_layout = QVBoxLayout()

        mascot_button = IconButton(Icon(117, 100, RANDOM_MACOT_ICON_PATH), 1)
        mascot_button.setToolTip("Goofy 🗿")

        mascot_button.clicked.connect(
            AudioPlayer(self, SEN_FAVOURITE_AUDIO_PATH, volume=60).play
        )
        mascot_button.clicked.connect(FetchFavouriteThread(self).start)
        self.search_bar = SearchBar(self)
        self.get_search_bar_text = lambda: self.search_bar.text()
        self.search_bar.setMinimumHeight(60)

        search_bar_and_mascot_widget = QWidget()
        search_bar_and_mascot_layout = QVBoxLayout()
        search_bar_and_mascot_layout.addWidget(
            mascot_button, alignment=Qt.AlignmentFlag.AlignHCenter
        )
        search_bar_and_mascot_layout.addWidget(self.search_bar)
        search_bar_and_mascot_layout.setSpacing(0)
        search_bar_and_mascot_widget.setLayout(search_bar_and_mascot_layout)
        main_layout.addWidget(search_bar_and_mascot_widget)

        search_buttons_widget = QWidget()
        search_buttons_layout = QHBoxLayout()
        self.pahe_search_button = SearchButton(self, PAHE)
        set_minimum_size_policy(self.pahe_search_button)
        self.gogo_search_button = SearchButton(self, GOGO)
        set_minimum_size_policy(self.gogo_search_button)
        search_buttons_layout.addWidget(self.pahe_search_button)
        search_buttons_layout.addWidget(self.gogo_search_button)
        search_buttons_widget.setLayout(search_buttons_layout)
        main_layout.addWidget(search_buttons_widget)
        self.results_layout = QVBoxLayout()
        self.results_widget = ScrollableSection(self.results_layout)
        self.res_wid_hor_scroll_bar = cast(
            QScrollBar, self.results_widget.horizontalScrollBar()
        )

        self.loading = AnimationAndText(
            LOADING_ANIMATION_PATH, 250, 300, "Loading.. .", 1, 48, 50
        )
        self.anime_not_found = AnimationAndText(
            ANIME_NOT_FOUND_PATH, 400, 300, ":( couldn't find that anime ", 1, 48, 50
        )
        self.bottom_section_stacked_widgets = QStackedWidget()
        self.bottom_section_stacked_widgets.addWidget(self.results_widget)
        self.bottom_section_stacked_widgets.addWidget(self.loading)
        self.bottom_section_stacked_widgets.addWidget(self.anime_not_found)
        self.bottom_section_stacked_widgets.setCurrentWidget(self.results_widget)
        main_layout.addWidget(self.bottom_section_stacked_widgets)
        self.search_thread: SearchThread | None = None
        main_widget.setLayout(main_layout)
        self.full_layout.addWidget(main_widget)
        self.setLayout(self.full_layout)
        # We use a timer instead of calling setFocus normally cause apparently Qt wont really set the widget in focus if the widget isn't shown on screen,
        # So we gotta wait a bit first till the UI is rendered.
        # Stack Overflow comment link: https://stackoverflow.com/questions/52853701/set-focus-on-button-in-app-with-group-boxes#comment92652037_52858926
        QTimer.singleShot(0, self.search_bar.setFocus)

    # Qt pushes the horizontal scroll bar to the center automatically sometimes
    def fix_hor_scroll_bar(self):
        self.res_wid_hor_scroll_bar.setValue(self.res_wid_hor_scroll_bar.minimum())

    def set_focus(self):
        self.search_bar.setFocus()
        self.fix_hor_scroll_bar()

    def search_anime(self, anime_title: str, site: str) -> None:
        if not anime_title:
            return
        if self.search_thread:
            self.search_thread.quit()
        was_anime_not_found = (
            self.bottom_section_stacked_widgets.currentWidget() == self.anime_not_found
        )
        self.loading.start()
        self.bottom_section_stacked_widgets.setCurrentWidget(self.loading)
        if was_anime_not_found:
            self.anime_not_found.stop()
        for idx in reversed(range(self.results_layout.count())):
            item = cast(
                QWidget, cast(QLayoutItem, self.results_layout.itemAt(idx)).widget()
            ).deleteLater()
            self.results_layout.removeItem(item)
        self.search_thread = SearchThread(self, anime_title, site)
        anime_title_lower = anime_title.lower()
        is_naruto = "naruto" in anime_title_lower or "boruto" in anime_title_lower
        if "one piece" in anime_title_lower:
            AudioPlayer(self, ONE_PIECE_REAL_AUDIO_PATH, volume=100).play()
        elif "jojo" in anime_title_lower:
            AudioPlayer(self, ZA_WARUDO_AUDIO_PATH, 100).play()
            for _ in range(180):
                self.main_window.app.processEvents()
                time.sleep(0.01)
            for x in range(20):
                self.main_window.app.processEvents()
                time.sleep(x * 0.01)
            time.sleep(2)
            AudioPlayer(self, TOKI_WA_UGOKI_DASU_AUDIO_PATH, 100).play()
            time.sleep(1.8)
        elif any(w_anime in anime_title_lower for w_anime in W_ANIME):
            AudioPlayer(self, GIGACHAD_AUDIO_PATH, 25).play()
        elif any(l_anime in anime_title_lower for l_anime in L_ANIME):
            AudioPlayer(self, WHAT_DA_HELL_AUDIO_PATH, 100).play()
        elif is_naruto:
            self.kage_bunshin_no_jutsu = AudioPlayer(
                self, KAGE_BUNSHIN_AUDIO_PATH, volume=50
            )
            self.kage_bunshin_no_jutsu.play()
        elif IS_CHRISTMAS:
            AudioPlayer(self, MERRY_CHRISMASU_AUDIO_PATH, 30).play()

        if is_naruto:
            self.search_thread.finished.connect(self.start_naruto_results_thread)
        else:
            self.search_thread.finished.connect(self.show_results)
        self.search_thread.start()

    def start_naruto_results_thread(self, site: str, results: list[Anime]):
        NarutoResultsThread(self, site, results).start()

    def play_bunshin_poof(self):
        AudioPlayer(self, BUNSHIN_POOF_AUDIO_PATH, 10).play()

    def show_results(self, site: str, results: list[Anime]):
        if not results:
            self.anime_not_found.start()
            self.bottom_section_stacked_widgets.setCurrentWidget(self.anime_not_found)
        else:
            self.bottom_section_stacked_widgets.setCurrentWidget(self.results_widget)
            for result in results:
                button = ResultButton(result, self.main_window, self, site, 9, 48)
                self.results_layout.addWidget(button)
        self.loading.stop()
        self.search_thread = None

    def make_naruto_result_button(self, result: Anime, site: str):
        button = ResultButton(result, self.main_window, self, site, 9, 48)
        self.results_layout.addWidget(button)


class NarutoResultsThread(QThread):
    send_result = pyqtSignal(Anime, str)
    stop_loading_animation = pyqtSignal()
    start_anime_not_found_animation = pyqtSignal()
    set_curr_wid = pyqtSignal(QWidget)
    play_bunshin = pyqtSignal()

    def __init__(self, search_window: SearchWindow, site: str, results: list[Anime]):
        super().__init__(search_window)
        self.search_window = search_window
        self.results = results
        self.site = site
        self.bunshin_poof = AudioPlayer(search_window, BUNSHIN_POOF_AUDIO_PATH)
        self.send_result.connect(search_window.make_naruto_result_button)
        self.stop_loading_animation.connect(search_window.loading.stop)
        self.start_anime_not_found_animation.connect(
            search_window.anime_not_found.start
        )
        self.set_curr_wid.connect(
            search_window.bottom_section_stacked_widgets.setCurrentWidget
        )
        self.play_bunshin.connect(search_window.play_bunshin_poof)

    def run(self):
        while self.search_window.kage_bunshin_no_jutsu.isPlaying():
            time.sleep(0.1)
        if not self.results:
            self.start_anime_not_found_animation.emit()
            self.set_curr_wid.emit(self.search_window.anime_not_found)
        else:
            self.stop_loading_animation.emit()
            self.set_curr_wid.emit(self.search_window.results_widget)
            for idx, result in enumerate(self.results):
                self.send_result.emit(result, self.site)
                if idx <= 5:
                    self.play_bunshin.emit()
                    time.sleep(0.35)
            self.search_window.search_thread = None


class FetchFavouriteThread(QThread):
    def __init__(self, search_window: SearchWindow) -> None:
        super().__init__(search_window)
        self.search_window = search_window

    def run(self):
        favourite = self.get_random_sen_favourite()
        if not favourite:
            return
        self.type_write_favourite_in_search_bar(favourite)

    def type_write_favourite_in_search_bar(self, favourite_name: str):
        self.search_window.search_bar.clear()
        for idx in range(len(favourite_name)):
            self.search_window.search_bar.setText(favourite_name[: idx + 1])
            time.sleep(0.1)

    def get_random_sen_favourite(self) -> str | None:
        page = random.choice((1, 2))
        query = """
        query getUserFavourite($id: Int, $page: Int){
        User(id: $id) {
            favourites{
            anime(page: $page){
                nodes{
                title{
                    romaji
                }
                }
                pageInfo {
                lastPage
                perPage
                total
                }
            }
            }
        }
        }
        """
        response = CLIENT.post(
            ANILIST_API_ENTRYPOINY,
            json={"query": query, "variables": {"id": SEN_ANILIST_ID, "page": page}},
            headers=CLIENT.make_headers({"Content-Type": "application/json"}),
        )
        if response.status_code != 200:
            return None
        response_json = response.json()
        favourites: list[dict["str", Any]] = response_json["data"]["User"][
            "favourites"
        ]["anime"]["nodes"]
        if not favourites:
            return None
        chosen_favourite = random.choice(favourites)
        anime_title = chosen_favourite["title"]["romaji"]
        return anime_title


class SearchBar(QLineEdit):
    def __init__(self, search_window: SearchWindow):
        super().__init__()
        self.search_window = search_window
        self.setPlaceholderText("Enter anime title")
        self.installEventFilter(self)
        self.setStyleSheet(
            f"""
            QLineEdit{{
                border: 1px solid black;
                border-radius: 15px;
                padding: 5px;
                background-color: white;
                color: black;
                font-size: 30px;
                font-family: {SETTINGS.font_family};
            }}
        """
        )

    def eventFilter(self, a0: QObject | None, a1: QEvent | None):
        if isinstance(a1, QKeyEvent) and a0 == self and a1.type() == a1.Type.KeyPress:
            if a1.key() == Qt.Key.Key_Enter or a1.key() == Qt.Key.Key_Return:
                self.search_window.pahe_search_button.animateClick()
                return True
            elif a1.key() == Qt.Key.Key_Tab:
                self.search_window.gogo_search_button.animateClick()
                return True
            elif a1.key() == Qt.Key.Key_Down:
                first_button = self.search_window.results_layout.itemAt(0)
                if first_button:
                    cast(QWidget, first_button.widget()).setFocus()
                return True
        return super().eventFilter(a0, a1)


class SearchButton(StyledButton):
    def __init__(self, window: SearchWindow, site: str):
        if site == PAHE:
            super().__init__(
                window,
                40,
                "black",
                PAHE_NORMAL_COLOR,
                PAHE_HOVER_COLOR,
                PAHE_PRESSED_COLOR,
            )
            self.setText("Animepahe")
        else:
            super().__init__(
                window,
                40,
                "black",
                GOGO_NORMAL_COLOR,
                GOGO_HOVER_COLOR,
                GOGO_PRESSED_COLOR,
            )
            self.setText("Gogoanime")
        self.clicked.connect(
            lambda: window.search_anime(window.get_search_bar_text(), site)
        )


class ResultButton(OutlinedButton):
    def __init__(
        self,
        anime: Anime,
        main_window: "MainWindow",
        search_window: SearchWindow,
        site: str,
        paint_x: int,
        paint_y: int,
    ):
        self.search_window = search_window
        if site == PAHE:
            hover_color = PAHE_NORMAL_COLOR
            pressed_color = PAHE_HOVER_COLOR
        else:
            hover_color = GOGO_NORMAL_COLOR
            pressed_color = GOGO_HOVER_COLOR
        super().__init__(
            paint_x,
            paint_y,
            None,
            40,
            "white",
            "transparent",
            hover_color,
            pressed_color,
            21,
        )
        self.setText(anime.title)
        self.setStyleSheet(
            self.styleSheet()
            + """
                           QPushButton{
                           text-align: left;
                           border: none;
                           }"""
        )
        self.style_sheet_buffer = self.styleSheet()
        self.focused_sheet = (
            self.style_sheet_buffer
            + f"""
                    QPushButton{{
                        background-color: {hover_color};
        }}"""
        )
        self.clicked.connect(
            lambda: main_window.switch_to_chosen_anime_window(anime, site)
        )
        self.installEventFilter(self)

    def eventFilter(self, a0: QObject | None, a1: QEvent | None):
        if a0 == self:
            a1 = cast(QEvent, a1)
            if a1.type() == QEvent.Type.FocusIn:
                self.setStyleSheet(self.focused_sheet)
            elif a1.type() == QEvent.Type.FocusOut:
                self.setStyleSheet(self.style_sheet_buffer)
            if (
                isinstance(a1, QKeyEvent)
                and a1.type() == a1.Type.KeyPress
                and (
                    a1.key()
                    in (
                        Qt.Key.Key_Tab,
                        Qt.Key.Key_Up,
                        Qt.Key.Key_Down,
                        Qt.Key.Key_Left,
                        Qt.Key.Key_Right,
                    )
                )
            ):
                # It doesn't work without the QTimer for some reason, probably cause the horizontal scroll bar centering bug happens
                # after this event is processed so the fix is overwridden hence we wait for the bug to happen first then fix it thus we need the QTimer
                QTimer(self).singleShot(0, self.search_window.fix_hor_scroll_bar)
        return super().eventFilter(a0, a1)


class SearchThread(QThread):
    finished = pyqtSignal(str, list)

    def __init__(self, search_window: SearchWindow, anime_title: str, site: str):
        super().__init__(search_window)
        self.anime_title = anime_title
        self.site = site

    def run(self):
        extracted_results = []
        if self.site == PAHE:
            results = pahe.search(self.anime_title)

            for result in results:
                title, page_link, anime_id = pahe.extract_anime_title_page_link_and_id(
                    result
                )
                extracted_results.append(Anime(title, page_link, anime_id))
        elif self.site == GOGO:
            results = gogo.search(self.anime_title)
            for title, page_link in results:
                extracted_results.append(Anime(title, page_link, None))
        self.finished.emit(self.site, extracted_results)
