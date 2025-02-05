from senpwai.common.scraper import AiringStatus, strip_title
from senpwai.common.static import DUB, GOGO, PAHE
from senpwai.common.classes import SETTINGS, Anime, AnimeDetails
from senpwai.scrapers import pahe, gogo
from typing import Callable


def check_tracked_anime(
    removed_tracked_callback: Callable[[str], None],
    finished_tracking_callback: Callable[[str], None],
    no_dub_callback: Callable[[str], None],
    start_download_callback: Callable[[AnimeDetails], None],
    queued_new_episodes_callback: Callable[[str], None],
    start_downloading_immediately: bool,
) -> None:
    queued: list[str] = []
    all_anime_details: list[AnimeDetails] = []
    for title in SETTINGS.tracked_anime:
        anime: Anime
        site = SETTINGS.tracking_site
        if site == PAHE:
            result = pahe_fetch_anime_obj(title)
            if not result:
                result = gogo_fetch_anime_obj(title)
                if not result:
                    continue
                site = GOGO
        else:
            result = gogo_fetch_anime_obj(title)
            if not result:
                result = pahe_fetch_anime_obj(title)
                if not result:
                    continue
                site = PAHE
        anime = result
        anime_details = AnimeDetails(anime, site)
        start_eps = anime_details.haved_end if anime_details.haved_end else 1
        anime_details.set_lacked_episodes(start_eps, anime_details.episode_count)
        if (
            not anime_details.lacked_episodes
            and anime_details.metadata.airing_status == AiringStatus.FINISHED
        ):
            removed_tracked_callback(anime_details.anime.title)
            finished_tracking_callback(anime_details.sanitised_title)
            continue
        if anime_details.sub_or_dub == DUB and not anime_details.dub_available:
            no_dub_callback(anime_details.sanitised_title)
            continue
        queued.append(anime_details.sanitised_title)
        if start_downloading_immediately:
            start_download_callback(anime_details)
        all_anime_details.append(anime_details)
    if queued:
        all_str = ", ".join(queued)
        queued_new_episodes_callback(all_str)
    if not start_downloading_immediately:
        for anime_details in all_anime_details:
            start_download_callback(anime_details)


def pahe_fetch_anime_obj(title: str) -> Anime | None:
    results = pahe.search(title)
    title_fuzzy = strip_title(title, True).lower()
    for result in results:
        res_title, page_link, anime_id = pahe.extract_anime_title_page_link_and_id(
            result
        )
        if strip_title(res_title, True).lower() == title_fuzzy:
            return Anime(title, page_link, anime_id)
    return None


def gogo_fetch_anime_obj(title: str) -> Anime | None:
    results = gogo.search(title)
    title_fuzzy = strip_title(title, True).lower()
    for res_title, page_link in results:
        if strip_title(res_title, True).lower() == title_fuzzy:
            return Anime(title, page_link, None)
    return None
