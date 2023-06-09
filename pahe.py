import requests
from bs4 import BeautifulSoup, ResultSet, Tag
import json
from tqdm import tqdm
import os
import re
from typing import Callable, cast, Any
from math import pow
from intersection import network_monad, parser, test_downloading, match_quality

pahe_home_url = 'https://animepahe.ru'
api_url_extension = '/api?m='


def search(keyword: str) -> list[dict]:
    search_url = pahe_home_url+api_url_extension+'search&q='+keyword
    response = network_monad(lambda: network_monad(
        lambda: requests.get(search_url).content))
    try:
        decoded = json.loads(response.decode('UTF-8'))
        return decoded['data']
    except (json.decoder.JSONDecodeError, KeyError):
        return []


def extract_anime_id_title_and_page_link(result: dict) -> tuple[str, str, str]:
    anime_id = result['session']
    title = result['title']
    page_link = f'{pahe_home_url}{api_url_extension}release&id={anime_id}&sort=episode_asc'
    return anime_id, title, page_link


def get_total_episode_page_count(anime_page_link: str) -> int:
    page_url = f'{anime_page_link}&page={1}'
    response = network_monad(lambda: network_monad(
        lambda: requests.get(page_url).content))
    decoded_anime_page = json.loads(response.decode('UTF-8'))
    total_episode_page_count: int = decoded_anime_page['last_page']
    return total_episode_page_count
# Issues GET requests together with the id of the anime to retrieve a list of the episode page links(not download links)


def get_episode_page_links(start_episode: int, end_episode: int, anime_page_link: str, anime_id: str, progress_update_callback: Callable = lambda update: None, console_app=False) -> list[str]:
    page_url = anime_page_link
    episodes_data = []
    page_no = 1
    progress_bar = None if not console_app else tqdm(
        total=end_episode, desc=' Fetching episode page links', units='eps')
    while page_url != None:
        page_url = f'{anime_page_link}&page={page_no}'
        response = network_monad(
            lambda page_url=page_url: requests.get(page_url).content)
        decoded_anime_page = json.loads(response.decode('UTF-8'))
        episodes_data += decoded_anime_page['data']
        page_url = decoded_anime_page["next_page_url"]
        page_no += 1
        progress_update_callback(1)
        if progress_bar:
            progress_bar.update()
    # To avoid episodes like 7.5 and 5.5 cause they're usually just recaps
    episodes_data = list(filter(lambda episode: type(
        episode['episode']) != float, episodes_data))
    # Take note cause indices work diff from episode numbers
    episodes_data = episodes_data[start_episode-1: end_episode]
    episode_sessions = [episode['session'] for episode in episodes_data]
    episode_links = [
        f'{pahe_home_url}/play/{anime_id}/{episode_session}' for episode_session in episode_sessions]
    return episode_links


def get_pahewin_download_page_links_and_info(episode_page_links: list[str], progress_update_callback: Callable = lambda x: None, console_app=False) -> tuple[list[list[str]], list[list[str]]]:
    progress_bar = None if not console_app else tqdm(total=len(
        episode_page_links), desc=' Fetching download page links', unit='eps')
    download_data: list[ResultSet[BeautifulSoup]] = []
    for idx, episode_page_link in enumerate(episode_page_links):
        episode_page = network_monad(
            lambda episode_page_link=episode_page_link: requests.get(episode_page_link).content)
        soup = BeautifulSoup(episode_page, parser)
        download_data.append(soup.find_all(
            'a', class_='dropdown-item', target='_blank'))
        progress_update_callback(1)
        if progress_bar:
            progress_bar.update(idx+1 - progress_bar.n)
    if progress_bar:
        progress_bar.set_description(' Done')
        progress_bar.close()
    # Scrapes the download data of each episode and stores the links for the in a list which is contained in another list containing all episodes
    pahewin_download_page_links: list[list[str]] = [
        [cast(str, download_link["href"]) for download_link in episode_data] for episode_data in download_data]
    # Scrapes the download data of each episode and stores the info for each quality and dub or sub in a list which is contained in another list containing all episodes
    download_info: list[list[str]] = [[episode_info.text.strip(
    ) for episode_info in episode_data] for episode_data in download_data]
    return (pahewin_download_page_links, download_info)


def dub_available(anime_page_link: str, anime_id: str) -> bool:
    page_url = f'{anime_page_link}&page={1}'
    response = network_monad(lambda: requests.get(page_url).content)
    decoded_anime_page = json.loads(response.decode('UTF-8'))
    episodes_data = decoded_anime_page['data']
    episode_sessions = [episode['session'] for episode in episodes_data]
    episode_links = [
        f'{pahe_home_url}/play/{anime_id}/{episode_session}' for episode_session in episode_sessions]
    episode_links = [episode_links[-1]]
    _, download_info = get_pahewin_download_page_links_and_info(episode_links)

    dub_pattern = r'eng$'
    for episode in download_info:
        found_dub = False
        for info in episode:
            if (match := re.search(dub_pattern, info)) and match:
                found_dub = True
        if not found_dub:
            return False
    return True


def bind_sub_or_dub_to_link_info(sub_or_dub: str, pahewin_download_page_links: list[list[str]], download_info: list[list[str]]) -> tuple[list[list[str]], list[list[str]]]:
    bound_links: list[list[str]] = []
    bound_info: list[list[str]] = []
    dub_pattern = r'eng$'
    for idx_out, episode_info in enumerate(download_info):
        links: list[str] = []
        infos: list[str] = []
        for idx_in, info in enumerate(episode_info):
            match = re.search(dub_pattern, info)
            if (sub_or_dub == 'dub' and match) or (sub_or_dub == 'sub' and not match):
                links.append(pahewin_download_page_links[idx_out][idx_in])
                infos.append(info)
        bound_links.append(links)
        bound_info.append(infos)

    return (bound_links, bound_info)


def bind_quality_to_link_info(quality: str, pahewin_download_page_links: list[list[str]], download_info: list[list[str]]) -> tuple[list[str], list[str]]:
    bound_links: list[str] = []
    bound_info: list[str] = []
    for idx_out, episode_info in enumerate(download_info):
        idx_in = match_quality(episode_info, quality)
        bound_links.append(pahewin_download_page_links[idx_out][idx_in])
        bound_info.append(episode_info[idx_in]) 
    return (bound_links, bound_info)


def calculate_total_download_size(bound_info: list[str]) -> int:
    pattern = r'\b(\d+)MB\b'
    total_size = 0
    download_sizes: list[int] = []
    for episode in bound_info:
        match = cast(re.Match, re.search(pattern, episode))
        size = int(match.group(1))
        download_sizes.append(size)
        total_size += size
    return total_size


def get_string(content, s1):
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


def decrypt_token_and_post_url_page(full_key: str, key: str, v1: int, v2: int):
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


def get_direct_download_links(pahewin_download_page_links: list[str], progress_update_callback: Callable = lambda x: None, console_app=False) -> list[str]:
    progress_bar = None if not console_app else tqdm(total=len(
        pahewin_download_page_links), desc=' Fetching direct download links', unit='eps')
    direct_download_links: list[str] = []
    param_regex = re.compile(
        r"""\(\"(\w+)\",\d+,\"(\w+)\",(\d+),(\d+),(\d+)\)""")
    for idx, pahewin_link in enumerate(pahewin_download_page_links):
        kwik_download_page = network_monad(
            lambda pahewin_link=pahewin_link: requests.get(pahewin_link).content)
        soup = BeautifulSoup(kwik_download_page, parser)
        download_link = cast(str, cast(Tag, soup.find(
            "a", class_="btn btn-primary btn-block redirect"))["href"])

        response = network_monad(
            lambda download_link=download_link: requests.get(download_link))
        cookies = response.cookies
        match = cast(re.Match, param_regex.search(response.text))
        full_key, key, v1, v2 = match.group(1), match.group(
            2), match.group(3), match.group(4)
        decrypted = decrypt_token_and_post_url_page(
            full_key, key, int(v1), int(v2))
        soup = BeautifulSoup(decrypted, parser)
        post_url = cast(str, cast(Tag, soup.form)['action'])
        token_value = cast(str, cast(Tag, soup.input)['value'])
        response = network_monad(lambda post_url=post_url, download_link=download_link, cookies=cookies, token_value=token_value: requests.post(post_url, headers={'Referer': download_link}, cookies=cookies, data={
                                 '_token': token_value}, allow_redirects=False))
        direct_download_link = response.headers['location']
        direct_download_links.append(direct_download_link)
        progress_update_callback(1)
        if progress_bar:
            progress_bar.update(idx+1 - progress_bar.n)
    if progress_bar:
        progress_bar.set_description(' Done')
        progress_bar.close()
    return direct_download_links


def extract_poster_summary_and_episode_count(anime_id: str) -> tuple[str, str, int]:
    page_link = f'{pahe_home_url}/anime/{anime_id}'
    response = network_monad(lambda: requests.get(page_link).content)
    soup = BeautifulSoup(response, parser)
    poster = soup.find(class_='youtube-preview')
    if not isinstance(poster, Tag):
        poster = cast(Tag, soup.find(class_='poster-image'))
    poster_link = cast(str, poster['href'])
    summary = cast(Tag, soup.find(class_='anime-synopsis')).get_text()

    page_link = f'{pahe_home_url}{api_url_extension}release&id={anime_id}&sort=episode_desc'
    response = network_monad(lambda: requests.get(page_link).content)
    episode_count = json.loads(response)['total']
    return (poster_link, summary, int(episode_count))


def test_getting_direct_download_links(query_anime_title: str, start_episode: int, end_episode: int, quality: str, sub_or_dub='sub') -> list[str]:
    result = search(query_anime_title)[0]
    anime_id, anime_title, anime_page_link = extract_anime_id_title_and_page_link(
        result)
    _, _, episode_count = extract_poster_summary_and_episode_count(anime_id)
    episode_page_links = get_episode_page_links(
        start_episode, end_episode, anime_page_link, anime_id)
    download_page_links, download_info = get_pahewin_download_page_links_and_info(
        episode_page_links, console_app=True)
    direct_download_links = get_direct_download_links(bind_quality_to_link_info(
        quality, *bind_sub_or_dub_to_link_info(sub_or_dub, download_page_links, download_info))[0], console_app=True)
    # list(map(print, direct_download_links))
    list(map(print, download_info))
    return direct_download_links


def main():
    # Download settings
    query = 'Senyuu.'
    quality = '360p'
    sub_or_dub = 'sub'
    start_episode = 1
    end_episode = 4

    direct_download_links = test_getting_direct_download_links(
        query, start_episode, end_episode, quality, sub_or_dub)
    # test_downloading(query, direct_download_links)

#    test_downloading('Senyuu.', [
#                     'https://eu-11.files.nextcdn.org/get/11/04/d3185322653a395e921c3f66ada4a12ed482a9b2b77f3edc65c412f4378d9e79?file=AnimePahe_Senyuu._-_03_BD_360p_Final8.mp4&token=-_aOZ9BLRIfTgUw9DNi43A&expires=1688735253'])


if __name__ == "__main__":
    main()
