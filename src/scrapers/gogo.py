from bs4 import BeautifulSoup, ResultSet, Tag
from requests.cookies import RequestsCookieJar
from random import choice as randomchoice

from typing import Callable, cast, Any
from shared.app_and_scraper_shared import PARSER, CLIENT, match_quality, IBYTES_TO_MBS_DIVISOR, PausableAndCancellableFunction, AnimeMetadata, get_new_domain_name_from_readme, sanitise_title

# Hls mode imports
import json
from yarl import URL
import base64
import re
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.padding import PKCS7
from cryptography.hazmat.backends import default_backend

GOGO = 'gogo'
GOGO_HOME_URL = 'https://gogoanimehd.io'
DUB_EXTENSION = ' (Dub)'
REGISTERED_ACCOUNT_EMAILS = ['benida7218@weirby.com', 'hareki4411@wisnick.com' ,'nanab67795@weirby.com', 'xener53725@weirby.com', 'nenado3105@weirby.com', 
                             'yaridod257@weirby.com', 'ketoh33964@weirby.com', 'kajade1254@wisnick.com', 'nakofe3005@weirby.com', 'gedidij506@weirby.com',
                             'sihaci1525@undewp.com', 'lorimob952@soebing.com', 'nigeha6048@undewp.com', 'goriwij739@undewp.com', 'pekivik280@soebing.com'
                             'hapas66158@undewp.com', 'wepajof522@undewp.com', 'semigo1458@undewp.com', 'xojecog864@undewp.com', 'lobik97135@wanbeiz.com' ]

SESSION_COOKIES: RequestsCookieJar | None = None
# Hls mode constants
KEYS_REGEX = re.compile(rb'(?:container|videocontent)-(\d+)')
ENCRYPTED_DATA_REGEX = re.compile(rb'data-value="(.+?)"')


def search(keyword: str, ignore_dub=True) -> list[tuple[str, str]]:
    ajax_search_url = 'https://ajax.gogo-load.com/site/loadAjaxSearch?keyword='+keyword
    response = CLIENT.get(ajax_search_url)
    content = response.json()['content']
    soup = BeautifulSoup(content, PARSER)
    a_tags = cast(list[Tag], soup.find_all('a'))
    title_and_link: list[tuple[str, str]] = []
    for a in a_tags:
        title = a.text
        link = f'{GOGO_HOME_URL}/{a["href"]}'
        if DUB_EXTENSION in title and ignore_dub:
            continue
        title_and_link.append((title, link))
    return title_and_link


def extract_anime_id(anime_page_content: bytes) -> int:
    soup = BeautifulSoup(anime_page_content, PARSER)
    anime_id = cast(str, cast(Tag, soup.find(
        'input', id='movie_id'))['value'])
    return int(anime_id)


def get_download_page_links(start_episode: int, end_episode: int, anime_id: int) -> list[str]:
    ajax_url = f'https://ajax.gogo-load.com/ajax/load-list-episode?ep_start={start_episode}&ep_end={end_episode}&id={anime_id}'
    content = CLIENT.get(ajax_url).content
    soup = BeautifulSoup(content, PARSER)
    a_tags = soup.find_all('a')
    episode_page_links: list[str] = []
    # Reversed cause their ajax api returns the episodes in reverse order i.e 3, 2, 1
    for a in reversed(a_tags):
        resource = cast(str, a['href']).strip()
        episode_page_links.append(GOGO_HOME_URL + resource)
    return episode_page_links

class GetDirectDownloadLinks(PausableAndCancellableFunction):
    def __init__(self) -> None:
        super().__init__()

    def get_direct_download_links(self, download_page_links: list[str], user_quality: str, progress_update_callback: Callable = lambda x: None) -> list[str]:
        direct_download_links: list[str] = []
        for eps_pg_link in download_page_links:
            link = ''
            while link == '':
                response = CLIENT.get(eps_pg_link, cookies=get_session_cookies())
                soup = BeautifulSoup(response.content, PARSER)
                a_tags = cast(ResultSet[Tag], cast(Tag, soup.find('div', class_='cf-download')).find_all('a'))
                qualities = [a.text for a in a_tags]
                idx = match_quality(qualities, user_quality)
                redirect_link = cast(str, a_tags[idx]['href'])
                link = CLIENT.get(redirect_link, cookies=get_session_cookies()).headers.get('Location', redirect_link)
            direct_download_links.append(link)
            self.resume.wait()
            if self.cancelled:
                return []
            progress_update_callback(1)
        return direct_download_links


class CalculateTotalDowloadSize(PausableAndCancellableFunction):
    def __init__(self):
        super().__init__()

    def calculate_total_download_size(self, direct_download_links: list[str], progress_update_callback: Callable = lambda update: None, in_megabytes=False) -> int:
        total_size = 0
        for link in (direct_download_links):
            response = CLIENT.get(link, stream=True, cookies=get_session_cookies())
            size = response.headers.get('Content-Length', 0)
            if in_megabytes:
                total_size += round(int(size) / IBYTES_TO_MBS_DIVISOR)
            else:
                total_size += int(size)
            self.resume.wait()
            if self.cancelled:
                return 0
            progress_update_callback(1)
        return total_size

def get_anime_page_content(anime_page_link: str) -> tuple[bytes, str]:
    """
    Returns a string too which is the new anime_page_link if there was a change in Gogo's domain name
    """
    response = CLIENT.get(anime_page_link)
    # we assume they changed domain names if the status code isn't 200
    if response.status_code != 200:
        global GOGO_HOME_URL
        prev_home_url = GOGO_HOME_URL
        GOGO_HOME_URL = get_new_domain_name_from_readme(GOGO)
        anime_page_link.replace(prev_home_url, GOGO_HOME_URL)
        return CLIENT.get(anime_page_link).content, anime_page_link
    return response.content, anime_page_link



def extract_anime_metadata(anime_page_content: bytes) -> AnimeMetadata:
    soup = BeautifulSoup(anime_page_content, PARSER)
    poster_link = cast(str, cast(Tag, cast(Tag, soup.find(
        class_='anime_info_body_bg')).find('img'))['src'])
    metadata_tags = soup.find_all('p', class_='type')
    summary = metadata_tags[1].get_text().replace('Plot Summary: ', '')
    genre_tags = cast(ResultSet[Tag], metadata_tags[2].find_all('a'))
    genres = cast(list[str], [g['title'] for g in genre_tags])
    release_year = int(metadata_tags[3].get_text().replace('Released: ', ''))
    episode_count = int(cast(Tag, cast(ResultSet[Tag], cast(Tag, soup.find(
        'ul', id='episode_page')).find_all('li'))[-1].find('a')).get_text().split('-')[-1])
    tag = soup.find('a', title="Ongoing Anime")
    if tag:
        status = "ONGOING"
    elif episode_count == 0:
        status = "UPCOMING"
    else:
        status = "FINISHED"

    return AnimeMetadata(poster_link, summary, episode_count, status, genres, release_year)


def dub_availability_and_link(anime_title: str) -> tuple[bool, str]:
    dub_title = f'{anime_title}{DUB_EXTENSION}'
    results = search(dub_title, False)
    for res_title, link in results:
        if dub_title == res_title:
            return True, link 
    return False, ''

# Hls mode functions start here

def get_embed_url(episode_page_link: str) -> str:
    response = CLIENT.get(episode_page_link)
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
    parsed_url = URL(embed_url)
    content_id = parsed_url.query['id']
    streaming_page_host = f'https://{parsed_url.host}/'
    streaming_page = CLIENT.get(embed_url).content

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
    ajax_response = CLIENT.get(
        streaming_page_host + "encrypt-ajax.php?" + component,
        headers=CLIENT.append_headers({"x-requested-with": "XMLHttpRequest"}),
    )
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

class GetMatchedQualityLinks(PausableAndCancellableFunction):
    def __init__(self) -> None:
        super().__init__()
        
    def get_matched_quality_link(self, hls_links: list[str], quality: str, progress_update_callback: Callable[[int], None] = lambda x: None) -> list[str]:
        matched_links: list[str] = []
        for h in hls_links:
            response = CLIENT.get(h)
            self.resume.wait()
            if self.cancelled:
                return []
            lines = response.text.split(',')
            qualities = [line for line in lines if "NAME=" in line]
            idx = match_quality(qualities, quality)
            resource = qualities[idx].splitlines()[1]
            base_url = URL(h).parent
            matched_links.append(f"{base_url}/{resource}")
            progress_update_callback(1)
        return matched_links
class GetSegmentsUrls(PausableAndCancellableFunction):
    def __init__(self) -> None:
        super().__init__()

    def get_segments_urls(self, matched_links: list[str], progress_update_callback: Callable[[int], None] = lambda x: None) -> list[list[str]]:
        segments_urls: list[list[str]] = []
        for m in matched_links:
            response = CLIENT.get(m)
            self.resume.wait()
            if self.cancelled:
                return []
            segments = response.text.splitlines()
            base_url = "/".join(m.split("/")[:-1])
            segment_urls: list[str] = []
            for seg in segments:
                if seg.endswith('.ts'):
                    segment_url = f"{base_url}/{seg}"
                    segment_urls.append(segment_url)
            segments_urls.append(segment_urls)
            progress_update_callback(1)
        return segments_urls
class GetHlsLinks(PausableAndCancellableFunction):
    def __init__(self) -> None:
        super().__init__()

    def get_hls_links(self, download_page_links: list[str], progress_update_callback: Callable = lambda x: None) -> list[str]:
        hls_links: list[str] = []
        for eps_url in download_page_links:
            hls_links.append(extract_stream_url(get_embed_url(eps_url)))
            self.resume.wait()
            if self.cancelled:
                return []
            progress_update_callback(1)
        return hls_links

def get_session_cookies(fresh=False) -> RequestsCookieJar:
    global SESSION_COOKIES
    if SESSION_COOKIES and not fresh:
        return SESSION_COOKIES
    login_url = f'{GOGO_HOME_URL}/login.html'
    response = CLIENT.get(login_url)
    soup = BeautifulSoup(response.content, PARSER)
    form_div = cast(Tag, soup.find('div', class_='form-login'))
    csrf_token = cast(Tag, form_div.find('input', {'name': '_csrf'}))['value']
    form_data = {"email": randomchoice(REGISTERED_ACCOUNT_EMAILS), 'password': 'amogus69420', "_csrf": csrf_token}
    # A valid User-Agent is required during this post request hence the CLIENT is technically only necessary here
    response = CLIENT.post(login_url, form_data, cookies=response.cookies)
    SESSION_COOKIES = response.cookies
    if len(SESSION_COOKIES) == 0:
        return get_session_cookies()
    return SESSION_COOKIES