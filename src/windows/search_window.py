from PyQt6.QtGui import QKeyEvent
from PyQt6.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QStackedWidget, QLineEdit, QScrollBar, QLayoutItem
from PyQt6.QtCore import Qt, QThread, pyqtSignal, QEvent, QTimer
from shared.global_vars_and_funcs import random_mascot_icon_path, GOGO, PAHE, loading_animation_path, sadge_piece_path, set_minimum_size_policy, sen_anilist_id, anilist_api_entrypoint, one_piece_audio_path, kage_bunshin_audio_path, toki_wa_ugoki_dasu_audio_path, za_warudo_audio_path
from shared.global_vars_and_funcs import PAHE_NORMAL_COLOR, PAHE_HOVER_COLOR, PAHE_PRESSED_COLOR, GOGO_NORMAL_COLOR, GOGO_HOVER_COLOR, GOGO_PRESSED_COLOR, search_window_bckg_image_path, sen_favourite_audio_path, bunshin_poof_audio_path, gigachad_audio_path, what_da_hell_audio_path
from shared.shared_classes_and_widgets import Anime, StyledButton, OutlinedButton, ScrollableSection, AnimationAndText, IconButton, AudioPlayer, Icon
from shared.app_and_scraper_shared import CLIENT
from windows.main_actual_window import MainWindow, Window
from scrapers import pahe
from scrapers import gogo
from random import choice as randomchoice
from time import sleep as timesleep
from typing import cast


class SearchWindow(Window):
    def __init__(self, main_window: MainWindow):
        super().__init__(main_window, search_window_bckg_image_path)
        self.main_window = main_window
        main_widget = QWidget()
        main_layout = QVBoxLayout()

        mascot_button = IconButton(Icon(117, 100, random_mascot_icon_path), 1)
        mascot_button.setToolTip("Goofy 🗿")

        mascot_button.clicked.connect(AudioPlayer(
            self, sen_favourite_audio_path, volume=60).play)
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
        self.gogo_search_button = SearchButton(self, GOGO)
        set_minimum_size_policy(self.gogo_search_button)
        search_buttons_layout.addWidget(self.pahe_search_button)
        search_buttons_layout.addWidget(self.gogo_search_button)
        search_buttons_widget.setLayout(search_buttons_layout)
        main_layout.addWidget(search_buttons_widget)
        self.bottom_section_stacked_widgets = QStackedWidget()

        self.results_layout = QVBoxLayout()
        self.results_widget = ScrollableSection(self.results_layout)
        self.res_wid_hor_scroll_bar = cast(
            QScrollBar, self.results_widget.horizontalScrollBar())

        self.loading = AnimationAndText(
            loading_animation_path, 250, 300, "Loading.. .", 1, 48, 50)
        self.anime_not_found = AnimationAndText(
            sadge_piece_path, 400, 300, ":( couldn't find that anime ", 1, 48, 50)
        self.bottom_section_stacked_widgets.addWidget(self.results_widget)
        self.bottom_section_stacked_widgets.addWidget(self.loading)
        self.bottom_section_stacked_widgets.addWidget(self.anime_not_found)
        self.bottom_section_stacked_widgets.setCurrentWidget(
            self.results_widget)
        main_layout.addWidget(self.bottom_section_stacked_widgets)
        self.search_thread = None
        main_widget.setLayout(main_layout)
        self.full_layout.addWidget(main_widget)
        self.setLayout(self.full_layout)
        # We use a timer instead of calling setFocus normally cause apparently Qt wont really set the widget in focus if the widget isn't shown on screen/rendered,
        # So we gotta wait a bit first till the UI is rendered. StackOverflow Comment link: https://stackoverflow.com/questions/52853701/set-focus-on-button-in-app-with-group-boxes#comment92652037_52858926
        QTimer.singleShot(0, self.search_bar.setFocus)

    # Qt pushes the horizontal scroll bar to the center automatically sometimes
    def fix_hor_scroll_bar(self):
        self.res_wid_hor_scroll_bar.setValue(
            self.res_wid_hor_scroll_bar.minimum())

    def on_focus(self):
        self.search_bar.setFocus()
        self.fix_hor_scroll_bar()

    def search_anime(self, anime_title: str, site: str) -> None:
        if anime_title == "":
            return
        if self.search_thread:
            self.search_thread.quit()
        prev_top_was_anime_not_found = self.bottom_section_stacked_widgets.currentWidget(
        ) == self.anime_not_found
        self.loading.start()
        self.bottom_section_stacked_widgets.setCurrentWidget(self.loading)
        if prev_top_was_anime_not_found:
            self.anime_not_found.stop()
        for idx in reversed(range(self.results_layout.count())):
            item = cast(QWidget, cast(
                QLayoutItem, self.results_layout.itemAt(idx)).widget()).deleteLater()
            self.results_layout.removeItem(item)
        upper_title = anime_title.upper()
        self.search_thread = SearchThread(self, anime_title, site)
        w_anime = ("vermeil", "golden kamuy", "goblin slayer", "hajime", "megalobox", "kengan ashura", "kengan asura", "kengan", "golden boy", "valkyrie", "dr stone", "dr. stone", "death parade", "death note", "code geass", "attack on titan", "kaiji"
                   "shingeki no kyojin", "daily lives", "danshi koukosei", "daily lives of highshool boys", "arakawa", "haikyuu", "kaguya", "chio", "asobi asobase", "prison school", "grand blue", "mob psycho", "to your eternity", "fire force", "mieruko", "fumetsu")
        l_anime = ("tokyo ghoul", "sword art", "boku no pico", "full metal", "fmab", "fairy tail", "dragon ball",
                   "hunter x hunter", "hunter hunter", "platinum end", "record of ragnarok", "7 deadly sins", "seven deadly sins")
        if "ONE PIECE" in upper_title:
            AudioPlayer(self, one_piece_audio_path, volume=100).play()
        elif "JOJO" in upper_title:
            AudioPlayer(self, za_warudo_audio_path, 100).play()
            for _ in range(180):
                self.main_window.app.processEvents()
                timesleep(0.01)
            for x in range(20):
                self.main_window.app.processEvents()
                timesleep(x * 0.01)
            timesleep(2)
            AudioPlayer(self, toki_wa_ugoki_dasu_audio_path, 100).play()
            timesleep(1.8)
        lower = anime_title.lower()
        for w in w_anime:
            if w in lower:
                AudioPlayer(self, gigachad_audio_path, 50).play()
        for l in l_anime:
            if l in lower:
                AudioPlayer(self, what_da_hell_audio_path, 100).play()
        if "NARUTO" in upper_title:
            self.kage_bunshin_no_jutsu = AudioPlayer(
                self, kage_bunshin_audio_path, volume=50)
            self.kage_bunshin_no_jutsu.play()
            self.search_thread.finished.connect(
                self.start_naruto_results_thread)
        else:
            self.search_thread.finished.connect(self.show_results)
        self.search_thread.start()

    def start_naruto_results_thread(self, site: str, results: list[Anime]):
        NarutoResultsThread(self, site, results).start()

    def play_bunshin_poof(self):
        AudioPlayer(self, bunshin_poof_audio_path, 10).play()

    def show_results(self, site: str, results: list[Anime]):
        if results == []:
            self.anime_not_found.start()
            self.bottom_section_stacked_widgets.setCurrentWidget(
                self.anime_not_found)
        else:
            self.bottom_section_stacked_widgets.setCurrentWidget(
                self.results_widget)
            for result in results:
                button = ResultButton(
                    result, self.main_window, self, site, 9, 48)
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
        self.bunshin_poof = AudioPlayer(search_window, bunshin_poof_audio_path)
        self.send_result.connect(search_window.make_naruto_result_button)
        self.stop_loading_animation.connect(search_window.loading.stop)
        self.start_anime_not_found_animation.connect(
            search_window.anime_not_found.start)
        self.set_curr_wid.connect(
            search_window.bottom_section_stacked_widgets.setCurrentWidget)
        self.play_bunshin.connect(search_window.play_bunshin_poof)

    def run(self):
        while self.search_window.kage_bunshin_no_jutsu.isPlaying():
            pass
        if self.results == []:
            self.start_anime_not_found_animation.emit()
            self.set_curr_wid.emit(self.search_window.anime_not_found)
        else:
            self.stop_loading_animation.emit()
            self.set_curr_wid.emit(self.search_window.results_widget)
            for idx, result in enumerate(self.results):
                self.send_result.emit(result, self.site)
                if idx <= 5:
                    self.play_bunshin.emit()
                    timesleep(0.35)
            self.search_window.search_thread = None


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
            timesleep(0.1)

    def get_random_sen_favourite(self) -> str | None:
        page = randomchoice((1, 2))
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
        response = CLIENT.post(anilist_api_entrypoint, json={"query": query, "variables": {
                               "id": sen_anilist_id, "page": page}}, headers=CLIENT.append_headers({"Content-Type": "application/json"}))
        if response.status_code != 200:
            return None
        data = response.json()
        favourite_anime = data["data"]["User"]["favourites"]["anime"]["nodes"]
        count = len(favourite_anime)
        if count <= 0:
            return None
        chosen = randomchoice(favourite_anime)
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
                        cast(QWidget, first_button.widget()).setFocus()
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
            self.setToolTip("Stable 🌲")
        else:
            super().__init__(window, 40, "black", GOGO_NORMAL_COLOR,
                             GOGO_HOVER_COLOR, GOGO_PRESSED_COLOR)
            self.setText("Gogoanime")
            self.setToolTip("Experimental 🧪")
        self.clicked.connect(lambda: window.search_anime(
            window.get_search_bar_text(), site))


class ResultButton(OutlinedButton):
    def __init__(self, anime: Anime,  main_window: MainWindow, search_window: SearchWindow, site: str, paint_x: int, paint_y: int):
        self.search_window = search_window
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
            if isinstance(event, QKeyEvent) and event.type() == event.Type.KeyPress and (event.key() in (Qt.Key.Key_Tab, Qt.Key.Key_Up, Qt.Key.Key_Down, Qt.Key.Key_Left, Qt.Key.Key_Right)):
                # It doesn't work without the QTimer for some reason, probably cause the horizontal scroll bar centering bug happens
                # after this event is processed so the fix is overwridden hence we wait for the bug to happen first then fix it thus we need the QTimer
                QTimer.singleShot(0, self.search_window.fix_hor_scroll_bar)
        return super().eventFilter(obj, event)


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
                    result)
                extracted_results.append(Anime(title, page_link, anime_id))
        elif self.site == GOGO:
            results = gogo.search(self.anime_title)
            for title, page_link in results:
                extracted_results.append(Anime(title, page_link, None))
        self.finished.emit(self.site, extracted_results)
