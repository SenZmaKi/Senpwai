import os
import sys
from random import choice as randomchoice
from appdirs import user_config_dir
from pathlib import Path
from scrapers.gogo import EDGE, CHROME, FIREFOX
from PyQt6.QtWidgets import QSizePolicy
import json
from typing import cast
from subprocess import Popen
import logging

if getattr(sys, 'frozen', False):
    base_directory = os.path.dirname(sys.executable)
else:
    base_directory = os.path.dirname(os.path.realpath('__file__'))

COMPANY_NAME = "AkatsuKi Inc."
APP_NAME = "Senpwai"
VERSION = "2.0.1"
base_config_dir = user_config_dir()
if sys.platform == "win32":
    config_dir = os.path.join(base_config_dir, "Programs", APP_NAME)
else:
    config_dir = os.path.join(base_config_dir, APP_NAME)
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
default_sub_or_dub = SUB
Q_1080 = "1080p"
Q_720 = "720p"
Q_480 = "480p"
Q_360 = "360p"
default_quality = Q_720
GOGO_NORM_MODE = "norm"
GOGO_HLS_MODE = "hls"
DEFAULT_GOGO_NORM_OR_HLS = GOGO_NORM_MODE
default_auto_download_site = PAHE
default_start_minimised = False
default_run_on_startup = False
default_on_captcha_switch_to = PAHE

error_logs_file_path = os.path.join(config_dir, "errors.log")
if not os.path.exists(error_logs_file_path):
    with open(error_logs_file_path, "w") as f:
        f.write("__-- FIRST BOOT --__\n")

logging.basicConfig(filename=error_logs_file_path, level=logging.ERROR,
                    format='%(asctime)s - %(levelname)s - %(message)s')


def log_error(error: str):
    logging.error(error)


def open_folder(folder_path: str) -> None:
    if sys.platform == "win32":
        os.startfile(folder_path)
    elif sys.platform == "linux":
        Popen(["xdg-open", folder_path])
    else:
        Popen(["open", folder_path])


downloads_folder = os.path.join(Path.home(), "Downloads")
if not os.path.isdir(downloads_folder):
    os.mkdir(downloads_folder)
downloads_folder = os.path.join(downloads_folder, "Anime")
if not os.path.isdir(downloads_folder):
    os.mkdir(downloads_folder)
default_download_folder_paths = [downloads_folder]

default_max_simutaneous_downloads = 2
default_gogo_browser = CHROME
default_allow_notifications = True
default_start_in_fullscreen = True
default_gogo_hls_mode = False

assets_path = os.path.join(base_directory, "assets")
def join_from_assets(file): return os.path.join(assets_path, file)


SENPWAI_ICON_PATH = join_from_assets("senpwai-icon.ico")
task_complete_icon_path = join_from_assets("task-complete.png")
loading_animation_path = join_from_assets("loading.gif")
sadge_piece_path = join_from_assets("sadge-piece.gif")
folder_icon_path = join_from_assets("folder.png")
mascots_folder_path = join_from_assets("mascots")
mascots_files = list(Path(mascots_folder_path).glob("*"))
random_mascot_icon_path = str(randomchoice(mascots_files))

bckg_images_path = join_from_assets("background-images")


def join_from_bckg_images(img_title): return os.path.join(
    bckg_images_path, img_title).replace("\\", "/")


search_window_bckg_image_path = join_from_bckg_images("search.jpg")
chosen_anime_window_bckg_image_path = join_from_bckg_images("chosen-anime.jpg")
settings_window_bckg_image_path = join_from_bckg_images("settings.jpg")
downlaod_window_bckg_image_path = join_from_bckg_images("downloads.png")
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
one_piece_audio_path = join_from_audio(f"one-piece-real-{randomchoice((1, 2))}.mp3")
kage_bunshin_audio_path = join_from_audio("kage-bunshin-no-jutsu.mp3")

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

KEY_SUB_OR_DUB = "sub_or_dub"
KEY_QUALITY = "quality"
KEY_DOWNLOAD_FOLDER_PATHS = "download_folder_paths"
KEY_MAX_SIMULTANEOUS_DOWNLOADS = "max_simultaneous_downloads"
KEY_GOGO_DEFAULT_BROWSER = "gogo_default_browser"
KEY_ALLOW_NOTIFICATIONS = "allow_notifcations"
deprecated_key_make_download_complete_notifications = "make_download_complete_notifications"
KEY_START_IN_FULLSCREEN = "start_in_fullscreen"
KEY_START_MINIMISED = "start_minimised"
KEY_RUN_ON_STARTUP = "run_on_startup"
KEY_GOGO_NORM_OR_HLS_MODE = "gogo_hls_mode"
KEY_TRACKED_ANIME = "tracked_anime"
KEY_AUTO_DOWNLOAD_SITE = "auto_download_site"
KEY_ON_CAPTCHA_SWITCH_TO = "on_captcha_switch_to"



amogus_easter_egg = "ඞ"
SETTINGS_TYPES = (str | int | bool | list[str])


def requires_admin_access(folder_path):
    try:
        temp_file = os.path.join(folder_path, 'temp.txt')
        open(temp_file, 'w').close()
        os.unlink(temp_file)
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


def validate_settings_json(settings_json: dict) -> dict:
    clean_settings = {}
    try:
        sub_or_dub = settings_json[KEY_SUB_OR_DUB]
        if sub_or_dub not in (SUB, DUB):
            raise KeyError
        clean_settings[KEY_SUB_OR_DUB] = sub_or_dub
    except KeyError:
        clean_settings[KEY_SUB_OR_DUB] = default_sub_or_dub
    try:
        quality = settings_json[KEY_QUALITY]
        if quality not in (Q_1080, Q_720, Q_480, Q_360):
            raise KeyError
        clean_settings[KEY_QUALITY] = quality
    except KeyError:
        clean_settings[KEY_QUALITY] = default_quality
    valid_folder_paths: list[str] = default_download_folder_paths
    try:
        # If a KeyError gets raised then set it to the default setting
        download_folder_paths = cast(
            list[str], settings_json[KEY_DOWNLOAD_FOLDER_PATHS])
        # If no  KeyError then validate the folders first before saving them, there's probably better ways to do this but I'm hungry af
        valid_folder_paths = [fix_qt_path_for_windows(path) for path in download_folder_paths if os.path.isdir(
            path) and not requires_admin_access(path) and path not in valid_folder_paths]
        if valid_folder_paths == []:
            valid_folder_paths = default_download_folder_paths
        raise KeyError
    except KeyError:
        clean_settings[KEY_DOWNLOAD_FOLDER_PATHS] = valid_folder_paths
    try:
        max_simultaneous_downloads = settings_json[KEY_MAX_SIMULTANEOUS_DOWNLOADS]
        if not isinstance(max_simultaneous_downloads, int) or max_simultaneous_downloads <= 0:
            raise KeyError
        clean_settings[KEY_MAX_SIMULTANEOUS_DOWNLOADS] = max_simultaneous_downloads
    except KeyError:
        clean_settings[KEY_MAX_SIMULTANEOUS_DOWNLOADS] = default_max_simutaneous_downloads
    try:
        gogo_default_browser = settings_json[KEY_GOGO_DEFAULT_BROWSER]
        if gogo_default_browser not in (CHROME, EDGE, FIREFOX):
            raise KeyError
        clean_settings[KEY_GOGO_DEFAULT_BROWSER] = gogo_default_browser
    except KeyError:
        clean_settings[KEY_GOGO_DEFAULT_BROWSER] = default_gogo_browser
    try:
        try:
            allow_notifications = settings_json[KEY_ALLOW_NOTIFICATIONS]
        except KeyError:
            allow_notifications = settings_json[deprecated_key_make_download_complete_notifications]
        if not isinstance(allow_notifications, bool):
            raise KeyError
        clean_settings[KEY_ALLOW_NOTIFICATIONS] = allow_notifications
    except KeyError:
        clean_settings[KEY_ALLOW_NOTIFICATIONS] = default_allow_notifications
    try:
        start_in_fullscreen = settings_json[KEY_START_IN_FULLSCREEN]
        if not isinstance(start_in_fullscreen, bool):
            raise KeyError
        clean_settings[KEY_START_IN_FULLSCREEN] = start_in_fullscreen
    except KeyError:
        clean_settings[KEY_START_IN_FULLSCREEN] = default_start_in_fullscreen
    try:
        gogo_norm_or_hls_mode = settings_json[KEY_GOGO_NORM_OR_HLS_MODE]
        if gogo_norm_or_hls_mode not in (GOGO_NORM_MODE, GOGO_HLS_MODE):
            raise KeyError
        clean_settings[KEY_GOGO_NORM_OR_HLS_MODE] = gogo_norm_or_hls_mode
    except KeyError:
        clean_settings[KEY_GOGO_NORM_OR_HLS_MODE] = DEFAULT_GOGO_NORM_OR_HLS
    try:
        tracked_anime = cast(
            list[str], list(set(settings_json[KEY_TRACKED_ANIME])))
        if not isinstance(tracked_anime, list):
            raise KeyError
        valid = []
        for anime in tracked_anime:
            if isinstance(anime, str):
                valid.append(anime)
        clean_settings[KEY_TRACKED_ANIME] = valid
    except KeyError:
        clean_settings[KEY_TRACKED_ANIME] = []
    try:
        pahe_or_gogo_auto = settings_json[KEY_AUTO_DOWNLOAD_SITE]
        if pahe_or_gogo_auto not in (PAHE, GOGO):
            raise KeyError
        clean_settings[KEY_AUTO_DOWNLOAD_SITE] = pahe_or_gogo_auto
    except KeyError:
        clean_settings[KEY_AUTO_DOWNLOAD_SITE] = default_auto_download_site
    try:
        start_minimsed = settings_json[KEY_START_MINIMISED]
        if not isinstance(start_minimsed, bool):
            raise KeyError
        clean_settings[KEY_START_MINIMISED] = start_minimsed
    except KeyError:
        clean_settings[KEY_START_MINIMISED] = default_start_minimised
    try:
        run_on_startup = settings_json[KEY_RUN_ON_STARTUP]
        if not isinstance(run_on_startup, bool):
            raise KeyError
        clean_settings[KEY_RUN_ON_STARTUP] = run_on_startup
    except KeyError:
        clean_settings[KEY_RUN_ON_STARTUP]  = default_run_on_startup

    try:
        oncaptcha = settings_json[KEY_ON_CAPTCHA_SWITCH_TO]
        if oncaptcha not in (PAHE, GOGO_HLS_MODE):
            raise KeyError
        clean_settings[KEY_ON_CAPTCHA_SWITCH_TO] = oncaptcha
    except KeyError:
        clean_settings[KEY_ON_CAPTCHA_SWITCH_TO] = default_on_captcha_switch_to

    return clean_settings


join_to_settings = lambda x: os.path.join(x, "settings.json")
SETTINGS_JSON_PATH = join_to_settings(config_dir)
def configure_settings() -> dict[str, SETTINGS_TYPES]:
    settings = {}
    s_path = SETTINGS_JSON_PATH
    if sys.platform == "win32":
        deprecated_settings_json_path = join_to_settings(os.path.join(base_config_dir, APP_NAME))
        if not os.path.isfile(s_path) and os.path.isfile(deprecated_settings_json_path):
            s_path = deprecated_settings_json_path

    if os.path.exists(s_path):
        with open(s_path, "r") as f:
            try:
                settings = cast(dict, json.load(f))
            except json.decoder.JSONDecodeError:
                pass
    s_path = SETTINGS_JSON_PATH
    with open(s_path, "w") as f:
        validated_settings = validate_settings_json(settings)
        json.dump(validated_settings, f, indent=4)
        return validated_settings


settings = configure_settings()
