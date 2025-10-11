import re

PAHE = "pahe"
PAHE_DOMAIN = "animepahe.si"
PAHE_HOME_URL = f"https://{PAHE_DOMAIN}"
FULL_SITE_NAME = "Animepahe"
API_ENTRY_POINT = f"{PAHE_HOME_URL}/api?m="
"""
Base URL for Pahe's API, used for retrieving anime information.
"""
ANIME_PAGE_URL = f"{API_ENTRY_POINT}release&id={{}}&sort=episode_asc"
"""
Generates the anime page link from the provided anime id
Example: https://animepahe.ru/api?m=release&id={anime_id}&sort=episode_asc
"""
EPISODE_PAGE_URL = f"{PAHE_HOME_URL}/play/{{}}/{{}}"
"""
Generates episode page link from the provided anime id and episode session
Example: https://animepahe.ru/play/{anime_id}/{episode_session}
"""
LOAD_EPISODES_URL = "{}&page={}"
"""
Generates the load episodes link from the provided anime page link and page number.
Example: {anime_page_link}&page={page_number}
"""
KWIK_PAGE_REGEX = re.compile(r"https?://kwik.cx/f/([^\"']+)")
DUB_PATTERN = "eng"

EPISODE_SIZE_REGEX = re.compile(r"\b(\d+)MB\b")
PARAM_REGEX = re.compile(r"""\(\"(\w+)\",\d+,\"(\w+)\",(\d+),(\d+),(\d+)\)""")
CHAR_MAP = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ+/"
CHAR_MAP_BASE = 10
CHAR_MAP_DIGITS = CHAR_MAP[:CHAR_MAP_BASE]
MAX_SIMULTANEOUS_PART_DOWNLOADS = 2
