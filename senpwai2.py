import sys
import typing
from PyQt6 import QtGui
from PyQt6.QtGui import QColor, QPalette, QPixmap, QGuiApplication, QPen, QPainterPath, QPainter
from PyQt6.QtGui import QMovie, QKeyEvent, QIcon
from PyQt6.QtWidgets import QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, QLabel, QLineEdit, QPushButton, QFrame, QScrollArea, QProgressBar
from PyQt6.QtCore import QObject, Qt, QSize, QThread, pyqtSignal, QTimer, QEvent, QPoint, QByteArray
from PyQt6.sip import array

import os
import pahe
import gogo
from pathlib import Path
from random import randint  
import requests
import string
import re
import time
import threading
from typing import Callable, cast


pahe_name = "pahe"
gogo_name = "gogo"

dub = "dub"
sub = "sub"
sub_or_dub = sub
q_1080 = "1080"
q_720 = "720"
q_480 = "480"
q_360 = "360"
quality = q_720
default_download_folder_path = os.path.abspath(r'C:\\Users\\PC\\Downloads\\Anime')
default_site = pahe_name

root_path = os.path.abspath(r'.\\')
assets_path = os.path.join(root_path, "assets")

bckg_images_path = os.path.join(assets_path, "background-images")
bckg_images = list(Path(bckg_images_path).glob("*"))
bckg_image_path = str(bckg_images[randint(0, len(bckg_images)-1)])
loading_animation_path = os.path.join(assets_path, "loading.gif")
crying_animation_path = os.path.join(assets_path, "sadge-piece.gif")
folder_icon_path = os.path.join(assets_path, "folder.png")
pause_icon_path = os.path.join(assets_path, "pause.png")
resume_icon_path = os.path.join(assets_path, "resume.png")
cancel_icon_path = os.path.join(assets_path, "cancel.png")


# Goofy aah function to avoid screen blinking bug during window switch XD
def sleep_before_updating_screen():

    time.sleep(0)

class Anime():
    def __init__(self, title: str, page_link: str, anime_id: str|None) -> None:
        self.title = title
        self.page_link = page_link
        self.id = anime_id

class BckgImg(QLabel):
    def __init__(self, parent) -> None:
        super().__init__(parent)
        pixmap = QPixmap(bckg_image_path)
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
        self.setIconSize(self.size())
        self.enterEvent = lambda event: self.setIconSize(QSize(round(size_x*size_factor), round(size_y*size_factor)))
        self.leaveEvent = lambda a0: self.setIconSize(QSize(size_x, size_y))
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
        super().paintEvent(event)

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
        painter.end()

        # Call the parent class's paintEvent to draw the button background and other properties
        super().paintEvent(event)

class ProgressBar(QWidget):
    def __init__(self, parent, task_title: str, item_task_is_applied_on: str, size_x: int, size_y: int, total_value: int, units: str):
        super().__init__(parent)
        self.item_task_is_applied_on = item_task_is_applied_on
        self.total_value = total_value
        self.units = units
        self.layout = QHBoxLayout(self) # type: ignore 
        self.setLayout(self.layout)

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
                 font-size: 22px;
                 font-family: "Berlin Sans FB Demi";
             }

             QProgressBar::chunk {
                 background-color: orange;
                 border-radius: 10px;
             }
         """)
        style_sheet = """
                        QLabel {
                        color: white;
                        font-size: 20px;
                        font-family: "Berlin Sans FB Demi";
                        background-color: rgba(0, 0, 0, 200);
                        border-radius: 10px;
                        padding: 5px;
                            }
                            """
        height = 50
        self.percentage = QLabel(self)
        self.percentage.setText("0 %")
        self.percentage.setFixedHeight(height)
        self.percentage.setStyleSheet(style_sheet)

        self.rate = QLabel(self)
        self.rate.setText(f"0{units} /s")
        self.rate.setFixedHeight(height)
        self.rate.setStyleSheet(style_sheet)
        
        self.eta = QLabel(self)
        self.eta.setText("∞ secs left")
        self.eta.setFixedHeight(height)
        self.eta.setStyleSheet(style_sheet)
        
        self.current_against_max_values = QLabel(self)
        self.current_against_max_values.setText(f"0/{total_value} {units}")
        self.current_against_max_values.setFixedHeight(height)
        self.current_against_max_values.setStyleSheet(style_sheet)

        self.layout.addWidget(self.percentage)
        self.layout.addWidget(self.bar)
        self.layout.addWidget(self.eta)
        self.layout.addWidget(self.rate)
        self.layout.addWidget(self.current_against_max_values)
        self.prev_time = time.time()

    def update(self, added_value: int):
        new_value = self.bar.value() + added_value
        curr_time = time.time()
        time_elapsed = curr_time - self.prev_time
        self.prev_time = curr_time
        rate = added_value / time_elapsed
        max_value = self.bar.maximum()
        eta = (max_value - new_value) * (1/rate) 
        if new_value >= max_value:
            new_value = max_value
            self.bar.setFormat(f"Completed {self.item_task_is_applied_on}")

        self.bar.setValue(new_value)
        percent_new_value = round(new_value / max_value * 100)
        self.percentage.setText(f"{percent_new_value}%")
        self.eta.setText(f"{round(eta/60)}mins left"if eta >= 60 else f"{round(eta)} secs left")
        self.rate.setText(f"{round(rate)} {self.units}/s")
        self.current_against_max_values.setText(f" {new_value}/{max_value} {self.units}")


class DownloadProgressBar(ProgressBar):
    def __init__(self, parent, task_title: str, item_task_is_applied_on: str, size_x: int, size_y: int, total_value: int, units: str, pause_callback: Callable):
        super().__init__(parent, task_title, item_task_is_applied_on, size_x, size_y, total_value, units)
        self.pause_button = IconButton(self, 50, 50, pause_icon_path, 1.25)
        self.paused = False
        self.pause_icon = self.pause_button.icon()
        self.pause_callback = pause_callback
        resume_icon_pixmap = QPixmap(resume_icon_path)
        resume_icon_pixmap.scaled(50, 50, Qt.AspectRatioMode.IgnoreAspectRatio)
        self.resume_icon = QIcon(resume_icon_pixmap) 
        self.pause_button.clicked.connect(self.pause_or_resume)

        self.folder_button = FolderButton(self, pause_icon_path, 50, 50)
        self.cancel_button = IconButton(self, 50, 50, cancel_icon_path, 1.25)

        self.layout.addWidget(self.pause_button)
        self.layout.addWidget(self.folder_button)
        self.layout.addWidget(self.cancel_button)

    def pause_or_resume(self):
        if not self.pause_callback(): return
        self.paused = not self.paused
        if self.paused: self.pause_button.setIcon(self.resume_icon)
        else: self.pause_button.setIcon(self.pause_icon)

class AnimeDetails():
    def __init__(self, anime: Anime, site: str):
        self.anime = anime
        self.site = site
        self.sanitised_title = sanitise_title(anime.title)
        self.anime_folder_path = self.get_anime_folder_path()
        self.potentially_haved_episodes = self.get_potentially_haved_episodes()
        self.haved_start, self.haved_end, self.haved_count = self.get_start_end_and_count_of_haved_episodes()
        self.dub_available = self.get_dub_availablilty_status()
        self.poster, self.summary, self.episode_count = self.get_poster_image_summary_and_episode_count()
        self.start_download_episode = None
        self.end_download_episode = None
        self.quality = quality
        self.sub_or_dub = sub_or_dub 
        self.direct_download_links: list[str] = []
        self.download_info: list[str] = []
        self.download_sizes: list[int] = []
        self.total_download_size: int = 0

    def get_anime_folder_path(self) -> str | None:
        path = os.path.join(default_download_folder_path, self.sanitised_title)
        return path if os.path.isdir(path) else None

    def get_potentially_haved_episodes(self) -> list[Path] | None:
        if not self.anime_folder_path: return None
        episodes = list(Path(self.anime_folder_path).glob("*"))
        return episodes    

    def get_start_end_and_count_of_haved_episodes(self) -> tuple[int, int, int] | tuple[None, None, None]:
        pattern = fr"{self.anime.title} Episode (\d+)"
        haved_episodes = []
        if self.potentially_haved_episodes:
            for episode in self.potentially_haved_episodes:
                match = re.search(pattern, episode.name)
                if match:
                    episode_number = int(match.group(1))
                    if episode_number > 0: haved_episodes.append(episode_number)
            haved_episodes.sort()
        return (haved_episodes[0], haved_episodes[-1], len(haved_episodes)) if len(haved_episodes) > 0 else (None, None, None)
    
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
            poster_image = requests.get(poster_url).content
        elif self.site == gogo_name:
            poster_url, summary, episode_count = gogo.extract_poster_summary_and_episode_count(self.anime.page_link)
            poster_image = requests.get(poster_url).content
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
        self.setup_search_window()     

        self.setup_chosen_anime_window_thread = None
       
        # For testing purposes
        self.setup_chosen_anime_window(Anime("Senyuu.", "https://animepahe.ru/api?m=release&id=84394db4-6b5b-4cb8-d010-3c9b34f04974&sort=episode_asc", "84394db4-6b5b-4cb8-d010-3c9b34f04974"), pahe_name)


    def setup_search_window(self):
        self.search_window = SearchWindow(self)
        self.setCentralWidget(self.search_window)

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
        self.chosen_anime_window = ChosenAnimeWindow(self, anime_details)
        sleep_before_updating_screen()
        self.setCentralWidget(self.chosen_anime_window)
        sleep_before_updating_screen()
        self.setup_chosen_anime_window_thread = None

        # For testing purposes
        self.chosen_anime_window.download_button.click()

    
    def switch_to_download_window(self, start_episode: int, end_index: int):
        self.download_window = DownloadWindow(self, start_episode, end_index)
        self.setCentralWidget(self.download_window)
        self.download_window.get_episode_page_links(self.chosen_anime_window.anime_details)

class SearchWindow(QWidget):
    def __init__(self, main_window: MainWindow):
        super().__init__(main_window)
        self.setFixedSize(main_window.size())
        self.bckg_img = BckgImg(self)

        self.search_widget = QWidget(self)
        self.search_widget.setFixedSize(1000, 150)
        self.search_widget.move(30, 50)

        self.search_bar = SearchBar(self.search_widget, self)
        self.search_bar_text = lambda: self.search_bar.text()
        self.main_window = main_window
        pahe_search_button = SearchButton(self.search_widget, self, pahe_name, )
        gogo_search_button = SearchButton(self.search_widget, self, gogo_name)
        pahe_search_button.move(self.search_bar.x()+200, self.search_bar.y()+80)
        gogo_search_button.move(self.search_bar.x()+500, self.search_bar.y()+80)

        self.results_layout = QVBoxLayout()
        ScrollableSection(self, self.results_layout, 950, 440, 20, 200)

        self.anime_not_found = AnimationAndText(self, crying_animation_path, 450, 300, 290, 180, "Couldn't find that anime", 0, 165, 40)
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


class DownloadWindow(QWidget):
    def __init__(self, parent: MainWindow, start_episode: int, end_episode: int):
        super().__init__(parent)
        self.setFixedSize(parent.size())
        self.downloads_section = QWidget(self)
        #self.downloads_section.setFixedSize(self.x(), 550)
        self.start_episode = start_episode
        self.end_index = end_episode
        BckgImg(self)
        spacing = "   " # Fix to  positioning issues lol
        self.loading = AnimationAndText(self, loading_animation_path, 450, 300, 290, 180, f"{spacing}Getting episode page links.. .", 0, 160, 30)
        self.downloads_layout = QVBoxLayout(self)
        self.downloads_layout.setContentsMargins(0, 0, 0, 0)
        ScrollableSection(self, self.downloads_layout, 950, 440, 20, 200)

    def get_episode_page_links(self, anime_details: AnimeDetails):
        if anime_details.site == pahe_name: 
            episode_page_progress_bar = ProgressBar(self, "Getting episode page links", "", 500, 40, pahe.get_total_episode_page_count(anime_details.anime.page_link), "pgs")
            self.downloads_layout.insertWidget(0, episode_page_progress_bar)
            return GetEpisodePageLinksThread(self, anime_details, self.start_episode, self.end_index, 
                                  lambda eps_links: self.get_download_page_links(eps_links, anime_details), episode_page_progress_bar.update).start()    
        if anime_details.site ==  gogo_name and anime_details.sub_or_dub == dub and anime_details.dub_available: anime_details.anime.page_link = gogo.get_dub_anime_page_link(anime_details.anime.title) 
        GetEpisodePageLinksThread(self, anime_details, self.start_episode, self.end_index, 
                                  lambda eps_links : self.get_download_page_links(eps_links, anime_details), lambda x: None).start() 
        
    def get_download_page_links(self, episode_page_links: list[str], anime_details: AnimeDetails):
        download_page_progress_bar = ProgressBar(self, "Fetching download page links", "", 500, 40, len(episode_page_links), "eps")
        self.downloads_layout.insertWidget(0, download_page_progress_bar)
        GetDownloadPageThread(self, anime_details.site, episode_page_links, lambda down_pge_lnk, down_info: self.get_direct_download_links(down_pge_lnk, down_info, anime_details)
                              , download_page_progress_bar.update).start()
        
    def get_direct_download_links(self, download_page_links: list[str], download_info: list[list[str]], anime_details: AnimeDetails):
        if anime_details.site == gogo_name: 
            direct_download_links_progress_bar =  ProgressBar(self, "Retrieving direct download links", "", 500, 40, len(download_page_links), "eps") 
            self.downloads_layout.insertWidget(0, direct_download_links_progress_bar)
            return GetDirectDownloadLinksThread(self, download_page_links, download_info, anime_details, lambda: self.start_download(anime_details), direct_download_links_progress_bar.update).start()
        GetDirectDownloadLinksThread(self, download_page_links, download_info, anime_details, lambda: self.start_download(anime_details), lambda x: None).start()

    def start_download(self, anime_details: AnimeDetails):
       pass 
class GetEpisodePageLinksThread(QThread):
    finished = pyqtSignal(list)
    def __init__(self, parent, anime_details: AnimeDetails, start_episode: int, end_episode: int, finished_callback: Callable, progress_update_callback: Callable):
        super().__init__(parent)
        self.anime_details = anime_details
        self.progress_update_callback = progress_update_callback
        self.finished.connect(lambda episode_page_links: finished_callback(episode_page_links))
        self.start_episode = start_episode
        self.end_index = end_episode
    def run(self):
        if self.anime_details.site == pahe_name:
            episode_page_links = pahe.get_episode_page_links(self.start_episode, self.end_index, self.anime_details.anime.page_link, cast(str, self.anime_details.anime.id), self.progress_update_callback)
            self.finished.emit(episode_page_links)
        elif self.anime_details.site == gogo_name:
            episode_page_links = gogo.generate_episode_page_links(self.start_episode, self.end_index, self.anime_details.anime.page_link)
            self.finished.emit(episode_page_links)

class GetDownloadPageThread(QThread):
    finished = pyqtSignal(list, list)
    def __init__(self, parent, site: str, episode_page_links: list[str], finished_callback: Callable, progress_update_callback: Callable):
        super().__init__(parent)
        self.site = site
        self.episode_page_links = episode_page_links
        self.progress_update_callback = progress_update_callback
        self.finished.connect(lambda download_page_links, download_info: finished_callback(download_page_links, download_info))
    def run(self):
        if self.site == pahe_name:
            download_page_links, download_info = pahe.get_download_page_links_and_info(self.episode_page_links, self.progress_update_callback)
            self.finished.emit(download_page_links, download_info)
        elif self.site == gogo_name:
            download_page_links = gogo.get_download_page_links(self.episode_page_links, self.progress_update_callback)
            self.finished.emit(download_page_links, [])

class GetDirectDownloadLinksThread(QThread):
    finished =  pyqtSignal()
    def __init__(self, parent: QObject, download_page_links: list[str] | list[list[str]], download_info: list[list[str]], anime_details: AnimeDetails, finished_callback: Callable, progress_update_callback: Callable):
        super().__init__(parent)
        self.download_page_links = download_page_links
        self.download_info = download_info
        self.anime_details = anime_details
        self.progress_update_callback = progress_update_callback
        self.finished.connect(finished_callback)

    def run(self):
        if self.anime_details.site == pahe_name:
            bound_links, bound_info = pahe.bind_sub_or_dub_to_link_info(self.anime_details.sub_or_dub, cast(list[list[str]], self.download_page_links), self.download_info)
            bound_links, self.anime_details.download_info = pahe.bind_quality_to_link_info(self.anime_details.quality, bound_links, bound_info )
            self.anime_details.direct_download_links = pahe.get_direct_download_links(bound_links)
            self.finished.emit()
        if self.anime_details.site ==  gogo_name:
            self.anime_details.direct_download_links = gogo.get_direct_download_link_as_per_quality(cast(list[str], self.download_page_links), self.anime_details.quality, 
                                                                                        gogo.set_up_headless_browser(), self.progress_update_callback)
            self.finished.emit()
                                                                                                    
class CalculateDownloadSizes(QThread):
    finished = pyqtSignal()
    def __init__(self, parent: QObject, anime_details: AnimeDetails, finished_callback: Callable, progress_update_callback: Callable):
        super().__init__(parent)
        self.progress_update_callback = progress_update_callback
        self.anime_details = anime_details
        self.finished.connect(finished_callback)
    def run(self):
        if self.anime_details.site == pahe_name:
            self.anime_details.total_download_size, self.anime_details.download_sizes = pahe.get_download_sizes(self.anime_details.download_info)
        elif self.anime_details.site == gogo_name:                # With gogoanime we dont have to store the download sizes for each episode since we dont use a headless browser to actually download just to get the links
            self.anime_details.total_download_size = gogo.calculate_download_total_size(self.anime_details.direct_download_links, self.progress_update_callback)
class ChosenAnimeWindow(QWidget):
    def __init__(self, parent: MainWindow, anime_details: AnimeDetails):
        super().__init__(parent)
        self.main_window = parent
        self.setFixedSize(parent.size())
        self.anime_details = anime_details
        self.anime = anime_details.anime

        BckgImg(self)
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
        self.button_720 = QualityButton(self, 630, 400, q_720) 
        self.button_480 = QualityButton(self, 695, 400, q_480) 
        self.button_360 = QualityButton(self, 760, 400, q_360) 
        self.setup_quality_buttons_color_clicked_status()
        self.quality_buttons_list = [self.button_1080, self.button_720, self.button_480, self.button_360]

        for button in self.quality_buttons_list: 
                                    # x holds a boolean value that connect passes to the callback for some reason
            button.clicked.connect(lambda x, updater=button.quality: self.co_update_quality_buttons(updater))

        start_episode = str((self.anime_details.haved_end)+1) if (self.anime_details.haved_end and self.anime_details.haved_end < self.anime_details.episode_count) else "1"
        self.start_episode_input = EpisodeInput(self, 420, 460, "START")
        self.start_episode_input.setText(str(start_episode))
        self.end_episode_input = EpisodeInput(self, 500, 460, "END")
        self.download_button = DownloadButton(self, self.anime_details)

        HavedEpisodes(self, self.anime_details.haved_start, self.anime_details.haved_end, self.anime_details.haved_count)
        self.episode_count = EpisodeCount(self, str(self.anime_details.episode_count))
        if self.anime_details.anime_folder_path: FolderButton(self, self.anime_details.anime_folder_path, 60, 60, 710, 445)
    
    
    def co_update_quality_buttons(self, updater: str):
        for button in self.quality_buttons_list:
            if button.quality != updater:
                button.change_style_sheet(button.bckg_color, button.hover_color)

    def setup_quality_buttons_color_clicked_status(self):
        if quality == q_1080:
            self.button_1080.change_style_sheet(self.button_1080.pressed_color, self.button_1080.pressed_color)
        elif quality == q_720:
            self.button_720.change_style_sheet(self.button_720.pressed_color, self.button_720.pressed_color)
        elif quality == q_480:
            self.button_480.change_style_sheet(self.button_480.pressed_color, self.button_480.pressed_color)
        elif quality == q_360:
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
    def __init__(self, parent: ChosenAnimeWindow, anime_details: AnimeDetails):
        super().__init__(parent)
        self.chosen_anime_window = parent
        self.main_window = parent.main_window
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
                background-color: yellow;
            }
            QPushButton:pressed {
                background-color: orange;
            }
            """)
    
    def handle_download_button_clicked(self):
        start_episode = self.chosen_anime_window.start_episode_input.text()
        end_episode = self.chosen_anime_window.end_episode_input.text()
        
        invalid_input = False
        # Ordering and chaining of each condition is really important, take note
        if (end_episode) == "0"  or (end_episode != "" and start_episode  != "" and ((int(end_episode) < int(start_episode)) or (int(end_episode) > self.chosen_anime_window.anime_details.episode_count))):
            end_episode = ""
            self.chosen_anime_window.end_episode_input.setText("")
            invalid_input = True

        if (start_episode == "0" or start_episode == "" or int(start_episode) > self.chosen_anime_window.anime_details.episode_count):
            start_episode = ""
            self.chosen_anime_window.start_episode_input.setText("")
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
        # For testing purposes
        start_episode = 12
        start_episode = int(start_episode)
        end_episode = int(end_episode) if end_episode != "" else int(self.chosen_anime_window.anime_details.episode_count)
        self.main_window.switch_to_download_window(start_episode, end_episode)


class FolderButton(IconButton):
    def __init__(self, parent, path: str, size_x: int, size_y: int, pos_x: int=0, pos_y: int=0 ):
        super().__init__(parent, size_x, size_y, folder_icon_path, 1.3)
        self.folder_path = path
        if pos_x != 0 and pos_y != 0: self.move(pos_x, pos_y)
        self.clicked.connect(lambda: os.startfile(self.folder_path))
        self.enterEvent = lambda event: self.setIconSize(QSize(round(self.iconSize().width()*1.3), round(self.iconSize().height()*1.3)))
        self.leaveEvent = lambda a0: self.setIconSize(QSize(size_x, size_y))
        self.setStyleSheet("""
            QPushButton {
                border: none; 
                background-color: transparent;
            }""")
    
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
        self.setText(title.upper() if len(title)<=20 else title)
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

class SummaryLabel(QLabel):
    def __init__(self, parent, summary: str):
        super().__init__(parent)
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

#Santises folder name to only allow names that windows can create a folder with
def sanitise_title(title: str):
    valid_chars = set(string.printable) - set('\\/:*?"<>|')
    sanitised = ''.join(filter(lambda c: c in valid_chars, title))
    return sanitised[:255].rstrip()

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

class SearchButton(QPushButton):
    def __init__(self, parent: QWidget, window: SearchWindow, site: str) :
        super().__init__(parent)
        self.setFixedSize(200, 50)
        self.clicked.connect(lambda: window.search_anime(window.search_bar_text(), site))
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.installEventFilter(self)
        bckg_color = ''
        hover_color = ''
        if site == pahe_name:
            self.setText("Animepahe")
            bckg_color = "#FFC300"
            hover_color = "#FFD700"
        elif site == gogo_name:
            self.setText("Gogoanime")
            hover_color = "#00FF7F"
            bckg_color = "#00FF00"
        pressed_color = "#F5DEB3"
        self.setStyleSheet(f"""
            QPushButton {{
                color: black;
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

    # Set the purple theme
    palette = app.palette()
    palette.setColor(QPalette.ColorRole.Window, QColor("#FFA500"))
    palette.setColor(QPalette.ColorRole.WindowText, Qt.GlobalColor.white)
    app.setPalette(palette)

    window = MainWindow()
    window.show()

    sys.exit(app.exec())
