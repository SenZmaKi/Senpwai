import requests
import threading
from bs4 import BeautifulSoup, ResultSet, Tag
import time
from tqdm import tqdm
import os
import keyboard
from pygetwindow import getActiveWindowTitle
import webbrowser

from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.chrome.service import Service as ChromeService
from selenium.webdriver import ChromeOptions
from selenium.webdriver import Chrome
from subprocess import CREATE_NO_WINDOW
from typing import Callable, cast, NoReturn
from intersection import parser, Download, network_monad, test_downloading

gogo_home_url = 'https://gogoanime.hu'
dub_extension = ' (Dub)'


def search(keyword: str) -> list[BeautifulSoup]:
    search_url = '/search.html?keyword='
    search = gogo_home_url + search_url + keyword
    response = network_monad(lambda: requests.get(search).content)
    soup = BeautifulSoup(response, parser)
    results_page = cast(Tag, soup.find('ul', class_="items"))
    results = results_page.find_all('li')
    return results


def extract_anime_title_and_page_link(result: BeautifulSoup) -> tuple[str, str] | tuple[None, None]:
    title = cast(str, cast(Tag, result.find('a'))['title'])
    page_link = gogo_home_url + cast(str, cast(Tag, result.find('a'))['href'])
    if dub_extension in title:
        return (None, None)
    return (title, page_link)


def generate_episode_page_links(start_episode: int, end_episode: int, anime_page_link: str) -> list[str]:
    episode_page_links: list[str] = []
    for episode_num in range(start_episode, end_episode+1):
        episode_page_links.append(
            f'{gogo_home_url}{anime_page_link.split("/category")[1]}-episode-{episode_num}')
    return episode_page_links


def set_up_headless_browser() -> Chrome:
    # Configuring the settings for the headless browser
    chrome_options = ChromeOptions()
    # chrome_options.add_argument("--headless=new")
    chrome_options.add_argument('--disable-extensions')
    chrome_options.add_argument('--disable-infobars')
    chrome_options.add_argument('--no-sandbox')
    chrome_options.add_argument(f"referer={gogo_home_url}")

    chrome_options.add_experimental_option("prefs", {
        "download.prompt_for_download": False,
        "download.directory_upgrade": True,
        "safebrowsing_for_trusted_sources_enabled": False,
        "safebrowsing.enabled": False
    })

    service_chrome = ChromeService(
        executable_path=ChromeDriverManager().install())
    service_chrome.creation_flags = CREATE_NO_WINDOW
    chrome_driver = Chrome(service=service_chrome, options=chrome_options)
    return chrome_driver


def get_all_quality_links(download_page_link: str, driver: Chrome, max_load_wait_time: int, load_wait_time=1) -> list[str]:
    driver.get(download_page_link)
    time.sleep(load_wait_time)
    soup = BeautifulSoup(driver.page_source, parser)
    all_page_links = soup.find_all('a')
    all_quality_links = [link['href']
                         for link in all_page_links if 'download' in link.attrs]
    if (len(all_quality_links) == 0):
        if load_wait_time >= max_load_wait_time:
            raise TimeoutError
        else:
            return get_all_quality_links(download_page_link, driver, max_load_wait_time, load_wait_time+1)
    return all_quality_links


def get_direct_download_link_as_per_quality(download_page_links: list[str], quality: str, driver: Chrome, progress_update_call_back: Callable = lambda update: None, max_load_wait_time=25, console_app=False) -> list[str]:
    download_links: list[str] = []
    quality_dict = {'360': 0,
                    '480': 1,
                    '720': 2,
                    '1080': 3}
    chosen_quality = quality_dict[quality]

    progress_bar = None if not console_app else tqdm(
        total=len(download_page_links), desc=' Fetching download links', unit='eps')
    download_links: list[str] = []
    for idx, page_link in enumerate(download_page_links):
        all_quality_links = get_all_quality_links(
            page_link, driver, max_load_wait_time)
        if len(all_quality_links) != 4:
            chosen_quality = 0 if quality == '360' or quality == '480' else -1
        download_links.append(all_quality_links[chosen_quality])
        progress_update_call_back(1)
        if progress_bar:
            progress_bar.update(idx+1 - progress_bar.n)
    if progress_bar:
        progress_bar.set_description(' Done')
        progress_bar.close()
    return download_links


def get_download_page_links(episode_page_links: list[str], progress_update_callback: Callable = lambda x: None, console_app=False) -> list[str]:
    progress_bar = None if not console_app else tqdm(total=len(
        episode_page_links), desc=' Fetching download page links', unit='eps')
    download_page_links: list[str] = []
    for idx, episode_page_link in enumerate(episode_page_links):
        response = network_monad(
            lambda episode_page_link=episode_page_link: requests.get(episode_page_link).content)
        soup = BeautifulSoup(response, parser)
        soup = cast(Tag, soup.find('li', class_='dowloads'))
        link = cast(str, cast(Tag, soup.find('a', target='_blank'))['href'])
        download_page_links.append(link)
        progress_update_callback(1)
        if progress_bar:
            progress_bar.update(idx+1 - progress_bar.n)
    if progress_bar:
        progress_bar.close()
        progress_bar.set_description(' Done')
    return download_page_links


def calculate_download_total_size(download_links: list[str], progress_update_callback: Callable = lambda update: None, console_app=False) -> int:
    progress_bar = None if not console_app else tqdm(
        total=len(download_links), desc=' Calculating total download size', unit='eps')
    total_size = 0
    for idx, link in enumerate(download_links):
        response = network_monad(
            lambda link=link: requests.get(link, stream=True))
        size = response.headers.get('content-length', 0)
        total_size += int(size)
        progress_update_callback(1)
        if progress_bar:
            progress_bar.update(idx+1 - progress_bar.n)
    if progress_bar:
        progress_bar.set_description(' Done')
        progress_bar.close()
    total_size = round(total_size/1048576)
    return total_size


def open_browser_with_links(download_links: str) -> None:
    for link in download_links:
        webbrowser.open_new_tab(link)


def extract_poster_summary_and_episode_count(anime_page_link: str) -> tuple[str, str, int]:
    response = network_monad(lambda: requests.get(anime_page_link).content)
    soup = BeautifulSoup(response, parser)
    poster_link = cast(str, cast(Tag, cast(Tag, soup.find(
        class_='anime_info_body_bg')).find('img'))['src'])
    summary = soup.find_all('p', class_='type')[
        1].get_text().replace('Plot Summary: ', '')
    episode_count = cast(Tag, cast(ResultSet[Tag], cast(Tag, soup.find(
        'ul', id='episode_page')).find_all('li'))[-1].find('a')).get_text().split('-')[-1]
    return (poster_link, summary, int(episode_count))


def dub_available(anime_title: str) -> bool:
    dub_title = f'{anime_title}{dub_extension}'
    results = search(dub_title)
    for result in results:
        title = cast(str, cast(Tag, result.find('a'))['title'])
        if dub_title == title:
            return True
    return False
# Assumes dub is available


def get_dub_anime_page_link(anime_title: str) -> str:
    dub_title = f'{anime_title}{dub_extension}'
    results = search(dub_title)
    page_link = ''
    for result in results:
        title = cast(str, cast(Tag, result.find('a'))['title'])
        if dub_title == title:
            page_link = gogo_home_url + \
                cast(str, cast(Tag, result.find('a'))['href'])
            break
    return page_link


def test_getting_direct_download_links(query_anime_title: str, start_episode: int, end_episode: int, quality: str, sub_or_dub='sub') -> list[str]:
    result = search(query_anime_title)[0]
    anime_title, anime_page_link = cast(
        tuple[str, str], extract_anime_title_and_page_link(result))
    if sub_or_dub == 'dub' and dub_available(anime_title):
        anime_page_link = cast(str, dub_available(anime_title))
    extract_poster_summary_and_episode_count(anime_page_link)
    episode_page_links = generate_episode_page_links(
        start_episode, end_episode, anime_page_link)
    download_page_links = get_download_page_links(
        episode_page_links, console_app=True)
    chrome_driver = set_up_headless_browser()
    direct_download_links = get_direct_download_link_as_per_quality(
        download_page_links, quality, chrome_driver, max_load_wait_time=50, console_app=True)
    calculate_download_total_size(direct_download_links, console_app=True)
    chrome_driver.close()
    list(map(print, direct_download_links))
    return direct_download_links


def main():
    # Download settings
    query = 'Senyuu.'
    quality = '360'
    sub_or_dub = 'sub'
    start_episode = 1
    end_episode = 4

    direct_download_links = test_getting_direct_download_links(
        query, start_episode, end_episode, quality, sub_or_dub)
    test_downloading(query, direct_download_links)


if __name__ == "__main__":
    main()
