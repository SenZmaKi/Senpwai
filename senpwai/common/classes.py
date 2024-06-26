import json
import logging
import os
import re
from pathlib import Path
from typing import NamedTuple, cast

import anitopy
from appdirs import user_config_dir

from senpwai.common.scraper import (
    CLIENT,
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


class UpdateInfo(NamedTuple):
    is_update_available: bool
    download_url: str
    file_name: str
    release_notes: str


def update_available(
    latest_release_api_url: str, app_name: str, curr_version: str
) -> UpdateInfo:
    latest_version_json = CLIENT.get(latest_release_api_url).json()
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


class Settings:
    types = str | int | bool | list[str]

    def __init__(self) -> None:
        self.config_dir = self.setup_config_dir()
        self.settings_json_path = os.path.join(self.config_dir, "settings.json")
        # Default settings
        # Only these settings will be saved to settings.json
        # NOTE: Everytime you add a new class member that isn't a setting, make sure  to update the Settings.dict_settings() method
        self.sub_or_dub = SUB
        self.quality = Q_720
        self.download_folder_paths = self.setup_default_download_folder()
        self.max_simultaneous_downloads = 2
        self.font_family = "Berlin Sans FB Demi"
        self.allow_notifications = True
        self.start_maximized = True
        self.run_on_startup = False
        self.gogo_norm_or_hls_mode = GOGO_NORM_MODE
        self.tracked_anime: list[str] = []
        self.auto_download_site = PAHE
        self.check_for_new_eps_after = 24
        self.gogo_skip_calculate = False
        self.version = VERSION

        self.configure_settings()
        self.setup_logger()
        self.is_update_install = self.version != VERSION

    def setup_logger(self) -> None:
        error_logs_file_path = os.path.join(self.config_dir, "errors.log")
        if not os.path.exists(error_logs_file_path):
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

    def configure_settings(self) -> None:
        if not os.path.isfile(self.settings_json_path):
            self.save_settings()
            return
        with open(self.settings_json_path, "r") as f:
            try:
                settings = cast(dict, json.load(f))
                # TODO: DEPRECATION: Remove in version 2.1.11+ cause we use start_maximized now
                start_in_fullscreen = settings.get("start_in_fullscreen", None)
                if start_in_fullscreen is not None:
                    self.start_maximized = start_in_fullscreen
                    settings.pop("start_in_fullscreen")
                    f.close()
                    self.save_settings()
                self.__dict__.update(settings)
            except json.decoder.JSONDecodeError:
                self.save_settings()

    def setup_default_download_folder(self) -> list[str]:
        downloads_folder = os.path.join(Path.home(), "Downloads", "Anime")
        if not os.path.isfile(self.settings_json_path) and not os.path.isdir(
            downloads_folder
        ):
            os.makedirs(downloads_folder)
        return [downloads_folder]

    def dict_settings(self) -> dict:
        return {
            k: v
            for k, v in self.__dict__.items()
            # NOTE: Everytime you add a new class member that isn't a setting, make sure to include it here
            if k not in ("config_dir", "settings_json_path", "is_update_install")
        }

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


SETTINGS = Settings()


class Anime:
    def __init__(self, title: str, page_link: str, anime_id: str | None) -> None:
        self.title = title
        self.page_link = page_link
        self.id = anime_id


class AnimeDetails:
    def __init__(self, anime: Anime, site: str) -> None:
        self.anime = anime
        self.site = site
        self.is_hls_download = (
            True
            if site == GOGO and SETTINGS.gogo_norm_or_hls_mode == GOGO_HLS_MODE
            else False
        )
        self.sanitised_title = sanitise_title(anime.title)
        self.default_download_path = SETTINGS.download_folder_paths[0]
        self.anime_folder_path = self.get_anime_folder_path()
        self.potentially_haved_episodes = list(Path(self.anime_folder_path).glob("*"))
        self.haved_episodes: list[int] = []
        (
            self.haved_start,
            self.haved_end,
            self.haved_count,
        ) = self.get_start_end_and_count_of_haved_episodes()
        self.dub_available, self.dub_page_link = self.get_dub_availablilty_status()
        self.metadata, self.anime_page_content = self.get_metadata()
        self.episode_count = self.metadata.episode_count
        self.quality = SETTINGS.quality
        self.sub_or_dub = SETTINGS.sub_or_dub
        self.ddls_or_segs_urls: list[str] | list[list[str]] = []
        self.download_info: list[str] = []
        self.total_download_size: int = 0
        self.lacked_episode_numbers: list[int] = []
        self.skip_calculating_size = (
            True
            if site == GOGO
            and not self.is_hls_download
            and SETTINGS.gogo_skip_calculate
            else False
        )

    def episode_title(self, lacked_eps_idx: int) -> str:
        episode_number_str = str(self.lacked_episode_numbers[lacked_eps_idx]).zfill(2)
        return f"{self.sanitised_title} E{episode_number_str}"

    def validate_anime_folder_path(self) -> None:
        if not os.path.isdir(self.anime_folder_path):
            os.makedirs(self.anime_folder_path)

    def get_anime_folder_path(self) -> str:
        def try_path(title: str) -> str | None:
            for path in SETTINGS.download_folder_paths:
                potential = os.path.join(path, title)
                if os.path.isdir(potential):
                    return potential
            return None

        fully_sanitised_title = sanitise_title(self.anime.title, True, " ")
        parent_seasons_path = ""
        season_number = 1
        parsed_title = ""
        anime_type = ""
        parsed = {}

        def init(title: str) -> None:
            nonlocal \
                parsed, \
                parsed_title, \
                parent_seasons_path, \
                anime_type, \
                season_number
            parsed = anitopy.parse(title)
            if parsed:
                parsed_title = parsed.get("anime_title", title)
                # It could be that the anime is a Special/OVA/ONA
                anime_type = parsed.get("anime_type", "")
                if anime_type:
                    # In the resulting parsed anime_title, Anitopy only ignores Seasons but not Types for some reason, e.g., "Attack On Titan Season 1" will
                    # be parsed to "Attack on Titan" meanwhile, "Attack on Titan Specials" will still remain as "Attack on Titan"
                    parsed_title = parsed_title.replace(anime_type, "").strip()
                parent_seasons_path = try_path(parsed_title)
                if not anime_type:
                    season_number = parsed.get("anime_season", 1)

        init(self.sanitised_title)
        if not parent_seasons_path:
            init(fully_sanitised_title)
        if parent_seasons_path and parsed_title and parsed:
            target_folders = (
                [anime_type]
                if anime_type
                else [
                    f"Season {season_number}",
                    f"SN {season_number}",
                    f"Sn {season_number}",
                    f"{parsed_title} Season {season_number}",
                    f"{parsed_title} SN {season_number}",
                    f"{parsed_title} Sn {season_number}",
                ]
            )
            target_folders += [self.sanitised_title, fully_sanitised_title]

            for f in target_folders:
                folder = os.path.join(parent_seasons_path, f)
                if os.path.isdir(folder):
                    return folder
        if path := try_path(self.sanitised_title):
            return path
        elif path := try_path(fully_sanitised_title):
            return path
        else:
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
