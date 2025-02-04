import re

GOGO = "gogo"
GOGO_HOME_URL = "https://anitaku.bz"
AJAX_ENTRY_POINT = "https://ajax.gogocdn.net"
AJAX_SEARCH_URL = f"{AJAX_ENTRY_POINT}/site/loadAjaxSearch?keyword="
AJAX_LOAD_EPS_URL = (
    f"{AJAX_ENTRY_POINT}/ajax/load-list-episode?ep_start={{}}&ep_end={{}}&id={{}}"
)
FULL_SITE_NAME = "Gogoanime"
DUB_EXTENSION = " (Dub)"
REGISTERED_ACCOUNT_EMAILS = [
    "benida7218@weirby.com",
    "hareki4411@wisnick.com",
    "nanab67795@weirby.com",
    "xener53725@weirby.com",
    "nenado3105@weirby.com",
    "yaridod257@weirby.com",
    "ketoh33964@weirby.com",
    "kajade1254@wisnick.com",
    "nakofe3005@weirby.com",
    "gedidij506@weirby.com",
    "sihaci1525@undewp.com",
    "lorimob952@soebing.com",
    "nigeha6048@undewp.com",
    "goriwij739@undewp.com",
    "pekivik280@soebing.com",
    "hapas66158@undewp.com",
    "wepajof522@undewp.com",
    "semigo1458@undewp.com",
    "xojecog864@undewp.com",
    "lobik97135@wanbeiz.com",
]

KEYS_REGEX = re.compile(rb"(?:container|videocontent)-(\d+)")
ENCRYPTED_DATA_REGEX = re.compile(rb'data-value="(.+?)"')
BASE_URL_REGEX = re.compile(r"(http[s]?://[a-zA-Z0-9\.\-]+)")
