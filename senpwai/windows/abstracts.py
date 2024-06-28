from typing import TYPE_CHECKING, Callable

from PyQt6.QtCore import Qt
from PyQt6.QtWidgets import (
    QHBoxLayout,
    QVBoxLayout,
    QWidget,
)
from senpwai.common.static import (
    ABOUT_ICON_PATH,
    DOWNLOADS_ICON_PATH,
    SEARCH_ICON_PATH,
    SETTINGS_ICON_PATH,
)
from senpwai.common.widgets import IconButton, Icon

# https://stackoverflow.com/questions/39740632/python-type-hinting-without-cyclic-imports/3957388#39757388
if TYPE_CHECKING:
    from senpwai.windows.main import MainWindow


class NavBarButton(IconButton):
    def __init__(self, icon_path: str, switch_to_window_callable: Callable):
        super().__init__(Icon(50, 50, icon_path), 1.15)
        self.clicked.connect(switch_to_window_callable)
        self.setStyleSheet(
            """
            QPushButton {
                    border-radius: 21px;
                    background-color: black;
                }"""
        )


class AbstractWindow(QWidget):
    def __init__(self, main_window: "MainWindow", bckg_img_path: str):
        super().__init__(main_window)
        self.bckg_img_path = bckg_img_path
        self.full_layout = QHBoxLayout()
        nav_bar_widget = QWidget()
        self.nav_bar_layout = QVBoxLayout()

        self.search_window_button = NavBarButton(
            SEARCH_ICON_PATH, main_window.switch_to_search_window
        )
        self.download_window_button = NavBarButton(
            DOWNLOADS_ICON_PATH, main_window.switch_to_download_window
        )
        self.settings_window_button = NavBarButton(
            SETTINGS_ICON_PATH, main_window.switch_to_settings_window
        )
        self.about_window_button = NavBarButton(
            ABOUT_ICON_PATH, main_window.switch_to_about_window
        )
        self.nav_bar_buttons = [
            self.search_window_button,
            self.download_window_button,
            self.settings_window_button,
            self.about_window_button,
        ]
        for button in self.nav_bar_buttons:
            self.nav_bar_layout.addWidget(button)
        self.nav_bar_layout.setAlignment(Qt.AlignmentFlag.AlignTop)
        nav_bar_widget.setLayout(self.nav_bar_layout)
        self.full_layout.addWidget(nav_bar_widget)


class AbstractTemporaryWindow(AbstractWindow):
    def __init__(self, main_window: "MainWindow", bckg_img_path: str):
        super().__init__(main_window, bckg_img_path)
        for button in self.nav_bar_buttons:
            button.clicked.connect(
                lambda: main_window.stacked_windows.removeWidget(self)
            )
            button.clicked.connect(self.deleteLater)
