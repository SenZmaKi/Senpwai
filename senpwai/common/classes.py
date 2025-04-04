import json
import logging
import math
import os
import re
from pathlib import Path
from typing import NamedTuple, TypedDict, cast

import anitopy
from appdirs import user_config_dir

from senpwai.common.scraper import (
    CLIENT,
    IBYTES_TO_MBS_DIVISOR,
    AnimeMetadata,
    sanitise_title,
)
from senpwai.common.static import (
    APP_NAME,
    GOGO,
    GOGO_HLS_MODE,
    GOGO_NORM_MODE,
    PAHE,
    Q_720,
    SUB,
    VERSION,
    windows_setup_file_titles,
)
from senpwai.scrapers import gogo, pahe

VERSION_REGEX = re.compile(r"(\d+(\.\d+)*)")


def get_max_part_size(download_size: int, site: str, is_hls_download: bool) -> int:
    if (
        is_hls_download
        or SETTINGS.max_part_size_mbs <= 0
        or download_size <= SETTINGS.max_part_size_bytes()
    ):
        return 0
    return (
        math.ceil(download_size / pahe.MAX_SIMULTANEOUS_PART_DOWNLOADS)
        if site == pahe.PAHE
        else SETTINGS.max_part_size_bytes()
    )


class UpdateInfo(NamedTuple):
    is_update_available: bool
    download_url: str
    file_name: str
    release_notes: str


def update_available(
    latest_release_api_url: str, app_name: str, curr_version: str
) -> UpdateInfo:
    response = CLIENT.get(latest_release_api_url)
    if not response.ok:
        raise Exception(
            f"Failed to fetch latest release info\nURL: {latest_release_api_url}\nResponse Status Code: {response.status_code}\nResponse Text {response.text}"
        )
    latest_version_json = response.json()
    latest_version_tag = latest_version_json["tag_name"]
    match = cast(re.Match, VERSION_REGEX.search(latest_version_tag))
    latest_version = match.group(1)
    download_url: str = ""
    file_name = ""
    # NOTE: Update this logic if you ever officially release on Linux or Mac
    target_file_names = windows_setup_file_titles(app_name)
    is_update_available = True if latest_version != curr_version else False
    if is_update_available:
        for asset in latest_version_json["assets"]:
            matched_file_name = None
            for target_file_name in target_file_names:
                if asset["name"] == target_file_name:
                    matched_file_name = target_file_name
                    break
            if matched_file_name is not None:
                download_url, file_name = (
                    asset["browser_download_url"],
                    matched_file_name,
                )
                break
    release_notes: str = latest_version_json["body"]
    return UpdateInfo(is_update_available, download_url, file_name, release_notes)


class CustomAnimeFolder(TypedDict):
    anime_title: str
    folder: str


class Settings:
    def __init__(self) -> None:
        self.config_dir = self.setup_config_dir()
        self.settings_json_path = os.path.join(self.config_dir, "settings.json")
        # NOTE: Everytime you add a new class member that isn't a setting, make sure to add it here
        self.excluded_in_save = (
            "config_dir",
            "settings_json_path",
            "is_update_install",
            "excluded_in_save",
        )
        # Default settings
        # Only these settings will be saved to settings.json
        self.sub_or_dub = SUB
        self.quality = Q_720
        self.download_folder_paths = self.setup_default_download_folder()
        self.max_simultaneous_downloads = 2
        self.font_family = "Berlin Sans FB Demi"
        self.allow_notifications = True
        self.start_maximized = True
        self.run_on_startup = False
        self.gogo_mode = GOGO_NORM_MODE
        self.tracked_anime: list[str] = []
        self.tracking_site = PAHE
        self.tracking_interval_hrs = 24
        self.version = VERSION
        self.close_minimize_to_tray = False
        self.max_part_size_mbs = 0
        self.custom_anime_folders: list[CustomAnimeFolder] = []

        self.load_settings()
        self.save_settings()
        self.setup_logger()
        self.is_update_install = self.version != VERSION
        if self.is_update_install:
            self.version = VERSION
            self.save_settings()

    def setup_logger(self) -> None:
        error_logs_file_path = os.path.join(self.config_dir, "errors.log")
        if (not os.path.exists(error_logs_file_path)) or os.path.getsize(
            error_logs_file_path
        ) >= 20 * IBYTES_TO_MBS_DIVISOR:
            f = open(error_logs_file_path, "w")
            f.close()

        logging.basicConfig(
            filename=error_logs_file_path,
            level=logging.ERROR,
            format="%(asctime)s - %(levelname)s - %(message)s",
        )

    def setup_config_dir(self) -> str:
        config_dir = os.path.join(user_config_dir(), APP_NAME)
        if not os.path.isdir(config_dir):
            os.makedirs(config_dir)
        return config_dir

    def load_settings(self) -> None:
        if not os.path.isfile(self.settings_json_path):
            return
        try:
            with open(self.settings_json_path, "r") as f:
                settings = cast(dict, json.load(f))
                # TODO: DEPRECATIONs: Remove
                tracking_interval = settings.get("tracking_interval", None)
                if tracking_interval is not None:
                    self.tracking_interval_hrs = tracking_interval
                    settings.pop("tracking_interval")
                start_in_fullscreen = settings.get("start_in_fullscreen", None)
                if start_in_fullscreen is not None:
                    self.start_maximized = start_in_fullscreen
                    settings.pop("start_in_fullscreen")
                auto_download_site = settings.get("auto_download_site", None)
                if auto_download_site is not None:
                    self.tracking_site = auto_download_site
                    settings.pop("auto_download_site")
                check_for_new_eps_after = settings.get("check_for_new_eps_after", None)
                if check_for_new_eps_after is not None:
                    self.tracking_interval_hrs = check_for_new_eps_after
                    settings.pop("check_for_new_eps_after")
                gogo_norm_or_hls_mode = settings.get("gogo_norm_or_hls_mode", None)
                if gogo_norm_or_hls_mode is not None:
                    self.gogo_mode = gogo_norm_or_hls_mode
                    settings.pop("gogo_norm_or_hls_mode")
                if "gogo_skip_calculate" in settings:
                    settings.pop("gogo_skip_calculate")
                self.__dict__.update(settings)
        except json.JSONDecodeError:
            pass

    def max_part_size_bytes(self) -> int:
        return self.max_part_size_mbs * IBYTES_TO_MBS_DIVISOR

    def setup_default_download_folder(self) -> list[str]:
        downloads_folder = os.path.join(Path.home(), "Downloads", "Anime")
        if not os.path.isfile(self.settings_json_path) and not os.path.isdir(
            downloads_folder
        ):
            os.makedirs(downloads_folder)
        return [downloads_folder]

    def dict_settings(self) -> dict:
        return {
            k: v for k, v in self.__dict__.items() if k not in self.excluded_in_save
        }

    def get_custom_anime_folder_index(
        self,
        anime_title: str,
    ) -> int:
        lower_title = sanitise_title(anime_title, True).lower()
        try:
            idx = next(
                idx
                for idx, caf in enumerate(self.custom_anime_folders)
                if sanitise_title(caf["anime_title"], True).lower() == lower_title
            )
            return idx
        except StopIteration:
            return -1

    def add_custom_anime_folder(self, anime_title: str, folder: str) -> None:
        self.custom_anime_folders.append({"anime_title": anime_title, "folder": folder})
        self.save_settings()

    def remove_custom_anime_folder(self, index: int) -> None:
        self.custom_anime_folders.pop(index)
        self.save_settings()

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

    def update_max_simultaneous_downloads(
        self, max_simultaneous_downloads: int
    ) -> None:
        self.max_simultaneous_downloads = max_simultaneous_downloads
        self.save_settings()

    def update_allow_notifications(self, allow_notifications: bool) -> None:
        self.allow_notifications = allow_notifications
        self.save_settings()

    def update_start_maximized(self, start_maximized: bool) -> None:
        self.start_maximized = start_maximized
        self.save_settings()

    def update_run_on_startup(self, run_on_startup: bool) -> None:
        self.run_on_startup = run_on_startup
        self.save_settings()

    def update_gogo_mode(self, gogo_mode: str) -> None:
        self.gogo_mode = gogo_mode
        self.save_settings()

    def update_tracked_anime(self, tracked_anime: list[str]) -> None:
        self.tracked_anime = tracked_anime
        self.save_settings()

    def remove_tracked_anime(self, anime_title: str) -> None:
        self.tracked_anime.remove(anime_title)
        self.save_settings()

    def add_tracked_anime(self, anime_name: str) -> None:
        self.tracked_anime.append(anime_name)
        self.save_settings()

    def update_tracking_site(self, auto_download_site: str) -> None:
        self.tracking_site = auto_download_site
        self.save_settings()

    def update_tracking_interval_hrs(self, tracking_interval_hrs: int) -> None:
        self.tracking_interval_hrs = tracking_interval_hrs
        self.save_settings()

    def update_pahe_home_url(self, pahe_home_url: str) -> None:
        self.pahe_home_url = pahe_home_url
        self.save_settings()

    def update_gogo_home_url(self, gogo_home_url: str) -> None:
        self.gogo_home_url = gogo_home_url
        self.save_settings()

    def update_close_minimize_to_tray(self, close_minimize_to_tray: bool) -> None:
        self.close_minimize_to_tray = close_minimize_to_tray
        self.save_settings()

    def update_max_part_size_mbs(self, max_part_size_mbs: int) -> None:
        self.max_part_size_mbs = max_part_size_mbs
        self.save_settings()

    def save_settings(self) -> None:
        with open(self.settings_json_path, "w") as f:
            json.dump(self.dict_settings(), f, indent=4)


SETTINGS = Settings()


class Anime:
    def __init__(self, title: str, page_link: str, anime_id: str | None) -> None:
        self.title = title
        self.page_link = page_link
        self.id = anime_id


class ParsedDetails(NamedTuple):
    anitopy_parsed: dict[str, str]
    parsed_title: str
    parent_seasons_path: str
    anime_types: list[str]
    season_number: int


class AnimeDetails:
    def __init__(self, anime: Anime, site: str) -> None:
        self.anime = anime
        self.site = site
        self.is_hls_download = (
            True if site == GOGO and SETTINGS.gogo_mode == GOGO_HLS_MODE else False
        )
        self.sanitised_title = sanitise_title(anime.title)
        self.shortened_title = self.get_shortened_title()
        self.default_download_path = SETTINGS.download_folder_paths[0]
        self.set_anime_folder_path(self.get_anime_folder_path())
        self.dub_available, self.dub_page_link = self.get_dub_availablilty_status()
        self.metadata, self.anime_page_content = self.get_metadata()
        self.episode_count = self.metadata.episode_count
        self.quality = SETTINGS.quality
        self.sub_or_dub = SETTINGS.sub_or_dub
        self.ddls_or_segs_urls: list[str] | list[list[str]] = []
        self.download_info: list[str] = []
        self.total_download_size_mbs = 0
        self.download_sizes_bytes: list[int] = []
        self.lacked_episode_numbers: list[int] = []

    def get_shortened_title(self):
        # Around 5 words i.e., 5 * 8
        max_anime_title_length = 40
        if len(self.sanitised_title) <= max_anime_title_length:
            return self.sanitised_title
        shortened = self.sanitised_title[: max_anime_title_length - 3]
        return f"{shortened.strip()}..."

    def episode_title(self, lacked_eps_idx: int, shortened: bool) -> str:
        episode_number_str = str(self.lacked_episode_numbers[lacked_eps_idx]).zfill(2)
        title = self.shortened_title if shortened else self.sanitised_title
        return f"{title} E{episode_number_str}"

    def validate_anime_folder_path(self) -> None:
        if not os.path.isdir(self.anime_folder_path):
            os.makedirs(self.anime_folder_path)

    def set_anime_folder_path(self, anime_folder_path: str) -> None:
        self.anime_folder_path = anime_folder_path
        self.potentially_haved_episodes = list(Path(self.anime_folder_path).glob("*"))
        self.haved_episodes: list[int] = []
        (
            self.haved_start,
            self.haved_end,
            self.haved_count,
        ) = self.get_start_end_and_count_of_haved_episodes()

    def get_anime_folder_path(self) -> str:
        def detect_path(title: str) -> str | None:
            for path in SETTINGS.download_folder_paths:
                potential = os.path.join(path, title)
                if os.path.isdir(potential):
                    return potential
            return None

        def parse_title(title: str) -> ParsedDetails | None:
            anitopy_parsed = anitopy.parse(title)
            if not anitopy_parsed:
                return None

            parsed_title = anitopy_parsed.get("anime_title", title)
            if not parsed_title:
                return None
            # It could be that the anime is a Special/OVA/ONA
            anime_types = anitopy_parsed.get("anime_type", [])
            if isinstance(anime_types, str):
                anime_types = [anime_types]
            for at in anime_types:
                # In the resulting parsed anime_title, Anitopy only ignores Seasons but not Types for some reason, e.g., "Attack On Titan Season 1" will
                # be parsed to "Attack on Titan" meanwhile, "Attack on Titan Specials" will still remain as "Attack on Titan Specials" so we need to remove the type
                parsed_title = parsed_title.replace(at, "").strip()
            season_number = (
                anitopy_parsed.get("anime_season", 1) if not anime_types else 1
            )
            parent_seasons_path = detect_path(parsed_title)
            if not parent_seasons_path:
                return None
            return ParsedDetails(
                anitopy_parsed,
                parsed_title,
                parent_seasons_path,
                anime_types,
                season_number,
            )

        try:
            lower_title = sanitise_title(self.anime.title, True).lower()
            folder = next(
                caf["folder"]
                for caf in SETTINGS.custom_anime_folders
                if sanitise_title(caf["anime_title"], True).lower() == lower_title
            )
            return folder
        except StopIteration:
            pass
        parsed_details = parse_title(self.sanitised_title)
        fully_sanitised_title = sanitise_title(self.anime.title, True, " ")
        if not parsed_details:
            parsed_details = parse_title(fully_sanitised_title)

        if parsed_details:
            zfilled_season = str(parsed_details.season_number).zfill(2)
            potential_folders = (
                [
                    *parsed_details.anime_types,
                    *[
                        f"{parsed_details.parsed_title} {at}"
                        for at in parsed_details.anime_types
                    ],
                ]
                if parsed_details.anime_types
                else [
                    f"Season {parsed_details.season_number}",
                    f"SN {parsed_details.season_number}",
                    f"Sn {parsed_details.season_number}",
                    f"S{parsed_details.season_number}",
                    f"{parsed_details.parsed_title} Season {parsed_details.season_number}",
                    f"{parsed_details.parsed_title} SN {parsed_details.season_number}",
                    f"{parsed_details.parsed_title} Sn {parsed_details.season_number}",
                    f"{parsed_details.parsed_title} S{parsed_details.season_number}",
                    f"Season {zfilled_season}",
                    f"SN {zfilled_season}",
                    f"Sn {zfilled_season}",
                    f"S{zfilled_season}",
                    f"{parsed_details.parsed_title} Season {zfilled_season}",
                    f"{parsed_details.parsed_title} SN {zfilled_season}",
                    f"{parsed_details.parsed_title} Sn {zfilled_season}",
                    f"{parsed_details.parsed_title} S{zfilled_season}",
                ]
            )

            potential_folders += [self.sanitised_title, fully_sanitised_title]

            for f in potential_folders:
                folder = os.path.join(parsed_details.parent_seasons_path, f)
                if os.path.isdir(folder):
                    return folder

        if path := detect_path(self.sanitised_title):
            return path
        if path := detect_path(fully_sanitised_title):
            return path
        return os.path.join(self.default_download_path, self.sanitised_title)

    def get_start_end_and_count_of_haved_episodes(
        self,
    ) -> tuple[int, int, int] | tuple[None, None, None]:
        if self.potentially_haved_episodes:
            for episode in self.potentially_haved_episodes:
                if "[Downloading]" in episode.name:
                    continue
                parsed = anitopy.parse(episode.name)
                if not parsed:
                    continue
                try:
                    episode_number = int(parsed["episode_number"])
                except (KeyError, ValueError):
                    continue
                if episode_number > 0:
                    self.haved_episodes.append(episode_number)
            self.haved_episodes.sort()
        return (
            (self.haved_episodes[0], self.haved_episodes[-1], len(self.haved_episodes))
            if self.haved_episodes
            else (None, None, None)
        )

    def get_dub_availablilty_status(self) -> tuple[bool, str]:
        if self.site == PAHE:
            dub_available = pahe.dub_available(
                self.anime.page_link, cast(str, self.anime.id)
            )
            link = self.anime.page_link
        else:
            dub_available, link = gogo.dub_availability_and_link(self.anime.title)
        return dub_available, link

    def get_metadata(self) -> tuple[AnimeMetadata, bytes]:
        if self.site == PAHE:
            metadata = pahe.get_anime_metadata(cast(str, self.anime.id))
            page_content = b""
        else:
            page_content, self.anime.page_link = gogo.get_anime_page_content(
                self.anime.page_link
            )
            metadata = gogo.extract_anime_metadata(page_content)
        return metadata, page_content
