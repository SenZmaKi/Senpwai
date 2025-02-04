from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.padding import PKCS7
from senpwai.scrapers.gogo.constants import KEYS_REGEX, ENCRYPTED_DATA_REGEX
from senpwai.common.scraper import (
    PARSER,
    CLIENT,
    ProgressFunction,
    closest_quality_index,
)
from bs4 import BeautifulSoup, Tag
from typing import cast, Callable
from yarl import URL
import base64
import re
import json


class GetHlsMatchedQualityLinks(ProgressFunction):
    def __init__(self) -> None:
        super().__init__()

    def get_hls_matched_quality_links(
        self,
        hls_links: list[str],
        quality: str,
        progress_update_callback: Callable[[int], None] | None = None,
    ) -> list[str]:
        matched_links: list[str] = []
        for link in hls_links:
            response = CLIENT.get(link)
            self.resume.wait()
            if self.cancelled:
                return []
            lines = response.text.split(",")
            qualities = [line for line in lines if "NAME=" in line]
            idx = closest_quality_index(qualities, quality)
            resource = qualities[idx].splitlines()[1]
            base_url = URL(link).parent
            matched_links.append(f"{base_url}/{resource}")
            if progress_update_callback:
                progress_update_callback(1)
        return matched_links


class GetHlsSegmentsUrls(ProgressFunction):
    def __init__(self) -> None:
        super().__init__()

    def get_hls_segments_urls(
        self,
        matched_links: list[str],
        progress_update_callback: Callable[[int], None] | None = None,
    ) -> list[list[str]]:
        segments_urls: list[list[str]] = []
        for link in matched_links:
            response = CLIENT.get(link)
            self.resume.wait()
            if self.cancelled:
                return []
            segments = response.text.splitlines()
            base_url = "/".join(link.split("/")[:-1])
            segment_urls: list[str] = []
            for seg in segments:
                if seg.endswith(".ts"):
                    segment_url = f"{base_url}/{seg}"
                    segment_urls.append(segment_url)
            segments_urls.append(segment_urls)
            if progress_update_callback: 
                progress_update_callback(1)
        return segments_urls


class GetHlsLinks(ProgressFunction):
    def __init__(self) -> None:
        super().__init__()

    def get_hls_links(
        self,
        download_page_links: list[str],
        progress_update_callback: Callable[[int], None] | None = None,
    ) -> list[str]:
        hls_links: list[str] = []
        for eps_url in download_page_links:
            hls_links.append(extract_stream_url(get_embed_url(eps_url)))
            self.resume.wait()
            if self.cancelled:
                return []
            if progress_update_callback:
                progress_update_callback(1)
        return hls_links


def get_embed_url(episode_page_link: str) -> str:
    response = CLIENT.get(episode_page_link)
    soup = BeautifulSoup(response.content, PARSER)
    return cast(str, cast(Tag, soup.select_one("iframe"))["src"])


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
    decrypted_data = decryptor.update(base64.b64decode(data)) + decryptor.finalize()
    unpadder = PKCS7(128).unpadder()
    unpadded_data = unpadder.update(decrypted_data) + unpadder.finalize()
    return unpadded_data.decode()


def extract_stream_url(embed_url: str) -> str:
    parsed_url = URL(embed_url)
    content_id = parsed_url.query["id"]
    streaming_page_host = f"https://{parsed_url.host}/"
    streaming_page = CLIENT.get(embed_url).content

    encryption_key, iv, decryption_key = (
        _.group(1) for _ in KEYS_REGEX.finditer(streaming_page)
    )
    component = aes_decrypt(
        cast(re.Match[bytes], ENCRYPTED_DATA_REGEX.search(streaming_page))
        .group(1)
        .decode(),
        key=encryption_key,
        iv=iv,
    ) + "&id={}&alias={}".format(
        aes_encrypt(content_id, key=encryption_key, iv=iv).decode(), content_id
    )

    component = component.split("&", 1)[1]
    ajax_response = CLIENT.get(
        streaming_page_host + "encrypt-ajax.php?" + component,
        headers=CLIENT.make_headers({"X-Requested-With": "XMLHttpRequest"}),
    )
    content = json.loads(
        aes_decrypt(ajax_response.json()["data"], key=decryption_key, iv=iv)
    )

    try:
        source = content["source"]
        stream_url = source[0]["file"]
    except KeyError:
        source = content["source_bk"]
        stream_url = source[0]["file"]
    return stream_url
