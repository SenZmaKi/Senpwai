from PyQt6.QtGui import QPixmap, QKeyEvent
from PyQt6.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QLabel, QStackedWidget, QLineEdit
from PyQt6.QtCore import Qt, QThread, pyqtSignal, QEvent, QTimer
from shared.global_vars_and_funcs import mascot_icon_path, gogo_name, pahe_name, loading_animation_path, sadge_piece_path, set_minimum_size_policy
from shared.global_vars_and_funcs import pahe_normal_color, pahe_hover_color, pahe_pressed_color, gogo_normal_color, gogo_hover_color, gogo_pressed_color, search_window_bckg_image_path
from shared.shared_classes_and_widgets import Anime, StyledButton, OutlinedButton, ScrollableSection, AnimationAndText
from windows.main_actual_window import MainWindow, Window
from scrapers import pahe
from scrapers import gogo


class SearchWindow(Window):
    def __init__(self, main_window: MainWindow):
        super().__init__(main_window, search_window_bckg_image_path)
        self.main_window = main_window
        main_widget = QWidget()
        main_layout = QVBoxLayout()

        mascot_label = QLabel()
        mascot_label.setPixmap(QPixmap(mascot_icon_path))
        mascot_label.setFixedSize(130, 100)
        mascot_label.setScaledContents(True)

        self.search_bar = SearchBar(self)
        self.get_search_bar_text = lambda: self.search_bar.text()
        self.search_bar.setMinimumHeight(60)

        search_bar_and_mascot_widget = QWidget()
        search_bar_and_mascot_layout = QVBoxLayout()
        search_bar_and_mascot_layout.addWidget(
            mascot_label, alignment=Qt.AlignmentFlag.AlignHCenter)
        search_bar_and_mascot_layout.addWidget(self.search_bar)
        search_bar_and_mascot_layout.setSpacing(0)
        search_bar_and_mascot_widget.setLayout(search_bar_and_mascot_layout)
        main_layout.addWidget(search_bar_and_mascot_widget)

        search_buttons_widget = QWidget()
        search_buttons_layout = QHBoxLayout()
        self.pahe_search_button = SearchButton(self, pahe_name)
        set_minimum_size_policy(self.pahe_search_button)
        # self.pahe_search_button.setFixedSize(220, 60)
        self.gogo_search_button = SearchButton(self, gogo_name)
        set_minimum_size_policy(self.gogo_search_button)
        # self.gogo_search_button.setFixedSize(220, 60)
        search_buttons_layout.addWidget(self.pahe_search_button)
        search_buttons_layout.addWidget(self.gogo_search_button)
        search_buttons_widget.setLayout(search_buttons_layout)
        main_layout.addWidget(search_buttons_widget)
        self.bottom_section_stacked_widgets = QStackedWidget()

        self.results_layout = QVBoxLayout()
        self.results_widget = ScrollableSection(self.results_layout)

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
        main_widget.setLayout(main_layout)
        self.full_layout.addWidget(main_widget)
        self.setLayout(self.full_layout)
        # We use a timer instead of calling setFocus raw cause apparently Qt wont setFocus if the widget isn't shown on screen, so we gotta wait a but first or sth StackOverflow Comment link: https://stackoverflow.com/questions/52853701/set-focus-on-button-in-app-with-group-boxes#comment92652037_52858926
        QTimer.singleShot(0, self.search_bar.setFocus)

    def search_anime(self, anime_title: str, site: str) -> None:
        # Check setup_chosen_anime_window and MainWindow for why the if statement
        # I might remove this cause the behavior experienced in setup_chosen_anime_window is absent here for some reason, but for safety I'll just keep it
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
            for result in results:
                button = ResultButton(result, self.main_window, site, 9, 48)
                self.results_layout.addWidget(button)
        self.loading.stop()
        self.search_thread = None


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
                    if first_button := self.search_window.results_layout.itemAt(0):
                        first_button.widget().setFocus()
                    else:
                        self.search_window.gogo_search_button.animateClick()
                    return True
        return super().eventFilter(obj, event)


class SearchButton(StyledButton):
    def __init__(self, window: SearchWindow, site: str):
        if site == pahe_name:
            super().__init__(window, 40, "black", pahe_normal_color,
                             pahe_hover_color, pahe_pressed_color)
            self.setText("Animepahe")
            self.setToolTip("Recommended")
        else:
            super().__init__(window, 40, "black", gogo_normal_color,
                             gogo_hover_color, gogo_pressed_color)
            self.setText("Gogoanime")
        self.clicked.connect(lambda: window.search_anime(
            window.get_search_bar_text(), site))


class ResultButton(OutlinedButton):
    def __init__(self, anime: Anime,  main_window: MainWindow, site: str, paint_x: int, paint_y: int):
        if site == pahe_name:
            hover_color = pahe_normal_color
            pressed_color = pahe_hover_color
        else:
            hover_color = gogo_normal_color
            pressed_color = gogo_hover_color
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
            if isinstance(event, QKeyEvent):
                if event.type() == event.Type.KeyPress and (event.key() == Qt.Key.Key_Enter or event.key() == Qt.Key.Key_Return):
                    self.animateClick()
            elif event.type() == QEvent.Type.FocusIn:
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
        if self.site == pahe_name:
            results = pahe.search(self.anime_title)

            for result in results:
                anime_id, title, page_link = pahe.extract_anime_id_title_and_page_link(
                    result)
                extracted_results.append(Anime(title, page_link, anime_id))
        elif self.site == gogo_name:
            results = gogo.search(self.anime_title)
            for result in results:
                title, page_link = gogo.extract_anime_title_and_page_link(
                    result)
                if title and page_link:  # to handle dub cases
                    extracted_results.append(Anime(title, page_link, None))
        self.finished.emit(extracted_results)
