import os
import random
import sys
from datetime import datetime
from pathlib import Path
from random import choice as random_choice
from subprocess import Popen
from types import TracebackType
import logging

IS_PIP_INSTALL = False
if getattr(sys, "frozen", False):
    # Senpwai/senpwai.exe
    ROOT_DIRECTORY = os.path.dirname(sys.executable)
    IS_EXECUTABLE = True
else:
    # senpwai/utils/static_utils.py
    ROOT_DIRECTORY = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
    if os.path.dirname(ROOT_DIRECTORY).endswith("site-packages"):
        IS_PIP_INSTALL = True
    IS_EXECUTABLE = False

APP_NAME = "Senpwai"
APP_NAME_LOWER = APP_NAME.lower()
APP_EXE_PATH = os.path.join(ROOT_DIRECTORY, f"{APP_NAME_LOWER}.exe")
VERSION = "2.1.0"
DESCRIPTION = "A desktop app for tracking and batch downloading anime"

date = datetime.today()
IS_CHRISTMAS = True if date.month == 12 and date.day >= 20 else False


def log_exception(e: Exception):
    custom_exception_handler(type(e), e, e.__traceback__)


def custom_exception_handler(
        type_: type[BaseException], value: BaseException, traceback: TracebackType | None
):
    logging.error(f"Unhandled exception: {type_.__name__}: {value}")
    sys.__excepthook__(type_, value, traceback)


def try_deleting_safely(path: str):
    if os.path.isfile(path):
        try:
            os.unlink(path)
        except PermissionError:
            pass


def generate_windows_setup_file_titles(app_name: str) -> tuple[str, str]:
    return (f"{app_name}-setup.exe", f"{app_name}-setup.msi")


for setup in generate_windows_setup_file_titles(APP_NAME):
    try_deleting_safely(setup)

GITHUB_REPO_URL = "https://github.com/SenZmaKi/Senpwai"
GITHUB_API_LATEST_RELEASE_ENDPOINT = (
    "https://api.github.com/repos/SenZmaKi/Senpwai/releases/latest"
)
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

GOGO_NORMAL_COLOR = "#00FF00"
GOGO_HOVER_COLOR = "#60FF00"
GOGO_PRESSED_COLOR = "#99FF00"

RED_NORMAL_COLOR = "#E80000"
RED_HOVER_COLOR = "#FF0202"
RED_PRESSED_COLOR = "#FF1C1C"

MINIMISED_TO_TRAY_ARG = "--minimised_to_tray"

AMOGUS_EASTER_EGG = "ඞ"


def open_folder(folder_path: str) -> None:
    if sys.platform == "win32":
        os.startfile(folder_path)
    elif sys.platform == "linux":
        Popen(["xdg-open", folder_path])
    else:
        Popen(["open", folder_path])


def requires_admin_access(folder_path):
    try:
        temp_file = os.path.join(folder_path, "temp.txt")
        open(temp_file, "w").close()
        try_deleting_safely(temp_file)
        return False
    except PermissionError:
        return True


# Paths


assets_path = os.path.join(ROOT_DIRECTORY, "assets")


def join_from_assets(file):
    return os.path.join(assets_path, file)


misc_path = os.path.join(assets_path, "misc")


def join_from_misc(file):
    return os.path.join(misc_path, file)


# Define the paths for the loading screens
loading_screens = [
    join_from_misc("loading.gif"),
    join_from_misc("loading_1.gif"),
    join_from_misc("loading_2.gif")
]

SENPWAI_ICON_PATH = join_from_misc("senpwai-icon.ico")
TASK_COMPLETE_ICON_PATH = join_from_misc("task-complete.png")
LOADING_ANIMATION_PATH = random.choice(loading_screens)
SADGE_PIECE_PATH = join_from_misc("sadge-piece.gif")
FOLDER_ICON_PATH = join_from_misc("folder.png")

mascots_folder_path = join_from_assets("mascots")
mascots_files = list(Path(mascots_folder_path).glob("*"))
RANDOM_MACOT_ICON_PATH = (
    # Incase Senpcli was installed without Senpwai
    str(random_choice(mascots_files)) if mascots_files else ""
)

bckg_images_path = join_from_assets("background-images")


def join_from_bckg_images(
        img_title,
):  # fix windows path for Qt cause it only accepts forward slashes
    return os.path.join(bckg_images_path, img_title).replace("\\", "/")


s = "christmas.jpg" if IS_CHRISTMAS else "search.jpg"
SEARCH_WINDOW_BCKG_IMAGE_PATH = join_from_bckg_images(s)
CHOSEN_ANIME_WINDOW_BCKG_IMAGE_PATH = join_from_bckg_images("chosen-anime.jpg")
SETTINGS_WINDOW_BCKG_IMAGE_PATH = join_from_bckg_images("settings.jpg")
DOWNLOAD_WINDOW_BCKG_IMAGE_PATH = join_from_bckg_images("downloads.png")
CHOPPER_CRYING_PATH = join_from_bckg_images("chopper-crying.png")
ABOUT_BCKG_IMAGE_PATH = join_from_bckg_images("about.jpg")
UPDATE_BCKG_IMAGE_PATH = join_from_bckg_images("update.jpg")

link_icons_folder_path = join_from_assets("link-icons")


def join_from_link_icons(icon_path):
    return os.path.join(link_icons_folder_path, icon_path)


GITHUB_SPONSORS_ICON_PATH = join_from_link_icons("github-sponsors.svg")
GITHUB_ICON_PATH = join_from_link_icons("github.png")
PATREON_ICON_PATH = join_from_link_icons("patreon.png")
REDDIT_ICON_PATH = join_from_link_icons("reddit.png")
DISCORD_ICON_PATH = join_from_link_icons("discord.png")

download_icons_folder_path = join_from_assets("download-icons")


def join_from_download_icons(icon_path):
    return os.path.join(download_icons_folder_path, icon_path)


PAUSE_ICON_PATH = join_from_download_icons("pause.png")
RESUME_ICON_PATH = join_from_download_icons("resume.png")
CANCEL_ICON_PATH = join_from_download_icons("cancel.png")
REMOVE_FROM_QUEUE_ICON_PATH = join_from_download_icons("trash.png")
MOVE_UP_QUEUE_ICON_PATH = join_from_download_icons("up.png")
MOVE_DOWN_QUEUE_ICON_PATH = join_from_download_icons("down.png")

audio_folder_path = join_from_assets("audio")


def join_from_audio(audio_path):
    return os.path.join(audio_folder_path, audio_path)


GIGACHAD_AUDIO_PATH = join_from_audio("gigachad.mp3")
HENTAI_ADDICT_AUDIO_PATH = join_from_audio("aqua-crying.mp3")
MORBIUS_AUDIO_PATH = join_from_audio("morbin-time.mp3")
SEN_FAVOURITE_AUDIO_PATH = join_from_audio("sen-favourite.wav")
SEN_FAVOURITE_AUDIO_PATH = join_from_audio(
    f"one-piece-real-{random_choice((1, 2))}.mp3"
)
KAGE_BUNSHIN_AUDIO_PATH = join_from_audio("kage-bunshin-no-jutsu.mp3")
BUNSHIN_POOF_AUDIO_PATH = join_from_audio("bunshin-poof.mp3")
ZA_WARUDO_AUDIO_PATH = join_from_audio("za-warudo.mp3")
TOKI_WA_UGOKI_DASU_AUDIO_PATH = join_from_audio("toki-wa-ugoki-dasu.mp3")
WHAT_DA_HELL_AUDIO_PATH = join_from_audio("what-da-hell.mp3")
MERRY_CHRISMASU_AUDIO_PATH = join_from_audio("merry-chrismasu.mp3")

reviewer_profile_pics_folder_path = join_from_assets("reviewer-profile-pics")


def join_from_reviewer(icon_path):
    return os.path.join(reviewer_profile_pics_folder_path, icon_path)


SEN_ICON_PATH = join_from_reviewer("sen.png")
MORBIUS_IS_PEAK_ICON_PATH = join_from_reviewer("morbius-is-peak.png")
HENTAI_ADDICT_ICON_PATH = join_from_reviewer("hentai-addict.png")

navigation_bar_icons_folder_path = join_from_assets("navigation-bar-icons")


def join_from_navbar(icon_path):
    return os.path.join(navigation_bar_icons_folder_path, icon_path)


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
}
L_ANIME = {
    "tokyo ghoul",
    "sword art",
    "boku no pico",
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
