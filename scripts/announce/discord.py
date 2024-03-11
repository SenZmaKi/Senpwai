import json
import requests
import re

from scripts.utils import ARGS, ROOT_DIR, get_piped_input
from scripts.announce.utils import FailedToAnnounce

CHANNEL_URL = "https://discord.com/api/v10/channels/1142774130689720370/messages"
URL_REGEX = re.compile(r"https://\S+")


def remove_embed_url(string: str) -> str:
    return URL_REGEX.sub(lambda x: f"<{x.group(0)}>", string)


def main(title: str, release_notes: str) -> None:
    with open(ROOT_DIR.joinpath(".credentials/discord.json")) as f:
        token = json.load(f)["token"]
        headers = {
            "Authorization": f"Bot {token}",
            "Content-Type": "application/json",
        }
        nonembed_notes = remove_embed_url(release_notes)
        smaller_titles = "\n".join(
            [
                line.replace("# ", "## ", 1) if line.strip().startswith("# ") else line
                for line in nonembed_notes.splitlines()
            ]
        )

        everyone = "@everyone\n" if "--ping_everyone" in ARGS else ""
        message = f"{everyone}# {title}\n\n" + smaller_titles
        payload = {
            "content": message,
        }
        response = requests.post(url=CHANNEL_URL, headers=headers, json=payload)
        if not response.ok:
            raise FailedToAnnounce("discord", response.json())


if __name__ == "__main__":
    main(ARGS[0], get_piped_input())
