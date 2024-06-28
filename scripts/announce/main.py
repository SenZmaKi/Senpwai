from scripts.announce import discord
from scripts.announce import reddit
from scripts.common import log_info


def main(title: str, release_notes: str) -> None:
    log_info("Announcing on Discord")
    discord.main(title, release_notes)
    log_info("Posting on Reddit")
    reddit.main(title, release_notes)
