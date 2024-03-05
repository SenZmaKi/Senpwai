from io import TextIOWrapper
import os
import subprocess

PREV_VERSION = "2.1.3"
NEW_VERSION = "2.1.4"
FILES_PATHS = [
    "pyproject.toml",
    "senpwai/utils/static.py",
    "setup.iss",
    "setup_senpcli.iss",
]


def log_error(msg: str) -> None:
    print(f"[-] Error: {msg}")


def log_info(msg: str) -> None:
    print(f"[+] Info: {msg}")


def log_warning(msg: str) -> None:
    print(f"[!] Warning: {msg}")


def truncate(file: TextIOWrapper, content: str) -> None:
    file.seek(0)
    file.write(content)
    file.truncate()


def main() -> None:
    log_info(f"Bumping version from {PREV_VERSION} -> {NEW_VERSION}\n")
    for file_path in FILES_PATHS:
        if not os.path.isfile(file_path):
            log_error(f'"{file_path}" not found')
            continue
        with open(file_path, "r+") as f:
            content = f.read()
            new_content = content.replace(PREV_VERSION, NEW_VERSION)
            if new_content == content:
                if NEW_VERSION in new_content:
                    log_warning(
                        f'Failed to find previous version in "{file_path}" but the new version is in it'
                    )
                else:
                    log_error(f'Failed to find previous version in "{file_path}"')
                continue
            truncate(f, new_content)
            log_info(f'Bumped version in "{file_path}"')
    subprocess.run("git diff")


if __name__ == "__main__":
    main()
