import sys
from PyQt6 import QtCore
from PyQt6.QtGui import QColor, QPalette, QPixmap, QGuiApplication, QPen, QPainterPath, QPainter, QMovie, QKeyEvent, QIcon, QAction
from PyQt6.QtWidgets import QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, QLabel, QLineEdit, QPushButton, QFrame, QScrollArea, QProgressBar, QSystemTrayIcon, QStackedWidget
from PyQt6.QtCore import QObject, Qt, QSize, QThread, pyqtSignal, QEvent, QPoint, pyqtSlot, QMutex, QMetaObject, Q_ARG
import os
import pahe
import gogo
from pathlib import Path
from random import randint  
import requests
from typing import Callable, cast
from intersection import ibytes_to_mbs_divisor, sanitise_title, Download, network_monad
from time import time
import anitopy
from selenium.common.exceptions import WebDriverException
import webbrowser

pahe_name = "pahe"
gogo_name = "gogo"

dub = "dub"
sub = "sub"
sub_or_dub = sub
q_1080 = "1080p"
q_720 = "720p"
q_480 = "480p"
q_360 = "360p"
default_quality = q_360
default_download_folder_path = [os.path.abspath(r'C:\\Users\\PC\\Downloads\\Anime'), os.path.abspath(r'D:\Series')]
default_site = pahe_name
max_simutaneous_downloads = 4 
default_gogo_browser = gogo.chrome

root_path = os.path.abspath(r'.\\')
assets_path = os.path.join(root_path, "assets")

senpwai_icon_path = os.path.abspath("Senpwai_icon.ico")
bckg_images_path = os.path.join(assets_path, "background-images")
bckg_images = list(Path(bckg_images_path).glob("*"))
bckg_image_path = str(bckg_images[randint(0, len(bckg_images)-1)])
loading_animation_path = os.path.join(assets_path, "loading.gif")
sadge_piece_path = os.path.join(assets_path, "sadge-piece.gif")
folder_icon_path = os.path.join(assets_path, "folder.png")
pause_icon_path = os.path.join(assets_path, "pause.png")
resume_icon_path = os.path.join(assets_path, "resume.png")
cancel_icon_path = os.path.join(assets_path, "cancel.png")
download_complete_icon_path = os.path.join(assets_path, "download-complete.png")
chopper_crying_path = os.path.join(assets_path, "chopper-crying.png")
zero_two_peeping_path = os.path.join(assets_path, "zero-two-peeping.png")

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
        self.setFixedSize(parent.size())

class Animation(QLabel):
    def __init__(self, parent, animation_path: str, size_x: int, size_y: int, pos_x: int, pos_y: int):
        super().__init__(parent)
        self.setFixedSize(size_x, size_y)
        self.move(pos_x, pos_y)
        self.animation = QMovie(animation_path)
        self.animation.setScaledSize(self.size())

class IconButton(QPushButton):
    def __init__(self, parent, size_x: int, size_y: int, icon_path: str, size_factor: int | float):
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

class AnimationAndText(Animation):
    def __init__(self, parent, animation_path: str, size_x: int, size_y: int, pos_x: int, pos_y: int, text: str, paint_x: int, paint_y: int, font_size: int):
        super().__init__(parent, animation_path, size_x, size_y, pos_x, pos_y)
        self.setMovie(self.animation)
        self.animation_path = animation_path
        self.text_label = OutlinedLabel(parent, paint_x, paint_y)
        self.text_label.setFixedSize(size_x, size_y)
        self.text_label.move(pos_x, pos_y)
        self.text_label.setText(text)
        self.text_label.setStyleSheet(f"""
                    OutlinedLabel {{
                        color: #FFEF00;
                        font-size: {font_size}px;
                        font-family: "Berlin Sans FB Demi";
                        }}
                        """)
        self.hide()
        self.text_label.hide()



    def start(self):
        self.animation.start()
        self.show()
        self.text_label.show()
    
    def stop(self):
        self.hide()
        self.text_label.hide()
        self.animation.stop()


class OutlinedLabel(QLabel):
    def __init__(self, parent, paint_x, paint_y):
        self.paint_x = paint_x
        self.paint_y = paint_y
        super().__init__(parent)
    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)

        # Draw the outline around the text
        pen = QPen(QColor("black"))
        pen.setWidth(5)
        painter.setPen(pen)

        path = QPainterPath()
        path.addText(self.paint_x,self.paint_y, self.font(), self.text())
        painter.drawPath(path)
        painter.end()
        # Call the parent class's paintEvent to draw the button background and other properties
        return super().paintEvent(event)

class OutlinedButton(QPushButton):
    def __init__(self, paint_x, paint_y):
        self.paint_x = paint_x
        self.paint_y = paint_y
        super().__init__()
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
    def __init__(self, parent, task_title: str, item_task_is_applied_on: str, size_x: int, size_y: int, total_value: int, units: str, units_divisor: int = 1):
        super().__init__(parent)
        self.item_task_is_applied_on = item_task_is_applied_on
        self.total_value = total_value
        self.units = units
        self.units_divisor = units_divisor
        self.mutex = QMutex()
        self.items_layout = QHBoxLayout(self) # type: ignore 
        self.setLayout(self.items_layout)

        self.bar = QProgressBar(self)
        self.bar.setFixedSize(size_x, size_y)
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
                 font-size: 20px;
                 font-family: "Berlin Sans FB Demi";
             }

             QProgressBar::chunk {
                 background-color: orange;
                 border-radius: 10px;
             }
         """)
        self.completed_stylesheet = """
             QProgressBar {
                 border: 1px solid black;
                 color: black;
                 text-align: center;
                 border-radius: 10px;
                 background-color: rgba(255, 255, 255, 150);
                 font-size: 20px;
                 font-family: "Berlin Sans FB Demi";
             }

             QProgressBar::chunk {
                 background-color: #00FF00;
                 border-radius: 10px;
             }
         """
        style_sheet = """
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
        self.percentage.setStyleSheet(style_sheet)

        self.rate = OutlinedLabel(self, 1, 40)
        self.rate.setText(f" 0 {units}/s")
        self.rate.setFixedHeight(height)
        self.rate.setStyleSheet(style_sheet)
        
        self.eta = OutlinedLabel(self, 1, 40)
        self.eta.setText("∞ secs left")
        self.eta.setFixedHeight(height)
        self.eta.setStyleSheet(style_sheet)
        
        self.current_against_max_values = OutlinedLabel(self, 1, 40)
        self.current_against_max_values.setText(f"0/{round(total_value/units_divisor)} {units}")
        self.current_against_max_values.setFixedHeight(height)
        self.current_against_max_values.setStyleSheet(style_sheet)

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
    def __init__(self, parent, task_title: str, item_task_is_applied_on: str, size_x: int, size_y: int, total_value: int, units: str, units_divisor: int, has_icon_buttons: bool = True):
        super().__init__(parent, task_title, item_task_is_applied_on, size_x, size_y, total_value, units, units_divisor)
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
            self.pause_button = IconButton(self, 40, 40, pause_icon_path, 1.3)
            self.pause_icon = self.pause_button.icon()
            resume_icon_pixmap = QPixmap(resume_icon_path)
            resume_icon_pixmap.scaled(40, 40, Qt.AspectRatioMode.IgnoreAspectRatio)
            self.resume_icon = QIcon(resume_icon_pixmap) 
            self.cancel_button: IconButton = IconButton(self, 35, 35, cancel_icon_path, 1.3)
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
        self.quality = default_quality
        self.sub_or_dub = sub_or_dub 
        self.direct_download_links: list[str] = []
        self.download_info: list[str] = []
        self.total_download_size: int = 0
        self.predicted_episodes_to_download: list[int] = []

    def get_anime_folder_path(self) -> str | None:
        def try_path(title: str)->str | None:
            detected = None
            for path in default_download_folder_path:
                potential = os.path.join(path, title)
                upper = potential.upper()
                lower = potential.lower()
                if os.path.isdir(potential): detected = potential 
                if os.path.isdir(upper):  detected = upper
                if os.path.isdir(lower): detected = lower
                if detected:
                    self.chosen_default_download_path = path
                    return detected
            self.chosen_default_download_path = default_download_folder_path[0]
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
        self.setWindowTitle("Senpwai")
        self.setFixedSize(1000, 650)
        self.move(0, 0)
        
        # Places window at the center of the screen
        center_point = QGuiApplication.primaryScreen().availableGeometry().center()
        window_position = QPoint(center_point.x() - self.rect().center().x(), center_point.y() - self.rect().center().y())
        self.move(window_position)
        self.tray_icon = QSystemTrayIcon(QIcon(senpwai_icon_path), self)
        self.tray_icon.show()
        self.download_window = DownloadWindow(self)
        self.search_window = SearchWindow(self)
        self.stacked_windows = QStackedWidget(self)
        self.stacked_windows.addWidget(self.search_window)
        self.stacked_windows.addWidget(self.download_window)
        self.stacked_windows.setCurrentWidget(self.search_window)
        self.setCentralWidget(self.stacked_windows)
        self.setup_chosen_anime_window_thread = None
        # FOr testing purposes
        #self.create_and_switch_to_captcha_block_window("Naruto", ["https://ligma.com", "https://deeznuts.com"])
        # self.create_and_switch_to_no_supported_browser_window("Senyuu")

        # For testing purposes, the anime id changes after a while so check on animepahe if it doesn't work
        # self.setup_chosen_anime_window(Anime("Senyuu.", "https://animepahe.ru/api?m=release&id=471abb96-a428-6172-b066-d89f7f9f276c", "471abb96-a428-6172-b066-d89f7f9f276c"), pahe_name)
        #self.setup_chosen_anime_window(Anime("Senyuu", "https://gogoanime.hu/category/senyuu-", None), gogo_name)

    def restore_window(self):
        self.setWindowState(self.windowState() & ~Qt.WindowState.WindowMinimized)
        self.activateWindow()

    def center_window(self) -> None:
        screen_geometry = QGuiApplication.primaryScreen().geometry()
        x = (screen_geometry.width() - self.width()) // 2
        y = (screen_geometry.height() - self.height()) // 2
        self.move(x, y)

    def setup_chosen_anime_window(self, anime: Anime, site: str):
        # This if statement prevents error: "QThread: Destroyed while thread is still running" that happens when more than one thread is spawned when a set a user clicks more than one ResultButton causing the original thread to be reassigned hence get destroyed
        if not self.setup_chosen_anime_window_thread:
            self.search_window.loading.start()
            self.setup_chosen_anime_window_thread = SetupChosenAnimeWindowThread(self, anime, site)                  
            self.setup_chosen_anime_window_thread.finished.connect(lambda anime_details: self.handle_finished_drawing_window_widgets(anime_details))
            self.setup_chosen_anime_window_thread.start()

    def handle_finished_drawing_window_widgets(self, anime_details: AnimeDetails):
        self.setup_chosen_anime_window_thread = None
        self.search_window.loading.stop()
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
        captcha_block_window = CaptchBlockWindow(self, anime_title, download_page_links)
        self.stacked_windows.addWidget(captcha_block_window)
        self.stacked_windows.setCurrentWidget(captcha_block_window)

    def create_and_switch_to_no_supported_browser_window(self, anime_title: str):
        no_supported_browser_window = NoSupportedBrowserWindow(self, anime_title)
        self.stacked_windows.addWidget(no_supported_browser_window)
        self.stacked_windows.setCurrentWidget(no_supported_browser_window)
        

class CaptchBlockWindow(QWidget):
    def __init__(self, main_window: MainWindow, anime_title: str, download_page_links: list[str]) -> None:
        super().__init__(main_window)
        self.setFixedSize(main_window.size())
        BckgImg(self, chopper_crying_path)
        main_widget = QWidget(self)
        main_widget.setFixedSize(self.size())
        info_label = StyledLabel(main_widget, 30)
        info_label.move(50, 50)
        info_label.setText("\nCaptcha block detected, this only ever happens with Gogoanime\n")
        open_browser_with_links_button = StyledButton(main_widget, 25, "black", "#00FF00", "#00FF7F", "#7aea8e", 260, 100, 150, 300, 10)
        open_browser_with_links_button.setText("Download in browser")
        open_browser_with_links_button.clicked.connect(lambda: list(map(webbrowser.open_new_tab, download_page_links))) # type: ignore
        switch_to_anime_pahe_button = StyledButton(main_widget, 25, "black", "#FFC300", "#FFD700", "#FFE900", 280, 100, 620, 300, 10)
        switch_to_anime_pahe_button.setText("Switch to animepahe")
        switch_to_anime_pahe_button.clicked.connect(lambda: main_window.switch_to_pahe(anime_title, self))

class NoSupportedBrowserWindow(QWidget):
    def __init__(self, main_window: MainWindow, anime_title: str):
        super().__init__(main_window)
        self.setFixedSize(main_window.size())
        BckgImg(self, chopper_crying_path)
        main_widget = QWidget(self)
        main_widget.setFixedSize(self.size()) 
        info_label = StyledLabel(main_widget, 30)
        info_label.move(150, 50)
        info_label.setText("\nUnfortunately downloaading from Gogoanime requires\n you have either Chrome, Edge or Firefox installed\n") 
        download_chrome_button = StyledButton(main_widget, 25, "black", "#00FF00", "#00FF7F", "#7aea8e", 230, 100, 150, 300, 10)
        download_chrome_button.setText("Download Chrome")
        download_chrome_button.clicked.connect(lambda: webbrowser.open_new_tab("https://www.google.com/chrome")) # type: ignore
        switch_to_anime_pahe_button = StyledButton(main_widget, 25, "black", "#FFC300", "#FFD700", "#FFE900", 280, 100, 620, 300, 10)
        switch_to_anime_pahe_button.setText("Switch to animepahe")
        switch_to_anime_pahe_button.clicked.connect(lambda: main_window.switch_to_pahe(anime_title, self))
        
class SearchWindow(QWidget):
    def __init__(self, main_window: MainWindow):
        super().__init__(main_window)
        self.setFixedSize(main_window.size())
        self.bckg_img = BckgImg(self, bckg_image_path)

        self.search_widget = QWidget(self)
        self.search_widget.setFixedSize(1000, 150)
        self.search_widget.move(30, 50)

        zero_two_peeping = QLabel(self)
        zero_two_peeping.setPixmap(QPixmap(zero_two_peeping_path))
        zero_two_peeping.move(480, 0)
        zero_two_peeping.setFixedSize(65, 50)
        zero_two_peeping.setScaledContents(True)
        
        self.search_bar = SearchBar(self.search_widget, self)
        self.search_bar_text = lambda: self.search_bar.text()
        self.search_bar.setFocus()
        self.main_window = main_window
        self.pahe_search_button = SearchButton(self.search_widget, self, pahe_name, )
        self.gogo_search_button = SearchButton(self.search_widget, self, gogo_name)
        self.pahe_search_button.move(self.search_bar.x()+200, self.search_bar.y()+80)
        self.gogo_search_button.move(self.search_bar.x()+500, self.search_bar.y()+80)

        self.results_layout = QVBoxLayout()
        ScrollableSection(self, self.results_layout, 950, 440, 20, 200)

        self.anime_not_found = AnimationAndText(self, sadge_piece_path, 450, 300, 290, 180, "Couldn't find that anime", 0, 165, 40)
        spacing = "              " # Easy fix to  positioning issues lol
        self.loading = AnimationAndText(self, loading_animation_path, 450, 300, 290, 180, f"{spacing}Loading.. .", 0, 165, 40)
        self.search_thread = None


    def search_anime(self, anime_title: str, site: str) -> None:
        # Check setup_chosen_anime_window and MainWindow for why the if statement
        # I might remove this cause the behavior experienced in setup_chosen_anime_window is absent here for some reason, but for safety I'll just keep it
        if not self.search_thread:
            for idx in reversed(range(self.results_layout.count())):
                self.results_layout.itemAt(idx).widget().deleteLater()
            self.anime_not_found.stop()
            self.loading.start()
            self.search_thread = SearchThread(self, anime_title, site)
            self.search_thread.finished.connect(lambda results: self.handle_finished_search(site, results))
            self.search_thread.start()

    def handle_finished_search(self, site: str, results: list[Anime]): 
        self.loading.stop()   
        if len(results) == 0:
            self.anime_not_found.start()

        for result in results:
            button = ResultButton(result, self.main_window, site, 9, 43)
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
    def __init__(self, parent: QWidget, layout: QVBoxLayout, size_x: int, size_y: int, pos_x: int, pos_y: int):
        super().__init__(parent)
        self.resize(size_x, size_y)
        self.move(pos_x, pos_y)
        self.setWidgetResizable(True)
        self.widget_section = QWidget()
        self.widget_section.setLayout(layout)
        self.setWidget(self.widget_section)
        self.setStyleSheet("""
                    QWidget {
                        background-color: transparent;
                        border: None;
                        }""")

class SearchBar(QLineEdit):
    def __init__(self, parent: QWidget, window: SearchWindow):
        super().__init__(parent)
        self.setFixedSize(900, 50)
        self.move(30, 0)
        self.my_window = window
        self.setPlaceholderText("Enter anime title")
    # self.returnPressed.connect(lambda: search_window.search_anime(self.text(), default_site))
        self.installEventFilter(self)
        self.setStyleSheet("""
            QLineEdit{
                border: 1px solid white;
                border-radius: 15px;
                padding: 5px;
                color: black;
                font-size: 14px;
                font-family: "Berlin Sans FB Demi";
            }
        """)

    def eventFilter(self, obj, event: QEvent):
        if isinstance(event, QKeyEvent):
            if obj == self and event.type() == event.Type.KeyPress:
                if event.key() == Qt.Key.Key_Enter or event.key() == Qt.Key.Key_Return:
                    self.my_window.search_anime(self.text(), default_site)
                elif event.key() == Qt.Key.Key_Tab:
                    if first_button := self.my_window.results_layout.itemAt(0): first_button.widget().setFocus()
                    else:
                        self.my_window.search_anime(self.text(), gogo_name) if default_site == pahe_name else self.my_window.search_anime(self.text(), pahe_name)
                    return True
        return super().eventFilter(obj, event)


class DownloadedEpisodeCount(QLabel):
    def __init__(self, parent, total_episodes: int, tray_icon: QSystemTrayIcon, anime_title: str, 
                 download_complete_icon: QIcon, anime_folder_path: str):
        super().__init__(parent)
        self.total_episodes = total_episodes
        self.current_episodes = 0
        self.tray_icon = tray_icon
        self.tray_icon.messageClicked.connect(lambda : os.startfile(anime_folder_path))
        self.anime_title = anime_title
        self.download_complete_icon = download_complete_icon
        self.resize(100, 50)
        self.move(200, 100)
        self.setText(f"{0}/{total_episodes} eps")
        self.setStyleSheet("""
            QLabel {
                color: white;
                font-size: 20px;
                font-family: "Berlin Sans FB Demi";
                background-color: rgba(0, 0, 0, 200);
                border-radius: 10px;
                padding: 5px;
                    }
                    """)
        self.show()

    def download_complete_notification(self):
        self.tray_icon.showMessage("Download Complete", self.anime_title, self.download_complete_icon)


    def update(self, added_episode_count: int):
        self.current_episodes+=added_episode_count
        self.setText(f"{self.current_episodes}/{self.total_episodes} eps")
        if self.current_episodes == self.total_episodes and self.total_episodes > 0:
            self.download_complete_notification()

class CancelAllButton(QPushButton):
    def __init__(self, parent):
        super().__init__(parent)
        self.setFixedSize(90, 40)
        self.move(410, 103)
        self.setText("CANCEL")
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.cancel_callback: Callable = lambda: None
        self.setStyleSheet("""
                QPushButton {
                text-align: left;
                color: white;
                padding: 5px;
                font-size: 18px;
                font-family: Berlin Sans FB Demi;
                padding: 10px;
                border-radius: 5px;
                background-color: red;
            }
            QPushButton:hover {
                background-color: #ED2B2A;
            }
            QPushButton:pressed {
                background-color: #990000;
            }
            """)
        self.clicked.connect(self.cancel) 
        self.show()

    def cancel(self):
        self.cancel_callback()

class PauseAllButton(QPushButton):
    def __init__(self, parent):
        super().__init__(parent)
        self.setFixedSize(90, 40)
        self.setText("PAUSE")
        self.move(310, 103)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.pause_callback: Callable = lambda: None
        self.not_paused_style_sheet = """
                QPushButton {
                text-align: left;
                color: white;
                padding: 5px;
                font-size: 18px;
                font-family: Berlin Sans FB Demi;
                padding: 10px;
                border-radius: 5px;
                background-color: #FFA41B;
            }
            QPushButton:hover {
                background-color: #FFA756;
            }
            QPushButton:pressed {
                background-color: #F86F03;
            }
            """
        self.paused_style_sheet = """
                QPushButton {
                text-align: left;
                color: white;
                padding: 5px;
                font-size: 18px;
                font-family: Berlin Sans FB Demi;
                padding: 10px;
                border-radius: 5px;
                background-color: #FFA756;
            }
            QPushButton:hover {
                background-color: #FFA41B;
            }
            QPushButton:pressed {
                background-color: #F86F03;
            }
            """
        self.setStyleSheet(self.not_paused_style_sheet)
        self.paused = False
        self.clicked.connect(self.pause_or_resume)
        self.show()

    def pause_or_resume(self):
        self.paused = not self.paused
        self.pause_callback()
        if self.paused: 
            self.setText("RESUME")
            self.setStyleSheet(self.paused_style_sheet)

        elif not self.paused:
            self.setText("PAUSE")
            self.setStyleSheet(self.not_paused_style_sheet)



class DownloadWindow(QWidget):
    def __init__(self, main_window: MainWindow):
        super().__init__(main_window)
        self.main_window = main_window
        self.setFixedSize(main_window.size())
        BckgImg(self, bckg_image_path)
        self.download_complete_icon = QIcon(download_complete_icon_path)
        self.tray_icon = main_window.tray_icon
        self.downloads_layout = QVBoxLayout(self)
        ScrollableSection(self, self.downloads_layout, 1000, 440, 5, 200)
        self.anime_progress_widget = QWidget(self)
        self.anime_progress_widget.resize(1000, 210)
        self.anime_progress_widget.move(0, 0)

    def dynamic_episodes_predictor_initialiser_pro_turboencapsulator(self, anime_details: AnimeDetails):
        for episode in range(anime_details.start_download_episode, anime_details.end_download_episode+1):
            if episode not in anime_details.haved_episodes: anime_details.predicted_episodes_to_download.append(episode)

    def get_episode_page_links(self, anime_details: AnimeDetails):
        if anime_details.site == pahe_name: 
            episode_page_progress_bar = ProgressBar(self, "Getting episode page links", "", 400, 33, pahe.get_total_episode_page_count(anime_details.anime.page_link), "pgs")
            self.downloads_layout.insertWidget(0, episode_page_progress_bar)
            return GetEpisodePageLinksThread(self, anime_details, anime_details.start_download_episode, anime_details.end_download_episode, 
                                  lambda eps_links: self.get_download_page_links(eps_links, anime_details), episode_page_progress_bar.update).start()    
        if anime_details.site ==  gogo_name and anime_details.sub_or_dub == dub and anime_details.dub_available: anime_details.anime.page_link = gogo.get_dub_anime_page_link(anime_details.anime.title) 
        GetEpisodePageLinksThread(self, anime_details, anime_details.start_download_episode, anime_details.end_download_episode, 
                                  lambda eps_links : self.get_download_page_links(eps_links, anime_details), lambda x: None).start() 

    def get_download_page_links(self, episode_page_links: list[str], anime_details: AnimeDetails):
        self.dynamic_episodes_predictor_initialiser_pro_turboencapsulator(anime_details)
        episode_page_links = [episode_page_links[eps-anime_details.start_download_episode] for eps in anime_details.predicted_episodes_to_download]
        download_page_progress_bar = ProgressBar(self, "Fetching download page links", "", 400, 33, len(episode_page_links), "eps")
        self.downloads_layout.insertWidget(0, download_page_progress_bar)
        GetDownloadPageThread(self, anime_details.site, episode_page_links, lambda down_pge_lnk, down_info: self.get_direct_download_links(down_pge_lnk, down_info, anime_details)
                              , download_page_progress_bar.update).start()

    def get_direct_download_links(self, download_page_links: list[str], download_info: list[list[str]], anime_details: AnimeDetails):
        direct_download_links_progress_bar =  ProgressBar(self, "Retrieving direct download links", "", 400, 33, len(download_page_links), "eps") 
        self.downloads_layout.insertWidget(0, direct_download_links_progress_bar)
        GetDirectDownloadLinksThread(self, download_page_links, download_info, anime_details, lambda status: self.check_link_status(status, anime_details, download_page_links), 
                                     direct_download_links_progress_bar.update).start()

    def check_link_status(self, status: int, anime_details: AnimeDetails, download_page_links: list[str]):
        print(status)
        if status == 1: self.calculate_download_size(anime_details)
        elif status == 2: self.main_window.create_and_switch_to_no_supported_browser_window(anime_details.anime.title)
        elif status == 3: self.main_window.create_and_switch_to_captcha_block_window(anime_details.anime.title, download_page_links)

    def calculate_download_size(self, anime_details: AnimeDetails):
        if anime_details.site == gogo_name:
            calculating_download_size_progress_bar = ProgressBar(self, "Calcutlating total download size", "", 400, 33, len(anime_details.direct_download_links), "eps")
            self.downloads_layout.insertWidget(0, calculating_download_size_progress_bar)
            CalculateDownloadSizes(self, anime_details, lambda : self.start_download(anime_details), calculating_download_size_progress_bar.update).start()
        elif anime_details.site == pahe_name:
            CalculateDownloadSizes(self, anime_details, lambda : self.start_download(anime_details), lambda x: None).start()

    def start_download(self, anime_details: AnimeDetails):
        if not anime_details.anime_folder_path:
            anime_details.anime_folder_path = os.path.join(anime_details.chosen_default_download_path, anime_details.sanitised_title)
            os.mkdir(anime_details.anime_folder_path)                          
        displayed_title = anime_details.sanitised_title if len(anime_details.sanitised_title)<=24 else f"{anime_details.sanitised_title[:24]}.. ."
        anime_progress_bar = DownloadProgressBar(self.anime_progress_widget, "Downloading", displayed_title, 425, 50, anime_details.total_download_size, "MB", 1, False)
        anime_progress_bar.resize(980, 60)
        anime_progress_bar.move(10, 10)
        anime_progress_bar.show()
        downloaded_episode_count = DownloadedEpisodeCount(self.anime_progress_widget, len(anime_details.predicted_episodes_to_download), self.tray_icon, 
                                                          anime_details.anime.title, self.download_complete_icon, anime_details.anime_folder_path)
        FolderButton(self.anime_progress_widget, cast(str, anime_details.anime_folder_path), 80, 80, 500, 80).show()
        self.current_download = DownloadManagerThread(self, anime_details, anime_progress_bar, downloaded_episode_count)
        PauseAllButton(self.anime_progress_widget).pause_callback = self.current_download.pause_or_resume
        CancelAllButton(self.anime_progress_widget).cancel_callback = self.current_download.cancel
        self.current_download.start()

    @pyqtSlot(str, int, dict)
    def receive_download_progress_bar_details(self, episode_title: str, episode_size: int, progress_bars: dict[str, DownloadProgressBar]):
        bar = DownloadProgressBar(None, "Downloading", episode_title, 400, 33, episode_size, "MB", ibytes_to_mbs_divisor)
        progress_bars[episode_title] = bar 
        self.downloads_layout.insertWidget(0, bar)

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
        if not self.paused:
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
            while len(self.progress_bars) == max_simutaneous_downloads: continue
            download_size = self.get_exact_episode_size(link)
            if download_size == 0: continue
            while self.paused: continue
            if self.cancelled: break
            episode_title = f"{self.anime_details.sanitised_title} Episode {self.anime_details.predicted_episodes_to_download[idx]}"
            displayed_episode_title = episode_title if len(self.anime_details.sanitised_title) <= 10 else f"{self.anime_details.sanitised_title[:10]}... Episode {self.anime_details.predicted_episodes_to_download[idx]}"
            self.mutex.lock()
            self.send_progress_bar_details.emit(displayed_episode_title, download_size, self.progress_bars)
            self.mutex.unlock()
            while displayed_episode_title not in self.progress_bars: continue  
            DownloadThread(self, link, episode_title, download_size, self.anime_details.site, cast(str, self.anime_details.anime_folder_path), 
                           self.progress_bars[displayed_episode_title], displayed_episode_title, self.pop_from_progress_bars, 
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
            self.anime_progress_bar.bar.setMaximum(self.anime_progress_bar.bar.maximum() - round(self.size / ibytes_to_mbs_divisor))
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
        if self.anime_details.site == gogo_name:                # With gogoanime we dont have to store the download sizes for each episode since we dont use a headless browser to actually download just to get the links
            self.anime_details.total_download_size = gogo.calculate_download_total_size(self.anime_details.direct_download_links, lambda x: self.update_bar.emit(x))
        elif self.anime_details.site == pahe_name:
            self.anime_details.total_download_size = pahe.calculate_total_download_size(self.anime_details.download_info)
        self.finished.emit()
        
        
class ChosenAnimeWindow(QWidget):
    def __init__(self, parent: MainWindow, anime_details: AnimeDetails):
        super().__init__(parent)
        self.main_window = parent
        self.setFixedSize(parent.size())
        self.anime_details = anime_details
        self.anime = anime_details.anime

        BckgImg(self, bckg_image_path)
        Poster(self, self.anime_details.poster)
        Title(self, self.anime_details.anime.title)
        LineUnderTitle(self)
        SummaryLabel(self, self.anime_details.summary)

        if self.anime_details.dub_available:
            self.dub_button = SubDubButton(self, 425, 400, dub)
            self.sub_button = SubDubButton(self, 490, 400, sub)

            if sub_or_dub == dub: self.dub_button.click()
            elif sub_or_dub == sub:
                self.sub_button.click()
            
            self.dub_button.clicked.connect(lambda: self.co_update_sub_dub_buttons(dub))
            self.sub_button.clicked.connect(lambda: self.co_update_sub_dub_buttons(sub))
        else:
            self.sub_button = SubDubButton(self, 490, 400, sub)
            self.sub_button.click()
        
        self.button_1080 = QualityButton(self, 565, 400, q_1080) 
        self.button_1080.setFixedSize(69, 40)
        self.button_720 = QualityButton(self, 639, 400, q_720) 
        self.button_480 = QualityButton(self, 704, 400, q_480) 
        self.button_360 = QualityButton(self, 769, 400, q_360) 
        self.setup_quality_buttons_color_clicked_status()
        self.quality_buttons_list = [self.button_1080, self.button_720, self.button_480, self.button_360]

        for button in self.quality_buttons_list: 
                                    # x holds a boolean value that connect passes to the callback for some reason
            button.clicked.connect(lambda x, updater=button.quality: self.co_update_quality_buttons(updater))

        start_episode = str((self.anime_details.haved_end)+1) if (self.anime_details.haved_end and self.anime_details.haved_end < self.anime_details.episode_count) else "1"
        self.start_episode_input = EpisodeInput(self, 420, 460, "START")
        self.start_episode_input.setText(str(start_episode))
        self.end_episode_input = EpisodeInput(self, 500, 460, "END")
        self.download_button = DownloadButton(self, self.main_window.download_window, self.anime_details)
        self.download_button.setFocus()

        HavedEpisodes(self, self.anime_details.haved_start, self.anime_details.haved_end, self.anime_details.haved_count)
        self.episode_count = EpisodeCount(self, str(self.anime_details.episode_count))
        if self.anime_details.anime_folder_path: FolderButton(self, self.anime_details.anime_folder_path, 60, 60, 710, 445)
    
    
    def co_update_quality_buttons(self, updater: str):
        for button in self.quality_buttons_list:
            if button.quality != updater:
                button.change_style_sheet(button.bckg_color, button.hover_color)

    def setup_quality_buttons_color_clicked_status(self):
        if default_quality == q_1080:
            self.button_1080.change_style_sheet(self.button_1080.pressed_color, self.button_1080.pressed_color)
        elif default_quality == q_720:
            self.button_720.change_style_sheet(self.button_720.pressed_color, self.button_720.pressed_color)
        elif default_quality == q_480:
            self.button_480.change_style_sheet(self.button_480.pressed_color, self.button_480.pressed_color)
        elif default_quality == q_360:
            self.button_360.change_style_sheet(self.button_360.pressed_color, self.button_360.pressed_color)

    def co_update_sub_dub_buttons(self, updater: str):
        if updater == dub:
            self.sub_button.change_style_sheet(self.sub_button.bckg_color, self.sub_button.hover_color)
        elif updater == sub:
            self.dub_button.change_style_sheet(self.dub_button.bckg_color, self.dub_button.hover_color)


class SetupChosenAnimeWindowThread(QThread):
    finished = pyqtSignal(AnimeDetails)
    def __init__(self, window: MainWindow, anime: Anime, site: str):
        super().__init__(window)
        self.anime = anime
        self.site = site
        self.window = window
    def run(self):
        self.finished.emit(AnimeDetails(self.anime, self.site))

class DownloadButton(QPushButton):
    def __init__(self, chosen_anime_window: ChosenAnimeWindow, download_window: DownloadWindow, anime_details: AnimeDetails, ):
        super().__init__(chosen_anime_window)
        self.chosen_anime_window = chosen_anime_window
        self.download_window = download_window
        self.main_window = chosen_anime_window.main_window
        self.anime_details =  anime_details
        self.clicked.connect(self.handle_download_button_clicked)
        self.move(570, 450)
        self.setFixedSize(125, 50)
        self.setText("DOWNLOAD")
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setStyleSheet("""
                QPushButton {
                text-align: left;
                color: white;
                padding: 5px;
                font-size: 18px;
                font-family: Berlin Sans FB Demi;
                padding: 10px;
                border-radius: 5px;
                background-color: green;
            }
            QPushButton:hover {
                background-color: #20d941;
            }
            QPushButton:pressed {
                background-color: #5be673;
            }
            """)
    
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

        if haved_end >= episode_count: invalid_input = True

        if ((end_episode < start_episode) or (end_episode > episode_count)):
            end_episode = ""
            self.chosen_anime_window.end_episode_input.setText(end_episode)
            invalid_input = True

        if (start_episode > episode_count):
            start_episode = str(haved_end) if haved_end > 0 else "1"
            self.chosen_anime_window.start_episode_input.setText(start_episode)
            invalid_input = True

        if invalid_input:
            self.chosen_anime_window.episode_count.setStyleSheet("""
            QLabel {
                color: white;
                font-size: 20px;
                font-family: "Berlin Sans FB Demi";
                background-color: rgba(255, 0, 0, 255);
                border-radius: 10px;
                padding: 5px;
                border: 1px solid black;
                    }
                    """)
            return
        start_episode = int(start_episode)
        # For testing purposes
        # end_episode = start_episode
        end_episode = int(end_episode)
        self.anime_details.start_download_episode = start_episode
        self.anime_details.end_download_episode = end_episode
        self.main_window.stacked_windows.setCurrentWidget(self.main_window.download_window)
        self.download_window.get_episode_page_links(self.anime_details)
        self.main_window.stacked_windows.removeWidget(self.chosen_anime_window)



class FolderButton(IconButton):
    def __init__(self, parent, path: str, size_x: int, size_y: int, pos_x: int=0, pos_y: int=0 ):
        super().__init__(parent, size_x, size_y, folder_icon_path, 1.3)
        self.folder_path = path
        if pos_x != 0 and pos_y != 0: self.move(pos_x, pos_y)
        self.clicked.connect(lambda: os.startfile(self.folder_path))
    
class EpisodeCount(QLabel):
    def __init__(self, parent, count: str):
        super().__init__(parent)
        self.setText(f"{count} episodes")
        self.move(420, 515)
        self.setStyleSheet("""
            QLabel {
                color: white;
                font-size: 20px;
                font-family: "Berlin Sans FB Demi";
                background-color: rgba(255, 50, 0, 180);
                border-radius: 10px;
                padding: 5px;
                    }
                    """)


class Poster(QLabel):
        def __init__(self, parent, image: bytes):
            super().__init__(parent)
            x = 350
            y = 500
            pixmap = QPixmap()
            pixmap.loadFromData(image) # type: ignore Type checking is ass on this one honestly
            pixmap = pixmap.scaled(x, y, Qt.AspectRatioMode.IgnoreAspectRatio)

            self.move(50, 50)
            self.setPixmap(pixmap)
            self.setFixedSize(x, y)
            self.setStyleSheet("""
                        QLabel {
                        background-color: rgba(255, 140, 0, 200);
                        border-radius: 10px;
                        padding: 5px;
                        }
                        """)

class Title(OutlinedLabel):
    def __init__(self, parent, title: str):
        super().__init__(parent, 0, 28)
        self.move(450, 50)
        title = title.upper()
        if len(title) > 27: title = f"{title[:27]}.. ."
        self.setText(title)
        self.setStyleSheet("""
                    OutlinedLabel {
                        color: orange;
                        font-size: 30px;
                        font-family: "Berlin Sans FB Demi";
                            }
                            """)

class LineUnderTitle(QFrame):
        def __init__(self, parent):
            super().__init__(parent)
            self.setFrameShape(QFrame.Shape.HLine)
            self.setFixedSize(550, 7)
            self.move(430, 85)
            self.setStyleSheet("""
                        QFrame { 
                            background-color: black; 
                            }
                            """)

class StyledLabel(QLabel):
    def __init__(self, parent, font_size: int):
        super().__init__(parent)
        self.setStyleSheet(f"""
                    QLabel {{
                        color: white;
                        font-size: {font_size}px;
                        font-family: "Berlin Sans FB Demi";
                        background-color: rgba(0, 0, 0, 200);
                        border-radius: 10px;
                        padding: 5px;
                    }}
                            """)

class SummaryLabel(StyledLabel):
    def __init__(self, parent, summary: str):
        super().__init__(parent, 20)
        self.move(430, 100)
        words = summary.split(" ")
        formated_summary = []
        letter_count = 0
        for idx, word in enumerate(words):
            if idx == 100:
                formated_summary.append(".. .")
                break
            word = word.replace("\r", " ")
            word = word.replace("\n", " ")
            letter_count+=len(word)
            if letter_count >= 41:
                letter_count = 0
                formated_summary.append("\n")
            formated_summary.append(word)
        
        words = ' '.join(formated_summary)
        self.setText(words)

class HavedEpisodes(QLabel):
    def __init__(self, parent, start: int | None, end: int | None, count: int |None):
        super().__init__(parent)
        self.start = start
        self.end = end
        self.count = count
        self.move(570, 515)
        self.setStyleSheet("""
                    QLabel {
                        color: white;
                        font-size: 20px;
                        font-family: "Berlin Sans FB Demi";
                        background-color: rgba(0, 0, 0, 200);
                        border-radius: 10px;
                        padding: 5px;
                            }
                            """)
        if not count: self.setText("You have No episodes of this anime")
        else: self.setText(f"You have {count} episodes from {start} to {end}") if count != 1 else self.setText(f"You have {count} episode from {start} to {end}")


class EpisodeInput(QLineEdit):
    def __init__(self, parent, x: int, y: int, start_or_end):
        super().__init__(parent)
        self.installEventFilter(self)
        self.move(x, y)
        self.setFixedSize(60, 30)
        self.setPlaceholderText(start_or_end)
        self.setStyleSheet("""
            QLineEdit{
                border: 2px solid black;
                border-radius: 5px;
                padding: 5px;
                color: black;
                font-size: 14px;
                font-family: "Berlin Sans FB Demi";
            }
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

        

class QualityButton(QPushButton):
    def __init__(self, parent: ChosenAnimeWindow, x: int, y: int, quality: str):
        super().__init__(parent)
        self.my_parent = parent
        self.bckg_color = "rgba(128, 128, 128, 220)"
        self.hover_color = "rgba(255, 255, 0, 220)"
        self.pressed_color = "rgba(255, 165, 0, 220)"
        self.move(x, y)
        self.setFixedSize(60, 40)
        self.quality = quality
        self.setText(self.quality)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.change_style_sheet(self.bckg_color, self.hover_color)
        self.clicked.connect(lambda: self.change_style_sheet(self.pressed_color, self.pressed_color))
        self.clicked.connect(lambda: self.update_quality())

    def update_quality(self):
        self.my_parent.anime_details.quality = self.quality
    def change_style_sheet(self, bckg_color: str, hover_color: str): 
        self.setStyleSheet(f"""
            QPushButton {{
            text-align: left;
            color: white;
            padding: 5px;
            font-size: 18px;
            font-family: Berlin Sans FB Demi;
            padding: 10px;
            border-radius: 5px;
            background-color: {bckg_color};
        }}
        QPushButton:hover {{
            background-color: {hover_color};
        }}
    """)

class SubDubButton(QPushButton):
    def __init__(self, parent: ChosenAnimeWindow, x: int, y: int, sub_dub: str):
        super().__init__(parent)      
        self.my_parent =  parent
        self.bckg_color = "rgba(128, 128, 128, 220)"
        self.hover_color = "rgba(255, 255, 0, 220)"
        self.pressed_color = "rgba(255, 165, 0, 220)"
        self.sub_or_dub = sub_dub
        self.move(x, y)
        self.setFixedSize(60, 40)
        self.setText(self.sub_or_dub.upper())
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.change_style_sheet(self.bckg_color, self.hover_color)
        self.clicked.connect(lambda: self.change_style_sheet(self.pressed_color, self.pressed_color))
        self.clicked.connect(self.update_sub_or_dub)

    def update_sub_or_dub(self):
        self.my_parent.anime_details.sub_or_dub = self.sub_or_dub
    def change_style_sheet(self, bckg_color: str, hover_color: str): 
        self.setStyleSheet(f"""
            QPushButton {{
            text-align: left;
            color: white;
            padding: 5px;
            font-size: 20px;
            font-family: Berlin Sans FB Demi;
            padding: 10px;
            border-radius: 5px;
            background-color: {bckg_color}
        }}
        QPushButton:hover {{
            background-color: {hover_color};
        }}
    """)

class ResultButton(OutlinedButton):
    def __init__(self, anime: Anime,  main_window: MainWindow, site: str, paint_x: int, paint_y: int):
        super().__init__(paint_x, paint_y)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setFixedSize(900, 60)
        self.setText(anime.title)
        self.clicked.connect(lambda: main_window.setup_chosen_anime_window(anime, site))
        self.installEventFilter(self)
        if site == pahe_name:
            self.hover_color = "#FFC300"
            self.pressed_color = "#FFD700"
        elif site == gogo_name:
            self.hover_color = "#00FF00"
            self.pressed_color = "#00FF7F"
        self.setStyleSheet(f"""
            QPushButton {{
                text-align: left;
                color: white;
                padding: 5px;
                font-size: 30px;
                font-family: Berlin Sans FB Demi;
                padding: 10px;
                border-radius: 5px;
            }}
            QPushButton:hover {{
                background-color: {self.hover_color};
            }}
            QPushButton:pressed {{  
                background-color:  {self.pressed_color};
            }}
        """)
    
    def eventFilter(self, obj, event: QEvent):
        if obj == self:
            if isinstance(event, QKeyEvent):
                if event.type() == event.Type.KeyPress and (event.key() == Qt.Key.Key_Enter or event.key() == Qt.Key.Key_Return):
                    self.click()
            elif event.type() == QEvent.Type.FocusIn:
                        self.setStyleSheet(f"""
                            QPushButton {{
                                text-align: left;
                                color: white;
                                padding: 5px;
                                font-size: 30px;
                                font-family: Berlin Sans FB Demi;
                                padding: 10px;
                                border-radius: 5px;
                                background-color: {self.hover_color};
                            }}
                            QPushButton:pressed {{  
                                background-color:  {self.pressed_color};
                                }}
                        """)
            elif event.type() == QEvent.Type.FocusOut:
                        self.setStyleSheet(f"""
                            QPushButton {{
                                text-align: left;
                                color: white;
                                padding: 5px;
                                font-size: 30px;
                                font-family: Berlin Sans FB Demi;
                                padding: 10px;
                                border-radius: 5px;
                            }}
                            QPushButton:hover {{
                                background-color: {self.hover_color};
                            }}
                            QPushButton:pressed {{  
                                background-color:  {self.pressed_color};
                            }}
                        """)                 
        return super().eventFilter(obj, event)

class StyledButton(QPushButton):
    def __init__(self, parent, font_size: int, font_color: str, normal_color: str, hover_color: str, pressed_color: str, size_x=0, size_y=0, pos_x=0, pos_y=0, border_radius=5):
        super().__init__(parent)
        if size_x != 0 and size_y != 0: self.resize(size_x, size_y)
        if pos_x != 0 and pos_y != 0: self.move(pos_x, pos_y)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setStyleSheet(f"""
            QPushButton {{
                color: {font_color};
                background-color: {normal_color};
                border-radius: 20px;
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



class SearchButton(QPushButton):
    def __init__(self, parent: QWidget, window: SearchWindow, site: str) :
        super().__init__(parent)
        self.setFixedSize(200, 50)
        self.clicked.connect(lambda: window.search_anime(window.search_bar_text(), site))
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.installEventFilter(self)
        bckg_color = ""
        hover_color = ""
        pressed_color = ""
        if site == pahe_name:
            self.setText("Animepahe")
            bckg_color = "#FFC300"
            hover_color = "#FFD700"
            pressed_color = "#FFE900"
        elif site == gogo_name:
            self.setText("Gogoanime")
            hover_color = "#00FF7F"
            bckg_color = "#00FF00"
            pressed_color = "#7aea8e"
        self.setStyleSheet(f"""
            QPushButton {{
                color: white;
                background-color: {bckg_color};
                border-radius: 20px;
                padding: 5px;
                font-size: 14px;
                font-family: "Berlin Sans FB Demi";
                padding: 10px;
                border-radius: 5px;


            }}
            QPushButton:hover {{
                background-color: {hover_color};
            }}
            
            QPushButton:pressed {{  
                background-color: {pressed_color};
            }}
            
           
        """)        


if __name__ == "__main__":
    app = QApplication(sys.argv)
    app.setApplicationName("Senpwai")
    app.setWindowIcon(QIcon(senpwai_icon_path))
    # Set the purple theme
    palette = app.palette()
    palette.setColor(QPalette.ColorRole.Window, QColor("#FFA500"))
    palette.setColor(QPalette.ColorRole.WindowText, Qt.GlobalColor.white)
    app.setPalette(palette)

    window = MainWindow()
    window.show()

    sys.exit(app.exec())
