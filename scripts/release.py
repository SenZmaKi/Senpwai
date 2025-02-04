import subprocess
import sys

from scripts.common import (
    RELEASE_DIR,
    REPO_URL,
    get_current_branch_name,
    git_commit,
    log_info,
    log_error,
    ROOT_DIR,
    overwrite,
)
from scripts import bump_version, ruff
from scripts import announce
from argparse import ArgumentParser

BRANCH_NAME = get_current_branch_name()


def merge_branch() -> None:
    completed_process = subprocess.run("git status", capture_output=True, text=True)
    completed_process.check_returncode()
    if "Changes" in completed_process.stdout:
        log_error("You have uncommited changes", True)
    subprocess.run(f"git push origin {BRANCH_NAME}").check_returncode()
    subprocess.run(f'gh pr create --title {BRANCH_NAME} --body "" ').check_returncode()
    subprocess.run("gh pr merge --auto --merge --delete-branch").check_returncode()


def add_change_log_link(release_notes: str, previous_version: str | None) -> str:
    new_version = bump_version.get_new_version()
    if previous_version:
        prev_version = previous_version
    else:
        prev_version = bump_version.get_prev_version(False)
        if new_version == prev_version:
            prev_version = input(
                'Failed to get previous version number, manual input required (without the "v" prefix)\n> '
            )
            if not prev_version:
                sys.exit()
    change_log_link = (
        f"**Full Changelog**: {REPO_URL}/compare/v{prev_version}...v{new_version}"
    )
    return f"{release_notes}\n\n{change_log_link}"


def get_release_notes(from_commits: bool, previous_version: str | None) -> str:
    with open(ROOT_DIR / "docs" / "release-notes.md", "r+") as f:
        if not from_commits:
            return add_change_log_link(f.read(), previous_version)
        completed_process = subprocess.run(
            f'git log --format="%s" master..{BRANCH_NAME}',
            capture_output=True,
            text=True,
        )
        completed_process.check_returncode()
        release_notes = f"# Changes\n\n{completed_process.stdout}"
        overwrite(f, release_notes)
        git_commit("Generate release notes from commits").check_returncode()
        return add_change_log_link(release_notes, previous_version)


def publish_release(release_notes: str) -> None:
    try:
        subprocess.run("glow", input=release_notes, text=True).check_returncode()
    except FileNotFoundError:
        print(release_notes)
    subprocess.run(
        f'gh release create {BRANCH_NAME} --notes "{release_notes}"'
    ).check_returncode()
    release_files = " ".join(f'"{file}"' for file in RELEASE_DIR.iterdir())
    subprocess.run(
        f"gh release upload  {BRANCH_NAME} {release_files}"
    ).check_returncode()


def new_branch(new_branch_name: str) -> None:
    if not new_branch_name:
        new_branch_name = input(
            'Enter new branch name (with the "v" prefix if necessary)\n> '
        )
    if new_branch_name:
        subprocess.run(f"git checkout -b {new_branch_name}").check_returncode()
        subprocess.run(
            f"git push --set-upstream origin {new_branch_name}"
        ).check_returncode()


def get_debug_comment_location() -> str | None:
    for f in (ROOT_DIR / "senpwai").rglob("*.py"):
        with open(f, "r", encoding="utf-8") as file:
            for idx, line in enumerate(file.readlines()):
                if "DEBUG" in line:
                    return f"{f}, line {idx + 1}"


def main() -> None:
    parser = ArgumentParser(description="Release pipeline")
    parser.add_argument(
        "-fc",
        "--from_commits",
        action="store_true",
        help="Generate release notes from commits",
    )
    parser.add_argument(
        "-sed",
        "--skip_export_dependencies",
        action="store_true",
        help="Skip exporting poetry dependencies to requirements.txt",
    )
    parser.add_argument(
        "-sb", "--skip_bump", action="store_true", help="Skip bumping version"
    )
    parser.add_argument(
        "-sr", "--skip_ruff", action="store_true", help="Skip running ruff"
    )
    parser.add_argument(
        "-sbr",
        "--skip_build_release",
        action="store_true",
        help="Skip building release",
    )
    parser.add_argument(
        "-smb",
        "--skip_merge_branch",
        action="store_true",
        help="Skip merging branch",
    )
    parser.add_argument(
        "-spr",
        "--skip_publish_release",
        action="store_true",
        help="Skip publishing release",
    )
    parser.add_argument(
        "-sp", "--skip_pypi", action="store_true", help="Skip publishing to PyPi"
    )
    parser.add_argument(
        "-sa", "--skip_announce", action="store_true", help="Skip announcing"
    )
    parser.add_argument(
        "-snb",
        "--skip_new_branch",
        action="store_true",
        help="Skip creating new branch",
    )
    parser.add_argument(
        "-pv",
        "--previous_version",
        help='Previous version number (without the "v" prefix)',
        type=str,
    )
    parser.add_argument(
        "-nbn",
        "--new_branch_name",
        help='New branch name (with the "v" prefix if necessary)',
        type=str,
    )

    parsed = parser.parse_args()
    if BRANCH_NAME == "master":
        log_error("On master branch, switch to version branch", True)
    debug_comment = get_debug_comment_location()
    if debug_comment:
        log_error(f"Debug comment found in {debug_comment}", True)
    if not parsed.skip_export_dependencies:
        log_info("Exporting dependencies")
        subprocess.run("poe export_dependencies").check_returncode()
        git_commit("Export poetry dependencies to requirements.txt")
    if not parsed.skip_bump:
        log_info("Bumping version")
        bump_version.main(True)
    if not parsed.skip_ruff:
        ruff.main(True, True)
    if not parsed.skip_build_release:
        log_info("Building release")
        subprocess.run("poe build_release_ddl").check_returncode()
    release_notes = get_release_notes(parsed.from_commits, parsed.previous_version)
    if not parsed.skip_merge_branch:
        log_info(f"Merging branch {BRANCH_NAME}")
        merge_branch()
    if not parsed.skip_publish_release:
        log_info(f"Publishing release {BRANCH_NAME}")
        publish_release(release_notes)
    if not parsed.skip_pypi:
        log_info("Publishing to PyPi")
        subprocess.run("poetry publish").check_returncode()
    if not parsed.skip_announce:
        log_info("Announcing")
        announce.main(
            f"Version {bump_version.get_new_version()} is Out!", release_notes
        )
    log_info(f"Finished release {BRANCH_NAME}")
    if not parsed.skip_new_branch:
        new_branch(parsed.new_branch_name)


if __name__ == "__main__":
    main()
