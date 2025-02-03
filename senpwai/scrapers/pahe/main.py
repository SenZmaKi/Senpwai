import re
import math
from typing import Any, Callable, NamedTuple, cast
from requests import Response
from bs4 import BeautifulSoup, Tag
from senpwai.common.scraper import (
    CLIENT,
    PARSER,
    AiringStatus,
    AnimeMetadata,
    DomainNameError,
    ProgressFunction,
    get_new_home_url_from_readme,
    closest_quality_index,
)
from senpwai.scrapers.pahe.constants import (
    CHAR_MAP_BASE,
    CHAR_MAP_DIGITS,
    PAHE_HOME_URL,
    FULL_SITE_NAME,
    API_ENTRY_POINT,
    ANIME_PAGE_URL,
    LOAD_EPISODES_URL,
    DUB_PATTERN,
    EPISODE_PAGE_URL,
    EPISODE_SIZE_REGEX,
    KWIK_PAGE_REGEX,
    PARAM_REGEX,
)

FIRST_REQUEST = True
COOKIES = {"__ddg1_": "", "__ddg2_": ""}
"""
For some reason these cookies just need to be set as in they don't even need to be valid
If something crashes, try updating to something like: 
COOKIES = {
    "__ddg1_": f"; Expires=Tue, 19 Jan 2038 03:14:07 GMT; Domain={PAHE_DOMAIN}; Path=/",
    "__ddg2_": f"; Expires=Tue, 19 Jan 2038 03:14:07 GMT; Domain={PAHE_DOMAIN}; Path=/",
}
Also it seems currently only __ddg2_ is necessary
"""


def site_request(url: str, allow_redirects=False) -> Response:
    """
    For requests that go specifically to the domain animepahe.ru instead of e.g., pahe.win or kwik.si
    Typically these requests need the cookies
    """
    try:
        # We only want to handle the domain change incase this is the first request
        # This is to avoid raising DomainNameError when the something else broke instead
        global FIRST_REQUEST
        if FIRST_REQUEST:
            FIRST_REQUEST = False
            response = CLIENT.get(
                url,
                cookies=COOKIES,
                allow_redirects=allow_redirects,
                exceptions_to_raise=(DomainNameError, KeyboardInterrupt),
            )
        else:
            response = CLIENT.get(url, cookies=COOKIES, allow_redirects=allow_redirects)
        COOKIES.update(response.cookies)
    except DomainNameError:
        global PAHE_HOME_URL
        PAHE_HOME_URL = get_new_home_url_from_readme(FULL_SITE_NAME)
        return site_request(url)
    return response


def search(keyword: str) -> list[dict[str, str]]:
    search_url = f"{API_ENTRY_POINT}search&q={keyword}"
    response = site_request(search_url)
    results_json = cast(dict, response.json())
    # The search api endpoint won't return json containing the data key if no results are found
    return results_json.get("data", [])


def extract_anime_title_page_link_and_id(
    result: dict[str, str],
) -> tuple[str, str, str]:
    anime_id = result["session"]
    title = result["title"]
    page_link = ANIME_PAGE_URL.format(anime_id)
    return title, page_link, anime_id


class EpisodePagesInfo(NamedTuple):
    start_page_num: int
    end_page_num: int
    total: int
    first_page_json: dict[str, Any]


def get_episode_pages_info(
    anime_page_link: str, start_episode: int, end_episode: int
) -> EpisodePagesInfo:
    page_url = LOAD_EPISODES_URL.format(anime_page_link, 1)
    first_page_json = site_request(page_url).json()
    per_page: int = first_page_json["per_page"]
    start_page_num = math.ceil(start_episode / per_page)
    end_page_num = math.ceil(end_episode / per_page)
    total = (end_page_num - start_page_num) + 1
    return EpisodePagesInfo(
        start_page_num, end_page_num, total, first_page_json
    )


class GetEpisodePageLinks(ProgressFunction):
    def __init__(self) -> None:
        super().__init__()

    @staticmethod
    def generate_episode_page_links(
        start_episode: int,
        end_episode: int,
        first_episode: int,
        episodes_data: list[dict[str, Any]],
        anime_id: str,
    ):
        start_idx = 0
        end_idx = len(episodes_data) - 1

        for idx, episode in enumerate(episodes_data):
            # Sometimes for sequels animepahe continues the episode numbers from the last episode of the previous season
            # For instance  "Boku no Hero Academia 2nd Season" episode 1 is shown as episode 14
            # So we do episode - (first_episode - 1) to get the real episode number e.g.,
            # 14 - (14 - 1) = 1
            # 15 - (14 - 1) = 2 and so on
            episode_num = episode["episode"] - (first_episode - 1)
            if episode_num == start_episode:
                start_idx = idx
            if episode_num == end_episode: 
                end_idx = idx
                break
        episodes_data = episodes_data[start_idx : end_idx + 1]
        episode_sessions = [episode["session"] for episode in episodes_data]
        return [
            EPISODE_PAGE_URL.format(anime_id, episode_session)
            for episode_session in episode_sessions
        ]

    # Retrieves a list of the episode page links (not download links)
    def get_episode_page_links(
        self,
        start_episode: int,
        end_episode: int,
        episode_pages_info: EpisodePagesInfo,
        anime_page_link: str,
        anime_id: str,
        progress_update_callback: Callable[[int], None] | None = None,
    ) -> list[str]:
        page_url = anime_page_link
        (
            start_page_num,
            end_page_num,
            _,
            first_page_json,
        ) = episode_pages_info

        episodes_data: list[dict[str, Any]] = []
        if start_page_num == 1:
            episodes_data.extend(first_page_json["data"])
            start_page_num += 1
            if progress_update_callback:
                progress_update_callback(1)
        for page_num in range(start_page_num, end_page_num + 1):
            page_url = LOAD_EPISODES_URL.format(anime_page_link, page_num)
            page_json = site_request(page_url).json()
            # To avoid episodes like 7.5 and 5.5 cause they're usually just recaps
            episodes = [
                ep for ep in page_json["data"] if isinstance(ep["episode"], int)
            ]
            episodes_data.extend(episodes)
            page_url = page_json["next_page_url"]
            self.resume.wait()
            if self.cancelled:
                return []
            if progress_update_callback:
                progress_update_callback(1)
        first_episode_json = next(
            ep for ep in first_page_json["data"] if isinstance(ep["episode"], int)
        )
        first_episode = first_episode_json["episode"]
        return GetEpisodePageLinks.generate_episode_page_links(
            start_episode,
            end_episode,
            first_episode,
            episodes_data,
            anime_id,
        )


class GetPahewinPageLinks(ProgressFunction):
    def __init__(self) -> None:
        super().__init__()

    def get_pahewin_page_links_and_info(
        self,
        episode_page_links: list[str],
        progress_update_callback: Callable[[int], None] | None = None,
    ) -> tuple[list[list[str]], list[list[str]]]:
        pahewin_links: list[list[str]] = []
        download_info: list[list[str]] = []
        for episode_page_link in episode_page_links:
            page_content = site_request(episode_page_link, allow_redirects=True).content
            soup = BeautifulSoup(page_content, PARSER)
            pahewin_data = soup.find_all("a", class_="dropdown-item", target="_blank")
            if pahewin_data:
                pahewin_links.append([cast(str, link["href"]) for link in pahewin_data])
                download_info.append([li.text.strip() for li in pahewin_data])
            self.resume.wait()
            if self.cancelled:
                return ([], [])
            if progress_update_callback:
                progress_update_callback(1)
        return (pahewin_links, download_info)


def is_dub(episode_download_info: str) -> bool:
    return episode_download_info.endswith(DUB_PATTERN)


def dub_available(anime_page_link: str, anime_id: str) -> bool:
    page_url = LOAD_EPISODES_URL.format(anime_page_link, 1)
    page_json = site_request(page_url).json()
    episodes_data = page_json.get("data", None)
    if episodes_data is None:
        return False
    episode_sessions = [episode["session"] for episode in episodes_data]
    episode_page_link = EPISODE_PAGE_URL.format(anime_id, episode_sessions[0])
    (
        _,
        download_info,
    ) = GetPahewinPageLinks().get_pahewin_page_links_and_info([episode_page_link])

    for info in download_info[0]:
        if is_dub(info):
            return True
    return False


def bind_sub_or_dub_to_link_info(
    sub_or_dub: str,
    pahewin_download_page_links: list[list[str]],
    download_info: list[list[str]],
) -> tuple[list[list[str]], list[list[str]]]:
    bound_links: list[list[str]] = []
    bound_info: list[list[str]] = []
    for link_list, episode_info in zip(pahewin_download_page_links, download_info):
        links: list[str] = []
        infos: list[str] = []
        for link, info in zip(link_list, episode_info):
            is_dub_link = is_dub(info)
            if (sub_or_dub == "sub" and not is_dub_link) or (
                sub_or_dub == "dub" and is_dub_link
            ):
                links.append(link)
                infos.append(info)
        if links and infos:
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
    for links, infos in zip(pahewin_download_page_links, download_info):
        index = closest_quality_index(infos, quality)
        bound_links.append(links[index])
        bound_info.append(infos[index])
    return (bound_links, bound_info)


def calculate_total_download_size(bound_info: list[str]) -> int:
    total_size = 0
    for episode in bound_info:
        match = cast(re.Match, EPISODE_SIZE_REGEX.search(episode))
        size = int(match.group(1))
        total_size += size
    return total_size 


def get_char_code(content: str, s1: int) -> int:
    j = 0
    for index, c in enumerate(reversed(content)):
        j += (int(c) if c.isdigit() else 0) * int(math.pow(s1, index))
    k = ""
    while j > 0:
        k = CHAR_MAP_DIGITS[j % CHAR_MAP_BASE] + k
        j = (j - (j % CHAR_MAP_BASE)) // CHAR_MAP_BASE
    return int(k) if k else 0


# Courtesy of Saikou app https://github.com/saikou-app/saikou
# RIP Saikou
def decrypt_post_form(full_key: str, key: str, v1: int, v2: int) -> str:
    r = ""
    i = 0
    while i < len(full_key):
        s = ""
        while full_key[i] != key[v2]:
            s += full_key[i]
            i += 1
        for idx, c in enumerate(key):
            s = s.replace(c, str(idx))
        r += chr(get_char_code(s, v2) - v1)
        i += 1
    return r


class GetDirectDownloadLinks(ProgressFunction):
    def __init__(self) -> None:
        super().__init__()

    def get_direct_download_links(
        self,
        pahewin_download_page_links: list[str],
        progress_update_callback: Callable[[int], None] | None = None,
    ) -> list[str]:
        direct_download_links: list[str] = []
        for pahewin_link in pahewin_download_page_links:
            # Extract kwik page links
            pahewin_html_page = CLIENT.get(pahewin_link).text
            kwik_page_link = cast(
                re.Match[str], KWIK_PAGE_REGEX.search(pahewin_html_page)
            ).group()

            # Extract direct download links from kwik html page
            response = CLIENT.get(kwik_page_link)
            match = cast(re.Match, PARAM_REGEX.search(response.text))
            full_key, key, v1, v2 = (
                match.group(1),
                match.group(2),
                match.group(3),
                match.group(4),
            )
            form = decrypt_post_form(full_key, key, int(v1), int(v2))
            soup = BeautifulSoup(form, PARSER)
            post_url = cast(str, cast(Tag, soup.form)["action"])
            token_value = cast(str, cast(Tag, soup.input)["value"])
            response = CLIENT.post(
                post_url,
                headers=CLIENT.make_headers({"Referer": kwik_page_link}),
                cookies=response.cookies,
                data={"_token": token_value},
                allow_redirects=False,
            )
            direct_download_link = response.headers["Location"]
            direct_download_links.append(direct_download_link)
            self.resume.wait()
            if self.cancelled:
                return []
            if progress_update_callback:
                progress_update_callback(1)
        return direct_download_links


def get_anime_metadata(anime_id: str) -> AnimeMetadata:
    page_link = f"{PAHE_HOME_URL}/anime/{anime_id}"
    page_content = site_request(page_link, allow_redirects=True).content
    soup = BeautifulSoup(page_content, PARSER)
    poster = soup.find(class_="youtube-preview")
    if not isinstance(poster, Tag):
        poster = cast(Tag, soup.find(class_="poster-image"))
    poster_url = cast(str, poster["href"])
    summary = cast(Tag, soup.find(class_="anime-synopsis")).get_text()
    genres_tag = cast(Tag, soup.find(class_="anime-genre font-weight-bold"))
    genres = (
        [
            cast(str, cast(Tag, genre_tag.find("a")["title"]))
            for genre_tag in genres_tag.find_all("li")
        ]
        if genres_tag
        else []
    )
    season_and_year = cast(
        str, cast(Tag, soup.select_one('a[href*="/anime/season/"]'))["title"]
    )
    _, release_year = season_and_year.split(" ")
    page_link = ANIME_PAGE_URL.format(anime_id)
    page_json = site_request(page_link).json()
    episode_count = page_json["total"]
    tag = soup.find(title="Currently Airing")
    if tag:
        airing_status = AiringStatus.ONGOING
    elif episode_count == 0:
        airing_status = AiringStatus.UPCOMING
    else:
        airing_status = AiringStatus.FINISHED
    return AnimeMetadata(
        poster_url, summary, episode_count, airing_status, genres, int(release_year)
    )
