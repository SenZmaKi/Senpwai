import os
import sys
from random import choice as randomchoice
from appdirs import user_config_dir
from pathlib import Path
from PyQt6.QtWidgets import QSizePolicy
import json
from typing import cast
from subprocess import Popen
import logging
from datetime import datetime
from types import TracebackType


def try_deleting_safely(path: str):
    if os.path.isfile(path):
        try:
            os.unlink(path)
        except PermissionError:
            pass


if getattr(sys, 'frozen', False):
    src_directory = os.path.join(os.path.dirname(sys.executable))
    is_executable = True
else:
    src_directory = os.path.dirname(os.path.realpath('__file__'))
    is_executable = False

APP_NAME = "Senpwai"
VERSION = "2.0.7"
UPDATE_INSTALLER_NAMES = (f"{APP_NAME}-updater.exe", f"{APP_NAME}-update.exe",
                          f"{APP_NAME}-updater.msi", f"{APP_NAME}-update.msi",
                          f"{APP_NAME}-setup.exe", f"{APP_NAME}-setup.msi",
                          f"{APP_NAME}-installer.exe", f"{APP_NAME}-installer.msi")


date = datetime.today()
IS_CHRISTMAS = True if date.month == 12 and date.day >= 20 else False

for name in UPDATE_INSTALLER_NAMES:
    full_path = os.path.join(src_directory, name)
    try_deleting_safely(full_path)

config_dir = os.path.join(user_config_dir(), APP_NAME)

if not os.path.isdir(config_dir):
    os.makedirs(config_dir)
GITHUB_REPO_URL = "https://github.com/SenZmaKi/Senpwai"
github_api_releases_entry_point = "https://api.github.com/repos/SenZmaKi/Senpwai/releases"
sen_anilist_id = 5363369
anilist_api_entrypoint = 'https://graphql.anilist.co'
PAHE = "pahe"
GOGO = "gogo"
DUB = "dub"
SUB = "sub"
Q_1080 = "1080p"
Q_720 = "720p"
Q_480 = "480p"
Q_360 = "360p"
GOGO_NORM_MODE = "norm"
GOGO_HLS_MODE = "hls"


class Settings():
    types = str | int | bool | list[str]

    def __init__(self, config_dir: str) -> None:
        self.settings_json_path = os.path.join(config_dir, "settings.json")

        # Default settings
        self.sub_or_dub = SUB
        self.quality = Q_720
        self.download_folder_paths = self.setup_default_download_folder()
        self.max_simultaneous_downloads = 3
        self.allow_notifications = True
        self.start_in_fullscreen = True
        self.run_on_startup = False
        self.gogo_norm_or_hls_mode = GOGO_NORM_MODE
        self.tracked_anime: list[str] = []
        self.auto_download_site = PAHE
        self.check_for_new_eps_after = 24
        self.gogo_skip_calculate = False

        self.configure()

    def configure(self) -> None:
        failed_to_load_settings = False if os.path.isfile(
            self.settings_json_path) else True
        if not failed_to_load_settings:
            with open(self.settings_json_path, "r") as f:
                try:
                    settings = cast(dict, json.load(f))
                    try:
                        self.__dict__.update(settings)
                        print(self.quality)
                    except ValueError:
                        failed_to_load_settings = True
                except json.decoder.JSONDecodeError:
                    failed_to_load_settings = True
        if failed_to_load_settings:
            with open(self.settings_json_path, "w") as f:
                json.dump(self.dict_settings(), f, indent=4)

    def setup_default_download_folder(self) -> list[str]:
        downloads_folder = os.path.join(Path.home(), "Downloads", "Anime")
        if not os.path.isfile(self.settings_json_path) and not os.path.isdir(downloads_folder):
            os.makedirs(downloads_folder)
        return [downloads_folder]

    def dict_settings(self) -> dict:
        d_settings = {k: v for k, v in self.__dict__.items()}
        d_settings.pop("settings_json_path")
        return d_settings

    def update_sub_or_dub(self, sub_or_dub: str) -> None:
        self.sub_or_dub = sub_or_dub
        self.save_settings()

    def update_quality(self, quality: str) -> None:
        self.quality = quality
        self.save_settings()

    def update_download_folder_paths(self, download_folder_paths: list[str]) -> None:
        self.download_folder_paths = download_folder_paths
        self.save_settings()

    def add_download_folder_path(self, download_folder_path: str) -> None:
        self.download_folder_paths.append(download_folder_path)
        self.save_settings()

    def remove_download_folder_path(self, download_folder_path: str) -> None:
        self.download_folder_paths.remove(download_folder_path)
        self.save_settings()

    def change_download_folder_path(self, old_path_idx: int, new_path: str) -> None:
        self.download_folder_paths[old_path_idx] = new_path
        self.save_settings()

    def pop_download_folder_path(self, index: int) -> None:
        self.download_folder_paths.pop(index)
        self.save_settings()

    def update_max_simultaneous_downloads(self, max_simultaneous_downloads: int) -> None:
        self.max_simultaneous_downloads = max_simultaneous_downloads
        self.save_settings()

    def update_allow_notifications(self, allow_notifications: bool) -> None:
        self.allow_notifications = allow_notifications
        self.save_settings()

    def update_start_in_fullscreen(self, start_in_fullscreen: bool) -> None:
        self.start_in_fullscreen = start_in_fullscreen
        self.save_settings()

    def update_run_on_startup(self, run_on_startup: bool) -> None:
        self.run_on_startup = run_on_startup
        self.save_settings()

    def update_gogo_norm_or_hls_mode(self, gogo_norm_or_hls_mode: str) -> None:
        self.gogo_norm_or_hls_mode = gogo_norm_or_hls_mode
        self.save_settings()

    def update_tracked_anime(self, tracked_anime: list[str]) -> None:
        self.tracked_anime = tracked_anime
        self.save_settings()

    def remove_tracked_anime(self, anime_name: str) -> None:
        self.tracked_anime.remove(anime_name)
        self.save_settings()

    def add_tracked_anime(self, anime_name: str) -> None:
        self.tracked_anime.append(anime_name)
        self.save_settings()

    def update_auto_download_site(self, auto_download_site: str) -> None:
        self.auto_download_site = auto_download_site
        self.save_settings()

    def update_check_for_new_eps_after(self, check_for_new_eps_after: int) -> None:
        self.check_for_new_eps_after = check_for_new_eps_after
        self.save_settings()

    def update_gogo_skip_calculate(self, gogo_skip_calculate: bool) -> None:
        self.gogo_skip_calculate = gogo_skip_calculate
        self.save_settings()

    def update_pahe_home_url(self, pahe_home_url: str) -> None:
        self.pahe_home_url = pahe_home_url
        self.save_settings()

    def update_gogo_home_url(self, gogo_home_url: str) -> None:
        self.gogo_home_url = gogo_home_url
        self.save_settings()

    def save_settings(self) -> None:
        with open(self.settings_json_path, "w") as f:
            json.dump(self.dict_settings(), f, indent=4)



SETTINGS = Settings(config_dir)


amogus_easter_egg = "ඞ"

error_logs_file_path = os.path.join(config_dir, "errors.log")
if not os.path.exists(error_logs_file_path):
    f = open(error_logs_file_path, "w")
    f.close()

version_file_path = os.path.join(config_dir, "version.txt")
with open(version_file_path, "w") as f:
    f.write(VERSION)

logging.basicConfig(filename=error_logs_file_path, level=logging.ERROR,
                    format='%(asctime)s - %(levelname)s - %(message)s')


def custom_exception_handler(type_: type[BaseException], value: BaseException, traceback: TracebackType | None):
    logging.error(f"Unhandled exception: {type_.__name__}: {value}")
    sys.__excepthook__(type_, value, traceback)


def log_exception(e: Exception):
    custom_exception_handler(type(e), e, e.__traceback__)


def open_folder(folder_path: str) -> None:
    if sys.platform == "win32":
        os.startfile(folder_path)
    elif sys.platform == "linux":
        Popen(["xdg-open", folder_path])
    else:
        Popen(["open", folder_path])


assets_path = os.path.join(src_directory, "assets")
def join_from_assets(file): return os.path.join(assets_path, file)


misc_path = os.path.join(assets_path, "misc")
def join_from_misc(file): return os.path.join(misc_path, file)


SENPWAI_ICON_PATH = join_from_misc("senpwai-icon.ico")
task_complete_icon_path = join_from_misc("task-complete.png")
loading_animation_path = join_from_misc("loading.gif")
sadge_piece_path = join_from_misc("sadge-piece.gif")
folder_icon_path = join_from_misc("folder.png")

mascots_folder_path = join_from_assets("mascots")
mascots_files = list(Path(mascots_folder_path).glob("*"))
random_mascot_icon_path = str(randomchoice(mascots_files))

bckg_images_path = join_from_assets("background-images")


def join_from_bckg_images(img_title): return os.path.join(
    bckg_images_path, img_title).replace("\\", "/")


s = "christmas.jpg" if IS_CHRISTMAS else "search.jpg"
search_window_bckg_image_path = join_from_bckg_images(s)
chosen_anime_window_bckg_image_path = join_from_bckg_images("chosen-anime.jpg")
settings_window_bckg_image_path = join_from_bckg_images("settings.jpg")
download_window_bckg_image_path = join_from_bckg_images("downloads.png")
chopper_crying_path = join_from_bckg_images("chopper-crying.png")
about_bckg_image_path = join_from_bckg_images("about.jpg")
update_bckg_image_path = join_from_bckg_images("update.jpg")

link_icons_folder_path = join_from_assets("link-icons")


def join_from_link_icons(icon_path): return os.path.join(
    link_icons_folder_path, icon_path
)


github_sponsors_icon_path = join_from_link_icons("github-sponsors.svg")
github_icon_path = join_from_link_icons("github.png")
patreon_icon_path = join_from_link_icons("patreon.png")
reddit_icon_path = join_from_link_icons("reddit.png")
discord_icon_path = join_from_link_icons("discord.png")

download_icons_folder_path = join_from_assets("download-icons")


def join_from_download_icons(icon_path): return os.path.join(
    download_icons_folder_path, icon_path
)


pause_icon_path = join_from_download_icons("pause.png")
resume_icon_path = join_from_download_icons("resume.png")
cancel_icon_path = join_from_download_icons("cancel.png")
remove_from_queue_icon_path = join_from_download_icons("trash.png")
move_up_queue_icon_path = join_from_download_icons("up.png")
move_down_queue_icon_path = join_from_download_icons("down.png")

audio_folder_path = join_from_assets("audio")


def join_from_audio(audio_path): return os.path.join(
    audio_folder_path, audio_path
)


gigachad_audio_path = join_from_audio("gigachad.mp3")
hentai_addict_audio_path = join_from_audio("aqua-crying.mp3")
morbius_audio_path = join_from_audio("morbin-time.mp3")
sen_favourite_audio_path = join_from_audio("sen-favourite.wav")
one_piece_audio_path = join_from_audio(
    f"one-piece-real-{randomchoice((1, 2))}.mp3")
kage_bunshin_audio_path = join_from_audio("kage-bunshin-no-jutsu.mp3")
bunshin_poof_audio_path = join_from_audio("bunshin-poof.mp3")
za_warudo_audio_path = join_from_audio("za-warudo.mp3")
toki_wa_ugoki_dasu_audio_path = join_from_audio("toki-wa-ugoki-dasu.mp3")
what_da_hell_audio_path = join_from_audio("what-da-hell.mp3")
merry_chrismasu_audio_path = join_from_audio("merry-chrismasu.mp3")

reviewer_profile_pics_folder_path = join_from_assets("reviewer-profile-pics")


def join_from_reviewer(icon_path): return os.path.join(
    reviewer_profile_pics_folder_path, icon_path
)


sen_icon_path = join_from_reviewer("sen.png")
morbius_is_peak_icon_path = join_from_reviewer("morbius-is-peak.png")
hentai_addict_icon_path = join_from_reviewer("hentai-addict.png")

navigation_bar_icons_folder_path = join_from_assets("navigation-bar-icons")


def join_from_navbar(icon_path): return os.path.join(
    navigation_bar_icons_folder_path, icon_path)


search_icon_path = join_from_navbar("search.png")
downloads_icon_path = join_from_navbar("downloads.png")
settings_icon_path = join_from_navbar("settings.png")
about_icon_path = join_from_navbar("about.png")
update_icon_path = join_from_navbar("update.png")

PAHE_NORMAL_COLOR = "#FFC300"
PAHE_HOVER_COLOR = "#FFD700"
PAHE_PRESSED_COLOR = "#FFE900"

GOGO_NORMAL_COLOR = "#00FF00"
GOGO_HOVER_COLOR = "#60FF00"
GOGO_PRESSED_COLOR = "#99FF00"

RED_NORMAL_COLOR = "#E80000"
RED_HOVER_COLOR = "#FF0202"
RED_PRESSED_COLOR = "#FF1C1C"


def requires_admin_access(folder_path):
    try:
        temp_file = os.path.join(folder_path, 'temp.txt')
        open(temp_file, 'w').close()
        try_deleting_safely(temp_file)
        return False
    except PermissionError:
        return True


def set_minimum_size_policy(object):
    object.setSizePolicy(QSizePolicy.Policy.Minimum,
                         QSizePolicy.Policy.Minimum)
    object.setFixedSize(object.sizeHint())


def fix_qt_path_for_windows(path: str) -> str:
    if sys.platform == "win32":
        path = path.replace("/", "\\")
    return path
