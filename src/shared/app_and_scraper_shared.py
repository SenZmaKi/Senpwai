import os
import sys
from time import sleep as timesleep
from typing import Callable, Any, cast, Iterator
import requests
from string import printable, digits, ascii_letters
import re
import subprocess
from threading import Event
from fake_useragent import UserAgent
from bs4 import BeautifulSoup, Tag
from shared.global_vars_and_funcs import log_exception, delete_file

PARSER = 'html.parser'
IBYTES_TO_MBS_DIVISOR = 1024*1024
QUALITY_REGEX_1 = re.compile(r'\b(\d{3,4})p\b')
QUALITY_REGEX_2 = re.compile(r'\b\d+x(\d+)\b')
NETWORK_RETRY_WAIT_TIME = 5
GITHUB_README_URL = "https://github.com/SenZmaKi/Senpwai/blob/master/README.md"
RESOURCE_MOVED_STATUS_CODES = (301, 302, 307, 308)

class Client():

    def __init__(self) -> None:
        self.headers = self.setup_request_headers()

    def setup_request_headers(self) -> dict[str, str]:
        headers = {'User-Agent': UserAgent().random}
        return headers

    def append_headers(self, to_append: dict) -> dict:
        to_append.update(self.headers)
        return to_append

    def make_request(self, method: str, url: str, headers: dict | None, cookies={}, stream=False, data: dict | bytes | None = None, json: dict | None = None,  allow_redirects=False, timeout: int | None = None) -> requests.Response:
        if not headers:
            headers = self.headers
        if method == 'GET':
            def func(): return requests.get(url, headers=headers, stream=stream,
                                            cookies=cookies, allow_redirects=allow_redirects, timeout=timeout)
        else:
            def func(): return requests.post(url, headers=headers, cookies=cookies,
                                             data=data, json=json, allow_redirects=allow_redirects)
        return cast(requests.Response, self.network_error_retry_wrapper(func))

    def get(self, url: str, stream=False, headers: dict | None = None, timeout: int | None = None, cookies={}) -> requests.Response:
        return self.make_request("GET", url, headers, stream=stream, timeout=timeout, cookies=cookies)

    def post(self, url: str, data: dict | bytes | None = None, json: dict | None = None, headers: dict | None = None, cookies={}, allow_redirects=False) -> requests.Response:
        return self.make_request('POST', url, headers, data=data, json=json, cookies=cookies, allow_redirects=allow_redirects)

    def network_error_retry_wrapper(self, callback: Callable[[], Any]) -> Any:
        while True:
            try:
                return callback()
            except requests.exceptions.RequestException as e:
                log_exception(e)
                timesleep(1)


CLIENT = Client()


class QualityAndIndices:
    def __init__(self, quality: int, index: int):
        self.quality = quality
        self.index = index


class AnimeMetadata:
    def __init__(self, poster_url: str, summary: str, episode_count: int, status: str, genres: list[str], release_year: int):
        self.poster_url = poster_url
        self.summary = summary
        self.episode_count = episode_count
        self.airing_status = status
        self.genres = genres
        self.release_year = release_year

    def get_poster_bytes(self) -> bytes:
        response = CLIENT.get(self.poster_url)
        return response.content


def match_quality(potential_qualities: list[str], user_quality: str) -> int:
    detected_qualities: list[tuple[int, int]] = []
    user_quality = user_quality.replace('p', '')
    for idx, potential_quality in enumerate(potential_qualities):
        match = QUALITY_REGEX_1.search(potential_quality)
        if not match:
            match = QUALITY_REGEX_2.search(potential_quality)

        if match:
            quality = cast(str, match.group(1))
            if quality == user_quality:
                return idx
            else:
                detected_qualities.append((int(quality), idx))
    int_user_quality = int(user_quality)
    if detected_qualities == []:
        if int_user_quality <= 480:
            return 0
        return -1

    detected_qualities.sort(key=lambda x: x[0])
    closest = detected_qualities[0]
    for quality in detected_qualities:
        if quality[0] > int_user_quality:
            break
        closest = quality
    return closest[1]

def run_process(args: list[str]) -> subprocess.CompletedProcess[bytes]:
    if sys.platform == "win32":
        return subprocess.run(args)
    return subprocess.run(args)

def sanitise_title(title: str, all=False, exclude='') -> str:
    if all:
        allowed_chars = set(ascii_letters + digits + exclude)
    else:
        allowed_chars = set(printable) - set('\\/:*?"<>|')
        title = title.replace(':', ' -')
    sanitised = ''.join([char for char in title if char in allowed_chars])

    return sanitised[:255].rstrip()


def dynamic_episodes_predictor_initialiser_pro_turboencapsulator(start_episode: int, end_episode: int, haved_episodes: list[int]) -> list[int]:
    predicted_episodes_to_download: list[int] = []
    for episode in range(start_episode, end_episode+1):
        if episode not in haved_episodes:
            predicted_episodes_to_download.append(episode)
    return predicted_episodes_to_download


def ffmpeg_is_installed() -> bool:
    try:
        run_process(["ffmpeg"])
        return True
    except FileNotFoundError:
        return False


class PausableAndCancellableFunction:
    def __init__(self) -> None:
        self.resume = Event()
        self.resume.set()
        self.cancelled = False

    def pause_or_resume(self):
        if self.resume.is_set():
            return self.resume.clear()
        self.resume.set()

    def cancel(self):
        if self.resume.is_set():
            self.cancelled = True


class Download(PausableAndCancellableFunction):
    def __init__(self, link_or_segment_urls: str | list[str], episode_title: str, download_folder_path: str, progress_update_callback: Callable = lambda x: None, file_extension='.mp4', is_hls_download=False, cookies=requests.sessions.RequestsCookieJar()) -> None:
        super().__init__()
        self.link_or_segment_urls = link_or_segment_urls
        self.episode_title = episode_title
        self.file_extension = file_extension
        self.download_folder_path = download_folder_path
        self.progress_update_callback = progress_update_callback
        self.is_hls_download = is_hls_download
        self.cookies = cookies
        file_title = f'{self.episode_title}{self.file_extension}'
        self.file_path = os.path.join(self.download_folder_path, file_title)
        ext = ".ts" if is_hls_download else file_extension
        temporary_file_title = f'{self.episode_title} [Downloading]{ext}'
        self.temporary_file_path = os.path.join(
            self.download_folder_path, temporary_file_title)
        if os.path.isfile(self.temporary_file_path):
            delete_file(self.temporary_file_path)

    def cancel(self):
        return super().cancel()

    def start_download(self):
        download_complete = False
        while not download_complete and not self.cancelled:
            if self.is_hls_download:
                download_complete = self.hls_download()
            else:
                download_complete = self.normal_download()
        if self.cancelled:
            delete_file(self.temporary_file_path)
            return
        delete_file(self.file_path)
        if self.is_hls_download:
            if sys.platform == "win32":
                subprocess.run(
                    ['ffmpeg', '-i', self.temporary_file_path, '-c', 'copy', self.file_path], creationflags=subprocess.CREATE_NO_WINDOW)
            else:
                subprocess.run(
                    ['ffmpeg', '-i', self.temporary_file_path, '-c', 'copy', self.file_path])
            return delete_file(self.temporary_file_path)
        try:
            return os.rename(self.temporary_file_path, self.file_path)
        except PermissionError:  # Maybe they started watching the episode on VLC before it finished downloading now VLC has a handle to the file hence PermissionDenied
            pass

    def hls_download(self) -> bool:
        with open(self.temporary_file_path, "wb") as f:
            for seg in self.link_or_segment_urls:
                response = CLIENT.get(seg)
                self.resume.wait()
                if self.cancelled:
                    return False
                f.write(response.content)
                self.progress_update_callback(1)
            return True

    def normal_download(self) -> bool:
        self.link_or_segment_urls = cast(str, self.link_or_segment_urls)
        response = CLIENT.get(self.link_or_segment_urls,
                              stream=True, timeout=30, cookies=self.cookies)

        def response_ranged(start_byte):
            self.link_or_segment_urls = cast(str, self.link_or_segment_urls)
            return CLIENT.get(self.link_or_segment_urls, stream=True, headers=CLIENT.append_headers({'Range': f'bytes={start_byte}-'}), timeout=30, cookies=self.cookies)

        total = int(response.headers.get('Content-Length', 0))

        def download(start_byte: int = 0) -> bool:
            mode = 'wb' if start_byte == 0 else 'ab'
            with open(self.temporary_file_path, mode) as file:
                iter_content = cast(Iterator[bytes], response.iter_content(chunk_size=IBYTES_TO_MBS_DIVISOR) if start_byte == 0 else CLIENT.network_error_retry_wrapper(
                    lambda: response_ranged(start_byte).iter_content(chunk_size=IBYTES_TO_MBS_DIVISOR)))
                while True:
                    try:
                        def get_data(): return next(iter_content)
                        data = cast(
                            bytes, CLIENT.network_error_retry_wrapper(get_data))
                        self.resume.wait()
                        if self.cancelled:
                            return False
                        size = file.write(data)
                        self.progress_update_callback(size)
                    except StopIteration:
                        break

            file_size = os.path.getsize(self.temporary_file_path)
            return True if file_size >= total else download(file_size)
        return download()


if __name__ == "__main__":
    pass
