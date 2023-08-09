import os
import sys
from random import randint
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

app_name = "Senpwai"
version = "2.0.0"
config_dir = os.path.join(user_config_dir(), app_name)
if not os.path.isdir(config_dir): 
    os.makedirs(config_dir)
github_repo_url = "https://github.com/SenZmaKi/Senpwai"
github_api_releases_entry_point = "https://api.github.com/repos/SenZmaKi/Senpwai/releases"
sen_anilist_id = 5363369
anilist_api_entrypoint = 'https://graphql.anilist.co'
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

error_logs_file_path = os.path.join(config_dir, "error-logs.txt")
if not os.path.exists(error_logs_file_path):
    with open(error_logs_file_path, "w") as f:
        f.write("__--FIRST BOOT--__\n")
    
logging.basicConfig(filename=error_logs_file_path, level=logging.ERROR, format='%(asctime)s - %(levelname)s - %(message)s')
def log_error(error: str):
    logging.error(error)

def open_folder(folder_path: str):
    if sys.platform == "win32": return os.startfile(folder_path)
    elif sys.platform == "linux": return Popen(["xdg-open", folder_path]) 
    else: return Popen(["open", folder_path])

downloads_folder = os.path.join(Path.home(), "Downloads")
if not os.path.isdir(downloads_folder):
    os.mkdir(downloads_folder)
downloads_folder = os.path.join(downloads_folder, "Anime")
if not os.path.isdir(downloads_folder):
    os.mkdir(downloads_folder)
default_download_folder_paths = [downloads_folder]

default_max_simutaneous_downloads = 2
default_gogo_browser = CHROME
default_make_download_complete_notification = True
default_start_in_fullscreen = True

assets_path = os.path.join(base_directory, "assets")
def join_from_assets(file): return os.path.join(assets_path, file)


senpwai_icon_path = join_from_assets("senpwai-icon.ico")
loading_animation_path = join_from_assets("loading.gif")
sadge_piece_path = join_from_assets("sadge-piece.gif")
folder_icon_path = join_from_assets("folder.png")
mascots_folder_path = join_from_assets("mascots")
mascots_files = list(Path(mascots_folder_path).glob("*"))
random_mascot_icon_path = str(mascots_files[randint(0, len(mascots_files)-1)])

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
download_complete_icon_path = join_from_download_icons("download-complete.png")

audio_folder_path = join_from_assets("audio")


def join_from_audio(audio_path): return os.path.join(
    audio_folder_path, audio_path
)


gigachad_audio_path = join_from_audio("gigachad.mp3")
hentai_addict_audio_path = join_from_audio("aqua-crying.mp3")
morbius_audio_path = join_from_audio("morbin-time.mp3")
sen_favourite_audio_path = join_from_audio("sen-favourite.wav")
one_piece_audio_path = join_from_audio(f"one-piece-real-{randint(1, 2)}.mp3")

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

pahe_normal_color = "#FFC300"
pahe_hover_color = "#FFD700"
pahe_pressed_color = "#FFE900"

gogo_normal_color = "#00FF00"
gogo_hover_color = "#60FF00"
gogo_pressed_color = "#99FF00"

red_normal_color = "#E80000"
red_hover_color = "#FF0202"
red_pressed_color = "#FF1C1C"

key_sub_or_dub = "sub_or_dub"
key_quality = "quality"
key_download_folder_paths = "download_folder_paths"
key_max_simulataneous_downloads = "max_simultaneous_downloads"
key_gogo_default_browser = "gogo_default_browser"
key_make_download_complete_notification = "make_download_complete_notification"
key_start_in_fullscreen = "start_in_fullscreen"

settings_file_path = os.path.join(
    config_dir, "settings.json")

amogus_easter_egg = "ඞ"
AllowedSettingsTypes = (str | int | bool | list[str])


def requires_admin_access(folder_path):
    try:
        temp_file = os.path.join(folder_path, 'temp.txt')
        open(temp_file, 'w').close()
        os.remove(temp_file)
        return False
    except PermissionError:
        return True


def set_minimum_size_policy(object):
    object.setSizePolicy(QSizePolicy.Policy.Minimum,
                         QSizePolicy.Policy.Minimum)
    object.setFixedSize(object.sizeHint())


def validate_settings_json(settings_json: dict) -> dict:
    clean_settings = {}
    try:
        sub_or_dub = settings_json[key_sub_or_dub]
        if sub_or_dub not in (sub, dub):
            raise KeyError
        clean_settings[key_sub_or_dub] = sub_or_dub
    except KeyError:
        clean_settings[key_sub_or_dub] = default_sub_or_dub
    try:
        quality = settings_json[key_quality]
        if quality not in (q_1080, q_720, q_480, q_360):
            raise KeyError
        clean_settings[key_quality] = quality
    except KeyError:
        clean_settings[key_quality] = default_quality
    valid_folder_paths: list[str] = default_download_folder_paths
    try:
        download_folder_paths = settings_json[key_download_folder_paths]
        valid_folder_paths = [path for path in download_folder_paths if os.path.isdir(
            path) and not requires_admin_access(path) and path not in valid_folder_paths]
        if len(valid_folder_paths) == 0:
            valid_folder_paths = default_download_folder_paths
        raise KeyError
    except KeyError:
        clean_settings[key_download_folder_paths] = valid_folder_paths
    try:
        max_simultaneous_downloads = settings_json[key_max_simulataneous_downloads]
        if not isinstance(max_simultaneous_downloads, int) or max_simultaneous_downloads <= 0:
            raise KeyError
        clean_settings[key_max_simulataneous_downloads] = max_simultaneous_downloads
    except KeyError:
        clean_settings[key_max_simulataneous_downloads] = default_max_simutaneous_downloads
    try:
        gogo_default_browser = settings_json[key_gogo_default_browser]
        if gogo_default_browser not in (CHROME, EDGE, FIREFOX):
            raise KeyError
        clean_settings[key_gogo_default_browser] = gogo_default_browser
    except KeyError:
        clean_settings[key_gogo_default_browser] = default_gogo_browser
    try:
        make_download_complete_notification = settings_json[key_make_download_complete_notification]
        if not isinstance(make_download_complete_notification, bool):
            raise KeyError
        clean_settings[key_make_download_complete_notification] = make_download_complete_notification
    except KeyError:
        clean_settings[key_make_download_complete_notification] = default_make_download_complete_notification
    try:
        start_in_fullscreen = settings_json[key_start_in_fullscreen]
        if not isinstance(start_in_fullscreen, bool):
            raise KeyError
        clean_settings[key_start_in_fullscreen] = start_in_fullscreen
    except KeyError:
        clean_settings[key_start_in_fullscreen] = default_start_in_fullscreen

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
