import os
from sys import platform
from time import sleep as timesleep
from typing import Callable, Any, cast, Iterator
import requests
from string import printable
import re
import subprocess
from threading import Event
from random_user_agent.user_agent import UserAgent
from random_user_agent.params import OperatingSystem, SoftwareName, SoftwareType, HardwareType
from random import choice as randomchoice
from bs4 import BeautifulSoup, Tag

PARSER = 'html.parser'
IBYTES_TO_MBS_DIVISOR = 1024*1024
QUALITY_REGEX = re.compile(r'\b(\d{3,4}p)\b')
NETWORK_RETRY_WAIT_TIME = 5
GITHUB_README_URL = "https://github.com/SenZmaKi/Senpwai/blob/master/README.md"
RESOURCE_MOVED_STATUS_CODES = (301, 302, 307, 308)


def extract_new_domain_name_from_readme(site_name: str) -> str:
    """
    Say Animepahe or Gogoanime change their domain name, now Senpwai makes an anime search but it gets a none 200 status code, 
    then it'll assume they changed their domain name. It'll try to extract the new domain name from the readme.
    So if the domain name changes be sure to update it in the readme, specifically in the hyperlinks i.e., [Animepahe](https://animepahe.ru)
    and without an ending / i.e., https://animepahe.ru instead of https://animepahe.ru/. Also test if Senpwai is properly extracting it incase you made a mistake.

    :param site_name: Can be either Animepahe or Gogoanime.
    """
    page_content = CLIENT.get(GITHUB_README_URL).content
    soup = BeautifulSoup(page_content, PARSER)
    new_domain_name =  cast(str, cast(Tag, soup.find('a', text=site_name))['href']).replace("\"", "").replace("\\", "")
    return new_domain_name
    


class Client():

    def __init__(self) -> None:
        self.headers = self.setup_request_headers()

    def setup_request_headers(self) -> dict[str, str]:
        if platform == 'win32':
            operating_systems = [OperatingSystem.WINDOWS.value]
        elif platform == 'linux':
            operating_systems = [OperatingSystem.LINUX.value]
        else:
            operating_systems = [OperatingSystem.DARWIN.value]
        software_names = [SoftwareName.CHROME.value, SoftwareName.FIREFOX.value,
                        SoftwareName.EDGE.value, SoftwareName.OPERA.value]
        software_types = [SoftwareType.WEB_BROWSER.value]
        hardware_types = [HardwareType.COMPUTER.value]
        if platform == 'darwin':
            software_types.append(SoftwareName.SAFARI.value)
        user_agent = randomchoice(UserAgent(limit=1000, software_names=software_names,
                                operating_systems=operating_systems, software_types=software_types,
                                hardware_types=hardware_types).get_user_agents())
        headers = {'User-Agent': user_agent['user_agent']}
        return headers
    
    def append_headers(self, to_append: dict) -> dict:
        new_headers = self.headers
        new_headers.update(to_append)
        return new_headers

    def make_request(self, method: str, url: str, headers: dict | None, cookies={}, stream=False, data: dict | bytes | None = None, json: dict | None = None,  allow_redirects=False, timeout: int | None = None) -> requests.Response:
        if not headers:
            headers = self.headers
        if method == 'GET':
            func = lambda: requests.get(url, headers=headers, stream=stream, cookies=cookies, allow_redirects=allow_redirects, timeout=timeout)
        else:
            func = lambda: requests.post(url, headers=headers, cookies=cookies, data=data, json=json, allow_redirects=allow_redirects)
        return cast(requests.Response, self.network_error_retry_wrapper(func))

    def get(self, url: str, stream=False, headers: dict | None = None, timeout: int | None = None) -> requests.Response:
        return self.make_request("GET", url, headers, stream=stream, timeout=timeout)

    def post(self, url: str, data: dict | bytes | None = None, json: dict | None = None, headers: dict | None = None, cookies={}, allow_redirects=False) -> requests.Response:
        return self.make_request('POST', url, headers, data=data, json=json, cookies=cookies, allow_redirects=allow_redirects)


    def network_error_retry_wrapper(self, callback: Callable[[], Any]) -> Any:
        while True:
            try:
                return callback()
            except (requests.exceptions.RequestException):
                    timesleep(1)
                    print('retrying')

CLIENT = Client()

class QualityAndIndices:
    def __init__(self, quality: int, index: int):
        self.quality = quality
        self.index = index


class AnimeMetadata:
    def __init__(self, poster_url: str, summary: str, episode_count: int, is_ongoing: bool, genres: list[str], release_year: int):
        self.poster_url = poster_url
        self.summary = summary
        self.episode_count = episode_count
        self.is_ongoing = is_ongoing
        self.genres = genres
        self.release_year = release_year

    def get_poster_bytes(self) -> bytes:
        return CLIENT.get(self.poster_url).content


def match_quality(potential_qualities: list[str], user_quality: str) -> int:
    detected_qualities: list[QualityAndIndices] = []
    for idx, potential_quality in enumerate(potential_qualities):
        match = QUALITY_REGEX.search(potential_quality)
        if match:
            quality = cast(str, match.group(1))
            if quality == user_quality:
                return idx
            else:
                quality = quality.replace('p', '')
                if quality.isdigit():
                    detected_qualities.append(
                        QualityAndIndices(int(quality), idx))
    int_user_quality = int(user_quality.replace('p', ''))
    if len(detected_qualities) <= 0:
        if int_user_quality <= 480:
            return 0
        return -1

    detected_qualities.sort(key=lambda x: x.quality)
    closest = detected_qualities[0]
    for quality in detected_qualities:
        if quality.quality > int_user_quality:
            break
        closest = quality
    return closest.index


def sanitise_title(title: str, all=False):
    def strip_all(x): return re.sub(r'[^a-zA-Z0-9]', '', x)
    if all:
        sanitised = strip_all(title)
    else:
        valid_chars = set(printable) - set('\\/:*?"<>|')
        title = title.replace(':', ' -')
        sanitised = ''.join(filter(lambda char: char in valid_chars, title))

    return sanitised[:255].rstrip()



def dynamic_episodes_predictor_initialiser_pro_turboencapsulator(start_episode: int, end_episode: int, haved_episodes: list[int]) -> list[int]:
    predicted_episodes_to_download: list[int] = []
    for episode in range(start_episode, end_episode+1):
        if episode not in haved_episodes:
            predicted_episodes_to_download.append(episode)
    return predicted_episodes_to_download


def ffmpeg_is_installed() -> bool:
    try:
        if platform == "win32":
            subprocess.run("ffmpeg", creationflags=subprocess.CREATE_NO_WINDOW)
        else:
            subprocess.run("ffmpeg")
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
    def __init__(self, link: str, episode_title: str, download_folder_path: str, progress_update_callback: Callable = lambda x: None, file_extension='.mp4', is_hls_download=False, hls_quality='') -> None:
        super().__init__()
        self.link = link
        self.episode_title = episode_title
        self.file_extension = file_extension
        self.download_folder_path = download_folder_path
        self.progress_update_callback = progress_update_callback
        self.is_hls_download = is_hls_download
        self.hls_resolution = hls_quality
        self.ffmpeg_process: subprocess.Popen
        file_title = f'{self.episode_title}{self.file_extension}'
        self.file_path = os.path.join(self.download_folder_path, file_title)
        temporary_file_title = f'{self.episode_title} [Downloading]{self.file_extension}'
        self.temporary_file_path = os.path.join(
            self.download_folder_path, temporary_file_title)
        if os.path.isfile(self.temporary_file_path):
            os.unlink(self.temporary_file_path)

    def cancel(self):
        if self.is_hls_download:
            self.ffmpeg_process.terminate()
        return super().cancel()

    def start_download(self):
        download_complete = False
        while not download_complete and not self.cancelled:
            if self.is_hls_download:
                download_complete = self.hls_download()
            else:
                download_complete = self.normal_download()
        if self.cancelled:
            if os.path.isfile(self.temporary_file_path):
                try:
                    os.unlink(self.temporary_file_path)
                except PermissionError:
                    pass
            return
        if os.path.isfile(self.file_path):
            os.unlink(self.file_path)
        # Incase the user opened the file before it completed downloading
        def rename():
            try:
                os.rename(self.temporary_file_path, self.file_path)
            except PermissionError:
                timesleep(10)
                return rename()

    def hls_download(self) -> bool:
        def get_potential_qualities(master_playlist_url: str) -> list[str]:
            response = CLIENT.get(master_playlist_url)
            lines = response.text.split(',')
            qualities = [line for line in lines if "NAME=" in line]
            return qualities

        def generate_ffmpeg_command(hls_link: str, resolution_index: int, file_path: str) -> list[str]:
            return ['ffmpeg', '-i', hls_link, '-map', f'0:p:{resolution_index}', '-c', 'copy', file_path]

        def download(hls_link: str, file_path: str, quality: str) -> bool:
            ep_qualities = get_potential_qualities(hls_link)
            target_quality_idx = match_quality(ep_qualities, quality)
            command = generate_ffmpeg_command(
                hls_link, target_quality_idx, file_path)
            if platform == 'win32':
                self.ffmpeg_process = subprocess.Popen(
                    args=command, creationflags=subprocess.CREATE_NO_WINDOW)
            else:
                self.ffmpeg_process = subprocess.Popen(
                    args=command
                )
            returncode = self.ffmpeg_process.wait()
            return True if returncode == 0 else False

        return download(self.link, self.temporary_file_path, self.hls_resolution)

    def normal_download(self) -> bool:
        response = CLIENT.get(self.link, stream=True, timeout=30)

        def response_ranged(start_byte): return CLIENT.get(self.link, stream=True, headers=CLIENT.append_headers({'Range': f'bytes={start_byte}-'}), timeout=30)

        total = int(response.headers.get('content-length', 0))

        def download(start_byte: int = 0) -> bool:
            mode = 'wb' if start_byte == 0 else 'ab'
            with open(self.temporary_file_path, mode) as file:
                iter_content = cast(Iterator[bytes], response.iter_content(chunk_size=IBYTES_TO_MBS_DIVISOR) if start_byte == 0 else CLIENT.network_error_retry_wrapper(
                    lambda: response_ranged(start_byte).iter_content(chunk_size=IBYTES_TO_MBS_DIVISOR)))
                while True:
                    try:
                        get_data = lambda: next(iter_content)
                        data = cast(bytes, CLIENT.network_error_retry_wrapper(get_data))
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
