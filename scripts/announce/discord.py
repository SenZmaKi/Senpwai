from argparse import ArgumentParser
from enum import Enum
import json
from typing import Any
import requests
import re

from scripts.common import ROOT_DIR, get_piped_input
from scripts.announce.common import FailedToAnnounce

CHANNEL_URL = "https://discord.com/api/v10/channels/{}/messages"
URL_REGEX = re.compile(r"https://\S+")


class ChannelID(Enum):
    general = "1131981620975517787"
    help = "1190075801815748648"
    bug_reports = "1134645830163378246"
    suggestions = "1134645775905861673"
    github_logs = "1205730845953097779"
    misc = "1211137093955362837"
    announcements = "1142774130689720370"

    def __str__(self) -> str:
        return self.name


def remove_embed_url(string: str) -> str:
    return URL_REGEX.sub(lambda x: f"<{x.group(0)}>", string)


def send_message(message: str, channel_id: str, message_reference_id: str) -> None:
    with open(ROOT_DIR / ".credentials" / "discord.json") as f:
        token = json.load(f)["token"]
        headers = {
            "Authorization": f"Bot {token}",
            "Content-Type": "application/json",
        }
        payload: dict[str, Any] = {
            "content": message,
        }
        if message_reference_id:
            payload["message_reference"] = {"message_id": message_reference_id}
        url = CHANNEL_URL.format(channel_id)
        response = requests.post(url, headers=headers, json=payload)
        if not response.ok:
            raise FailedToAnnounce("discord", response.json())


def main(
    title: str,
    message: str,
    is_release_notes=True,
    pinged_user_id="",
    message_reference_id="",
    channel_id=ChannelID.announcements.value,
) -> None:
    if is_release_notes:
        non_embed_notes = remove_embed_url(message)
        message = "\n".join(
            [
                line.replace("# ", "## ", 1) if line.strip().startswith("# ") else line
                for line in non_embed_notes.splitlines()
            ]
        )
    if pinged_user_id:
        ping_str = (
            "@everyone" if pinged_user_id == "everyone" else f"<@{pinged_user_id}>"
        )
        message = (
            f"{ping_str}\n{message}"
            if pinged_user_id == "everyone" and is_release_notes
            else f"{ping_str} {message}"
        )
    if title:
        message = f"# {title}\n{message}"
    send_message(message, channel_id, message_reference_id)


if __name__ == "__main__":
    parser = ArgumentParser(description="Message on Discord")
    parser.add_argument("-t", "--title", help="Title of the message", default="")
    parser.add_argument(
        "-m",
        "--message",
        help="Body of the message, will use stdin if not provided",
        default="",
    )
    parser.add_argument(
        "-irn",
        "--is_release_notes",
        action="store_true",
        help="Whether the message is release notes",
    )
    parser.add_argument(
        "-pui",
        "--pinged_user_id",
        type=str,
        help="ID of the user to ping",
        default="",
    )
    parser.add_argument(
        "-pe",
        "--ping_everyone",
        action="store_true",
        help="Ping everyone",
    )
    parser.add_argument(
        "-mri",
        "--message_reference_id",
        type=str,
        help="ID of the message to reply to",
        default="",
    )
    parser.add_argument(
        "-cid",
        "--channel_id",
        type=str,
        help="ID of the channel to send the message to",
        default="",
    )
    parser.add_argument(
        "-c",
        "--channel",
        type=lambda channel: ChannelID[channel],
        choices=list(ChannelID),
        help="Channel to send the message to",
        default=ChannelID.announcements,
    )
    parsed = parser.parse_args()
    message = parsed.message or get_piped_input()
    channel_id = parsed.channel_id or parsed.channel.value
    pinged_user_id = "everyone" if parsed.ping_everyone else parsed.pinged_user_id
    main(
        parsed.title,
        message,
        parsed.is_release_notes,
        pinged_user_id,
        parsed.message_reference_id,
        channel_id,
    )
