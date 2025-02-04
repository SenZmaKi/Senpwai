from pathlib import Path
import subprocess
import sys
from functools import cache
from io import TextIOWrapper
import os

ROOT_DIR = Path(__file__).parent.parent
REPO_URL = "https://github.com/SenZmaKi/Senpwai"
BUILD_DIR = ROOT_DIR / "build"
RELEASE_DIR = ROOT_DIR / "release"


def join_from_local_appdata(*paths: str) -> str:
    return os.path.join(
        os.environ["LOCALAPPDATA"],
        "Programs",
        *paths,
    )


def join_from_py_scripts(*paths: str) -> str:
    return join_from_local_appdata("Python", "Python311", "Scripts", *paths)


def git_commit(msg: str) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(f'git commit -am "scripts: {msg}"')


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
    complete_subprocess = subprocess.run(
        "git branch --show-current", capture_output=True, text=True
    )
    complete_subprocess.check_returncode()
    return complete_subprocess.stdout.strip()


def log_info(msg: str) -> None:
    print(f"[*] Info: {msg}")


def log_warning(msg: str) -> None:
    print(f"[!] Warning: {msg}")
