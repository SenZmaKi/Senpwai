from typing import Any


class FailedToAnnounce(Exception):
    def __init__(self, platform: str, response_json: dict[str, Any]) -> None:
        super().__init__(
            f"Failed to make announcement on {platform}\n\n{response_json}"
        )
