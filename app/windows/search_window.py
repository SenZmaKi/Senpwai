from PyQt6.QtGui import QKeyEvent
from PyQt6.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QStackedWidget, QLineEdit
from PyQt6.QtCore import Qt, QThread, pyqtSignal, QEvent, QTimer
from shared.global_vars_and_funcs import random_mascot_icon_path, GOGO, PAHE, loading_animation_path, sadge_piece_path, set_minimum_size_policy, sen_anilist_id, anilist_api_entrypoint, one_piece_audio_path
from shared.global_vars_and_funcs import PAHE_NORMAL_COLOR, PAHE_HOVER_COLOR, PAHE_PRESSED_COLOR, GOGO_NORMAL_COLOR, GOGO_HOVER_COLOR, GOGO_PRESSED_COLOR, search_window_bckg_image_path, sen_favourite_audio_path
from shared.shared_classes_and_widgets import Anime, StyledButton, OutlinedButton, ScrollableSection, AnimationAndText, IconButton, AudioPlayer
from shared.app_and_scraper_shared import network_error_retry_wrapper
from windows.main_actual_window import MainWindow, Window
from scrapers import pahe
from scrapers import gogo
import requests
from random import randint
from typing import cast
from time import sleep


class SearchWindow(Window):
    def __init__(self, main_window: MainWindow):
        super().__init__(main_window, search_window_bckg_image_path)
        self.main_window = main_window
        main_widget = QWidget()
        main_layout = QVBoxLayout()

        mascot_button = IconButton(130, 100, random_mascot_icon_path, 1)
        self.fetch_sen_favourite_audio = AudioPlayer(
            sen_favourite_audio_path, volume=60)
        mascot_button.clicked.connect(self.fetch_sen_favourite_audio.play)
        mascot_button.clicked.connect(FetchFavouriteThread(self).start)
        self.search_bar = SearchBar(self)
        self.get_search_bar_text = lambda: self.search_bar.text()
        self.search_bar.setMinimumHeight(60)

        search_bar_and_mascot_widget = QWidget()
        search_bar_and_mascot_layout = QVBoxLayout()
        search_bar_and_mascot_layout.addWidget(
            mascot_button, alignment=Qt.AlignmentFlag.AlignHCenter)
        search_bar_and_mascot_layout.addWidget(self.search_bar)
        search_bar_and_mascot_layout.setSpacing(0)
        search_bar_and_mascot_widget.setLayout(search_bar_and_mascot_layout)
        main_layout.addWidget(search_bar_and_mascot_widget)

        search_buttons_widget = QWidget()
        search_buttons_layout = QHBoxLayout()
        self.pahe_search_button = SearchButton(self, PAHE)
        set_minimum_size_policy(self.pahe_search_button)
        # self.pahe_search_button.setFixedSize(220, 60)
        self.gogo_search_button = SearchButton(self, GOGO)
        set_minimum_size_policy(self.gogo_search_button)
        # self.gogo_search_button.setFixedSize(220, 60)
        search_buttons_layout.addWidget(self.pahe_search_button)
        search_buttons_layout.addWidget(self.gogo_search_button)
        search_buttons_widget.setLayout(search_buttons_layout)
        main_layout.addWidget(search_buttons_widget)
        self.bottom_section_stacked_widgets = QStackedWidget()

        self.results_layout = QVBoxLayout()
        self.results_widget = ScrollableSection(self.results_layout)
        self.res_wid_hor_scroll_bar = self.results_widget.horizontalScrollBar()

        self.loading = AnimationAndText(
            loading_animation_path, 600, 300, "Loading.. .", 1, 48, 50)
        self.anime_not_found = AnimationAndText(
            sadge_piece_path, 400, 300, ":( couldn't find that anime ", 1, 48, 50)
        self.bottom_section_stacked_widgets.addWidget(self.results_widget)
        self.bottom_section_stacked_widgets.addWidget(self.loading)
        self.bottom_section_stacked_widgets.addWidget(self.anime_not_found)
        self.bottom_section_stacked_widgets.setCurrentWidget(
            self.results_widget)
        main_layout.addWidget(self.bottom_section_stacked_widgets)
        self.search_thread = None
        self.one_piece_real = AudioPlayer(one_piece_audio_path, volume=100)
        main_widget.setLayout(main_layout)
        self.full_layout.addWidget(main_widget)
        self.setLayout(self.full_layout)
        # We use a timer instead of calling setFocus normally cause apparently Qt wont really set the widget in focus if the widget isn't shown on screen, so we gotta wait a bit first or sth StackOverflow Comment link: https://stackoverflow.com/questions/52853701/set-focus-on-button-in-app-with-group-boxes#comment92652037_52858926
        QTimer.singleShot(0, self.search_bar.setFocus)

    def on_focus(self):
        self.search_bar.setFocus()
        self.res_wid_hor_scroll_bar.setValue(self.res_wid_hor_scroll_bar.minimum())

    def search_anime(self, anime_title: str, site: str) -> None:
        if self.search_thread:
            self.search_thread.quit()
        prev_top_was_anime_not_found = self.bottom_section_stacked_widgets.currentWidget(
        ) == self.anime_not_found
        self.loading.start()
        self.bottom_section_stacked_widgets.setCurrentWidget(self.loading)
        if prev_top_was_anime_not_found:
            self.anime_not_found.stop()
        for idx in reversed(range(self.results_layout.count())):
            item = self.results_layout.itemAt(idx)
            item.widget().deleteLater()
            self.results_layout.removeItem(item)
        if anime_title.upper() == "ONE PIECE":
            self.one_piece_real.play()
        self.search_thread = SearchThread(self, anime_title, site)
        self.search_thread.finished.connect(
            lambda results: self.handle_finished_search(site, results))
        self.search_thread.start()

    def handle_finished_search(self, site: str, results: list[Anime]):
        if len(results) == 0:
            self.anime_not_found.start()
            self.bottom_section_stacked_widgets.setCurrentWidget(
                self.anime_not_found)
        else:
            self.bottom_section_stacked_widgets.setCurrentWidget(
                self.results_widget)
            for idx, result in enumerate(results):
                button = ResultButton(result, self.main_window, site, 9, 48)
                # For testing purposes comment out on deployment
                # if idx == 0:
                #     button.click()
                self.results_layout.addWidget(button)
        self.loading.stop()
        self.search_thread = None


class FetchFavouriteThread(QThread):
    def __init__(self, search_window: SearchWindow) -> None:
        super().__init__(search_window)
        self.search_window = search_window

    def run(self):
        favourite = self.get_random_sen_favourite()
        if not favourite:
            return
        self.slow_print_favourite_in_search_bar(favourite)

    def slow_print_favourite_in_search_bar(self, favourite_name: str):
        self.search_window.search_bar.clear()
        for idx, _ in enumerate(favourite_name):
            self.search_window.search_bar.setText(favourite_name[:idx+1])
            sleep(0.1)

    def get_random_sen_favourite(self) -> str | None:
        page = randint(1, 2)
        query = '''
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
        '''
        response = cast(requests.Response, network_error_retry_wrapper(lambda: requests.post(anilist_api_entrypoint,
                                                                               json={"query": query,
                                                                                     "variables": {"id": sen_anilist_id, "page": page}},
                                                                               headers={"Content-Type": "application/json"})))
        if response.status_code != 200:
            return None
        data = response.json()
        favourite_anime = data["data"]["User"]["favourites"]["anime"]["nodes"]
        count = len(favourite_anime)
        if count <= 0:
            return None
        chosen = favourite_anime[randint(0, count-1)]
        anime_title = chosen["title"]["romaji"]
        return anime_title


class SearchBar(QLineEdit):
    def __init__(self, search_window: SearchWindow):
        super().__init__()
        self.search_window = search_window
        self.setPlaceholderText("Enter anime title")
        self.installEventFilter(self)
        self.setStyleSheet("""
            QLineEdit{
                border: 1px solid black;
                border-radius: 15px;
                padding: 5px;
                color: black;
                font-size: 30px;
                font-family: "Berlin Sans FB Demi";
            }
        """)

    def eventFilter(self, obj, event: QEvent):
        if isinstance(event, QKeyEvent):
            if obj == self and event.type() == event.Type.KeyPress:
                if event.key() == Qt.Key.Key_Enter or event.key() == Qt.Key.Key_Return:
                    self.search_window.pahe_search_button.animateClick()
                elif event.key() == Qt.Key.Key_Tab:
                    first_button = self.search_window.results_layout.itemAt(0)
                    if first_button: 
                        first_button.widget().setFocus()
                    else:
                        self.search_window.gogo_search_button.animateClick()
                    return True
        return super().eventFilter(obj, event)


class SearchButton(StyledButton):
    def __init__(self, window: SearchWindow, site: str):
        if site == PAHE:
            super().__init__(window, 40, "black", PAHE_NORMAL_COLOR,
                             PAHE_HOVER_COLOR, PAHE_PRESSED_COLOR)
            self.setText("Animepahe")
            self.setToolTip("Recommended")
        else:
            super().__init__(window, 40, "black", GOGO_NORMAL_COLOR,
                             GOGO_HOVER_COLOR, GOGO_PRESSED_COLOR)
            self.setText("Gogoanime")
            self.setToolTip("Unstable")
        self.clicked.connect(lambda: window.search_anime(
            window.get_search_bar_text(), site))


class ResultButton(OutlinedButton):
    def __init__(self, anime: Anime,  main_window: MainWindow, site: str, paint_x: int, paint_y: int):
        if site == PAHE:
            hover_color = PAHE_NORMAL_COLOR
            pressed_color = PAHE_HOVER_COLOR
        else:
            hover_color = GOGO_NORMAL_COLOR
            pressed_color = GOGO_HOVER_COLOR
        super().__init__(paint_x, paint_y, None, 40, "white",
                         "transparent", hover_color, pressed_color, 21)
        self.setText(anime.title)
        self.setStyleSheet(self.styleSheet()+"""
                           QPushButton{
                           text-align: left;
                           border: none;
                           }""")
        self.style_sheet_buffer = self.styleSheet()
        self.focused_sheet = self.style_sheet_buffer+f"""
                    QPushButton{{
                        background-color: {hover_color};
        }}"""
        self.clicked.connect(
            lambda: main_window.setup_and_switch_to_chosen_anime_window(anime, site))
        self.installEventFilter(self)

    def eventFilter(self, obj, event: QEvent):
        if obj == self:
            if event.type() == QEvent.Type.FocusIn:
                self.setStyleSheet(self.focused_sheet)
            elif event.type() == QEvent.Type.FocusOut:
                self.setStyleSheet(self.style_sheet_buffer)
        return super().eventFilter(obj, event)


class SearchThread(QThread):
    finished = pyqtSignal(list)

    def __init__(self, window: SearchWindow, anime_title: str, site: str):
        super().__init__(window)
        self.anime_title = anime_title
        self.site = site

    def run(self):
        extracted_results = []
        if self.site == PAHE:
            results = pahe.search(self.anime_title)

            for result in results:
                anime_id, title, page_link = pahe.extract_anime_id_title_and_page_link(
                    result)
                extracted_results.append(Anime(title, page_link, anime_id))
        elif self.site == GOGO:
            results = gogo.search(self.anime_title)
            for result in results:
                title, page_link = gogo.extract_anime_title_and_page_link(
                    result)
                if title and page_link:
                    extracted_results.append(Anime(title, page_link, None))
        self.finished.emit(extracted_results)
