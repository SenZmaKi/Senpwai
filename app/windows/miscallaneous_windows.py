from PyQt6.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QPushButton
from PyQt6.QtCore import Qt
from shared.global_vars_and_funcs import chopper_crying_path, pahe_normal_color, pahe_hover_color, pahe_pressed_color
from shared.global_vars_and_funcs import red_normal_color, red_hover_color, red_pressed_color, set_minimum_size_policy
from shared.global_vars_and_funcs import gogo_normal_color, gogo_hover_color, gogo_pressed_color
from shared.shared_classes_and_widgets import StyledButton, StyledLabel
from shared.global_vars_and_funcs import settings, key_gogo_default_browser, chrome_name, edge_name, chopper_crying_path
from windows.main_actual_window import MainWindow, Window
from typing import cast
from webbrowser import open_new_tab


class FailedGettingDirectDownloadLinksWindow(Window):
    def __init__(self, main_window: MainWindow, anime_title: str, info_text: str, buttons_unique_to_window: list[QPushButton]) -> None:
        super().__init__(main_window, chopper_crying_path)
        main_window.set_bckg_img(chopper_crying_path)
        info_label = StyledLabel(font_size=30)
        info_label.setText(info_text)
        set_minimum_size_policy(info_label)
        main_layout = QVBoxLayout()
        buttons_layout = QHBoxLayout()
        buttons_widget = QWidget()
        switch_to_anime_pahe_button = StyledButton(
            None, 25, "black", pahe_normal_color, pahe_hover_color, pahe_pressed_color)
        switch_to_anime_pahe_button.setText("Switch to animepahe")
        set_minimum_size_policy(switch_to_anime_pahe_button)
        switch_to_anime_pahe_button.clicked.connect(
            lambda: main_window.switch_to_pahe(anime_title, self))
        switch_to_anime_pahe_button.clicked.connect(
            main_window.set_bckg_img)
        change_default_browser_button = StyledButton(
            None, 25, "black", red_normal_color, red_hover_color, red_pressed_color)
        change_default_browser_button.setText("Change gogo default browser")
        change_default_browser_button.clicked.connect(
            lambda: main_window.stacked_windows.setCurrentWidget(main_window.settings_window))
        change_default_browser_button.clicked.connect(
            main_window.set_bckg_img)
        set_minimum_size_policy(change_default_browser_button)
        buttons_layout.addWidget(switch_to_anime_pahe_button)
        buttons_layout.addWidget(change_default_browser_button)
        list(map(buttons_layout.addWidget, buttons_unique_to_window))
        buttons_widget.setLayout(buttons_layout)
        main_layout.addWidget(
            info_label, alignment=Qt.AlignmentFlag.AlignCenter)
        main_layout.addWidget(buttons_widget)
        main_widget = QWidget()
        main_widget.setLayout(main_layout)
        self.full_layout.addWidget(main_widget)
        self.setLayout(self.full_layout)


class CaptchaBlockWindow(FailedGettingDirectDownloadLinksWindow):
    def __init__(self, main_window: MainWindow, anime_title: str, download_page_links: list[str]) -> None:
        main_window.set_bckg_img(chopper_crying_path)
        info_text = (
            f"Captcha block detected, this only ever happens with Gogoanime\nChanging your Gogo default browser setting to something else may help\nYour current Gogo default browser is {settings[key_gogo_default_browser].capitalize()}")
        open_browser_with_links_button = StyledButton(
            None, 25, "black", gogo_normal_color, gogo_hover_color, gogo_pressed_color)
        open_browser_with_links_button.setText("Download in browser")
        open_browser_with_links_button.clicked.connect(lambda: list(
            map(webbrowser.open_new_tab, download_page_links)))  # type: ignore
        set_minimum_size_policy(open_browser_with_links_button)
        super().__init__(main_window, anime_title,
                         info_text, [open_browser_with_links_button])


class NoDefaultBrowserWindow(FailedGettingDirectDownloadLinksWindow):
    def __init__(self, main_window: MainWindow, anime_title: str):
        gogo_default_browser = cast(str, settings[key_gogo_default_browser])
        info_text = f"Unfortunately downloaading from Gogoanime requires you have either: \n\t\tChrome, Edge or Firefox installed\nIf you've already installed then change your Gogo default browser setting\nYour current Gogo default browser is {gogo_default_browser.capitalize()}"
        download_browser_button = StyledButton(
            None, 25, "black", gogo_normal_color, gogo_hover_color, gogo_pressed_color)
        if gogo_default_browser == edge_name:
            download_browser_button.setText("Download Chrome")
            download_browser_button.clicked.connect(lambda: open_new_tab(
                "https://www.google.com/chrome"))  # type: ignore
        elif gogo_default_browser == chrome_name:
            download_browser_button.setText("Download Edge")
            download_browser_button.clicked.connect(lambda: open_new_tab(
                "https://www.microsoft.com/edge/download"))  # type: ignore
        else:
            download_browser_button.setText("Download Firefox")
            download_browser_button.clicked.connect(lambda: open_new_tab(
                "https://www.mozilla.org/firefox"))  # type: ignore
        set_minimum_size_policy(download_browser_button)
        super().__init__(main_window, anime_title,
                         info_text, [download_browser_button])
