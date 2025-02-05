import re
from typing import cast
from senpwai.common.scraper import CLIENT, strip_title
from bs4 import BeautifulSoup, Tag
import time


ANIME_FILLER_LIST_HOME = "https://www.animefillerlist.com"

cached_anime_list: dict[str, str] = {}
VALID_CACHE_DURATION = 24 * 60 * 60
cache_fetch_time = 0


def get_anime_list() -> dict[str, str]:
    global cached_anime_list, cache_fetch_time

    duration_since_fetch = time.time() - cache_fetch_time
    if cache_fetch_time and duration_since_fetch <= VALID_CACHE_DURATION:
        return cached_anime_list

    response = CLIENT.get(f"{ANIME_FILLER_LIST_HOME}/shows")
    cache_fetch_time = time.time()
    soup = BeautifulSoup(response.text, "html.parser")

    show_list_div = cast(Tag, soup.find("div", id="ShowList"))
    raw_shows_list = show_list_div.find_all("li")

    anime_list: dict[str, str] = {}
    for anime in raw_shows_list:
        a_tag = cast(Tag, anime.find("a"))
        anime_title = a_tag.text
        anime_slug = a_tag["href"]
        stripped_title = strip(anime_title)
        anime_list[stripped_title] = cast(str, anime_slug)

    cached_anime_list = anime_list
    return anime_list


def _get_filler_episodes(url: str) -> list[int]:
    response = CLIENT.get(url)
    soup = BeautifulSoup(response.text, "html.parser")
    episodes_list_table = cast(Tag, soup.find("table", class_="EpisodeList"))
    episodes_list = episodes_list_table.find_all("tr", class_="filler")
    filler_episodes = []
    for episode in episodes_list:
        eps_num_tag = cast(Tag, episode).find("td", class_="Number")
        eps_num = int(cast(Tag, eps_num_tag).text)
        filler_episodes.append(eps_num)

    return filler_episodes


def get_filler_episodes(anime_title: str) -> list[int]:
    anime_list = get_anime_list()
    stripped_title = strip(anime_title)
    try:
        match_title = next(
            anime_title for anime_title in anime_list if stripped_title == anime_title
        )
        match_url = f"{ANIME_FILLER_LIST_HOME}{anime_list[match_title]}"
        return _get_filler_episodes(match_url)
    except StopIteration:
        return []


def strip(title: str) -> str:
    # Bleach: Thousand-Year Blood War (Bleach: Sennen Kessen-hen)
    # becomes
    # Bleach: Thousand-Year Blood War 
    title = re.sub(r"\[.*?\]|\(.*?\)", "", title)
    stripped = strip_title(title, True).lower()
    return stripped


if __name__ == "__main__":
    fillers = get_filler_episodes("That Time I Got Reincarnated as a Slime")
    print(fillers)
