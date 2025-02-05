from enum import Enum
import os
import re
import subprocess
from base64 import b64decode
import random
from string import ascii_letters, digits, printable
from threading import Event
import threading
import time
from typing import Callable, Iterator, TypeVar, cast
from webbrowser import open_new_tab

import requests

from senpwai.common.static import OS, log_exception, try_deleting

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


class NoResourceLengthException(Exception):
    def __init__(self, url: str, redirect_url: str) -> None:
        msg = (
            f'Received no resource length from "{url}"'
            if url == redirect_url
            else f'Received no resource length from "{redirect_url}" redirected from "{url}"'
        )
        super().__init__(msg)


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
        headers = {"User-Agent": random.choice(USER_AGENTS)}
        return headers

    def make_headers(self, added_headers: dict) -> dict:
        added_headers.update(self.headers)
        return added_headers

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
        exceptions_to_raise: tuple[type[BaseException], ...] = (KeyboardInterrupt,),
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

        return self.network_error_retry_wrapper(callback, exceptions_to_raise)

    def get(
        self,
        url: str,
        stream=False,
        headers: dict | None = None,
        timeout: int | None = None,
        cookies={},
        allow_redirects=False,
        exceptions_to_raise: tuple[type[BaseException], ...] = (KeyboardInterrupt,),
    ) -> requests.Response:
        return self.make_request(
            "GET",
            url,
            headers,
            stream=stream,
            timeout=timeout,
            cookies=cookies,
            exceptions_to_raise=exceptions_to_raise,
            allow_redirects=allow_redirects,
        )

    def post(
        self,
        url: str,
        data: dict | bytes | None = None,
        json: dict | None = None,
        headers: dict | None = None,
        cookies={},
        allow_redirects=False,
        exceptions_to_raise: tuple[type[BaseException], ...] = (KeyboardInterrupt,),
    ) -> requests.Response:
        return self.make_request(
            "POST",
            url,
            headers,
            data=data,
            json=json,
            cookies=cookies,
            allow_redirects=allow_redirects,
            exceptions_to_raise=exceptions_to_raise,
        )

    def network_error_retry_wrapper(
        self,
        callback: Callable[[], T],
        exceptions_to_raise: tuple[type[BaseException], ...] = (KeyboardInterrupt,),
    ) -> T:
        while True:
            try:
                return callback()
            except requests.exceptions.RequestException as e:
                if isinstance(e, KeyboardInterrupt):
                    raise
                if (
                    exceptions_to_raise is not None
                    and DomainNameError in exceptions_to_raise
                ):
                    e = DomainNameError(e) if has_valid_internet_connection() else e
                if exceptions_to_raise is not None and any(
                    [isinstance(e, exception) for exception in exceptions_to_raise]
                ):
                    raise e
                log_exception(e)
                time.sleep(1)


CLIENT = Client()


class AiringStatus(Enum):
    ONGOING = "Ongoing"
    UPCOMING = "Upcoming"
    FINISHED = "Finished"

    # Stack Overflow answer link: https://stackoverflow.com/a/66575463/17193072
    # Enums in python suck so bad
    def __eq__(self, other: object) -> bool:
        if type(self).__qualname__ != type(other).__qualname__:
            return False
        other = cast(AiringStatus, other)
        return self.value == other.value


class AnimeMetadata:
    def __init__(
        self,
        poster_url: str,
        summary: str,
        episode_count: int,
        airing_status: AiringStatus,
        genres: list[str],
        release_year: int,
    ):
        self.poster_url = poster_url
        self.summary = summary
        self.episode_count = episode_count
        self.airing_status = airing_status
        self.genres = genres
        self.release_year = release_year

    def get_poster_bytes(self) -> bytes:
        response = CLIENT.get(self.poster_url)
        return response.content


def closest_quality_index(potential_qualities: list[str], target_quality: str) -> int:
    detected_qualities: list[tuple[int, int]] = []
    target_quality = target_quality.replace("p", "")
    for idx, potential_quality in enumerate(potential_qualities):
        match = QUALITY_REGEX_1.search(potential_quality)
        if not match:
            match = QUALITY_REGEX_2.search(potential_quality)

        if match:
            quality = cast(str, match.group(1))
            if quality == target_quality:
                return idx
            else:
                detected_qualities.append((int(quality), idx))
    int_target_quality = int(target_quality)
    if not detected_qualities:
        if int_target_quality <= 480:
            return 0
        return -1

    detected_qualities.sort(key=lambda x: x[0])
    closest = detected_qualities[0]
    for quality in detected_qualities:
        if quality[0] > int_target_quality:
            break
        closest = quality
    return closest[1]


def run_process_silently(args: list[str]) -> subprocess.CompletedProcess[bytes]:
    if OS.is_windows:
        return subprocess.run(args, creationflags=subprocess.CREATE_NO_WINDOW)
    return subprocess.run(args, capture_output=True)


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
    elif OS.is_linux:
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

    elif OS.is_android:
        try:
            run_process_in_new_console("pkg update -y && pkg install ffmpeg -y")
        except Exception:
            pass
        if ffmpeg_is_installed():
            return True
        else:
            print(
                'Try running "pkg update && pkg install ffmpeg", if it doesn\'t work look up a guide on the internet'
            )
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


def strip_title(title: str, all=False, exclude="") -> str:
    if all:
        allowed_chars = set(ascii_letters + digits + exclude)
    else:
        allowed_chars = set(printable) - set('\\/:*?"<>|')
        title = title.replace(":", " -")
    title = title.rstrip(".")
    sanitised = "".join(char for char in title if char in allowed_chars)

    return sanitised[:255].rstrip()



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
        download_size: int,
        progress_update_callback: Callable = lambda _: None,
        file_extension=".mp4",
        is_hls_download=False,
        cookies=requests.sessions.RequestsCookieJar(),
        max_part_size=0,
    ) -> None:
        super().__init__()
        self.link_or_segment_urls = link_or_segment_urls
        self.episode_title = episode_title
        self.download_folder_path = download_folder_path
        self.progress_update_callback = progress_update_callback
        self.is_hls_download = is_hls_download
        self.cookies = cookies
        self.update_lock = threading.Lock()
        self.max_part_size = max_part_size
        file_title = f"{self.episode_title}{file_extension}"
        self.file_path = os.path.join(self.download_folder_path, file_title)
        self.download_size = download_size
        ext = ".ts" if is_hls_download else file_extension
        temp_file_title = f"{self.episode_title} [Downloading]{ext}"
        self.temp_path = os.path.join(self.download_folder_path, temp_file_title)
        self.rm_temp_path()

    @staticmethod
    def get_total_download_size(url: str) -> tuple[int, str]:
        response = CLIENT.get(url, stream=True, allow_redirects=True)
        resource_length_str = response.headers.get("Content-Length", None)
        redirect_url = response.url
        if resource_length_str is None:
            raise NoResourceLengthException(url, redirect_url)
        return (int(resource_length_str), redirect_url)

    def cancel(self):
        return super().cancel()

    def rm_temp_path(self):
        if os.path.isdir(self.temp_path):
            try_deleting(self.temp_path, is_dir=True)
        else:
            try_deleting(self.temp_path)

    def start_download(self):
        if self.is_hls_download:
            self.hls_download()
        else:
            self.normal_download()
        if self.cancelled:
            self.rm_temp_path()
            return
        try_deleting(self.file_path)
        if self.is_hls_download:
            run_process_silently(
                ["ffmpeg", "-i", self.temp_path, "-c", "copy", self.file_path]
            )
            self.rm_temp_path()
            return
        # Multipart file download
        if os.path.isdir(self.temp_path):
            part_file_names = os.listdir(self.temp_path)
            part_file_names.sort(key=lambda x: int(x.split(".")[0]))
            with open(self.file_path, "wb") as merged_file:
                for part_file_name in part_file_names:
                    part_file_path = os.path.join(self.temp_path, part_file_name)
                    with open(part_file_path, "rb") as part_file:
                        merged_file.write(part_file.read())
            self.rm_temp_path()
        else:
            try:
                os.rename(self.temp_path, self.file_path)
            # Maybe they started watching the episode on VLC before it finished downloading now VLC has a handle to the file hence PermissionDenied
            except PermissionError:
                pass

    def hls_download(self) -> None:
        with open(self.temp_path, "wb") as f:
            for seg in self.link_or_segment_urls:
                response = CLIENT.get(seg)
                self.resume.wait()
                if self.cancelled:
                    return
                f.write(response.content)
                self.progress_update_callback(1)

    def normal_download(self) -> None:
        def download(
            start_byte: int,
            part_size: int,
            temp_file_path: str,
            is_retry=False,
            thread_num=1,
        ) -> None:
            with open(temp_file_path, "ab" if is_retry else "wb") as file:
                end_byte = start_byte + part_size - 1
                self.link_or_segment_urls = cast(str, self.link_or_segment_urls)
                headers = CLIENT.make_headers(
                    {"Range": f"bytes={start_byte}-{end_byte}"}
                )
                response = CLIENT.get(
                    self.link_or_segment_urls,
                    stream=True,
                    headers=headers,
                    timeout=30,
                    cookies=self.cookies,
                )
                iter_content = cast(
                    Iterator[bytes],
                    response.iter_content(chunk_size=IBYTES_TO_MBS_DIVISOR),
                )
                while response.ok:
                    try:
                        downloaded_data = CLIENT.network_error_retry_wrapper(
                            lambda: next(iter_content)
                        )
                        self.resume.wait()
                        if self.cancelled:
                            return
                        data_size = file.write(downloaded_data)
                        with self.update_lock:
                            self.progress_update_callback(data_size)
                    except StopIteration:
                        break

            file_size = os.path.getsize(temp_file_path)
            if file_size < part_size:
                download(
                    file_size, part_size, temp_file_path, True, thread_num=thread_num
                )

        if not self.max_part_size or self.max_part_size >= self.download_size:
            download(0, self.download_size, self.temp_path)
            return

        download_threads: list[threading.Thread] = []
        current_size = 0
        part_num = 0
        os.mkdir(self.temp_path)
        while current_size < self.download_size:
            part_num += 1
            download_size = min(self.download_size - current_size, self.max_part_size)
            temp_file_path = os.path.join(self.temp_path, f"{part_num}.part")

            download_thread = threading.Thread(
                target=lambda: download(
                    current_size, download_size, temp_file_path, thread_num=part_num
                ),
                daemon=True,
            )
            download_thread.start()
            download_threads.append(download_thread)
            current_size += download_size
        # Not using join() since it doesn't honour KeyboardInterrupt
        while any(dt.is_alive() for dt in download_threads):
            time.sleep(0.1)


def test_multipart_download():
    from tqdm import tqdm
    url = "https://github.com/SenZmaKi/Senpwai/releases/download/v2.1.14/Senpcli-setup.exe"
    download_size, url = Download.get_total_download_size(url)
    title = "Senpcli-setup"
    max_part_size = 5 * IBYTES_TO_MBS_DIVISOR

    pbar = tqdm(
        total=download_size,
        desc=f"Downloading: {title}",
        unit="iB",
        unit_scale=True,
        bar_format="{l_bar}{bar}| {n_fmt}/{total_fmt} [{elapsed}<{remaining}, {rate_noinv_fmt}]",
        leave=True,
    )

    def update(added: int):
        pbar.update(added)

    download = Download(
        url,
        title,
        r"",
        progress_update_callback=update,
        max_part_size=max_part_size,
        download_size=download_size,
        file_extension=".exe",
    )
    start_time = time.time()
    download.start_download()
    end_time = time.time()
    time_taken = end_time - start_time
    print(f"\nTime taken: {time_taken:.2f} seconds")
    pbar.set_description(f"Downloaded: {title}")

if __name__ == "__main__":
    test_multipart_download()
