from PyQt6.QtGui import QPixmap, QPen, QPainterPath, QPainter, QMovie, QKeyEvent, QIcon
from PyQt6.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QLabel, QLineEdit, QPushButton, QScrollArea, QProgressBar, QFrame
from PyQt6.QtCore import Qt, QSize, QMutex, QTimer, pyqtSlot
from shared.global_vars_and_funcs import AllowedSettingsTypes, pahe_name, gogo_name
from time import time
from shared.global_vars_and_funcs import pause_icon_path, resume_icon_path, cancel_icon_path, settings, key_gogo_default_browser, key_quality, key_sub_or_dub, default_download_folder_paths
from shared.global_vars_and_funcs import folder_icon_path, red_normal_color, red_pressed_color, pahe_normal_color, pahe_pressed_color, gogo_normal_color
from shared.app_and_scraper_shared import sanitise_title, network_monad
from pathlib import Path
from typing import cast
import requests
import anitopy
import os
from scrapers import pahe
from scrapers import gogo


class Anime():
    def __init__(self, title: str, page_link: str, anime_id: str | None) -> None:
        self.title = title
        self.page_link = page_link
        self.id = anime_id


class BckgImg(QLabel):
    def __init__(self, parent, image_path) -> None:
        super().__init__(parent)
        pixmap = QPixmap(image_path)
        self.setPixmap(pixmap)
        self.setScaledContents(True)


class Animation(QLabel):
    def __init__(self, animation_path: str, animation_size_x: int, animation_size_y: int, parent: QWidget | None = None):
        super().__init__(parent)
        self.animation = QMovie(animation_path)
        self.animation.setScaledSize(QSize(animation_size_x, animation_size_y))
        self.setMovie(self.animation)

    def start(self):
        return self.animation.start()

    def stop(self):
        return self.animation.stop()


class StyledLabel(QLabel):
    def __init__(self, parent=None, font_size: int = 20, bckg_color: str = "rgba(0, 0, 0, 220)", border_radius=10, font_color="white"):
        super().__init__(parent)
        self.setStyleSheet(f"""
                    QLabel {{
                        color: {font_color};
                        font-size: {font_size}px;
                        font-family: "Berlin Sans FB Demi";
                        background-color: {bckg_color};
                        border-radius: {border_radius}px;
                        border: 1px solid black;
                        padding: 5px;
                    }}
                            """)


class StyledButton(QPushButton):
    def __init__(self, parent: QWidget | None, font_size: int, font_color: str, normal_color: str, hover_color: str, pressed_color: str, border_radius=12):
        super().__init__()
        if parent:
            self.setParent(parent)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setStyleSheet(f"""
            QPushButton {{
                color: {font_color};
                background-color: {normal_color};
                border: 1px solid black;
                padding: 5px;
                font-size: {font_size}px;
                font-family: "Berlin Sans FB Demi";
                padding: 10px;
                border-radius: {border_radius}px;
            }}
            QPushButton:hover {{
                background-color: {hover_color};
            }}
            QPushButton:pressed {{  
                background-color: {pressed_color};
            }}
        """)


class OptionButton(StyledButton):
    def __init__(self, parent: QWidget | None, option: AllowedSettingsTypes, option_displayed: str, font_size: int, chosen_color: str, hover_color: str, font_color="white"):
        super().__init__(parent, font_size, font_color,
                         "rgba(128, 128, 128, 255)", chosen_color, hover_color)
        self.not_picked_style_sheet = self.styleSheet()
        styles_to_overwride = f"""
            QPushButton {{
            border-radius: 7px;
            background-color: {chosen_color};
        }}
        QPushButton:hover {{
            background-color: {chosen_color};
        }}
    """
        self.picked_style_sheet = self.not_picked_style_sheet+styles_to_overwride
        self.option = option
        self.setText(option_displayed)
        self.clicked.connect(lambda: self.picked_status(True))

    def picked_status(self, picked: bool):
        if picked:
            self.setStyleSheet(self.picked_style_sheet)
        else:
            self.setStyleSheet(self.not_picked_style_sheet)


class IconButton(QPushButton):
    def __init__(self, size_x: int, size_y: int, icon_path: str, size_factor: int | float, parent: QWidget | None = None):
        super().__init__(parent)
        self.setFixedSize(size_x, size_y)
        self.icon_pixmap = QPixmap(icon_path)
        self.icon_pixmap.scaled(
            size_x, size_y, Qt.AspectRatioMode.IgnoreAspectRatio)
        self.setIcon(QIcon(self.icon_pixmap))
        self.setIconSize(self.size()/size_factor)  # type: ignore
        self.enterEvent = lambda event: self.setIconSize(QSize(size_x, size_y))
        self.leaveEvent = lambda a0: self.setIconSize(
            QSize(size_x, size_y)/size_factor)  # type: ignore
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setStyleSheet("""
            QPushButton {
                border: none; 
                background-color: transparent;
            }""")


class AnimationAndText(QWidget):
    def __init__(self, animation_path: str, animation_size_x: int, animation_size_y: int, text: str, paint_x: int, paint_y: int, font_size: int, parent: QWidget | None = None):
        super().__init__(parent)
        self.animation = Animation(
            animation_path, animation_size_x, animation_size_y, parent)
        self.animation_path = animation_path
        self.text_label = OutlinedLabel(parent, paint_x, paint_y)
        self.text_label.setText(text)
        self.text_label.setStyleSheet(f"""
                    OutlinedLabel {{
                        color: #FFEF00;
                        font-size: {font_size}px;
                        font-family: "Berlin Sans FB Demi";
                        }}
                        """)
        self.main_layout = QVBoxLayout()
        self.main_layout.addWidget(self.animation)
        self.main_layout.addWidget(self.text_label)
        self.main_layout.setAlignment(
            self.animation, Qt.AlignmentFlag.AlignCenter)
        self.main_layout.setAlignment(
            self.text_label, Qt.AlignmentFlag.AlignCenter)
        self.setLayout(self.main_layout)

    def start(self):
        return self.animation.start()

    def stop(self):
        return self.animation.stop()


class OutlinedLabel(QLabel):
    def __init__(self, parent: QWidget | None, paint_x: int, paint_y: int):
        self.paint_x = paint_x
        self.paint_y = paint_y
        super().__init__(parent)

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)

        # Draw the outline around the text
        pen = QPen()
        pen.setWidth(5)
        painter.setPen(pen)

        path = QPainterPath()
        path.addText(self.paint_x, self.paint_y, self.font(), self.text())
        painter.drawPath(path)

        # Call the parent class's paintEvent to draw the button background and other properties
        painter.end()
        return super().paintEvent(event)


class OutlinedButton(StyledButton):
    def __init__(self, paint_x, paint_y, parent: QWidget | None, font_size: int, font_color: str, normal_color: str,
                 hover_color: str, pressed_color: str, border_radius=12):
        self.paint_x = paint_x
        self.paint_y = paint_y
        super().__init__(parent, font_size, font_color, normal_color,
                         hover_color, pressed_color, border_radius)

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)

        # Draw the outline around the text
        pen = QPen()
        pen.setWidth(5)
        painter.setPen(pen)

        path = QPainterPath()
        path.addText(self.paint_x, self.paint_y, self.font(), self.text())
        painter.drawPath(path)

        # Call the parent class's paintEvent to draw the button background and other properties
        painter.end()
        return super().paintEvent(event)

class ErrorLabel(StyledLabel):
    def __init__(self, font_size: int, shown_duration_in_secs: int=3, parent: QWidget | None = None):
        super().__init__(parent, font_size, font_color="red")
        self.shown_duration_in_secs = shown_duration_in_secs

    def show(self):
        QTimer().singleShot(self.shown_duration_in_secs * 1000, self.hide)
        return super().show()


class ProgressBar(QWidget):
    def __init__(self, parent: QWidget | None, task_title: str, item_task_is_applied_on: str, total_value: int, units: str, units_divisor: int = 1):
        super().__init__(parent)
        self.item_task_is_applied_on = item_task_is_applied_on
        self.total_value = total_value
        self.units = units
        self.units_divisor = units_divisor
        self.mutex = QMutex()
        self.items_layout = QHBoxLayout(self)  # type: ignore
        self.setLayout(self.items_layout)

        self.bar = QProgressBar(self)
        self.bar.setValue(0)
        self.bar.setMaximum(total_value)
        self.bar.setFormat(f"{task_title} {item_task_is_applied_on}")
        self.bar.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.bar.setStyleSheet("""
             QProgressBar {
                 border: 1px solid black;
                 color: black;
                 text-align: center;
                 border-radius: 10px;
                 background-color: rgba(255, 255, 255, 150);
                 font-size: 22px;
                 font-family: "Berlin Sans FB Demi";
             }

             QProgressBar::chunk {
                 background-color: orange;
                 border-radius: 10px;
             }
         """)
        style_to_overwride = f"""
                QProgressBar::chunk {{
                 background-color: {gogo_normal_color};
                }}"""
        self.completed_stylesheet = self.bar.styleSheet()+style_to_overwride
        text_style_sheet = """
                        OutlinedLabel {
                        color: white;
                        font-size: 26px;
                        font-family: "Berlin Sans FB Demi";
                            }
                            """
        height = 50
        self.percentage = OutlinedLabel(self, 1, 35)
        self.percentage.setText("0 %")
        self.percentage.setFixedHeight(height)
        self.percentage.setStyleSheet(text_style_sheet)

        self.rate = OutlinedLabel(self, 1, 40)
        self.rate.setText(f" 0 {units}/s")
        self.rate.setFixedHeight(height)
        self.rate.setStyleSheet(text_style_sheet)

        self.eta = OutlinedLabel(self, 1, 40)
        self.eta.setText("∞ secs left")
        self.eta.setFixedHeight(height)
        self.eta.setStyleSheet(text_style_sheet)

        self.current_against_max_values = OutlinedLabel(self, 1, 40)
        self.current_against_max_values.setText(
            f"0/{round(total_value/units_divisor)} {units}")
        self.current_against_max_values.setFixedHeight(height)
        self.current_against_max_values.setStyleSheet(text_style_sheet)

        self.items_layout.addWidget(self.percentage)
        self.items_layout.addWidget(self.bar)
        self.items_layout.addWidget(self.eta)
        self.items_layout.addWidget(self.rate)
        self.items_layout.addWidget(self.current_against_max_values)
        self.prev_time = time()

    @pyqtSlot(int)
    def update(self, added_value: int):
        self.mutex.lock()
        new_value = self.bar.value() + added_value
        curr_time = time()
        time_elapsed = curr_time - self.prev_time
        max_value = self.bar.maximum()
        if new_value >= max_value:
            new_value = max_value
            self.bar.setFormat(f"Completed {self.item_task_is_applied_on}")
            self.bar.setStyleSheet(self.completed_stylesheet)

        self.bar.setValue(new_value)
        percent_new_value = round(new_value / max_value * 100)
        self.percentage.setText(f"{percent_new_value}%")
        self.current_against_max_values.setText(
            f" {round(new_value/self.units_divisor)}/{round(max_value/self.units_divisor)} {self.units}")
        # In cases of annoying division by zero crash where downloads update super quick
        if time_elapsed > 0 and added_value > 0:
            rate = added_value / time_elapsed
            eta = (max_value - new_value) * (1/rate)
            if eta >= 3600:
                self.eta.setText(f"{round(eta/3600, 1)} hrs left")
            elif eta >= 60:
                self.eta.setText(f"{round(eta/60)} mins left")
            else:
                self.eta.setText(f"{round(eta)} secs left")
            self.rate.setText(
                f" {round(rate/self.units_divisor, 1)} {self.units}/s")
            self.prev_time = curr_time
        self.mutex.unlock()


class DownloadProgressBar(ProgressBar):
    def __init__(self, parent: QWidget | None, task_title: str, item_task_is_applied_on: str, total_value: int, units: str, units_divisor: int, has_icon_buttons: bool = True):
        super().__init__(parent, task_title, item_task_is_applied_on,
                         total_value, units, units_divisor)
        self.has_icon_buttons = has_icon_buttons
        self.task_title = task_title
        self.paused = False
        self.cancelled = False
        self.pause_callback = lambda: None
        self.cancel_callback = lambda: None
        self.not_paused_style_sheet = self.bar.styleSheet()
        self.paused_style_sheet = """
                QProgressBar {
                    border: 1px solid black;
                    color: black;
                    text-align: center;
                    border-radius: 10px;
                    background-color: rgba(255, 255, 255, 150);
                    font-size: 22px;
                    font-family: "Berlin Sans FB Demi";
                }

                QProgressBar::chunk {
                    background-color: #FFA756;
                    border-radius: 10px;
                }
            """
        if has_icon_buttons:
            self.pause_button = IconButton(40, 40, pause_icon_path, 1.3)
            self.pause_icon = self.pause_button.icon()
            resume_icon_pixmap = QPixmap(resume_icon_path)
            resume_icon_pixmap.scaled(
                40, 40, Qt.AspectRatioMode.IgnoreAspectRatio)
            self.resume_icon = QIcon(resume_icon_pixmap)
            self.cancel_button: IconButton = IconButton(
                35, 35, cancel_icon_path, 1.3)
            self.pause_button.clicked.connect(self.pause_or_resume)
            self.cancel_button.clicked.connect(self.cancel)

            self.items_layout.addWidget(self.pause_button)
            self.items_layout.addWidget(self.cancel_button)

    def is_complete(self) -> bool:
        return True if self.bar.value() >= self.total_value else False

    def cancel(self):
        if not self.paused and not self.is_complete():
            self.bar.setFormat(f"Cancelled {self.item_task_is_applied_on}")
            self.cancel_callback()
            self.cancelled = True
            self.bar.setStyleSheet("""
                QProgressBar {
                    border: 1px solid black;
                    color: black;
                    text-align: center;
                    border-radius: 10px;
                    background-color: rgba(255, 255, 255, 150);
                    font-size: 22px;
                    font-family: "Berlin Sans FB Demi";
                }

                QProgressBar::chunk {
                    background-color: #FF0000;
                    border-radius: 10px;
                }
            """)

    def pause_or_resume(self):
        if not self.cancelled and not self.is_complete():
            self.pause_callback()
            self.paused = not self.paused
            if self.paused:
                self.bar.setStyleSheet(self.paused_style_sheet)
                self.bar.setFormat(f"Paused {self.item_task_is_applied_on}")
                if self.has_icon_buttons:
                    self.pause_button.setIcon(self.resume_icon)
            else:
                self.bar.setStyleSheet(self.not_paused_style_sheet)
                self.bar.setFormat(
                    f"{self.task_title} {self.item_task_is_applied_on}")
                if self.has_icon_buttons:
                    self.pause_button.setIcon(self.pause_icon)


class AnimeDetails():
    def __init__(self, anime: Anime, site: str):
        self.anime = anime
        self.site = site
        self.browser = settings[key_gogo_default_browser]
        self.sanitised_title = sanitise_title(anime.title)
        self.chosen_default_download_path: str = ''
        self.anime_folder_path = self.get_anime_folder_path()
        self.potentially_haved_episodes = self.get_potentially_haved_episodes()
        self.haved_episodes: list[int] = []
        self.haved_start, self.haved_end, self.haved_count = self.get_start_end_and_count_of_haved_episodes()
        self.dub_available = self.get_dub_availablilty_status()
        self.poster, self.summary, self.episode_count = self.get_poster_image_summary_and_episode_count()
        self.start_download_episode = 0
        self.end_download_episode = 0
        self.quality = settings[key_quality]
        self.sub_or_dub = settings[key_sub_or_dub]
        self.direct_download_links: list[str] = []
        self.download_info: list[str] = []
        self.total_download_size: int = 0
        self.predicted_episodes_to_download: list[int] = []

    def get_anime_folder_path(self) -> str | None:
        def try_path(title: str) -> str | None:
            detected = None
            for path in default_download_folder_paths:
                potential = os.path.join(path, title)
                upper = potential.upper()
                lower = potential.lower()
                if os.path.isdir(potential):
                    detected = potential
                if os.path.isdir(upper):
                    detected = upper
                if os.path.isdir(lower):
                    detected = lower
                if detected:
                    self.chosen_default_download_path = path
                    return detected
            self.chosen_default_download_path = default_download_folder_paths[0]
            return None

        path = try_path(self.sanitised_title)
        if path:
            return path
        sanitised_title2 = sanitise_title(self.anime.title.replace(":", ""))
        path = try_path(sanitised_title2)
        return path

    def get_potentially_haved_episodes(self) -> list[Path] | None:
        if not self.anime_folder_path:
            return None
        episodes = list(Path(self.anime_folder_path).glob("*"))
        return episodes

    def get_start_end_and_count_of_haved_episodes(self) -> tuple[int, int, int] | tuple[None, None, None]:
        if self.potentially_haved_episodes:
            for episode in self.potentially_haved_episodes:
                if "[Downloading]" in episode.name:
                    continue
                parsed = anitopy.parse(episode.name)
                if not parsed:
                    continue
                try:
                    episode_number = int(parsed['episode_number'])
                except KeyError:
                    continue
                if episode_number > 0:
                    self.haved_episodes.append(episode_number)
            self.haved_episodes.sort()
        return (self.haved_episodes[0], self.haved_episodes[-1], len(self.haved_episodes)) if len(self.haved_episodes) > 0 else (None, None, None)

    def get_dub_availablilty_status(self) -> bool:
        dub_available = False
        if self.site == pahe_name:
            dub_available = pahe.dub_available(
                self.anime.page_link, cast(str, self.anime.id))
        elif self.site == gogo_name:
            dub_available = gogo.dub_available(self.anime.title)
        return dub_available

    def get_poster_image_summary_and_episode_count(self) -> tuple[bytes, str, int]:
        poster_image: bytes = b''
        summary: str = ''
        episode_count: int = 0
        if self.site == pahe_name:
            poster_url, summary, episode_count = pahe.extract_poster_summary_and_episode_count(
                cast(str, self.anime.id))
            poster_image = network_monad(
                lambda: requests.get(poster_url).content)
        elif self.site == gogo_name:
            poster_url, summary, episode_count = gogo.extract_poster_summary_and_episode_count(
                self.anime.page_link)
            poster_image = network_monad(
                lambda: requests.get(poster_url).content)
        return (poster_image, summary, episode_count)


class ScrollableSection(QScrollArea):
    def __init__(self, layout: QVBoxLayout):
        super().__init__()
        self.setWidgetResizable(True)
        self.main_widget = QWidget()
        self.main_widget.setLayout(layout)
        self.main_layout = self.layout()
        self.setWidget(self.main_widget)
        self.setStyleSheet("""
                    QWidget {
                        background-color: transparent;
                        border: None;
                        }""")


class FolderButton(IconButton):
    def __init__(self, path: str, size_x: int, size_y: int, parent: QWidget | None = None):
        super().__init__(size_x, size_y, folder_icon_path, 1.3, parent)
        self.folder_path = path
        self.clicked.connect(lambda: os.startfile(self.folder_path))


class NumberInput(QLineEdit):
    def __init__(self, font_size: int = 14, parent: QWidget | None = None):
        super().__init__(parent)
        self.installEventFilter(self)
        self.setStyleSheet(f"""
            QLineEdit{{
                border: 2px solid black;
                border-radius: 12px;
                padding: 5px;
                color: black;
                font-size: {font_size}px;
                font-family: "Berlin Sans FB Demi";
                background-color: white;
            }}
        """)

    def eventFilter(self, obj, event):
        if event.type() == QKeyEvent.Type.KeyPress:
            if event.key() in (Qt.Key.Key_0, Qt.Key.Key_1, Qt.Key.Key_2, Qt.Key.Key_3, Qt.Key.Key_4, Qt.Key.Key_5,
                               Qt.Key.Key_6, Qt.Key.Key_7, Qt.Key.Key_8, Qt.Key.Key_9, Qt.Key.Key_Backspace,
                               Qt.Key.Key_Delete, Qt.Key.Key_Left, Qt.Key.Key_Right):
                return False
            else:
                return True
        return super().eventFilter(obj, event)


class GogoBrowserButton(OptionButton):
    def __init__(self, window: QWidget, browser: str, font_size: int):
        super().__init__(window, browser, browser.upper(),
                         font_size, red_normal_color, red_pressed_color)
        self.browser = browser


class QualityButton(OptionButton):
    def __init__(self, window: QWidget, quality: str, font_size: int):
        super().__init__(window, quality, quality, font_size,
                         pahe_normal_color, pahe_pressed_color)
        self.quality = quality


class SubDubButton(OptionButton):
    def __init__(self, window: QWidget, sub_or_dub: str, font_size: int):
        super().__init__(window, sub_or_dub, sub_or_dub.upper(),
                         font_size,  pahe_normal_color, pahe_pressed_color)
        self.sub_or_dub = sub_or_dub

class HorizontalLine(QFrame):
    def __init__(self, color: str = "black", parent: QWidget | None = None):
        super().__init__(parent)
        self.setFrameShape(QFrame.Shape.HLine)
        self.setStyleSheet(f"""
                        QFrame {{ 
                            background-color: {color}; 
                            }}
                            """)


