from tqdm import tqdm
import os
from time import sleep
from typing import Callable, Any, cast
import requests
from string import printable
import re

parser = 'html.parser'
ibytes_to_mbs_divisor = 1024*1024
quality_pattern = re.compile(r'\b(\d{3,4}p)\b')
network_retry_wait_time = 5


class QualityAndIndices:
    def __init__(self, quality: int, index: int):
        self.quality = quality
        self.index = index


def match_quality(potential_qualities: list[str], user_quality: str) -> int:
    detected_qualities: list[QualityAndIndices] = []
    for idx, potential_quality in enumerate(potential_qualities):
        match = quality_pattern.search(potential_quality)
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
        print(quality.quality)
        if quality.quality > int_user_quality:
            break
        closest = quality
    return closest.index


def sanitise_title(title: str):
    # Santises folder name to only allow names that windows can create a folder with
    valid_chars = set(printable) - set('\\/:*?"<>|')
    title = title.replace(':', ' -')
    sanitised = ''.join(filter(lambda c: c in valid_chars, title))
    return sanitised[:255].rstrip()


def network_error_retry_wrapper(function: Callable) -> Any:
    while True:
        try:
            return function()
        except (requests.exceptions.ConnectionError, requests.exceptions.ReadTimeout):
            sleep(1)


def test_downloading(anime_title: str, direct_download_links: list[str]):
    for idx, link in enumerate(direct_download_links):
        Download(link, f'{anime_title} Episode {idx+1}',
                 os.path.abspath("test-downloads"), console_app=True).start_download()


def dynamic_episodes_predictor_initialiser_pro_turboencapsulator(start_episode: int, end_episode: int, haved_episodes: list[int]) -> list[int]:
    predicted_episodes_to_download: list[int] = []
    for episode in range(start_episode, end_episode+1):
        if episode not in haved_episodes:
            predicted_episodes_to_download.append(episode)
    return predicted_episodes_to_download


class PausableFunction():
    def __init__(self) -> None:
        self.paused = False
        self.cancelled = False

    def pause_or_resume(self):
        self.paused = not self.paused

    def cancel(self):
        self.cancelled = True


class Download(PausableFunction):
    def __init__(self, link: str, episode_title: str, download_folder: str, progress_update_callback: Callable = lambda x: None, file_extension='.mp4', console_app=False) -> None:
        super().__init__()
        self.link = link
        self.title = episode_title
        self.extension = file_extension
        self.path = download_folder
        self.progress_update_callback = progress_update_callback
        self.console_app = console_app
        self.file_path = None

    def start_download(self):
        response = network_error_retry_wrapper(lambda: requests.get(
            self.link, stream=True, timeout=30))

        def response_ranged(start_byte): return requests.get(
            self.link, stream=True, headers={'Range': f'bytes={start_byte}-'}, timeout=30)

        total = int(response.headers.get('content-length', 0))
        file_title = f'{self.title}{self.extension}'
        temporary_file_title = f'{self.title} [Downloading]{self.extension}'
        temp_file_path = os.path.join(self.path, temporary_file_title)
        self.file_path = temp_file_path
        download_completed_file_path = os.path.join(self.path, file_title)
        progress_bar = None if not self.console_app else tqdm(
            desc=f' Downloading {self.title}: ', total=total, unit='iB', unit_scale=True, unit_divisor=float(ibytes_to_mbs_divisor))

        def handle_download(start_byte: int = 0) -> bool:
            mode = 'wb' if start_byte == 0 else 'ab'
            with open(temp_file_path, mode) as file:
                iter_content = response.iter_content(chunk_size=ibytes_to_mbs_divisor) if start_byte == 0 else network_error_retry_wrapper(
                    lambda: response_ranged(start_byte).iter_content(chunk_size=ibytes_to_mbs_divisor))
                while True:
                    try:
                        data = network_error_retry_wrapper(
                            lambda: (next(iter_content)))
                        if progress_bar and self.paused:
                            progress_bar.set_description(' Paused')
                        if progress_bar:
                            progress_bar.set_description(
                                f' Downloading {self.title}: ')
                        while self.paused:
                            continue
                        if self.cancelled:
                            return False
                        size = file.write(data)
                        self.progress_update_callback(size)
                        if progress_bar:
                            progress_bar.update(size)
                    except Exception:
                        break

            file_size = os.path.getsize(temp_file_path)
            return True if file_size >= total else handle_download(file_size)
        if not handle_download():
            os.unlink(temp_file_path)
            return
        os.rename(temp_file_path, download_completed_file_path)
        self.file_path = download_completed_file_path
        if progress_bar:
            progress_bar.set_description(f' Completed {self.title}')
