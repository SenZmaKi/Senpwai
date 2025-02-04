import logging
import os
import shutil
import sys
from datetime import datetime
from functools import cache
from pathlib import Path
import random
from subprocess import Popen
from tempfile import gettempdir
import traceback
from types import TracebackType


def custom_exception_handler(
    type_: type[BaseException],
    value: BaseException,
    tb: TracebackType | None,
    manual_log=False,
) -> None:
    h = "Exception" if manual_log else "Unhandled exception"
    exception_str = "".join(traceback.format_exception(type_, value, tb))
    logging.error(f"{h}: {exception_str}{'-' * 125}\n")
    sys.__excepthook__(type_, value, tb)


sys.excepthook = custom_exception_handler

APP_NAME = "Senpwai"
APP_NAME_LOWER = "senpwai"
VERSION = "2.1.15"
DESCRIPTION = "A desktop app for tracking and batch downloading anime"

IS_PIP_INSTALL = False
APP_EXE_PATH = ""


class OS:
    is_android = "ANDROID_ROOT" in os.environ
    is_windows = sys.platform == "win32" and not is_android
    is_linux = sys.platform == "linux" and not is_android
    is_mac = sys.platform == "darwin" and not is_android


if getattr(sys, "frozen", False):
    # C:\Users\Username\AppData\Local\Programs\Senpwai
    ROOT_DIRECTORY = os.path.dirname(sys.executable)
    APP_EXE_PATH = sys.executable
    IS_EXECUTABLE = True
else:
    # C:\Users\Username\AppData\Local\Programs\Python\Python311\Lib\site-packages\senpwai
    ROOT_DIRECTORY = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
    # C:\Users\Username\AppData\Local\Programs\Python\Python311\Lib\site-packages
    maybe_site_packages = os.path.dirname(ROOT_DIRECTORY)
    if os.path.basename(maybe_site_packages) == "site-packages":
        IS_PIP_INSTALL = True
        if OS.is_windows:
            # C:\Users\Username\AppData\Local\Programs\Python\Python311\Scripts\senpwai.exe
            maybe_app_exe_path = os.path.join(
                os.path.dirname(os.path.dirname(maybe_site_packages)),
                "Scripts",
                f"{APP_NAME_LOWER}.exe",
            )
            if os.path.isfile(maybe_app_exe_path):
                APP_EXE_PATH = maybe_app_exe_path
    IS_EXECUTABLE = False
APP_EXE_ROOT_DIRECTORY = os.path.dirname(APP_EXE_PATH) if APP_EXE_PATH else ""
date = datetime.today()
IS_CHRISTMAS = date.month == 12 and date.day >= 20
IS_VALENTINES = date.month == 2 and date.day == 14


def log_exception(exception: Exception) -> None:
    custom_exception_handler(
        type(exception), exception, exception.__traceback__, manual_log=True
    )


def try_deleting(path: str, is_dir=False) -> None:
    try:
        if is_dir and os.path.isdir(path):
            shutil.rmtree(path)
        elif not is_dir and os.path.isfile(path):
            os.unlink(path)
    except PermissionError:
        pass


def windows_setup_file_titles(app_name: str) -> tuple[str, str]:
    return (f"{app_name}-setup.exe", f"{app_name}-setup.msi")


# TODO: DEPRECATION Remove in version 2.1.15+ since we download updates to temp
for title in windows_setup_file_titles(APP_NAME):
    try_deleting(os.path.join(ROOT_DIRECTORY, title))
for title in windows_setup_file_titles("Senpcli"):
    try_deleting(os.path.join(ROOT_DIRECTORY, title))

GITHUB_REPO_URL = "https://github.com/SenZmaKi/Senpwai"
GITHUB_API_LATEST_RELEASE_ENDPOINT = (
    "https://api.github.com/repos/SenZmaKi/Senpwai/releases/latest"
)
DISCORD_INVITE_LINK = "https://discord.gg/e9UxkuyDX2"
SEN_ANILIST_ID = 5363369
ANILIST_API_ENTRYPOINY = "https://graphql.anilist.co"
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
PAHE_NORMAL_COLOR = "#FFC300"
PAHE_HOVER_COLOR = "#FFD700"
PAHE_PRESSED_COLOR = "#FFE900"
PAHE_EXTRA_COLOR = "orange"

GOGO_NORMAL_COLOR = "#00FF00"
GOGO_HOVER_COLOR = "#60FF00"
GOGO_PRESSED_COLOR = "#99FF00"

RED_NORMAL_COLOR = "#E80000"
RED_HOVER_COLOR = "#FF0202"
RED_PRESSED_COLOR = "#FF1C1C"

MINIMISED_TO_TRAY_ARG = "--minimised_to_tray"

AMOGUS_EASTER_EGG = "ඞ"


def open_folder(folder_path: str) -> None:
    if OS.is_windows:
        os.startfile(folder_path)
    elif OS.is_linux:
        Popen(["xdg-open", folder_path])
    else:
        Popen(["open", folder_path])


@cache
def senpwai_tempdir() -> str:
    tempdir = os.path.join(gettempdir(), "Senpwai")
    if not os.path.isdir(tempdir):
        os.mkdir(tempdir)
    return tempdir


def requires_admin_access(folder_path: str) -> bool:
    try:
        temp_file = os.path.join(folder_path, "senpwai_admin_test_temp")
        open(temp_file, "w").close()
        os.unlink(temp_file)
        return False
    except PermissionError:
        return True


def fix_qt_path_for_windows(path: str) -> str:
    if OS.is_windows:
        return path.replace("/", "\\")
    return path


def fix_windows_path_for_qt(path: str) -> str:
    if OS.is_windows:
        return path.replace("\\", "/")
    return path


# Paths


assets_path = os.path.join(ROOT_DIRECTORY, "assets")


def join_from_assets(dir_name: str) -> str:
    return os.path.join(assets_path, dir_name)


misc_path = join_from_assets("misc")


def join_from_misc(file_name: str) -> str:
    return os.path.join(misc_path, file_name)


SENPWAI_ICON_PATH = join_from_misc("senpwai-icon.ico")
TASK_COMPLETE_ICON_PATH = join_from_misc("task-complete.png")
LOADING_ANIMATION_PATH = join_from_misc("loading.gif")
ANIME_NOT_FOUND_PATH = join_from_misc("anime-not-found.gif")
FOLDER_ICON_PATH = join_from_misc("folder.png")

mascots_folder_path = join_from_assets("mascots")
mascots_files = list(Path(mascots_folder_path).glob("*"))
RANDOM_MACOT_ICON_PATH = (
    # Incase Senpcli was installed without Senpwai
    str(random.choice(mascots_files)) if mascots_files else ""
)


bckg_images_path = join_from_assets("background-images")


def join_from_bckg_images(img_name: str) -> str:
    return fix_windows_path_for_qt(os.path.join(bckg_images_path, img_name))


if IS_CHRISTMAS:
    search_img = "christmas.jpg"
elif IS_VALENTINES:
    search_img = "valentines.jpg"
else:
    search_img = "search.jpg"
SEARCH_WINDOW_BCKG_IMAGE_PATH = join_from_bckg_images(search_img)
CHOSEN_ANIME_WINDOW_BCKG_IMAGE_PATH = join_from_bckg_images("chosen-anime.jpg")
SETTINGS_WINDOW_BCKG_IMAGE_PATH = join_from_bckg_images("settings.jpg")
DOWNLOAD_WINDOW_BCKG_IMAGE_PATH = join_from_bckg_images("downloads.png")
CHOPPER_CRYING_PATH = join_from_bckg_images("chopper-crying.png")
ABOUT_BCKG_IMAGE_PATH = join_from_bckg_images("about.jpg")
UPDATE_BCKG_IMAGE_PATH = join_from_bckg_images("update.jpg")

link_icons_folder_path = join_from_assets("link-icons")


def join_from_link_icons(icon_name: str) -> str:
    return os.path.join(link_icons_folder_path, icon_name)


GITHUB_SPONSORS_ICON_PATH = join_from_link_icons("github-sponsors.svg")
GITHUB_ICON_PATH = join_from_link_icons("github.png")
PATREON_ICON_PATH = join_from_link_icons("patreon.png")
REDDIT_ICON_PATH = join_from_link_icons("reddit.png")
DISCORD_ICON_PATH = join_from_link_icons("discord.png")

download_icons_folder_path = join_from_assets("download-icons")


def join_from_download_icons(icon_name: str) -> str:
    return os.path.join(download_icons_folder_path, icon_name)


PAUSE_ICON_PATH = join_from_download_icons("pause.png")
RESUME_ICON_PATH = join_from_download_icons("resume.png")
CANCEL_ICON_PATH = join_from_download_icons("cancel.png")
REMOVE_FROM_QUEUE_ICON_PATH = join_from_download_icons("trash.png")
MOVE_UP_QUEUE_ICON_PATH = join_from_download_icons("up.png")
MOVE_DOWN_QUEUE_ICON_PATH = join_from_download_icons("down.png")

audio_folder_path = join_from_assets("audio")


def join_from_audio(audio_name: str) -> str:
    return os.path.join(audio_folder_path, audio_name)


GIGACHAD_AUDIO_PATH = join_from_audio("gigachad.mp3")
HENTAI_ADDICT_AUDIO_PATH = join_from_audio("aqua-crying.mp3")
MORBIUS_AUDIO_PATH = join_from_audio("morbin-time.mp3")
SEN_FAVOURITE_AUDIO_PATH = join_from_audio("sen-favourite.wav")
ONE_PIECE_REAL_AUDIO_PATH = join_from_audio(
    f"one-piece-real-{random.choice((1, 2))}.mp3"
)
KAGE_BUNSHIN_AUDIO_PATH = join_from_audio("kage-bunshin-no-jutsu.mp3")
BUNSHIN_POOF_AUDIO_PATH = join_from_audio("bunshin-poof.mp3")
ZA_WARUDO_AUDIO_PATH = join_from_audio("za-warudo.mp3")
TOKI_WA_UGOKI_DASU_AUDIO_PATH = join_from_audio("toki-wa-ugoki-dasu.mp3")
WHAT_DA_HELL_AUDIO_PATH = join_from_audio("what-da-hell.mp3")
MERRY_CHRISMASU_AUDIO_PATH = join_from_audio("merry-chrismasu.mp3")

reviewer_profile_pics_folder_path = join_from_assets("reviewer-profile-pics")


def join_from_reviewers(icon_name: str) -> str:
    return os.path.join(reviewer_profile_pics_folder_path, icon_name)


SEN_ICON_PATH = join_from_reviewers("sen.png")
MORBIUS_IS_PEAK_ICON_PATH = join_from_reviewers("morbius-is-peak.png")
HENTAI_ADDICT_ICON_PATH = join_from_reviewers("hentai-addict.png")

navigation_bar_icons_folder_path = join_from_assets("navigation-bar-icons")


def join_from_navbar(icon_name: str) -> str:
    return os.path.join(navigation_bar_icons_folder_path, icon_name)


SEARCH_ICON_PATH = join_from_navbar("search.png")
DOWNLOADS_ICON_PATH = join_from_navbar("downloads.png")
SETTINGS_ICON_PATH = join_from_navbar("settings.png")
ABOUT_ICON_PATH = join_from_navbar("about.png")
UPDATE_ICON_PATH = join_from_navbar("update.png")

# Anime eastereggs

W_ANIME = {
    "vermeil",
    "golden kamuy",
    "goblin slayer",
    "hajime",
    "megalobox",
    "kengan ashura",
    "kengan asura",
    "kengan",
    "golden boy",
    "valkyrie",
    "dr stone",
    "dr. stone",
    "death parade",
    "death note",
    "code geass",
    "attack on titan",
    "kaiji",
    "shingeki no kyojin",
    "daily lives",
    "danshi koukosei",
    "daily lives of highshool boys",
    "detroit metal",
    "arakawa",
    "haikyuu",
    "kaguya",
    "chio",
    "asobi asobase",
    "prison school",
    "grand blue",
    "mob psycho",
    "to your eternity",
    "fire force",
    "mieruko",
    "fumetsu",
    "frieren",
    "dandadan",
}
L_ANIME = {
    "tokyo ghoul",
    "sword art",
    "boku no pico",
    "fullmetal",
    "full metal",
    "fmab",
    "fairy tail",
    "dragon ball",
    "hunter x hunter",
    "hunter hunter",
    "platinum end",
    "record of ragnarok",
    "7 deadly sins",
    "seven deadly sins",
    "apothecary",
}
