from pathlib import Path
import subprocess
import sys
from functools import cache
from io import TextIOWrapper

ROOT_DIR = Path(__file__).parent.parent
REPO_URL = "https://github.com/SenZmaKi/Senpwai"
ARGS = sys.argv[1:]


def git_commit(msg: str) -> None:
    subprocess.run(f'git commit -am "scripts: {msg}"')


def get_piped_input() -> str:
    full_input = ""
    try:
        while True:
            full_input = f"{full_input}\n{input()}"
    except EOFError:
        pass
    return full_input


def log_error(msg: str, exit=False) -> None:
    print(f"[-] Error: {msg}")
    if exit:
        sys.exit(1)


def overwrite(file: TextIOWrapper, content: str) -> None:
    file.seek(0)
    file.write(content)
    file.truncate()


@cache
def get_current_branch_name() -> str:
    return subprocess.run(
        "git branch --show-current", capture_output=True, text=True
    ).stdout.strip()


def log_info(msg: str) -> None:
    print(f"[*] Info: {msg}")


def log_warning(msg: str) -> None:
    print(f"[!] Warning: {msg}")
