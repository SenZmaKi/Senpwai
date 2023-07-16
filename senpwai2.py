import sys
from PyQt6 import QtCore
from PyQt6.QtGui import QColor, QPalette, QPixmap, QGuiApplication, QPen, QPainterPath, QPainter, QMovie, QKeyEvent, QIcon, QAction
from PyQt6.QtWidgets import QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, QLabel, QLineEdit, QPushButton, QFrame, QScrollArea, QProgressBar, QSystemTrayIcon, QStackedWidget, QLayout, QSizePolicy
from PyQt6.QtCore import QObject, Qt, QSize, QThread, pyqtSignal, QEvent, QPoint, pyqtSlot, QMutex
import os
import pahe
import gogo
from pathlib import Path
from random import randint  
import requests
from typing import Callable, cast
from intersection import ibytes_to_mbs_divisor, sanitise_title, Download, network_monad, dynamic_episodes_predictor_initialiser_pro_turboencapsulator
from time import time
import anitopy
from selenium.common.exceptions import WebDriverException
import webbrowser
from appdirs import user_config_dir
import json

if getattr(sys, 'frozen', False):
    base_directory = os.path.dirname(sys.executable)
else:
    base_directory = os.path.dirname(__file__)

app_name = "Senpwai"
pahe_name = "pahe"
gogo_name = "gogo"

dub = "dub"
sub = "sub"
default_sub_or_dub = sub
q_1080 = "1080p"
q_720 = "720p"
q_480 = "480p"
q_360 = "360p"
default_quality = q_720

folder = os.path.join(Path.home(), "Downloads")
if not os.path.isdir(folder): os.mkdir(folder)
folder = os.path.join(folder, "Anime")
if not os.path.isdir(folder): os.mkdir(folder)
default_download_folder_paths = [folder]

default_max_simutaneous_downloads = 2
default_gogo_browser = gogo.edge
default_make_download_complete_notification = True

assets_path = os.path.join(base_directory, "assets")

senpwai_icon_path = os.path.abspath("Senpwai_icon.ico")
bckg_images_path = os.path.join(assets_path, "background-images")
bckg_images = list(Path(bckg_images_path).glob("*"))
bckg_image_path = (str(bckg_images[randint(0, len(bckg_images)-1)])).replace("\\", "/")
loading_animation_path = os.path.join(assets_path, "loading.gif")
sadge_piece_path = os.path.join(assets_path, "sadge-piece.gif")
folder_icon_path = os.path.join(assets_path, "folder.png")
pause_icon_path = os.path.join(assets_path, "pause.png")
resume_icon_path = os.path.join(assets_path, "resume.png")
cancel_icon_path = os.path.join(assets_path, "cancel.png")
download_complete_icon_path = os.path.join(assets_path, "download-complete.png")
chopper_crying_path = os.path.join(assets_path, "chopper-crying.png")
zero_two_peeping_path = os.path.join(assets_path, "zero-two-peeping.png")

pahe_normal_color = "#FFC300"
pahe_hover_color = "#FFD700"
pahe_pressed_color = "#FFE900"

gogo_normal_color = "#00FF00"
gogo_hover_color = "#60FF00"
gogo_pressed_color = "#99FF00"

key_sub_or_dub = "sub_or_dub"
key_quality = "quality"
key_download_folder_paths = "download_folder_paths"
key_max_simulataneous_downloads = "max_simultaneous_downloads"
key_gogo_default_browser = "gogo_default_browser"
key_make_download_complete_notification = "make_download_complete_notification"

config_and_settings_folder_path = os.path.join(user_config_dir(), app_name)
if not os.path.isdir(config_and_settings_folder_path):
    os.mkdir(config_and_settings_folder_path)
settings_file_path = os.path.join(config_and_settings_folder_path, "settings.json")

def requires_admin_access(folder_path):
    try:
        temp_file = os.path.join(folder_path, 'temp.txt')
        open(temp_file, 'w').close()
        os.remove(temp_file)
        return False
    except PermissionError:
        return True


def validate_settings_json(settings_json: dict) -> dict:
    clean_settings = {}
    try:
        sub_or_dub = settings_json[key_sub_or_dub]
        if sub_or_dub not in (sub, dub): raise KeyError
        clean_settings[key_sub_or_dub] = sub_or_dub
    except KeyError:
        clean_settings[key_sub_or_dub] = default_sub_or_dub
    try:
        quality = settings_json[key_quality]
        if quality not in (q_1080, q_720, q_480, q_360): raise KeyError
        clean_settings[key_quality] = quality
    except KeyError:
        clean_settings[key_quality] = default_quality
    valid_folder_paths: list[str] = default_download_folder_paths
    try:
        download_folder_paths = settings_json[key_download_folder_paths]
        valid_folder_paths = [path for path in download_folder_paths if os.path.isdir(path) and not requires_admin_access(path)]
        if len(valid_folder_paths) == 0: 
            valid_folder_paths = default_download_folder_paths
        raise KeyError
    except KeyError:
        clean_settings[key_download_folder_paths] = valid_folder_paths
    try:
        max_simultaneous_downloads = settings_json[key_max_simulataneous_downloads]
        if not isinstance(max_simultaneous_downloads, int): raise KeyError
        clean_settings[key_max_simulataneous_downloads] = max_simultaneous_downloads
    except KeyError:
        clean_settings[key_max_simulataneous_downloads] = default_max_simutaneous_downloads
    try:
        gogo_default_browser = settings_json[key_gogo_default_browser]
        if gogo_default_browser not in (gogo.chrome, gogo.edge, gogo.firefox): raise KeyError
        clean_settings[key_gogo_default_browser] = gogo_default_browser
    except KeyError:
        clean_settings[key_gogo_default_browser] = default_gogo_browser
    try:
        make_download_complete_notification = settings_json[key_make_download_complete_notification] 
        if not isinstance(make_download_complete_notification, bool): raise KeyError
        clean_settings[key_make_download_complete_notification] = make_download_complete_notification
    except KeyError:
        clean_settings[key_make_download_complete_notification] = default_make_download_complete_notification
    
    return clean_settings

def configure_settings() -> dict:
    settings = {}
    if os.path.exists(settings_file_path):
        with open(settings_file_path, "r") as f:
            try:
                settings = cast(dict, json.load(f))
            except json.decoder.JSONDecodeError:
                pass
    with open(settings_file_path, "w") as f:
        validated_settings = validate_settings_json(settings)
        json.dump(validated_settings, f, indent=4)
        return validated_settings

settings = configure_settings()

def set_minimum_size_policy(object):
    object.setSizePolicy(QSizePolicy.Policy.Minimum, QSizePolicy.Policy.Minimum)
    object.setFixedSize(object.sizeHint())

class Anime():
    def __init__(self, title: str, page_link: str, anime_id: str|None) -> None:
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
    def __init__(self, animation_path: str, animation_size_x: int, animation_size_y: int, parent: QWidget | None=None):
        super().__init__(parent)
        self.animation = QMovie(animation_path)
        self.animation.setScaledSize(QSize(animation_size_x, animation_size_y))
        self.setMovie(self.animation)

    def start(self):
        return self.animation.start()

    def stop(self):
        return self.animation.stop()
class StyledLabel(QLabel):
    def __init__(self, parent=None, font_size: int=20, bckg_color: str="rgba(0, 0, 0, 220)", border_radius=10):
        super().__init__(parent)
        self.setStyleSheet(f"""
                    QLabel {{
                        color: white;
                        font-size: {font_size}px;
                        font-family: "Berlin Sans FB Demi";
                        background-color: {bckg_color};
                        border-radius: {border_radius}px;
                        border: 1px solid black;
                        padding: 5px;
                    }}
                            """)

class StyledButton(QPushButton):
    def __init__(self, parent: QWidget | None, font_size: int, font_color: str, normal_color: str, hover_color: str, pressed_color: str, border_radius=5):
        super().__init__()
        if parent: 
            self.setParent(parent)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setStyleSheet(f"""
            QPushButton {{
                color: {font_color};
                background-color: {normal_color};
                border-radius: 20px;
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

class IconButton(QPushButton):
    def __init__(self, size_x: int, size_y: int, icon_path: str, size_factor: int | float, parent: QWidget | None = None):
        super().__init__(parent)
        self.setFixedSize(size_x, size_y)
        self.icon_pixmap = QPixmap(icon_path)
        self.icon_pixmap.scaled(size_x, size_y, Qt.AspectRatioMode.IgnoreAspectRatio)
        self.setIcon(QIcon(self.icon_pixmap))
        self.setIconSize(self.size()/size_factor) # type: ignore
        self.enterEvent = lambda event: self.setIconSize(QSize(size_x, size_y))
        self.leaveEvent = lambda a0: self.setIconSize(QSize(size_x, size_y)/size_factor) # type: ignore
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setStyleSheet("""
            QPushButton {
                border: none; 
                background-color: transparent;
            }""")

class AnimationAndText(QWidget):
    def __init__(self, animation_path: str, animation_size_x: int, animation_size_y: int, text: str, paint_x: int, paint_y: int, font_size: int, parent: QWidget | None = None):
        super().__init__(parent)
        self.animation = Animation(animation_path, animation_size_x, animation_size_y, parent)
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
        self.main_layout.setAlignment(self.animation, Qt.AlignmentFlag.AlignCenter)
        self.main_layout.setAlignment(self.text_label, Qt.AlignmentFlag.AlignCenter)
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
                 hover_color: str, pressed_color: str, border_radius=5):
        self.paint_x = paint_x
        self.paint_y = paint_y
        super().__init__(parent, font_size, font_color, normal_color, hover_color, pressed_color, border_radius)
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

class ProgressBar(QWidget):
    def __init__(self, parent: QWidget | None, task_title: str, item_task_is_applied_on: str, total_value: int, units: str, units_divisor: int = 1):
        super().__init__(parent)
        self.item_task_is_applied_on = item_task_is_applied_on
        self.total_value = total_value
        self.units = units
        self.units_divisor = units_divisor
        self.mutex = QMutex()
        self.items_layout = QHBoxLayout(self) # type: ignore 
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
        style_to_overwride = """
                QProgressBar {
                 background-color: rgba(255, 255, 255, 150);
                }"""
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
        self.current_against_max_values.setText(f"0/{round(total_value/units_divisor)} {units}")
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
        self.current_against_max_values.setText(f" {round(new_value/self.units_divisor)}/{round(max_value/self.units_divisor)} {self.units}")
        # In cases of annoying division by zero crash where downloads update super quick
        if time_elapsed > 0 and added_value > 0:
            rate = added_value / time_elapsed
            eta = (max_value - new_value) * (1/rate) 
            if eta >= 3600: self.eta.setText(f"{round(eta/3600, 1)} hrs left")
            elif eta >= 60: self.eta.setText(f"{round(eta/60)} mins left")
            else: self.eta.setText(f"{round(eta)} secs left")
            self.rate.setText(f" {round(rate/self.units_divisor, 1)} {self.units}/s")
            self.prev_time = curr_time
        self.mutex.unlock()


class DownloadProgressBar(ProgressBar):
    def __init__(self, parent: QWidget | None, task_title: str, item_task_is_applied_on: str, total_value: int, units: str, units_divisor: int, has_icon_buttons: bool = True):
        super().__init__(parent, task_title, item_task_is_applied_on, total_value, units, units_divisor)
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
            resume_icon_pixmap.scaled(40, 40, Qt.AspectRatioMode.IgnoreAspectRatio)
            self.resume_icon = QIcon(resume_icon_pixmap) 
            self.cancel_button: IconButton = IconButton(35, 35, cancel_icon_path, 1.3)
            self.pause_button.clicked.connect(self.pause_or_resume)
            self.cancel_button.clicked.connect(self.cancel)

            self.items_layout.addWidget(self.pause_button)
            self.items_layout.addWidget(self.cancel_button)
    
    def is_complete(self)->bool:
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
                if self.has_icon_buttons: self.pause_button.setIcon(self.resume_icon)
            else: 
                self.bar.setStyleSheet(self.not_paused_style_sheet)
                self.bar.setFormat(f"{self.task_title} {self.item_task_is_applied_on}")
                if self.has_icon_buttons: self.pause_button.setIcon(self.pause_icon)

class AnimeDetails():
    def __init__(self, anime: Anime, site: str):
        self.anime = anime
        self.site = site
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
        def try_path(title: str)->str | None:
            detected = None
            for path in default_download_folder_paths:
                potential = os.path.join(path, title)
                upper = potential.upper()
                lower = potential.lower()
                if os.path.isdir(potential): detected = potential 
                if os.path.isdir(upper):  detected = upper
                if os.path.isdir(lower): detected = lower
                if detected:
                    self.chosen_default_download_path = path
                    return detected
            self.chosen_default_download_path = default_download_folder_paths[0]
            return None
        
        path = try_path(self.sanitised_title)
        if path: return path
        sanitised_title2 = sanitise_title(self.anime.title.replace(":", ""))
        path = try_path(sanitised_title2)
        return path

    def get_potentially_haved_episodes(self) -> list[Path] | None:
        if not self.anime_folder_path: return None
        episodes = list(Path(self.anime_folder_path).glob("*"))
        return episodes    

    def get_start_end_and_count_of_haved_episodes(self) -> tuple[int, int, int] | tuple[None, None, None]:
        if self.potentially_haved_episodes:
            for episode in self.potentially_haved_episodes:
                if "[Downloading]" in episode.name: continue
                parsed = anitopy.parse(episode.name)
                if not parsed: continue
                try:
                    episode_number = int(parsed['episode_number'])
                except KeyError:
                    continue
                if episode_number > 0: self.haved_episodes.append(episode_number)
            self.haved_episodes.sort()
        return (self.haved_episodes[0], self.haved_episodes[-1], len(self.haved_episodes)) if len(self.haved_episodes) > 0 else (None, None, None)
    
    def get_dub_availablilty_status(self) -> bool:
        dub_available = False
        if self.site == pahe_name:
            dub_available = pahe.dub_available(self.anime.page_link, cast(str, self.anime.id))
        elif self.site == gogo_name:
            dub_available = gogo.dub_available(self.anime.title)
        return dub_available

    def get_poster_image_summary_and_episode_count(self) -> tuple[bytes, str, int] :
        poster_image: bytes = b''
        summary: str = ''
        episode_count: int = 0
        if self.site == pahe_name:
            poster_url, summary, episode_count = pahe.extract_poster_summary_and_episode_count(cast(str, self.anime.id))
            poster_image = network_monad(lambda: requests.get(poster_url).content)
        elif self.site == gogo_name:
            poster_url, summary, episode_count = gogo.extract_poster_summary_and_episode_count(self.anime.page_link)
            poster_image = network_monad(lambda: requests.get(poster_url).content)
        return (poster_image, summary, episode_count)


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setStyleSheet(f"MainWindow{{border-image: url({bckg_image_path}) 0 0 0 0 stretch stretch;}}")
        # Places window at the center of the screen
        center_point = QGuiApplication.primaryScreen().availableGeometry().center()
        window_position = QPoint(center_point.x() - self.rect().center().x(), center_point.y() - self.rect().center().y())
        self.move(window_position)
        self.tray_icon = QSystemTrayIcon(QIcon(senpwai_icon_path), self)
        self.tray_icon.show()
        self.download_window = DownloadWindow(self)
        self.search_window = SearchWindow(self)
        self.settings_window = SettingsWindow(self)
        self.stacked_windows = QStackedWidget(self)
        self.stacked_windows.addWidget(self.search_window)
        self.stacked_windows.addWidget(self.download_window)
        self.stacked_windows.addWidget(self.settings_window)
        self.stacked_windows.setCurrentWidget(self.search_window)
        self.setCentralWidget(self.stacked_windows)
        self.setup_chosen_anime_window_thread = None
        # FOr testing purposes
        #self.create_and_switch_to_captcha_block_window("Naruto", ["https://ligma.com", "https://deeznuts.com"])
        # self.create_and_switch_to_no_supported_browser_window("Senyuu")

        # For testing purposes, the anime id changes after a while so check on animepahe if it doesn't work
        # self.setup_and_switch_to_chosen_anime_window(Anime("Senyuu.", "https://animepahe.ru/api?m=release&id=a8aa3a2e-e5da-2619-fce4-e829b65fef29", "a8aa3a2e-e5da-2619-fce4-e829b65fef29"), pahe_name)
        # self.setup_and_switch_to_chosen_anime_window(Anime("Blue Lock", "https://gogoanime.hu/category/blue-lock", None), gogo_name)

    def center_window(self) -> None:
        screen_geometry = QGuiApplication.primaryScreen().geometry()
        x = (screen_geometry.width() - self.width()) // 2
        y = (screen_geometry.height() - self.height()) // 2
        self.move(x, y)

    def setup_and_switch_to_chosen_anime_window(self, anime: Anime, site: str):
        # This if statement prevents error: "QThread: Destroyed while thread is still running" that happens when more than one thread is spawned when a set a user clicks more than one ResultButton causing the original thread to be reassigned hence get destroyed
        if not self.setup_chosen_anime_window_thread:
            self.search_window.loading.start()
            self.search_window.bottom_section_stacked_widgets.setCurrentWidget(self.search_window.loading)
            self.setup_chosen_anime_window_thread = SetupChosenAnimeWindowThread(self, anime, site)                  
            self.setup_chosen_anime_window_thread.finished.connect(lambda anime_details: self.handle_finished_drawing_window_widgets(anime_details))
            self.setup_chosen_anime_window_thread.start()

    def handle_finished_drawing_window_widgets(self, anime_details: AnimeDetails):
        self.setup_chosen_anime_window_thread = None
        self.search_window.loading.stop()
        self.search_window.bottom_section_stacked_widgets.setCurrentWidget(self.search_window.results_widget)
        chosen_anime_window = ChosenAnimeWindow(self, anime_details)
        self.stacked_windows.addWidget(chosen_anime_window)
        self.stacked_windows.setCurrentWidget(chosen_anime_window)
        self.setup_chosen_anime_window_thread = None


    def switch_to_pahe(self, anime_title: str, initiator: QWidget):
        self.stacked_windows.setCurrentWidget(self.search_window)
        self.stacked_windows.removeWidget(initiator)
        self.stacked_windows.removeWidget(initiator)
        self.search_window.search_bar.setText(anime_title)
        self.search_window.pahe_search_button.click()
    
    def create_and_switch_to_captcha_block_window(self, anime_title: str, download_page_links: list[str]) -> None:
        captcha_block_window = CaptchaBlockWindow(self, anime_title, download_page_links)
        self.stacked_windows.addWidget(captcha_block_window)
        self.stacked_windows.setCurrentWidget(captcha_block_window)

    def create_and_switch_to_no_supported_browser_window(self, anime_title: str):
        no_supported_browser_window = NoSupportedBrowserWindow(self, anime_title)
        self.stacked_windows.addWidget(no_supported_browser_window)
        self.stacked_windows.setCurrentWidget(no_supported_browser_window)

AllowedSettingsTypes = (str | int | bool | list[str])

class SettingsWindow(QWidget):
    def __init__(self, main_window: MainWindow) -> None:
        super().__init__()
        self.main_widget = BckgImg(None, bckg_image_path)
        self.main_layout = QVBoxLayout()
        self.main_scrollable = ScrollableSection(self.main_layout)
        self.sub_dub_setting = SubDubSetting(self)
        self.quality_setting = QualitySetting(self)
        self.max_simultaneous_downloads_setting = MaxSimultaneousDownloadsSetting(self)
        self.main_layout.addWidget(self.sub_dub_setting)
        self.main_layout.addWidget(self.quality_setting)
        self.main_layout.addWidget(self.max_simultaneous_downloads_setting)
        self.setLayout(self.main_layout)
    
    def update_settings_json(self, key: str, new_value: AllowedSettingsTypes):
        settings[key] = new_value
        with open(settings_file_path, "w") as f:
            json.dump(settings, f, indent=4)
class MaxSimultaneousDownloadsSetting(QWidget):
    def __init__(self, settings_window: SettingsWindow):
        super().__init__()
        self.setFixedSize(500, 80)
        self.setting_label = StyledLabel(font_size=25)
        self.setting_label.setText("Max simultaneous downloads")
        self.setting_label.setFixedSize(400, 60)
        self.main_layout = QHBoxLayout()
        self.number_input = NumberInput(font_size=25)
        self.number_input.setFixedSize(60, 50)
        self.number_input.setText(str(settings[key_max_simulataneous_downloads]))
        self.number_input.textChanged.connect(lambda value: settings_window.update_settings_json(key_max_simulataneous_downloads, value))
        self.main_layout.addWidget(self.setting_label)
        self.main_layout.addWidget(self.number_input)
        self.setLayout(self.main_layout)



class QualitySetting(QWidget):
    def __init__(self, settings_window: SettingsWindow):
        super().__init__()
        self.setFixedSize(800, 80)
        self.settings_window = settings_window
        self.setting_label = StyledLabel(font_size=25)
        self.setting_label.setText("Download quality")
        self.setting_label.setFixedSize(230, 60)
        self.main_layout = QHBoxLayout()
        self.button_1080 = QualityButton(settings_window, q_1080, 25)
        self.button_720 = QualityButton(settings_window, q_720, 25)
        self.button_480 = QualityButton(settings_window, q_480, 25)
        self.button_360 = QualityButton(settings_window, q_360, 25)
        self.quality_buttons_list = [self.button_1080, self.button_720, self.button_480, self.button_360]
        self.button_1080.setFixedSize(89, 50)
        for button in self.quality_buttons_list:
            quality = button.quality
            button.clicked.connect(lambda garbage_bool, quality=quality: self.update_quality(quality))
            if button.quality == settings[key_quality]:
                button.change_style_sheet(True)
            if button.quality == q_1080: continue
            button.setFixedSize(80, 50)
        self.main_layout.addWidget(self.setting_label)
        list(map(self.main_layout.addWidget, self.quality_buttons_list))
        self.setLayout(self.main_layout)

    def update_quality(self, quality: str):
        self.settings_window.update_settings_json(key_quality, quality)
        for button in self.quality_buttons_list:
            if button.quality != quality: button.change_style_sheet(False)


class SubDubSetting(QWidget):
    def __init__(self, settings_window: SettingsWindow):
        super().__init__()
        self.setFixedSize(500, 80)
        self.setting_label = StyledLabel(font_size=25)
        self.setting_label.setText("Sub or Dub")
        self.setting_label.setFixedSize(140, 60)
        self.main_layout = QHBoxLayout()
        self.sub_button = SubDubButton(settings_window, sub, 25) 
        self.dub_button = SubDubButton(settings_window, dub, 25)
        self.sub_button.setFixedSize(80, 50)
        self.dub_button.setFixedSize(80, 50)
        if settings[key_sub_or_dub] == sub: self.sub_button.click()
        else: self.dub_button.click()
        self.sub_button.clicked.connect(lambda: self.dub_button.change_style_sheet(False))
        self.dub_button.clicked.connect(lambda: self.sub_button.change_style_sheet(False))
        self.sub_button.clicked.connect(lambda: settings_window.update_settings_json(key_sub_or_dub, sub))
        self.dub_button.clicked.connect(lambda: settings_window.update_settings_json(key_sub_or_dub, dub))
        self.main_layout.addWidget(self.setting_label)
        self.main_layout.addWidget(self.sub_button)
        self.main_layout.addWidget(self.dub_button)
        self.setLayout(self.main_layout)
class CaptchaBlockWindow(QWidget):
    def __init__(self, main_window: MainWindow, anime_title: str, download_page_links: list[str]) -> None:
        super().__init__(main_window)
        self.setFixedSize(main_window.size())
        BckgImg(self, chopper_crying_path)
        info_label = StyledLabel(self, 30)
        info_label.move(50, 50)
        info_label.setText("\nCaptcha block detected, this only ever happens with Gogoanime\n")
        open_browser_with_links_button = StyledButton(self, 25, "black", gogo_normal_color, gogo_hover_color, gogo_pressed_color, 10)
        open_browser_with_links_button.setFixedSize(265, 100)
        open_browser_with_links_button.move(150, 300)
        open_browser_with_links_button.setText("Download in browser")
        open_browser_with_links_button.clicked.connect(lambda: list(map(webbrowser.open_new_tab, download_page_links))) # type: ignore
        switch_to_anime_pahe_button = StyledButton(self, 25, "black", pahe_normal_color, pahe_hover_color, pahe_pressed_color, 10)
        switch_to_anime_pahe_button.setFixedSize(265, 100)
        switch_to_anime_pahe_button.move(620, 300)
        switch_to_anime_pahe_button.setText("Switch to animepahe")
        switch_to_anime_pahe_button.clicked.connect(lambda: main_window.switch_to_pahe(anime_title, self))

class NoSupportedBrowserWindow(QWidget):
    def __init__(self, main_window: MainWindow, anime_title: str):
        super().__init__(main_window)
        self.setFixedSize(main_window.size())
        BckgImg(self, chopper_crying_path)
        info_label = StyledLabel(self, 30)
        info_label.move(150, 50)
        info_label.setText("\nUnfortunately downloaading from Gogoanime requires\n you have either Chrome, Edge or Firefox installed\n") 
        download_chrome_button = StyledButton(self, 25, "black", gogo_normal_color, gogo_hover_color, gogo_pressed_color, 10)
        download_chrome_button.setFixedSize(235, 100)
        download_chrome_button.move(150, 300)
        download_chrome_button.setText("Download Chrome")
        download_chrome_button.clicked.connect(lambda: webbrowser.open_new_tab("https://www.google.com/chrome")) # type: ignore
        switch_to_anime_pahe_button = StyledButton(self, 25, "black", pahe_normal_color, pahe_hover_color, pahe_pressed_color, 10)
        switch_to_anime_pahe_button.setFixedSize(280, 100)
        switch_to_anime_pahe_button.move(620, 300)
        switch_to_anime_pahe_button.setText("Switch to animepahe")
        switch_to_anime_pahe_button.clicked.connect(lambda: main_window.switch_to_pahe(anime_title, self))

class SearchWindow(QWidget):
    def __init__(self, main_window: MainWindow):
        super().__init__()
        self.main_window = main_window
        main_layout = QVBoxLayout()

        zero_two_peeping = QLabel()
        zero_two_peeping.setPixmap(QPixmap(zero_two_peeping_path))
        zero_two_peeping.setFixedSize(130, 100)
        zero_two_peeping.setScaledContents(True)
        main_layout.addWidget(zero_two_peeping)
        main_layout.setAlignment(zero_two_peeping, Qt.AlignmentFlag.AlignHCenter)
        
        self.search_bar = SearchBar(self)
        self.get_search_bar_text = lambda: self.search_bar.text()
        self.search_bar.setMinimumHeight(60)
        main_layout.addWidget(self.search_bar)
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

        self.loading = AnimationAndText(loading_animation_path, 600, 300, "Loading.. .", 1, 48, 50)
        self.anime_not_found = AnimationAndText(sadge_piece_path, 400, 300, ":( couldn't find that anime ", 1, 48, 50)
        self.bottom_section_stacked_widgets.addWidget(self.loading)
        self.bottom_section_stacked_widgets.addWidget(self.anime_not_found)
        self.bottom_section_stacked_widgets.addWidget(self.results_widget)
        self.bottom_section_stacked_widgets.setCurrentWidget(self.results_widget)
        main_layout.addWidget(self.bottom_section_stacked_widgets)


        self.setLayout(main_layout)
        self.search_thread = None
        self.search_bar.setFocus()


    def search_anime(self, anime_title: str, site: str) -> None:
        # Check setup_chosen_anime_window and MainWindow for why the if statement
        # I might remove this cause the behavior experienced in setup_chosen_anime_window is absent here for some reason, but for safety I'll just keep it
        if not self.search_thread:
            if self.bottom_section_stacked_widgets.currentWidget() == self.anime_not_found: self.anime_not_found.stop()
            self.bottom_section_stacked_widgets.setCurrentWidget(self.loading)
            self.loading.start()
            for idx in reversed(range(self.results_layout.count())):
                self.results_layout.itemAt(idx).widget().deleteLater()
            self.search_thread = SearchThread(self, anime_title, site)
            self.search_thread.finished.connect(lambda results: self.handle_finished_search(site, results))
            self.search_thread.start()

    def handle_finished_search(self, site: str, results: list[Anime]): 
        self.loading.stop() 
        if len(results) == 0:
            self.bottom_section_stacked_widgets.setCurrentWidget(self.anime_not_found)
            self.anime_not_found.start()
        else:
            self.bottom_section_stacked_widgets.setCurrentWidget(self.results_widget)  
            for result in results:
                button = ResultButton(result, self.main_window, site, 9, 48)
                self.results_layout.addWidget(button)
        self.search_thread = None


class SearchThread(QThread):
    finished = pyqtSignal(list) 
    def __init__(self, window: SearchWindow, anime_title: str, site: str):
        super().__init__(window)
        self.anime_title  = anime_title
        self.site  = site
    
    def run(self):
        extracted_results = []
        if self.site == pahe_name:
            results = pahe.search(self.anime_title)

            for result in results:
                anime_id, title, page_link = pahe.extract_anime_id_title_and_page_link(result)
                extracted_results.append(Anime(title, page_link, anime_id))
        elif self.site == gogo_name:
            results = gogo.search(self.anime_title) 
            for result in results:
                title, page_link = gogo.extract_anime_title_and_page_link(result)
                if title and page_link : # to handle dub cases
                    extracted_results.append(Anime(title, page_link, None))
        self.finished.emit(extracted_results)

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
                    if first_button := self.search_window.results_layout.itemAt(0): first_button.widget().setFocus()
                    else:
                        self.search_window.gogo_search_button.animateClick()
                    return True
        return super().eventFilter(obj, event)


class DownloadedEpisodeCount(StyledLabel):
    def __init__(self, parent, total_episodes: int, tray_icon: QSystemTrayIcon, anime_title: str, 
                 download_complete_icon: QIcon, anime_folder_path: str):
        super().__init__(parent, 30)
        self.total_episodes = total_episodes
        self.current_episodes = 0
        self.tray_icon = tray_icon
        if default_make_download_complete_notification:
            self.tray_icon.messageClicked.connect(lambda : os.startfile(anime_folder_path))
        self.anime_title = anime_title
        self.download_complete_icon = download_complete_icon
        self.setText(f"{0}/{total_episodes} eps")
        self.show()

    def download_complete_notification(self):
        self.tray_icon.showMessage("Download Complete", self.anime_title, self.download_complete_icon)

    def is_complete(self) -> bool:
        return self.current_episodes >= self.total_episodes

    def is_cancelled(self) -> bool:
        return self.total_episodes <= 0

    def update(self, added_episode_count: int):
        self.current_episodes+=added_episode_count
        self.setText(f"{self.current_episodes}/{self.total_episodes} eps")
        if  self.is_complete and not self.is_cancelled:
            self.download_complete_notification()
        super().update()
        set_minimum_size_policy(self)


class CancelAllButton(StyledButton):
    def __init__(self, parent: QWidget | None=None):
        super().__init__(parent, 25, "white", "red", "#ED2B2A", "#990000")
        self.setText("CANCEL")
        self.cancel_callback: Callable = lambda: None
        self.clicked.connect(self.cancel) 
        self.show()

    def cancel(self):
        self.cancel_callback()

class PauseAllButton(StyledButton):
    def __init__(self, download_is_active: Callable, parent: QWidget | None=None):
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



class DownloadWindow(QWidget):
    def __init__(self, main_window: MainWindow):
        super().__init__(main_window)
        self.main_window = main_window
        self.download_complete_icon = QIcon(download_complete_icon_path)
        self.tray_icon = main_window.tray_icon
        main_layout = QVBoxLayout()
        progress_bars_widget = QWidget()
        self.progress_bars_layout = QVBoxLayout()
        """
            Careful now DONT CHANGE THE ORDERING BELOW
            Without maintaining a reference to ScrollabeSection by assigning it to a variable, the garbage COllector deletes it and since the last known father
            to self.progress_bars_layout is ScrollableSection self.progress_bars_layout gets deleted resulting to RuntimeError. The same behaviour is experienced if we assign
            it to a variable but make the assignment after we call progress_bars_widget.setLayout(self.progress_bars_layout), since the last known father is scrollable_section
            but it gets out of scope when we leave the __init__ hence a garbage collected and a crash
        """ 
        _ = ScrollableSection(self.progress_bars_layout)
        progress_bars_widget.setLayout(self.progress_bars_layout)
        top_section_widget = QWidget()
        top_section_layout = QVBoxLayout()
        top_section_widget.setLayout(top_section_layout)
        first_row_of_progress_bar_widget = QWidget()
        self.first_row_of_progress_bar_layout = QHBoxLayout()
        first_row_of_progress_bar_widget.setLayout(self.first_row_of_progress_bar_layout)
        second_row_of_buttons_widget = QWidget()
        self.second_row_of_buttons_layout = QHBoxLayout()
        second_row_of_buttons_widget.setLayout(self.second_row_of_buttons_layout)
        top_section_layout.addWidget(first_row_of_progress_bar_widget)
        top_section_layout.addWidget(second_row_of_buttons_widget)
        main_layout.addWidget(top_section_widget)
        main_layout.addWidget(progress_bars_widget)
        self.setLayout(main_layout)

    def get_episode_page_links(self, anime_details: AnimeDetails):
        if anime_details.site == pahe_name: 
            episode_page_progress_bar = ProgressBar(None, "Getting episode page links", "", pahe.get_total_episode_page_count(anime_details.anime.page_link), "pgs")
            self.progress_bars_layout.insertWidget(0, episode_page_progress_bar)
            return GetEpisodePageLinksThread(self, anime_details, anime_details.start_download_episode, anime_details.end_download_episode, 
                                  lambda eps_links: self.get_download_page_links(eps_links, anime_details), episode_page_progress_bar.update).start()    
        if anime_details.site ==  gogo_name and anime_details.sub_or_dub == dub and anime_details.dub_available: anime_details.anime.page_link = gogo.get_dub_anime_page_link(anime_details.anime.title) 
        GetEpisodePageLinksThread(self, anime_details, anime_details.start_download_episode, anime_details.end_download_episode, 
                                  lambda eps_links : self.get_download_page_links(eps_links, anime_details), lambda x: None).start() 

    def get_download_page_links(self, episode_page_links: list[str], anime_details: AnimeDetails):
        episode_page_links = [episode_page_links[eps-anime_details.start_download_episode] for eps in anime_details.predicted_episodes_to_download]
        download_page_progress_bar = ProgressBar(self, "Fetching download page links", "", len(episode_page_links), "eps")
        self.progress_bars_layout.insertWidget(0, download_page_progress_bar)
        GetDownloadPageThread(self, anime_details.site, episode_page_links, lambda down_pge_lnk, down_info: self.get_direct_download_links(down_pge_lnk, down_info, anime_details)
                              , download_page_progress_bar.update).start()

    def get_direct_download_links(self, download_page_links: list[str], download_info: list[list[str]], anime_details: AnimeDetails):
        direct_download_links_progress_bar =  ProgressBar(self, "Retrieving direct download links", "", len(download_page_links), "eps") 
        self.progress_bars_layout.insertWidget(0, direct_download_links_progress_bar)
        GetDirectDownloadLinksThread(self, download_page_links, download_info, anime_details, lambda status: self.check_link_status(status, anime_details, download_page_links), 
                                     direct_download_links_progress_bar.update).start()

    def check_link_status(self, status: int, anime_details: AnimeDetails, download_page_links: list[str]):
        if status == 1: self.calculate_download_size(anime_details)
        elif status == 2: self.main_window.create_and_switch_to_no_supported_browser_window(anime_details.anime.title)
        elif status == 3: self.main_window.create_and_switch_to_captcha_block_window(anime_details.anime.title, download_page_links)

    def calculate_download_size(self, anime_details: AnimeDetails):
        if anime_details.site == gogo_name:
            calculating_download_size_progress_bar = ProgressBar(self, "Calcutlating total download size", "", len(anime_details.direct_download_links), "eps")
            self.progress_bars_layout.insertWidget(0, calculating_download_size_progress_bar)
            CalculateDownloadSizes(self, anime_details, lambda : self.start_download(anime_details), calculating_download_size_progress_bar.update).start()
        elif anime_details.site == pahe_name:
            CalculateDownloadSizes(self, anime_details, lambda : self.start_download(anime_details), lambda x: None).start()

    def start_download(self, anime_details: AnimeDetails):
        if not anime_details.anime_folder_path:
            anime_details.anime_folder_path = os.path.join(anime_details.chosen_default_download_path, anime_details.sanitised_title)
            os.mkdir(anime_details.anime_folder_path)                          
        anime_progress_bar = DownloadProgressBar(None, "Downloading", anime_details.anime.title, anime_details.total_download_size, "MB", 1, False)
        anime_progress_bar.bar.setMinimumHeight(50)
        self.first_row_of_progress_bar_layout.addWidget(anime_progress_bar)
        downloaded_episode_count = DownloadedEpisodeCount(None, len(anime_details.predicted_episodes_to_download), self.tray_icon, 
                                                          anime_details.anime.title, self.download_complete_icon, anime_details.anime_folder_path)
        download_is_active = lambda: not downloaded_episode_count.is_complete() or not downloaded_episode_count.is_cancelled()
        set_minimum_size_policy(downloaded_episode_count)
        folder_button = FolderButton(cast(str, anime_details.anime_folder_path), 120, 120, None)
        self.current_download = DownloadManagerThread(self, anime_details, anime_progress_bar, downloaded_episode_count)
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
        bar = DownloadProgressBar(None, "Downloading", episode_title, episode_size, "MB", ibytes_to_mbs_divisor)
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
        self.send_progress_bar_details.connect(download_window.receive_download_progress_bar_details)
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
            self.downloaded_episode_count.total_episodes-=1
            self.downloaded_episode_count.update(0)
    # Gogo's direct download link sometimes doesn't work, it returns a 302 status code meaning the resource has been moved, this attempts to redirect to that link
    # It is applied to Pahe too just in case
    def gogo_check_if_valid_link (self, link: str) -> requests.Response | None:
        response = cast(requests.Response, network_monad(lambda: requests.get(link, stream=True)))
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
            while len(self.progress_bars) == default_max_simutaneous_downloads: continue
            download_size = self.get_exact_episode_size(link)
            if download_size == 0: continue
            while self.paused: continue
            if self.cancelled: break
            episode_title = f"{self.anime_details.sanitised_title} Episode {self.anime_details.predicted_episodes_to_download[idx]}"
            self.mutex.lock()
            self.send_progress_bar_details.emit(episode_title, download_size, self.progress_bars)
            self.mutex.unlock()
            while episode_title not in self.progress_bars: continue  
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
        self.update_downloaded_episode_count.connect(update_downloaded_episode_count_callback)
        self.mutex = mutex
        self.download: Download | None = None
        self.is_cancelled = False

    def cancel(self):
        if self.download:
            self.download.cancel()
            new_maximum = self.anime_progress_bar.bar.maximum() - round(self.size / ibytes_to_mbs_divisor)
            if new_maximum > 0:
                self.anime_progress_bar.bar.setMaximum(new_maximum)
            new_value = round(self.anime_progress_bar.bar.value() - round(self.progress_bar.bar.value() / ibytes_to_mbs_divisor))
            if new_value < 0: new_value = 0
            self.anime_progress_bar.bar.setValue(new_value )
            self.is_cancelled = True
    
    def run(self):
        self.download = Download(self.link, self.title, self.download_folder, lambda x: self.update_bar.emit(x))
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
        self.finished.connect(lambda episode_page_links: finished_callback(episode_page_links))
        self.start_episode = start_episode
        self.end_index = end_episode
        self.update_bar.connect(progress_update_callback)
    def run(self):
        if self.anime_details.site == pahe_name:
            episode_page_links = pahe.get_episode_page_links(self.start_episode, self.end_index, self.anime_details.anime.page_link, cast(str, self.anime_details.anime.id), lambda x: self.update_bar.emit(x))
            self.finished.emit(episode_page_links)
        elif self.anime_details.site == gogo_name:
            episode_page_links = gogo.generate_episode_page_links(self.start_episode, self.end_index, self.anime_details.anime.page_link)
            self.finished.emit(episode_page_links)

class GetDownloadPageThread(QThread):
    finished = pyqtSignal(list, list)
    update_bar = pyqtSignal(int) 
    def __init__(self, parent, site: str, episode_page_links: list[str], finished_callback: Callable, progress_update_callback: Callable):
        super().__init__(parent)
        self.site = site
        self.episode_page_links = episode_page_links
        self.finished.connect(lambda download_page_links, download_info: finished_callback(download_page_links, download_info))
        self.update_bar.connect(progress_update_callback)
    def run(self):
        if self.site == pahe_name:
            download_page_links, download_info = pahe.get_pahewin_download_page_links_and_info(self.episode_page_links, lambda x: self.update_bar.emit(x))
            self.finished.emit(download_page_links, download_info)
        elif self.site == gogo_name:
            download_page_links = gogo.get_download_page_links(self.episode_page_links, lambda x: self.update_bar.emit(x))
            self.finished.emit(download_page_links, [])

class GetDirectDownloadLinksThread(QThread):
    finished =  pyqtSignal(int)
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
            bound_links, bound_info = pahe.bind_sub_or_dub_to_link_info(self.anime_details.sub_or_dub, cast(list[list[str]], self.download_page_links), self.download_info)
            bound_links, bound_info = pahe.bind_quality_to_link_info(self.anime_details.quality, bound_links, bound_info )
            self.anime_details.download_info = bound_info
            self.anime_details.direct_download_links = pahe.get_direct_download_links(bound_links, lambda x: self.update_bar.emit(x))
            self.finished.emit(1)
        if self.anime_details.site ==  gogo_name:
            try: 
                self.anime_details.direct_download_links = gogo.get_direct_download_link_as_per_quality(cast(list[str], self.download_page_links), self.anime_details.quality, 
                                                                                        gogo.setup_headless_browser(default_gogo_browser), lambda x: self.update_bar.emit(x))
                # For testing purposes
                # raise WebDriverException
                # raise TimeoutError
                self.finished.emit(1)
            except Exception as exception:
                if isinstance(exception, WebDriverException): self.finished.emit(2)
                elif isinstance(exception, TimeoutError): self.finished.emit(3)

                                                                                                    
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
            self.anime_details.total_download_size = gogo.calculate_download_total_size(self.anime_details.direct_download_links, lambda x: self.update_bar.emit(x), True)
        elif self.anime_details.site == pahe_name:
            self.anime_details.total_download_size = pahe.calculate_total_download_size(self.anime_details.download_info)
        self.finished.emit()
        
class ChosenAnimeWindow(QWidget):
    def __init__(self, main_window: MainWindow, anime_details: AnimeDetails):
        super().__init__(main_window)
        self.main_window = main_window
        self.anime_details = anime_details

        main_layout = QHBoxLayout()
        poster = Poster(self.anime_details.poster)
        main_layout.addWidget(poster)
        right_widgets_widget = QWidget()
        right_widgets_layout = QVBoxLayout()
        title = Title(self.anime_details.anime.title)
        right_widgets_layout.addWidget(title)
        line_under_title = HorizontalLine()
        line_under_title.setFixedHeight(10)
        right_widgets_layout.addWidget(line_under_title)
        summary = SummaryLabel(self.anime_details.summary)
        right_widgets_layout.addWidget(summary)

        self.sub_button = SubDubButton(self, sub, 25)
        set_minimum_size_policy(self.sub_button)
        # self.sub_button.setFixedSize(buttons_default_size)
        self.dub_button = None
        self.sub_button.clicked.connect(lambda: self.update_sub_or_dub(sub))
        if settings[key_sub_or_dub] == sub: self.sub_button.animateClick()
        if self.anime_details.dub_available:
            self.dub_button = SubDubButton(self, dub, 25)
            # self.dub_button.setFixedSize(buttons_default_size)
            set_minimum_size_policy(self.dub_button)
            self.dub_button.clicked.connect(lambda: self.update_sub_or_dub(dub))
            if settings[key_sub_or_dub] == dub: self.dub_button.click()
            self.dub_button.clicked.connect(lambda: self.sub_button.change_style_sheet(False))
            self.sub_button.clicked.connect(lambda: self.dub_button.change_style_sheet(False))# type: ignore
        else: 
            self.sub_button.click()
            self.anime_details.sub_or_dub = sub

        first_row_of_buttons_widget = QWidget()
        first_row_of_buttons_layout = QHBoxLayout()
        first_row_of_buttons_layout.addWidget(self.sub_button)
        if self.dub_button: first_row_of_buttons_layout.addWidget(self.dub_button)

        self.button_1080 = QualityButton(self, q_1080, 21) 
        self.button_720 = QualityButton(self, q_720, 21) 
        self.button_480 = QualityButton(self, q_480, 21) 
        self.button_360 = QualityButton(self, q_360, 21) 
        self.quality_buttons_list = [self.button_1080, self.button_720, self.button_480, self.button_360]

        for button in self.quality_buttons_list:
            set_minimum_size_policy(button)
            first_row_of_buttons_layout.addWidget(button)
            quality = button.quality
            button.clicked.connect(lambda garbage_bool, quality=quality: self.update_quality(quality))
            if quality == settings[key_quality]:
                button.change_style_sheet(True)
        first_row_of_buttons_layout.setAlignment(Qt.AlignmentFlag.AlignLeft)
        first_row_of_buttons_widget.setLayout(first_row_of_buttons_layout)
        right_widgets_layout.addWidget(first_row_of_buttons_widget)

        second_row_of_buttons_widget = QWidget()
        second_row_of_buttons_layout = QHBoxLayout()

        start_episode = str((self.anime_details.haved_end)+1) if (self.anime_details.haved_end and self.anime_details.haved_end < self.anime_details.episode_count) else "1"
        input_size = QSize(80, 40)
        self.start_episode_input = NumberInput(21)
        self.start_episode_input.setFixedSize(input_size)
        self.start_episode_input.setPlaceholderText("START")
        self.start_episode_input.setText(str(start_episode))
        self.end_episode_input = NumberInput(21)
        self.end_episode_input.setPlaceholderText("END")
        self.end_episode_input.setFixedSize(input_size)
        self.download_button = DownloadButton(self, self.main_window.download_window, self.anime_details)
        set_minimum_size_policy(self.download_button)
        # self.download_button.setFixedSize(180, buttons_default_size.height()+20)

        second_row_of_buttons_layout.addWidget(self.start_episode_input)
        second_row_of_buttons_layout.addWidget(self.end_episode_input)
        second_row_of_buttons_layout.addWidget(self.download_button)
        second_row_of_buttons_widget.setLayout(second_row_of_buttons_layout)
        second_row_of_buttons_layout.setAlignment(Qt.AlignmentFlag.AlignLeft)
        # second_row_of_buttons_layout.setAlignment(Qt.AlignmentFlag.AlignLeft)
        right_widgets_layout.addWidget(second_row_of_buttons_widget)

        third_row_of_labels_widget = QWidget()
        third_row_of_labels_layout = QHBoxLayout()

        haved_episodes = HavedEpisodes(self.anime_details.haved_start, self.anime_details.haved_end, self.anime_details.haved_count)
        # haved_episodes.setFixedSize(420, buttons_default_size.height())
        set_minimum_size_policy(haved_episodes)
        self.episode_count = EpisodeCount(str(self.anime_details.episode_count))
        # self.episode_count.setFixedSize(150, buttons_default_size.height())
        set_minimum_size_policy(self.episode_count)
        third_row_of_labels_layout.addWidget(self.episode_count)
        third_row_of_labels_layout.addWidget(haved_episodes)
        if self.anime_details.anime_folder_path: 
            folder_button = FolderButton(self.anime_details.anime_folder_path, 120, 120)
            third_row_of_labels_layout.addWidget(folder_button)
        third_row_of_labels_layout.setAlignment(Qt.AlignmentFlag.AlignLeft)
        third_row_of_labels_widget.setLayout(third_row_of_labels_layout)
        right_widgets_layout.addWidget(third_row_of_labels_widget)
        right_widgets_widget.setLayout(right_widgets_layout)
        main_layout.addWidget(right_widgets_widget)
        self.setLayout(main_layout)

        # For testing purposes
        #self.download_button.animateClick()

    def update_quality(self, quality: str):
        self.anime_details.quality = quality
        for button in self.quality_buttons_list:
            if button.quality != quality: button.change_style_sheet(False)

    def update_sub_or_dub(self, sub_or_dub: str):
        self.anime_details.sub_or_dub = sub_or_dub
        if sub_or_dub == dub: self.sub_button.change_style_sheet(False)
        elif self.dub_button != None: self.dub_button.change_style_sheet(False)


class SetupChosenAnimeWindowThread(QThread):
    finished = pyqtSignal(AnimeDetails)
    def __init__(self, window: MainWindow, anime: Anime, site: str):
        super().__init__(window)
        self.anime = anime
        self.site = site
        self.window = window
    def run(self):
        self.finished.emit(AnimeDetails(self.anime, self.site))

class DownloadButton(StyledButton):
    def __init__(self, chosen_anime_window: ChosenAnimeWindow, download_window: DownloadWindow, anime_details: AnimeDetails):
        super().__init__(chosen_anime_window, 26, "white", "green", gogo_normal_color, gogo_hover_color)
        self.chosen_anime_window = chosen_anime_window
        self.download_window = download_window
        self.main_window = chosen_anime_window.main_window
        self.anime_details =  anime_details
        self.clicked.connect(self.handle_download_button_clicked)
        self.setText("DOWNLOAD")
    
    def handle_download_button_clicked(self):
        invalid_input = False
        episode_count = self.anime_details.episode_count
        haved_end = int(self.anime_details.haved_end) if self.anime_details.haved_end else 0
        start_episode = self.chosen_anime_window.start_episode_input.text()
        end_episode = self.chosen_anime_window.end_episode_input.text()
        if start_episode == "0" or end_episode == "0": invalid_input = True
        if start_episode == "": start_episode = 1
        if end_episode == "": end_episode = episode_count
        start_episode = int(start_episode)
        end_episode = int(end_episode)

        if haved_end >= episode_count and start_episode >= haved_end: invalid_input = True

        if ((end_episode < start_episode) or (end_episode > episode_count)):
            end_episode = episode_count
            self.chosen_anime_window.end_episode_input.setText("")
            invalid_input = True

        if (start_episode > episode_count):
            start_episode = haved_end if haved_end > 0 else 1
            self.chosen_anime_window.start_episode_input.setText(str(start_episode))
            invalid_input = True

        # For testing purposes
        end_episode = start_episode

        self.anime_details.predicted_episodes_to_download = dynamic_episodes_predictor_initialiser_pro_turboencapsulator(start_episode, end_episode, self.anime_details.haved_episodes)
        if len(self.anime_details.predicted_episodes_to_download) == 0: invalid_input = True
        if invalid_input:
            self.chosen_anime_window.episode_count.setStyleSheet(self.chosen_anime_window.episode_count.invalid_input_style_sheet)
            return
        self.anime_details.start_download_episode = start_episode
        self.anime_details.end_download_episode = end_episode
        self.main_window.stacked_windows.setCurrentWidget(self.main_window.download_window)
        self.download_window.get_episode_page_links(self.anime_details)
        self.main_window.stacked_windows.removeWidget(self.chosen_anime_window)



class FolderButton(IconButton):
    def __init__(self, path: str, size_x: int, size_y: int, parent: QWidget | None = None ):
        super().__init__(size_x, size_y, folder_icon_path, 1.3, parent)
        self.folder_path = path
        self.clicked.connect(lambda: os.startfile(self.folder_path))
    
class EpisodeCount(StyledLabel):
    def __init__(self, count: str):
        super().__init__(None, 24, "rgba(255, 50, 0, 230)")
        self.setText(f"{count} episodes")
        self.normal_style_sheet = self.styleSheet()
        self.invalid_input_style_sheet = self.normal_style_sheet+"""
            QLabel {
                background-color: rgba(255, 0, 0, 255);
                border: 1px solid black;
                    }
                    """

class Poster(QLabel):
        def __init__(self, image: bytes):
            super().__init__()
            size_x = 350
            size_y = 500
            pixmap = QPixmap()
            pixmap.loadFromData(image) # type: ignore Type checking is ass on this one honestly
            pixmap = pixmap.scaled(size_x, size_y, Qt.AspectRatioMode.IgnoreAspectRatio)

            self.move(50, 60)
            self.setPixmap(pixmap)
            self.setFixedSize(size_x, size_y)
            self.setStyleSheet("""
                        QLabel {
                        background-color: rgba(255, 160, 0, 255);
                        border-radius: 10px;
                        padding: 5px;
                        border: 2px solid black;
                        }
                        """)

class Title(OutlinedLabel):
    def __init__(self, title: str):
        super().__init__(None, 0, 71)
        self.setText(title.upper())
        self.setWordWrap(True)
        self.setStyleSheet("""
                    OutlinedLabel {
                        color: orange;
                        font-size: 60px;
                        font-family: "Berlin Sans FB Demi";
                            }
                            """)

class HorizontalLine(QFrame):
        def __init__(self, color: str = "black", parent: QWidget | None = None):
            super().__init__(parent)
            self.setFrameShape(QFrame.Shape.HLine)
            self.setStyleSheet(f"""
                        QFrame {{ 
                            background-color: {color}; 
                            }}
                            """)


class SummaryLabel(StyledLabel):
    def __init__(self, summary: str):
        super().__init__(font_size=20)
        self.setText(summary)
        self.setWordWrap(True)

class HavedEpisodes(StyledLabel):
    def __init__(self, start: int | None, end: int | None, count: int |None):
        super().__init__(font_size=23)
        self.start = start
        self.end = end
        self.count = count
        if not count: self.setText("You have No episodes of this anime")
        else: self.setText(f"You have {count} episodes from {start} to {end}") if count != 1 else self.setText(f"You have {count} episode from {start} to {end}")


class NumberInput(QLineEdit):
    def __init__(self, font_size: int=14, parent: QWidget | None = None ):
        super().__init__(parent)
        self.installEventFilter(self)
        self.setStyleSheet(f"""
            QLineEdit{{
                border: 2px solid black;
                border-radius: 5px;
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


class QualityButton(StyledButton):
    def __init__(self, window: ChosenAnimeWindow | SettingsWindow, quality: str, font_size: int):
        self.chosen_anime_window = window
        normal_color = "rgba(128, 128, 128, 255)"
        hover_color = "rgba(255, 255, 0, 255)"
        pressed_color = "rgba(255, 165, 0, 255)"
        super().__init__(window, font_size, "white",  normal_color, hover_color, pressed_color)
        self.not_picked_style_sheet = self.styleSheet()
        styles_to_overwride = f"""
            QPushButton {{
            border-radius: 5px;
            background-color: {pressed_color};
        }}
        QPushButton:hover {{
            background-color: {pressed_color};
        }}
    """
        self.picked_style_sheet = self.not_picked_style_sheet+styles_to_overwride
        self.quality = quality
        self.setText(self.quality)
        self.clicked.connect(lambda: self.change_style_sheet(True))

    def change_style_sheet(self, picked: bool): 
        if picked: self.setStyleSheet(self.picked_style_sheet)
        else: self.setStyleSheet(self.not_picked_style_sheet)

class SubDubButton(StyledButton):
    def __init__(self, window: ChosenAnimeWindow | SettingsWindow, sub_dub: str, font_size: int):
        self.chosen_anime_window =  window
        normal_color = "rgba(128, 128, 128, 255)"
        hover_color = "rgba(255, 255, 0, 255)"
        pressed_color = "rgba(255, 165, 0, 255)"
        super().__init__(window, font_size, "white", normal_color, hover_color, pressed_color)      
        self.sub_or_dub = sub_dub
        self.setText(self.sub_or_dub.upper())
        self.not_picked_style_sheet = self.styleSheet()
        styles_to_overwride = f"""
            QPushButton {{
            border-radius: 5px;
            background-color: {pressed_color};
        }}
        QPushButton:hover {{
            background-color: {pressed_color};
        }}
    """
        self.picked_style_sheet = self.not_picked_style_sheet+styles_to_overwride
        self.setText(self.sub_or_dub.upper())
        self.clicked.connect(lambda: self.change_style_sheet(True))

    def change_style_sheet(self, picked: bool): 
        if picked: self.setStyleSheet(self.picked_style_sheet)
        else: self.setStyleSheet(self.not_picked_style_sheet)

class ResultButton(OutlinedButton):
    def __init__(self, anime: Anime,  main_window: MainWindow, site: str, paint_x: int, paint_y: int):
        if site == pahe_name:
            hover_color = pahe_normal_color
            pressed_color = pahe_hover_color
        else:
            hover_color = gogo_normal_color
            pressed_color = gogo_hover_color
        super().__init__(paint_x, paint_y, None, 40, "white", "transparent", hover_color, pressed_color)
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
        self.clicked.connect(lambda: main_window.setup_and_switch_to_chosen_anime_window(anime, site))
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




class SearchButton(StyledButton):
    def __init__(self, window: SearchWindow, site: str) :
        if site == pahe_name:
            super().__init__(window, 40, "white", pahe_normal_color, pahe_hover_color, pahe_pressed_color)
            self.setText("Animepahe")
        else:
            super().__init__(window, 40, "white", gogo_normal_color, gogo_hover_color, gogo_pressed_color)
            self.setText("Gogoanime")
        self.clicked.connect(lambda: window.search_anime(window.get_search_bar_text(), site))

if __name__ == "__main__":
    app = QApplication(sys.argv)
    app.setApplicationName(app_name)
    app.setWindowIcon(QIcon(senpwai_icon_path))
    # Set the purple theme
    palette = app.palette()
    palette.setColor(QPalette.ColorRole.Window, QColor(pahe_normal_color))
    palette.setColor(QPalette.ColorRole.WindowText, Qt.GlobalColor.white)
    app.setPalette(palette)

    window = MainWindow()
    window.showMaximized()
    sys.exit(app.exec())
