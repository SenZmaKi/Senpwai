import requests
from urllib.parse import quote
from bs4 import BeautifulSoup, ResultSet, Tag
from time import sleep
import webbrowser
from sys import platform

from selenium.common.exceptions import WebDriverException
from selenium.webdriver.chrome.service import Service as ChromeService
from selenium.webdriver.edge.service import Service as EdgeService
from selenium.webdriver.firefox.service import Service as FirefoxService
from selenium.webdriver import Chrome, Edge, Firefox, ChromeOptions, EdgeOptions, FirefoxOptions

import subprocess
from typing import Callable, cast
from shared.app_and_scraper_shared import PARSER, network_error_retry_wrapper, test_downloading, match_quality, IBYTES_TO_MBS_DIVISOR, NETWORK_RETRY_WAIT_TIME, PausableAndCancellableFunction, AnimeMetadata, REQUEST_HEADERS, extract_new_domain_name_from_readme

# Hls mode imports
import json
from yarl import URL as parseUrl
import base64
import re
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.padding import PKCS7
from cryptography.hazmat.backends import default_backend
from threading import Event

GOGO_HOME_URL = 'https://gogoanimehd.io'
DUB_EXTENSION = ' (Dub)'
EDGE = 'edge'
CHROME = 'chrome'
FIREFOX = 'firefox'

# Hls mode constants
# LOAD_EP_LIST_API = 'https://ajax.gogo-load.com/ajax/load-list-episode?ep_start=0&ep_end={}&id={}'
KEYS_REGEX = re.compile(rb'(?:container|videocontent)-(\d+)')
ENCRYPTED_DATA_REGEX = re.compile(rb'data-value="(.+?)"')


def search(keyword: str) -> list[BeautifulSoup]:
    global GOGO_HOME_URL
    print(GOGO_HOME_URL)
    url_extension = '/search.html?keyword='
    search_url = GOGO_HOME_URL + url_extension + quote(keyword)
    response = cast(requests.Response, network_error_retry_wrapper(
        lambda: requests.get(search_url, headers=REQUEST_HEADERS)))
    # If the status code isn't 200 we assume they changed their domain name
    if response.status_code != 200:
        GOGO_HOME_URL = extract_new_domain_name_from_readme("Gogoanime")
        return search(keyword)
    content = response.content
    soup = BeautifulSoup(content, PARSER)
    results_page = cast(Tag, soup.find('ul', class_="items"))
    results = results_page.find_all('li')
    return results


def extract_anime_title_and_page_link(result: BeautifulSoup) -> tuple[str, str] | tuple[None, None]:
    title = cast(str, cast(Tag, result.find('a'))['title'])
    page_link = GOGO_HOME_URL + cast(str, cast(Tag, result.find('a'))['href'])
    if DUB_EXTENSION in title:
        return (None, None)
    return (title, page_link)


def generate_episode_page_links(start_episode: int, end_episode: int, anime_page_link: str) -> list[str]:
    episode_page_links: list[str] = []
    for episode_num in range(start_episode, end_episode+1):
        episode_page_links.append(
            f'{GOGO_HOME_URL}{anime_page_link.split("/category")[1]}-episode-{episode_num}')
    return episode_page_links


class DriverManager():
    def __init__(self):
        self.is_inactive = Event()
        self.browser: str = EDGE
        self.driver: Chrome | Edge | Firefox | None = None
        self.is_inactive.set()

    def close_driver(self):
        if self.driver:
            self.driver.quit()
            self.driver = None
            self.is_inactive.set()

    def setup_driver(self, browser: str = EDGE) -> Chrome | Edge | Firefox:
        """
        Be sure to call `close_driver` once you're done using the driver
        """
        self.is_inactive.wait()

        def setup_options(options: ChromeOptions | EdgeOptions | FirefoxOptions) -> ChromeOptions | EdgeOptions | FirefoxOptions:
            options.add_argument('--disable-extensions')
            options.add_argument('--disable-infobars')
            options.add_argument('--no-sandbox')
            if isinstance(options, FirefoxOptions):
                # For testing purposes, when deploying remember to uncomment out
                options.add_argument("--headless")
                # pass
            else:
                # For testing purposes, when deploying remember to uncomment out
                options.add_argument("--headless=new")
                # pass
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

        if browser == EDGE:
            self.driver = setup_edge_driver()
        elif browser == CHROME:
            self.driver = setup_chrome_driver()
        else:
            self.driver = setup_firefox_driver()
        self.browser = browser
        self.is_inactive.clear()
        return self.driver


DRIVER_MANAGER = DriverManager()


class GetDirectDownloadLinks(PausableAndCancellableFunction):
    def __init__(self) -> None:
        super().__init__()

    def get_direct_download_link_as_per_quality(self, download_page_links: list[str], quality: str, driver: Chrome | Edge | Firefox, progress_update_call_back: Callable = lambda update: None, max_load_wait_time=7) -> list[str]:
        # For testing purposes
        # raise TimeoutError
        download_links: list[str] = []
        download_links: list[str] = []
        for page_link in download_page_links:
            links, quality_infos = get_links_and_quality_info(
                page_link, driver, max_load_wait_time, self)
            if self.cancelled:
                return []
            quality_idx = match_quality(quality_infos, quality)
            download_links.append(links[quality_idx])
            self.resume.wait()
            progress_update_call_back(1)
        return download_links


def get_links_and_quality_info(download_page_link: str, driver: Chrome | Edge | Firefox, max_load_wait_time: int, get_ddl: GetDirectDownloadLinks, load_wait_time=1) -> tuple[list[str], list[str]]:
    def network_error_retry():
        while True:
            if get_ddl.cancelled:
                return [], []
            try:
                return driver.get(download_page_link)
            except WebDriverException:
                sleep(NETWORK_RETRY_WAIT_TIME)
    network_error_retry()
    sleep(load_wait_time)
    soup = BeautifulSoup(driver.page_source, PARSER)
    links_and_infos = soup.find_all('a')
    links = [link_and_info['href']
             for link_and_info in links_and_infos if 'download' in link_and_info.attrs]
    quality_infos = [link_and_info.text.replace(
        'P', 'p') for link_and_info in links_and_infos if 'download' in link_and_info.attrs]
    get_ddl.resume.wait()
    if get_ddl.cancelled:
        return [], []
    if (len(links) == 0):
        if load_wait_time >= max_load_wait_time:
            raise TimeoutError
        else:
            return get_links_and_quality_info(download_page_link, driver, max_load_wait_time, get_ddl, load_wait_time+1)
    return (links, quality_infos)


class GetDownloadPageLinks(PausableAndCancellableFunction):
    def __init__(self) -> None:
        super().__init__()

    def get_download_page_links(self, episode_page_links: list[str], progress_update_callback: Callable = lambda x: None) -> list[str]:
        download_page_links: list[str] = []

        def extract_link(episode_page_link: str) -> str:
            response = cast(requests.Response, network_error_retry_wrapper(
                lambda page=episode_page_link: requests.get(page, headers=REQUEST_HEADERS)))
            if response.status_code != 200:
                # To handle a case like for Jujutsu Kaisen 2nd Season where when there is TV in the anime page link it misses in the episode page links
                episode_page_link = episode_page_link.replace('-tv', '')
                response = cast(requests.Response, network_error_retry_wrapper(
                    lambda page=episode_page_link: requests.get(page, headers=REQUEST_HEADERS)))
            soup = BeautifulSoup(response.content, PARSER)
            soup = cast(Tag, soup.find('li', class_='dowloads'))
            link = cast(str, cast(Tag, soup.find(
                'a', target='_blank'))['href'])
            return link

        for eps_pg_link in episode_page_links:
            try:
                link = extract_link(eps_pg_link)
            except AttributeError:
                link = fix_dead_episode_page_link(eps_pg_link)
                link = extract_link(eps_pg_link.replace('-tv', ''))
            download_page_links.append(link)
            self.resume.wait()
            if self.cancelled:
                return []
            progress_update_callback(1)
        return download_page_links


class CalculateTotalDowloadSize(PausableAndCancellableFunction):
    def __init__(self):
        super().__init__()

    def calculate_total_download_size(self, download_links: list[str], progress_update_callback: Callable = lambda update: None, in_megabytes=False) -> int:
        total_size = 0
        for idx, link in enumerate(download_links):
            response = network_error_retry_wrapper(
                lambda link=link: requests.get(link, stream=True, headers=REQUEST_HEADERS))
            size = response.headers.get('content-length', 0)
            if in_megabytes:
                total_size += round(int(size) / IBYTES_TO_MBS_DIVISOR)
            else:
                total_size += int(size)
            self.resume.wait()
            if self.cancelled:
                return 0
            progress_update_callback(1)
        return total_size


def open_browser_with_links(download_links: str) -> None:
    for link in download_links:
        webbrowser.open_new_tab(link)


def get_anime_metadata(anime_page_link: str) -> AnimeMetadata:
    response = network_error_retry_wrapper(
        lambda: requests.get(anime_page_link, headers=REQUEST_HEADERS).content)
    soup = BeautifulSoup(response, PARSER)
    poster_link = cast(str, cast(Tag, cast(Tag, soup.find(
        class_='anime_info_body_bg')).find('img'))['src'])
    metadata_tags = soup.find_all('p', class_='type')
    summary = metadata_tags[1].get_text().replace('Plot Summary: ', '')
    genre_tags = cast(ResultSet[Tag], metadata_tags[2].find_all('a'))
    genres = cast(list[str], [g['title'] for g in genre_tags])
    release_year = int(metadata_tags[3].get_text().replace('Released: ', ''))
    episode_count = cast(Tag, cast(ResultSet[Tag], cast(Tag, soup.find(
        'ul', id='episode_page')).find_all('li'))[-1].find('a')).get_text().split('-')[-1]
    tag = soup.find('a', title="Ongoing Anime")
    is_ongoing = False
    if tag:
        is_ongoing = True

    return AnimeMetadata(poster_link, summary, int(episode_count), is_ongoing, genres, release_year)


def dub_available(anime_title: str) -> bool:
    dub_title = f'{anime_title}{DUB_EXTENSION}'
    results = search(dub_title)
    for result in results:
        title = cast(str, cast(Tag, result.find('a'))['title'])
        if dub_title == title:
            return True
    return False


def get_dub_anime_page_link(anime_title: str) -> str:
    dub_title = f'{anime_title}{DUB_EXTENSION}'
    results = search(dub_title)
    page_link = ''
    for result in results:
        title = cast(str, cast(Tag, result.find('a'))['title'])
        if dub_title == title:
            page_link = GOGO_HOME_URL + \
                cast(str, cast(Tag, result.find('a'))['href'])
            break
    return page_link

# To handle a case like for Jujutsu Kaisen 2nd Season where when there is TV in the anime page link it misses in the episode page links


def fix_dead_episode_page_link(episode_page_link: str) -> str:
    return episode_page_link.replace('-tv', '')

# Hls mode functions start here


def get_embed_url(episode_page_link: str) -> str:
    response = cast(requests.Response, network_error_retry_wrapper(
        lambda: requests.get(episode_page_link, headers=REQUEST_HEADERS)))
    if response.status_code != 200:
        episode_page_link = fix_dead_episode_page_link(episode_page_link)
        response = cast(requests.Response, network_error_retry_wrapper(
            lambda: requests.get(episode_page_link, headers=REQUEST_HEADERS)))
    soup = BeautifulSoup(response.content, PARSER)
    return cast(str, cast(Tag, soup.select_one('iframe'))['src'])


def aes_encrypt(data: str, *, key, iv) -> bytes:
    backend = default_backend()
    cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=backend)
    encryptor = cipher.encryptor()
    padder = PKCS7(128).padder()
    padded_data = padder.update(data.encode()) + padder.finalize()
    return base64.b64encode(encryptor.update(padded_data) + encryptor.finalize())


def aes_decrypt(data: str, *, key, iv) -> str:
    backend = default_backend()
    cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=backend)
    decryptor = cipher.decryptor()
    decrypted_data = decryptor.update(
        base64.b64decode(data)) + decryptor.finalize()
    unpadder = PKCS7(128).unpadder()
    unpadded_data = unpadder.update(decrypted_data) + unpadder.finalize()
    return unpadded_data.decode()


def extract_stream_url(embed_url: str) -> str:
    parsed_url = parseUrl(embed_url)
    content_id = parsed_url.query['id']
    streaming_page_host = f'https://{parsed_url.host}/'
    streaming_page = cast(bytes, network_error_retry_wrapper(
        lambda: requests.get(embed_url, headers=REQUEST_HEADERS).content))

    encryption_key, iv, decryption_key = (
        _.group(1) for _ in KEYS_REGEX.finditer(streaming_page)
    )
    component = aes_decrypt(
        cast(re.Match[bytes], ENCRYPTED_DATA_REGEX.search(
            streaming_page)).group(1).decode(),
        key=encryption_key,
        iv=iv,
    ) + "&id={}&alias={}".format(
        aes_encrypt(content_id, key=encryption_key,
                    iv=iv).decode(), content_id
    )

    component = component.split("&", 1)[1]
    ajax_response = cast(requests.Response, network_error_retry_wrapper(lambda: requests.get(
        streaming_page_host + "encrypt-ajax.php?" + component,
        headers={"x-requested-with": "XMLHttpRequest",
                 'User-Agent': REQUEST_HEADERS['User-Agent']},
    )))
    content = json.loads(
        aes_decrypt(ajax_response.json()[
            'data'], key=decryption_key, iv=iv)
    )

    try:
        source = content["source"]
        stream_url = source[0]["file"]
    except KeyError:
        source = content["source_bk"]
        stream_url = source[0]["file"]
    return stream_url


class GetHlsLinks(PausableAndCancellableFunction):
    def __init__(self) -> None:
        super().__init__()

    def get_hls_links(self, episode_page_links: list[str], progress_update_callback: Callable = lambda x: None) -> list[str]:
        hls_links: list[str] = []
        for eps_url in episode_page_links:
            self.resume.wait()
            hls_links.append(extract_stream_url(get_embed_url(eps_url)))
            if self.cancelled:
                return []
            progress_update_callback(1)
        return hls_links


def test_getting_episode_page_links(anime_title: str, start_episode: int, end_episode: int, sub_or_dub='sub') -> list[str]:
    result = search(anime_title)[0]
    anime_title, anime_page_link = cast(
        tuple[str, str], extract_anime_title_and_page_link(result))
    if sub_or_dub == 'dub' and dub_available(anime_title):
        anime_page_link = cast(str, dub_available(anime_title))
    get_anime_metadata(anime_page_link)
    episode_page_links = generate_episode_page_links(
        start_episode, end_episode, anime_page_link)
    for p in episode_page_links:
        print(p)
    return episode_page_links


def test_getting_direct_download_links(episode_page_links: list[str], quality: str):
    download_page_links = GetDownloadPageLinks().get_download_page_links(
        episode_page_links)
    driver_manager = DriverManager()
    driver = driver_manager.setup_driver()
    direct_download_links = GetDirectDownloadLinks().get_direct_download_link_as_per_quality(
        download_page_links, quality, driver, max_load_wait_time=50)
    CalculateTotalDowloadSize().calculate_total_download_size(
        direct_download_links)
    driver_manager.close_driver()
    for p in direct_download_links:
        print(p)
    return direct_download_links


def test_getting_hls_links(episode_page_links: list[str]) -> list[str]:
    hls_links = GetHlsLinks().get_hls_links(episode_page_links)
    for h in hls_links:
        print(h)
    return hls_links


def main():
    # Download settings
    anime_title = 'Senyuu'
    quality = '360p'
    sub_or_dub = 'sub'
    start_episode = 5
    end_episode = 5

    episode_page_links = test_getting_episode_page_links(
        anime_title, start_episode, end_episode, sub_or_dub)
    # direct_download_links = test_getting_direct_download_links(episode_page_links, quality)
    # hls_links = test_getting_hls_links(episode_page_links)
    # test_downloading(anime_title, hls_links, True, quality)
    # test_downloading(anime_title, direct_download_links)


if __name__ == "__main__":
    main()
