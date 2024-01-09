import re
from math import pow
from typing import Callable, cast

import requests
from bs4 import BeautifulSoup, ResultSet, Tag
from senpwai.utils.scraper_utils import (
    CLIENT,
    PARSER,
    AnimeMetadata,
    DomainNameError,
    PausableAndCancellableFunction,
    get_new_home_url_from_readme,
    match_quality,
)

PAHE = "pahe"
PAHE_HOME_URL = "https://animepahe.ru"
FULL_SITE_NAME = "Animepahe"
API_ENTRY_POINT = f"{PAHE_HOME_URL}/api?m="
"""
The base URL for Pahe's API, used for retrieving anime information.
"""
ANIME_PAGE_URL = f"{API_ENTRY_POINT}release&id={{}}&sort=episode_asc"
"""
Generates the anime page link from the provided anime id.
Example: https://animepahe.ru/api?m=release&id={anime_id}&sort=episode_asc
"""
EPISODE_PAGE_URL = f"{PAHE_HOME_URL}/play/{{}}/{{}}"
"""
Generates episode page link from the provided anime id and episode session.
Example: https://animepahe.ru/play/{anime_id}/{episode_session}
"""
LOAD_EPISODES_URL = "{}&page={}"
"""
Generates the load episodes link from the provided anime page link and page number.
Example: {anime_page_link}&page={page_number}
"""
UUID_REGEX = re.compile(r"uuid=(.*?);")
UUID_COOKIE = {"uuid": ""}
KWIK_PAGE_REGEX = re.compile(r"https?://kwik.cx/f/([^\"']+)")
DUB_PATTERN = "eng"
EPISODE_SIZE_REGEX = re.compile(r"\b(\d+)MB\b")


def uuid_request(url: str, search_request=False) -> requests.Response:
    # Without setting the uuid cookie most requests redirect to some html page containing a valid uuid
    # but it seems like the uuid cookie only needs to be set as in they don't validate it
    try:
        # We only want to handle the domain change incase this is the first request
        # This is to avoid raising DomainNameError when the something else broke instead
        exceptions_to_ignore = [DomainNameError] if search_request else []
        response = CLIENT.get(
            url, cookies=UUID_COOKIE, exceptions_to_ignore=exceptions_to_ignore
        )
    except DomainNameError:
        global PAHE_HOME_URL
        PAHE_HOME_URL = get_new_home_url_from_readme(FULL_SITE_NAME)
        return uuid_request(url, search_request)
    if search_request:
        try:
            response.json()
        except requests.exceptions.JSONDecodeError:
            # This is a monkey patch fallback incase they start validating the uuid, it works by assuming the first request
            # which is a search request will involve decoding so if it fails decoding then it means they gave us the html page with the uuid
            # so we try and and extract a valid uuid from the page
            # TODO: if they ever start validating uuids implement a better implementation
            match = cast(re.Match[str], UUID_REGEX.search(response.text))
            UUID_COOKIE["uuid"] = match.group(1)
            return uuid_request(url)
    return response


def search(keyword: str) -> list[dict[str, str]]:
    search_url = f"{API_ENTRY_POINT}search&q={keyword}"
    response = uuid_request(search_url, True)
    decoded = cast(dict, response.json())
    # The search api endpoint won't return json containing the data key if no results are found
    return decoded.get("data", [])


def extract_anime_title_page_link_and_id(
    result: dict[str, str],
) -> tuple[str, str, str]:
    anime_id = result["session"]
    title = result["title"]
    page_link = ANIME_PAGE_URL.format(anime_id)
    return title, page_link, anime_id


def get_total_episode_page_count(anime_page_link: str) -> int:
    page_url = LOAD_EPISODES_URL.format(anime_page_link, 1)
    decoded = uuid_request(page_url).json()
    total_episode_page_count: int = decoded["last_page"]
    return total_episode_page_count


class GetEpisodePageLinks(PausableAndCancellableFunction):
    def __init__(self) -> None:
        super().__init__()

    # Retrieves a list of the episode page links (not download links)
    def get_episode_page_links(
        self,
        start_episode: int,
        end_episode: int,
        anime_page_link: str,
        anime_id: str,
        progress_update_callback: Callable = lambda _: None,
    ) -> list[str]:
        page_url = anime_page_link
        episodes_data = []
        page_no = 1
        while page_url is not None:
            page_url = LOAD_EPISODES_URL.format(anime_page_link, page_no)
            decoded = uuid_request(page_url).json()
            episodes_data += decoded["data"]
            page_url = decoded["next_page_url"]
            page_no += 1
            self.resume.wait()
            if self.cancelled:
                return []
            progress_update_callback(1)
        # To avoid episodes like 7.5 and 5.5 cause they're usually just recaps
        episodes_data = [
            ep for ep in episodes_data if not isinstance(ep["episode"], float)
        ]
        # Take note cause indices work differently from episode numbers
        episodes_data = episodes_data[start_episode - 1 : end_episode]
        episode_sessions = [episode["session"] for episode in episodes_data]
        episode_links = [
            EPISODE_PAGE_URL.format(anime_id, episode_session)
            for episode_session in episode_sessions
        ]
        return episode_links


class GetPahewinDownloadPageLinks(PausableAndCancellableFunction):
    def __init__(self) -> None:
        super().__init__()

    def get_pahewin_download_page_links_and_info(
        self,
        episode_page_links: list[str],
        progress_update_callback: Callable = lambda _: None,
    ) -> tuple[list[list[str]], list[list[str]]]:
        download_data: list[ResultSet[BeautifulSoup]] = []
        for episode_page_link in episode_page_links:
            page_content = uuid_request(episode_page_link).content
            soup = BeautifulSoup(page_content, PARSER)
            download_data.append(
                soup.find_all("a", class_="dropdown-item", target="_blank")
            )
            self.resume.wait()
            if self.cancelled:
                return ([], [])
            progress_update_callback(1)
        # Scrapes the download data of each episode and stores the links in a list which is contained in another list containing all episodes
        pahewin_download_page_links: list[list[str]] = [
            [cast(str, download_link["href"]) for download_link in episode_data]
            for episode_data in download_data
        ]
        # Scrapes the download data of each episode and stores the info for each quality and dub or sub in a list which is contained in another list containing all episodes
        download_info: list[list[str]] = [
            [episode_info.text.strip() for episode_info in episode_data]
            for episode_data in download_data
        ]
        return (pahewin_download_page_links, download_info)


def is_dub(anime_info: str) -> bool:
    return anime_info.endswith(DUB_PATTERN)


def dub_available(anime_page_link: str, anime_id: str) -> bool:
    page_url = LOAD_EPISODES_URL.format(anime_page_link, 1)
    decoded = uuid_request(page_url).json()
    episodes_data = decoded["data"]
    episode_sessions = [episode["session"] for episode in episodes_data]
    episode_links = [
        EPISODE_PAGE_URL.format(anime_id, episode_session)
        for episode_session in episode_sessions
    ]
    episode_links = [episode_links[-1]]
    (
        _,
        download_info,
    ) = GetPahewinDownloadPageLinks().get_pahewin_download_page_links_and_info(
        episode_links
    )

    for episode in download_info:
        found_dub = False
        for info in episode:
            found_dub = is_dub(info)
        if not found_dub:
            return False
    return True


def bind_sub_or_dub_to_link_info(
    sub_or_dub: str,
    pahewin_download_page_links: list[list[str]],
    download_info: list[list[str]],
) -> tuple[list[list[str]], list[list[str]]]:
    bound_links: list[list[str]] = []
    bound_info: list[list[str]] = []
    for idx_out, episode_info in enumerate(download_info):
        links: list[str] = []
        infos: list[str] = []
        for idx_in, info in enumerate(episode_info):
            is_dub_link = is_dub(info)
            if (sub_or_dub == "sub" and not is_dub_link) or (
                sub_or_dub == "dub" and is_dub_link
            ):
                links.append(pahewin_download_page_links[idx_out][idx_in])
                infos.append(info)
        bound_links.append(links)
        bound_info.append(infos)

    return (bound_links, bound_info)


def bind_quality_to_link_info(
    quality: str,
    pahewin_download_page_links: list[list[str]],
    download_info: list[list[str]],
) -> tuple[list[str], list[str]]:
    bound_links: list[str] = []
    bound_info: list[str] = []
    for idx_out, episode_info in enumerate(download_info):
        idx_in = match_quality(episode_info, quality)
        bound_links.append(pahewin_download_page_links[idx_out][idx_in])
        bound_info.append(episode_info[idx_in])
    return (bound_links, bound_info)


def calculate_total_download_size(bound_info: list[str]) -> int:
    total_size = 0
    download_sizes: list[int] = []
    for episode in bound_info:
        match = cast(re.Match, EPISODE_SIZE_REGEX.search(episode))
        size = int(match.group(1))
        download_sizes.append(size)
        total_size += size
    return total_size


def get_string(content: str, s1: int) -> int:
    map_thing = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ+/"
    s2 = 10
    map_string = map_thing[:s2]
    acc = 0
    for index, c in enumerate(reversed(content)):
        acc += (int(c) if c.isdigit() else 0) * int(pow(s1, index))
    k = ""
    while acc > 0:
        k = map_string[acc % s2] + k
        acc = (acc - (acc % s2)) // s2
    return int(k) if k.isdigit() else 0


# Courtesy of Saikou app https://github.com/saikou-app/saikou
def decrypt_token_and_post_url_page(full_key: str, key: str, v1: int, v2: int) -> str:
    r = ""
    i = 0
    while i < len(full_key):
        s = ""
        while full_key[i] != key[v2]:
            s += full_key[i]
            i += 1
        for j in range(len(key)):
            s = s.replace(key[j], str(j))
        r += chr(get_string(s, v2) - v1)
        i += 1
    return r


class GetDirectDownloadLinks(PausableAndCancellableFunction):
    def __init__(self) -> None:
        super().__init__()

    def get_direct_download_links(
        self,
        pahewin_download_page_links: list[str],
        progress_update_callback: Callable = lambda _: None,
    ) -> list[str]:
        direct_download_links: list[str] = []
        param_regex = re.compile(r"""\(\"(\w+)\",\d+,\"(\w+)\",(\d+),(\d+),(\d+)\)""")
        for pahewin_link in pahewin_download_page_links:
            # Extract kwik page links
            html_page = CLIENT.get(pahewin_link).text
            download_link = cast(
                re.Match[str], KWIK_PAGE_REGEX.search(html_page)
            ).group()

            # Extract direct download links from kwik page links
            response = CLIENT.get(download_link)
            cookies = response.cookies
            match = cast(re.Match, param_regex.search(response.text))
            full_key, key, v1, v2 = (
                match.group(1),
                match.group(2),
                match.group(3),
                match.group(4),
            )
            decrypted = decrypt_token_and_post_url_page(full_key, key, int(v1), int(v2))
            soup = BeautifulSoup(decrypted, PARSER)
            post_url = cast(str, cast(Tag, soup.form)["action"])
            token_value = cast(str, cast(Tag, soup.input)["value"])
            response = CLIENT.post(
                post_url,
                headers=CLIENT.append_headers({"Referer": download_link}),
                cookies=cookies,
                data={"_token": token_value},
                allow_redirects=False,
            )
            direct_download_link = response.headers["Location"]
            direct_download_links.append(direct_download_link)
            self.resume.wait()
            if self.cancelled:
                return []
            progress_update_callback(1)
        return direct_download_links


def get_anime_metadata(anime_id: str) -> AnimeMetadata:
    page_link = f"{PAHE_HOME_URL}/anime/{anime_id}"
    page_content = uuid_request(page_link).content
    soup = BeautifulSoup(page_content, PARSER)
    poster = soup.find(class_="youtube-preview")
    if not isinstance(poster, Tag):
        poster = cast(Tag, soup.find(class_="poster-image"))
    poster_link = cast(str, poster["href"])
    summary = cast(Tag, soup.find(class_="anime-synopsis")).get_text()
    genres_tags = cast(
        Tag, cast(Tag, soup.find(class_="anime-genre font-weight-bold")).find("ul")
    ).find_all("li")
    genres: list[str] = []
    for genre in genres_tags:
        genres.append(cast(str, cast(Tag, genre.find("a"))["title"]))
    season_and_year = cast(
        str, cast(Tag, soup.select_one('a[href*="/anime/season/"]'))["title"]
    )
    _, release_year = season_and_year.split(" ")
    page_link = ANIME_PAGE_URL.format(anime_id)
    decoded = uuid_request(page_link).json()
    episode_count = decoded["total"]
    tag = soup.find(title="Currently Airing")
    if tag:
        status = "ONGOING"
    elif episode_count == 0:
        status = "UPCOMING"
    else:
        status = "FINISHED"
    return AnimeMetadata(
        poster_link, summary, episode_count, status, genres, int(release_year)
    )
