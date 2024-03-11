import os
import re
import subprocess
import sys
from base64 import b64decode
from string import ascii_letters, digits, printable
from threading import Event
from time import sleep as timesleep
from typing import  TypeVar, Callable, Iterator, cast
from random import choice as random_choice
from webbrowser import open_new_tab

import requests

from senpwai.utils.static import log_exception, try_deleting, OS

T = TypeVar("T")
PARSER = "html.parser"
IBYTES_TO_MBS_DIVISOR = 1024 * 1024
QUALITY_REGEX_1 = re.compile(r"\b(\d{3,4})p\b")
QUALITY_REGEX_2 = re.compile(r"\b\d+x(\d+)\b")
NETWORK_RETRY_WAIT_TIME = 5
GITHUB_API_README_URL = "https://api.github.com/repos/SenZmaKi/Senpwai/readme"
RESOURCE_MOVED_STATUS_CODES = (301, 302, 307, 308)

FFMPEG_WINDOWS_INSTALLATION_GUIDE = "https://www.hostinger.com/tutorials/how-to-install-ffmpeg#How_to_Install_FFmpeg_on_Windows"
FFMPEG_LINUX_INSTALLATION_GUIDE = "https://www.hostinger.com/tutorials/how-to-install-ffmpeg#How_to_Install_FFmpeg_on_Linux"
FFMPEG_MAC_INSTALLATION_GUIDE = "https://www.hostinger.com/tutorials/how-to-install-ffmpeg#How_to_Install_FFmpeg_on_macOS"
USER_AGENTS = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/117.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/117.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Safari/605.1.15",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/117.0",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/118.0",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/117.0",
    "Mozilla/5.0 (Windows NT 10.0; rv:109.0) Gecko/20100101 Firefox/117.0",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36 Edg/116.0.1938.69",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36 OPR/102.0.0.0",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36 OPR/101.0.0.0",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36 Edg/116.0.1938.76",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36 Edg/117.0.2045.31",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36 Edg/116.0.1938.81",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36 Edg/117.0.2045.36",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/116.0",
    "Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/118.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36 Edg/117.0.2045.43",
    "Mozilla/5.0 (X11; Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/118.0",
    "Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/116.0",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.75 Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0",
    "Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:109.0) Gecko/20100101 Firefox/115.0",
    "Mozilla/5.0 (Windows NT 10.0; rv:102.0) Gecko/20100101 Firefox/102.0",
    "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/116.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:102.0) Gecko/20100101 Firefox/102.0",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36 Edg/116.0.1938.62",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/115.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5.2 Safari/605.1.15",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36 Edg/117.0.2045.41",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/116.0",
    "Mozilla/5.0 (Windows NT 10.0; rv:109.0) Gecko/20100101 Firefox/118.0",
    "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; CrOS x86_64 14541.0.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Safari/605.1.15",
)


def get_new_home_url_from_readme(site_name: str) -> str:
    """
    If the either Animepahe's or Gogoanime's domain name changes be sure to update it in the readme, specifically in the hyperlinks i.e., [Animepahe](https://animepahe.ru)
    and without an ending "/" i.e., https://animepahe.ru instead of https://animepahe.ru/ Also test if Senpwai is properly extracting it incase you made a mistake.

    :param site_name: Can be either Animepahe or Gogoanime.
    :return: The new home url.
    """
    encoded_readme_text = CLIENT.get(GITHUB_API_README_URL).json()["content"]
    readme_text = b64decode(encoded_readme_text).decode("utf-8")
    new_domain_name = cast(
        re.Match, re.search(rf"\[{site_name}\]\((.*)\)", readme_text)
    ).group(1)
    return new_domain_name


class DomainNameError(Exception):
    message = "The domain might have changed"

    def __init__(self, original_exception: Exception) -> None:
        super().__init__(DomainNameError.message, original_exception)
        self.original_exception = original_exception


def has_valid_internet_connection() -> bool:
    try:
        requests.get("https://www.google.com")
        return True
    except requests.exceptions.RequestException:
        return False


class Client:
    def __init__(self) -> None:
        self.headers = self.setup_request_headers()

    def setup_request_headers(self) -> dict[str, str]:
        headers = {"User-Agent": random_choice(USER_AGENTS)}
        return headers

    def append_headers(self, to_append: dict) -> dict:
        to_append.update(self.headers)
        return to_append

    def make_request(
        self,
        method: str,
        url: str,
        headers: dict | None,
        cookies={},
        stream=False,
        data: dict | bytes | None = None,
        json: dict | None = None,
        allow_redirects=False,
        timeout: int | None = None,
        exceptions_to_ignore: tuple[type[Exception], ...] = (type(KeyboardInterrupt),),
    ) -> requests.Response:
        if not headers:
            headers = self.headers
        if method == "GET":

            def callback():
                return requests.get(
                    url,
                    headers=headers,
                    stream=stream,
                    cookies=cookies,
                    allow_redirects=allow_redirects,
                    timeout=timeout,
                )
        else:

            def callback():
                return requests.post(
                    url,
                    headers=headers,
                    cookies=cookies,
                    data=data,
                    json=json,
                    allow_redirects=allow_redirects,
                )

        return self.network_error_retry_wrapper(callback, exceptions_to_ignore)

    def get(
        self,
        url: str,
        stream=False,
        headers: dict | None = None,
        timeout: int | None = None,
        cookies={},
        exceptions_to_raise: tuple[type[Exception], ...] = (type(KeyboardInterrupt),),
    ) -> requests.Response:
        return self.make_request(
            "GET",
            url,
            headers,
            stream=stream,
            timeout=timeout,
            cookies=cookies,
            exceptions_to_ignore=exceptions_to_raise,
        )

    def post(
        self,
        url: str,
        data: dict | bytes | None = None,
        json: dict | None = None,
        headers: dict | None = None,
        cookies={},
        allow_redirects=False,
        exceptions_to_ignore: tuple[type[Exception], ...] = (type(KeyboardInterrupt),),
    ) -> requests.Response:
        return self.make_request(
            "POST",
            url,
            headers,
            data=data,
            json=json,
            cookies=cookies,
            allow_redirects=allow_redirects,
            exceptions_to_ignore=exceptions_to_ignore,
        )

    def network_error_retry_wrapper(
        self,
        callback: Callable[[], T],
        exceptions_to_ignore: tuple[type[Exception], ...] = (type(KeyboardInterrupt),),
    ) -> T:
        while True:
            try:
                return callback()
            except requests.exceptions.RequestException as e:
                if isinstance(e, KeyboardInterrupt):
                    raise
                if (
                    exceptions_to_ignore is not None
                    and DomainNameError in exceptions_to_ignore
                ):
                    e = DomainNameError(e) if has_valid_internet_connection() else e
                if exceptions_to_ignore is not None and any(
                    [isinstance(e, exception) for exception in exceptions_to_ignore]
                ):
                    raise e
                log_exception(e)
                timesleep(1)


CLIENT = Client()


class AnimeMetadata:
    def __init__(
        self,
        poster_url: str,
        summary: str,
        episode_count: int,
        status: str,
        genres: list[str],
        release_year: int,
    ):
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
    user_quality = user_quality.replace("p", "")
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
    if not detected_qualities:
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


def run_process_silently(args: list[str]) -> subprocess.CompletedProcess[bytes]:
    if OS.is_windows:
        return subprocess.run(args, creationflags=subprocess.CREATE_NO_WINDOW)
    return subprocess.run(args)


def run_process_in_new_console(
    args: list[str] | str,
) -> subprocess.CompletedProcess[bytes]:
    if OS.is_windows:
        return subprocess.run(args, creationflags=subprocess.CREATE_NEW_CONSOLE)
    return subprocess.run(args, shell=True)


def try_installing_ffmpeg() -> bool:
    if OS.is_windows:
        try:
            run_process_in_new_console("winget install Gyan.FFmpeg")
        # I should probably catch the specific exceptions but I'm too lazy to figure out all the possible exceptions
        except Exception as _:
            pass
        # Incase the installation was scuffed
        if ffmpeg_is_installed():
            return True
        else:
            open_new_tab(FFMPEG_WINDOWS_INSTALLATION_GUIDE)
            return False
    elif sys.platform == "linux":
        try:
            run_process_in_new_console(
                "sudo apt-get update && sudo apt-get install ffmpeg"
            )
        except Exception as _:
            pass
        if ffmpeg_is_installed():
            return True
        else:
            open_new_tab(FFMPEG_LINUX_INSTALLATION_GUIDE)
            return False

    else:
        try:
            run_process_in_new_console("brew install ffmpeg")
        except Exception as _:
            pass
        if ffmpeg_is_installed():
            return True
        else:
            open_new_tab(FFMPEG_MAC_INSTALLATION_GUIDE)
            return False


def fuzz_str(text: str) -> str:
    return sanitise_title(text, True).lower()


def sanitise_title(title: str, all=False, exclude="") -> str:
    if all:
        allowed_chars = set(ascii_letters + digits + exclude)
    else:
        allowed_chars = set(printable) - set('\\/:*?"<>|')
        title = title.replace(":", " -")
    sanitised = "".join([char for char in title if char in allowed_chars])

    return sanitised[:255].rstrip()


def lacked_episode_numbers(
    start_episode: int, end_episode: int, haved_episodes: list[int]
) -> list[int]:
    predicted_episodes_to_download: list[int] = []
    for episode in range(start_episode, end_episode + 1):
        if episode not in haved_episodes:
            predicted_episodes_to_download.append(episode)
    return predicted_episodes_to_download


def lacked_episodes(
    lacking_episode_numbers: list[int], episode_page_links: list[str]
) -> list[str]:
    # Episode count is what is used to generate lacking_episode_numbers, episode count is gotten from anime the page which uses subbed episodes count
    # so for an anime where sub episodes are ahead of dub the missing episodes will be outside the range of the episode_page_links
    first_eps_number = lacking_episode_numbers[0]
    return [
        episode_page_links[eps_number - first_eps_number]
        for eps_number in lacking_episode_numbers
    ]


def ffmpeg_is_installed() -> bool:
    try:
        run_process_silently(["ffmpeg"])
        return True
    except FileNotFoundError:
        return False


class ProgressFunction:
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


class Download(ProgressFunction):
    def __init__(
        self,
        link_or_segment_urls: str | list[str],
        episode_title: str,
        download_folder_path: str,
        progress_update_callback: Callable = lambda _: None,
        file_extension=".mp4",
        is_hls_download=False,
        cookies=requests.sessions.RequestsCookieJar(),
    ) -> None:
        super().__init__()
        self.link_or_segment_urls = link_or_segment_urls
        self.episode_title = episode_title
        self.download_folder_path = download_folder_path
        self.progress_update_callback = progress_update_callback
        self.is_hls_download = is_hls_download
        self.cookies = cookies
        file_title = f"{self.episode_title}{file_extension}"
        self.file_path = os.path.join(self.download_folder_path, file_title)
        ext = ".ts" if is_hls_download else file_extension
        temporary_file_title = f"{self.episode_title} [Downloading]{ext}"
        self.temporary_file_path = os.path.join(
            self.download_folder_path, temporary_file_title
        )
        if os.path.isfile(self.temporary_file_path):
            try_deleting(self.temporary_file_path)

    @staticmethod
    def get_resource_length(url: str) -> tuple[int, str]:
        response = CLIENT.get(url, stream=True)
        new_location = response.headers.get("Location", "")
        if not new_location and response.status_code in RESOURCE_MOVED_STATUS_CODES:
            return Download.get_resource_length(new_location)
        return (int(response.headers.get("Content-Length", 0)), url)

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
            try_deleting(self.temporary_file_path)
            return
        try_deleting(self.file_path)
        if self.is_hls_download:
            run_process_silently(
                ["ffmpeg", "-i", self.temporary_file_path, "-c", "copy", self.file_path]
            )
            return try_deleting(self.temporary_file_path)
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
        response = CLIENT.get(
            self.link_or_segment_urls, stream=True, timeout=30, cookies=self.cookies
        )

        def response_ranged(start_byte_num: int) -> requests.Response:
            self.link_or_segment_urls = cast(str, self.link_or_segment_urls)
            return CLIENT.get(
                self.link_or_segment_urls,
                stream=True,
                headers=CLIENT.append_headers({"Range": f"bytes={start_byte_num}-"}),
                timeout=30,
                cookies=self.cookies,
            )

        total = int(response.headers.get("Content-Length", 0))

        def download(start_byte_num=0) -> bool:
            mode = "wb" if start_byte_num == 0 else "ab"
            with open(self.temporary_file_path, mode) as file:
                iter_content = cast(
                    Iterator[bytes],
                    response.iter_content(chunk_size=IBYTES_TO_MBS_DIVISOR)
                    if start_byte_num == 0
                    else CLIENT.network_error_retry_wrapper(
                        lambda: response_ranged(start_byte_num).iter_content(
                            chunk_size=IBYTES_TO_MBS_DIVISOR
                        )
                    ),
                )
                while True:
                    try:

                        def get_data() -> bytes:
                            return next(iter_content)

                        data = CLIENT.network_error_retry_wrapper(get_data)
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
