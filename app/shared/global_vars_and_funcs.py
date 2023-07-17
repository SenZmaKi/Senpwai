import os
import sys
from random import randint
from appdirs import user_config_dir
from pathlib import Path
from scrapers.gogo import edge_name, chrome_name, firefox_name
from PyQt6.QtWidgets import QSizePolicy
import json
from typing import cast

if getattr(sys, 'frozen', False):
    base_directory = os.path.dirname(sys.executable)
else:
    base_directory = os.path.dirname(os.path.realpath('__file__'))

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
if not os.path.isdir(folder):
    os.mkdir(folder)
folder = os.path.join(folder, "Anime")
if not os.path.isdir(folder):
    os.mkdir(folder)
default_download_folder_paths = [folder]

default_max_simutaneous_downloads = 2
default_gogo_browser = edge_name
default_make_download_complete_notification = True

assets_path = os.path.join(base_directory, "assets")

senpwai_icon_path = os.path.abspath("Senpwai_icon.ico")
bckg_images_path = os.path.join(assets_path, "background-images")
bckg_images = list(Path(bckg_images_path).glob("*"))
bckg_image_path = (
    str(bckg_images[randint(0, len(bckg_images)-1)])).replace("\\", "/")
loading_animation_path = os.path.join(assets_path, "loading.gif")
sadge_piece_path = os.path.join(assets_path, "sadge-piece.gif")
folder_icon_path = os.path.join(assets_path, "folder.png")
pause_icon_path = os.path.join(assets_path, "pause.png")
resume_icon_path = os.path.join(assets_path, "resume.png")
cancel_icon_path = os.path.join(assets_path, "cancel.png")
download_complete_icon_path = os.path.join(
    assets_path, "download-complete.png")
chopper_crying_path = os.path.join(
    assets_path, "chopper-crying.png").replace("\\", "/")
zero_two_peeping_path = os.path.join(assets_path, "zero-two-peeping.png")

pahe_normal_color = "#FFC300"
pahe_hover_color = "#FFD700"
pahe_pressed_color = "#FFE900"

gogo_normal_color = "#00FF00"
gogo_hover_color = "#60FF00"
gogo_pressed_color = "#99FF00"

third_normal_color = "#E80000"
third_hover_color = "#FF0202"
third_pressed_color = "#FF1C1C"

key_sub_or_dub = "sub_or_dub"
key_quality = "quality"
key_download_folder_paths = "download_folder_paths"
key_max_simulataneous_downloads = "max_simultaneous_downloads"
key_gogo_default_browser = "gogo_default_browser"
key_make_download_complete_notification = "make_download_complete_notification"

config_and_settings_folder_path = os.path.join(user_config_dir(), app_name)
if not os.path.isdir(config_and_settings_folder_path):
    os.mkdir(config_and_settings_folder_path)
settings_file_path = os.path.join(
    config_and_settings_folder_path, "settings.json")

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
            path) and not requires_admin_access(path)]
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
        if gogo_default_browser not in (chrome_name, edge_name, firefox_name):
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
