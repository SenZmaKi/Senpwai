from pathlib import Path
import os
import subprocess
import sys
from functools import cache

ROOT_DIR = Path(os.path.dirname(os.path.dirname(__file__)))


def log_error(msg: str, exit=False) -> None:
    print(f"[-] Error: {msg}")
    if exit:
        sys.exit(1)

@cache
def get_current_branch_name() -> str:
    return subprocess.run(
        "git branch --show-current", capture_output=True, text=True
    ).stdout.strip()

def log_info(msg: str) -> None:
    print(f"[+] Info: {msg}")


def log_warning(msg: str) -> None:
    print(f"[!] Warning: {msg}")
