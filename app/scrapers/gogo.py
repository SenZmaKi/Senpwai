import requests
from bs4 import BeautifulSoup, ResultSet, Tag
from time import sleep
from tqdm import tqdm
import webbrowser
from sys import platform

from selenium.common.exceptions import WebDriverException
from selenium.webdriver.chrome.service import Service as ChromeService
from selenium.webdriver.edge.service import Service as EdgeService
from selenium.webdriver.firefox.service import Service as FirefoxService
from selenium.webdriver import Chrome, Edge, Firefox, ChromeOptions, EdgeOptions, FirefoxOptions

import subprocess
from typing import Callable, cast
from shared.app_and_scraper_shared import parser, network_error_retry_wrapper, test_downloading, match_quality, ibytes_to_mbs_divisor, network_retry_wait_time, PausableFunction

gogo_home_url = 'https://gogoanime.hu'
dub_extension = ' (Dub)'
edge_name = 'edge'
chrome_name = 'chrome'
firefox_name = 'firefox'


def search(keyword: str) -> list[BeautifulSoup]:
    search_url = '/search.html?keyword='
    search = gogo_home_url + search_url + keyword
    response = network_error_retry_wrapper(
        lambda: requests.get(search).content)
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


def setup_headless_browser(browser: str = edge_name) -> Chrome | Edge | Firefox:
    def setup_options(options: ChromeOptions | EdgeOptions | FirefoxOptions) -> ChromeOptions | EdgeOptions | FirefoxOptions:
        options.add_argument('--disable-extensions')
        options.add_argument('--disable-infobars')
        options.add_argument('--no-sandbox')
        if isinstance(options, FirefoxOptions):
            # For testing purposes, when deploying remember to uncomment out
            options.add_argument("--headless")
        else:
            # For testing purposes, when deploying remember to uncomment out
            options.add_argument("--headless=new")
        return options

    def setup_edge_driver():
        service_edge = EdgeService()
        if platform == "win32":
            service_edge.creation_flags = subprocess.CREATE_NO_WINDOW
        options = cast(EdgeOptions, setup_options(EdgeOptions()))
        return Edge(service=service_edge, options=options)

    def setup_chrome_driver():
        service_chrome = ChromeService()
        service_chrome.creation_flags = subprocess.CREATE_NO_WINDOW
        options = cast(ChromeOptions, setup_options(ChromeOptions()))
        return Chrome(service=service_chrome, options=options)

    def setup_firefox_driver():
        service_firefox = FirefoxService()
        if platform == "win32":
            service_firefox.creation_flags = subprocess.CREATE_NO_WINDOW
        options = cast(FirefoxOptions, setup_options(FirefoxOptions()))
        return Firefox(service=service_firefox, options=options)

    if browser == edge_name:
        return setup_edge_driver()
    elif browser == chrome_name:
        return setup_chrome_driver()
    else:
        return setup_firefox_driver()


def get_links_and_quality_info(download_page_link: str, driver: Chrome | Edge | Firefox, max_load_wait_time: int, load_wait_time=1) -> tuple[list[str], list[str]]:
    def network_error_retry():
        while True:
            try:
                return driver.get(download_page_link)
            except WebDriverException:
                sleep(network_retry_wait_time)
    network_error_retry()
    sleep(load_wait_time)
    soup = BeautifulSoup(driver.page_source, parser)
    links_and_infos = soup.find_all('a')
    links = [link_and_info['href']
             for link_and_info in links_and_infos if 'download' in link_and_info.attrs]
    quality_infos = [link_and_info.text.replace(
        'P', 'p') for link_and_info in links_and_infos if 'download' in link_and_info.attrs]
    if (len(links) == 0):
        if load_wait_time >= max_load_wait_time:
            raise TimeoutError
        else:
            return get_links_and_quality_info(download_page_link, driver, max_load_wait_time, load_wait_time+1)
    return (links, quality_infos)


class GetDirectDownloadLinks(PausableFunction):
    def __init__(self) -> None:
        super().__init__()

    def get_direct_download_link_as_per_quality(self, download_page_links: list[str], quality: str, driver: Chrome | Edge | Firefox, progress_update_call_back: Callable = lambda update: None, max_load_wait_time=6, console_app=False) -> list[str]:
        # For testing purposes
        # raise TimeoutError
        download_links: list[str] = []
        progress_bar = None if not console_app else tqdm(
            total=len(download_page_links), desc=' Fetching download links', unit='eps')
        download_links: list[str] = []
        for idx, page_link in enumerate(download_page_links):
            links, quality_infos = get_links_and_quality_info(
                page_link, driver, max_load_wait_time)
            quality_idx = match_quality(quality_infos, quality)
            print(quality_infos[quality_idx])
            download_links.append(links[quality_idx])
            while self.paused:
                continue
            if self.cancelled:
                return []
            progress_update_call_back(1)
            if progress_bar:
                progress_bar.update(idx+1 - progress_bar.n)
        if progress_bar:
            progress_bar.set_description(' Complete')
            progress_bar.close()
        return download_links


class GetDownloadPageLinks(PausableFunction):
    def __init__(self) -> None:
        super().__init__()

    def cancel(self):
        self.cancelled = True

    def get_download_page_links(self, episode_page_links: list[str], progress_update_callback: Callable = lambda x: None, console_app=False) -> list[str]:
        progress_bar = None if not console_app else tqdm(total=len(
            episode_page_links), desc=' Fetching download page links', unit='eps')
        download_page_links: list[str] = []

        def get_page_content(episode_page_link): return requests.get(
            episode_page_link).content

        def extract_link(episode_page_link: str) -> str:
            response = network_error_retry_wrapper(lambda page=episode_page_link: get_page_content(episode_page_link)
                                                   )
            soup = BeautifulSoup(response, parser)
            soup = cast(Tag, soup.find('li', class_='dowloads'))
            link = cast(str, cast(Tag, soup.find(
                'a', target='_blank'))['href'])
            return link

        for idx, episode_page_link in enumerate(episode_page_links):
            try:
                link = extract_link(episode_page_link)
            except AttributeError:
                # To handle a case like for Jujutsu Kaisen 2nd Season where when there is TV in the titie it misses in the episode page links
                link = extract_link(episode_page_link.replace('-tv', ''))
            download_page_links.append(link)
            while self.paused:
                continue
            if self.cancelled:
                return []
            progress_update_callback(1)
            if progress_bar:
                progress_bar.update(idx+1 - progress_bar.n)
        if progress_bar:
            progress_bar.close()
            progress_bar.set_description(' Done')
        return download_page_links


class CalculateTotalDowloadSize(PausableFunction):
    def __init__(self):
        super().__init__()

    def calculate_total_download_size(self, download_links: list[str], progress_update_callback: Callable = lambda update: None, in_megabytes=False, console_app=False) -> int:
        progress_bar = None if not console_app else tqdm(
            total=len(download_links), desc=' Calculating total download size', unit='eps')
        total_size = 0
        for idx, link in enumerate(download_links):
            response = network_error_retry_wrapper(
                lambda link=link: requests.get(link, stream=True))
            size = response.headers.get('content-length', 0)
            if in_megabytes:
                total_size += round(int(size) / ibytes_to_mbs_divisor)
            else:
                total_size += int(size)
            while self.paused:
                continue
            if self.cancelled:
                return 0
            progress_update_callback(1)
            if progress_bar:
                progress_bar.update(idx+1 - progress_bar.n)
        if progress_bar:
            progress_bar.set_description(' Done')
            progress_bar.close()
        return total_size


def open_browser_with_links(download_links: str) -> None:
    for link in download_links:
        webbrowser.open_new_tab(link)


def extract_poster_summary_and_episode_count(anime_page_link: str) -> tuple[str, str, int]:
    response = network_error_retry_wrapper(
        lambda: requests.get(anime_page_link).content)
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
    download_page_links = GetDownloadPageLinks().get_download_page_links(
        episode_page_links, console_app=True)
    driver = setup_headless_browser(edge_name)
    direct_download_links = GetDirectDownloadLinks().get_direct_download_link_as_per_quality(
        download_page_links, quality, driver, max_load_wait_time=50, console_app=True)
    CalculateTotalDowloadSize().calculate_total_download_size(
        direct_download_links, console_app=True)
    driver.quit()
    list(map(print, direct_download_links))
    return direct_download_links


def main():
    # Download settings
    query = 'Jujutsu season 2'
    quality = '480p'
    sub_or_dub = 'sub'
    start_episode = 1
    end_episode = 3

    direct_download_links = test_getting_direct_download_links(
        query, start_episode, end_episode, quality, sub_or_dub)
    # test_downloading(query, direct_download_links)


if __name__ == "__main__":
    main()
