from typing import Any, cast
from scripts.announce.utils import FailedToAnnounce
from scripts.utils import ARGS, ROOT_DIR, get_piped_input
import json
import requests
import re
from scripts.utils import log_info

ACCESS_TOKEN_URL = "https://www.reddit.com/api/v1/access_token"
SUBMIT_POST_URL = "https://oauth.reddit.com/api/submit"
APPROVE_POST_URL = "https://oauth.reddit.com/api/approve"
POST_ID_REGEX = re.compile(
    r"https://www\.reddit\.com/r/Senpwai/comments/([a-zA-Z0-9_]+)/"
)


def validate_response(is_ok: bool, response_json: dict[str, Any]) -> None:
    # Only valid in submit_post
    success = response_json.get("success", None)
    if not is_ok or success is not None and not success:
        raise FailedToAnnounce("reddit", response_json)


def fetch_access_token() -> str:
    with open(ROOT_DIR.joinpath(".credentials/reddit.json"), "r") as f:
        credentials = json.load(f)
        data = {
            "scope": "*",
            "grant_type": "password",
            "username": credentials["username"],
            "password": credentials["password"],
        }
        headers = {"User-Agent": "script"}
        auth = (credentials["client_id"], credentials["client_secret"])
        response = requests.post(
            ACCESS_TOKEN_URL, data=data, headers=headers, auth=auth
        )
        validate_response(response.ok, response.json())
        return response.json()["access_token"]


def submit_post(
    title: str,
    release_notes: str,
    access_token: str,
) -> str:
    headers = {"Authorization": f"Bearer {access_token}", "User-Agent": "script"}

    data = {
        "title": title,
        "kind": "self",
        "sr": "Senpwai",
        "resubmit": "true",
        "send_replies": "true",
        "text": release_notes,
    }

    response = requests.post(SUBMIT_POST_URL, headers=headers, data=data)
    response_json = response.json()
    validate_response(response.ok, response_json)
    return cast(re.Match, POST_ID_REGEX.search(response.text)).group(1)


def approve_post(post_short_id: str, access_token: str) -> None:
    headers = {"Authorization": f"Bearer {access_token}", "User-Agent": "script"}
    response = requests.post(
        APPROVE_POST_URL, headers=headers, data={"id": f"t3_{post_short_id}"}
    )
    response_json = response.json()
    validate_response(response.ok, response_json)


def main(title: str, release_notes: str) -> None:
    log_info("Fetching auth token")
    access_token = fetch_access_token()
    log_info("Submitting post")
    post_short_id = submit_post(title, release_notes, access_token)
    log_info("Approving post")
    approve_post(post_short_id, access_token)


if __name__ == "__main__":
    main(ARGS[0], get_piped_input())
