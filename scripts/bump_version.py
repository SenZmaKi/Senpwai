from argparse import ArgumentParser
from functools import cache
import subprocess
import sys
import re
from typing import cast
from scripts.common import (
    ROOT_DIR,
    get_current_branch_name,
    git_commit,
    log_info,
    log_warning,
    overwrite,
)
from scripts import common


PYPROJECT_FILE_PATH = ROOT_DIR / "pyproject.toml"
FILES_PATHS = [
    PYPROJECT_FILE_PATH,
    ROOT_DIR / "senpwai/common/static.py",
    ROOT_DIR / "scripts/setup.iss",
    ROOT_DIR / "scripts/setup_senpcli.iss",
]

ENCOUNTERED_ERROR = False
VERSION_REGEX = re.compile(r"(\d+(\.\d+)*)")


def log_error(msg: str, exit=False) -> None:
    common.log_error(msg, exit)
    global ENCOUNTERED_ERROR
    ENCOUNTERED_ERROR = True


@cache
def get_prev_version(exit=True) -> str:
    prev_version = ""
    with open(PYPROJECT_FILE_PATH, "r") as f:
        opt_version = VERSION_REGEX.search(f.read())
        if opt_version is not None:
            prev_version = opt_version.group(1)
    if not prev_version:
        log_error("Failed to get previous version", exit)
    return prev_version


@cache
def get_new_version() -> str:
    branch_name = get_current_branch_name()
    if branch_name == "master":
        log_error("On master branch, switch to version branch", True)
    new_version = VERSION_REGEX.search(branch_name)
    if new_version is None:
        log_error("Failed to get new version", True)
    return cast(re.Match, new_version).group(1)


def bump_version(prev_version: str, new_version: str, ignore_same: bool):
    for file_path in FILES_PATHS:
        if not file_path.is_file():
            log_error(f'"{file_path}" not found')
            continue
        with open(file_path, "r+") as f:
            content = f.read()
            new_content = content.replace(prev_version, new_version)
            if not ignore_same and new_content == content:
                if new_version in new_content:
                    log_warning(
                        f'Failed to find previous version in "{file_path}" but the new version is in it'
                    )
                else:
                    log_error(f'Failed to find previous version in "{file_path}"')
                continue
            overwrite(f, new_content)
            log_info(f'Bumped version in "{file_path}"')


def main(ignore_same=False) -> None:
    parser = ArgumentParser(description="Bump version in files")
    parser.add_argument(
        "-is",
        "--ignore_same",
        action="store_true",
        help="Ignore if previous and new version are the same",
    )
    parser.add_argument(
        "-pv",
        "--previous_version",
        type=str,
        help="Previous version to bump from",
        default=get_prev_version(),
    )
    parser.add_argument(
        "-nv",
        "--new_version",
        type=str,
        help="New version to bump to",
        default=get_new_version(),
    )
    parsed = parser.parse_args()
    ignore_same = parsed.ignore_same
    previous_version = parsed.previous_version
    new_version = parsed.new_version
    if not ignore_same and previous_version == new_version:
        log_error(f"Previous and New version are the same: {previous_version}", True)
    log_info(f"Bumping version from {previous_version} --> {new_version}")
    bump_version(previous_version, new_version, ignore_same)
    subprocess.run("git --no-pager diff").check_returncode()
    git_commit(f"Bump version from {previous_version} --> {new_version}")
    if ENCOUNTERED_ERROR:
        sys.exit(1)


if __name__ == "__main__":
    main()
