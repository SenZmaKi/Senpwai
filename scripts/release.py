import subprocess

from scripts.common import (
    REPO_URL,
    get_current_branch_name,
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
    git_status_completed_process = subprocess.run(
        "git status", capture_output=True, text=True
    )
    git_status_completed_process.check_returncode()
    if "Changes" in git_status_completed_process.stdout:
        log_error("You have uncommited changes", True)
    subprocess.run(f"git push origin {BRANCH_NAME}").check_returncode()
    subprocess.run(f'gh pr create --title {BRANCH_NAME} --body "" ').check_returncode()
    subprocess.run("gh pr merge --auto --merge --delete-branch").check_returncode()


def add_change_log_link(release_notes: str) -> str:
    change_log_link = f"\n\n**Full Changelog**: {REPO_URL}/compare/v{bump_version.get_prev_version()}...v{bump_version.get_new_version()}"
    return release_notes + change_log_link


def get_release_notes(from_commits: bool) -> str:
    with open(ROOT_DIR.joinpath("docs", "release-notes.md"), "r+") as f:
        if from_commits:
            return add_change_log_link(f.read())
        new_commits_completed_process = subprocess.run(
            f"git log --oneline master..{BRANCH_NAME}", capture_output=True, text=True
        )
        new_commits_completed_process.check_returncode()
        release_notes = f"# Changes\n\n{new_commits_completed_process.stdout}"
        overwrite(f, release_notes)
        return add_change_log_link(release_notes)


def publish_release(release_notes: str) -> None:
    subprocess.run("glow", input=release_notes.encode()).check_returncode()
    subprocess.run(
        f'gh release create {BRANCH_NAME} --notes "{release_notes}"'
    ).check_returncode()
    subprocess.run(
        f'gh release upload  {BRANCH_NAME} {ROOT_DIR.joinpath("setups/Senpwai-setup.exe")} {ROOT_DIR.joinpath("setups/Senpcli-setup.exe")}'
    ).check_returncode()


def main() -> None:
    parser = ArgumentParser(description="Release pipeline")
    parser.add_argument(
        "-fc",
        "--from_commits",
        action="store_true",
        help="Generate release notes from commits",
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
    parsed = parser.parse_args()
    if BRANCH_NAME == "master":
        log_error("On master branch, switch to version branch", True)
    if not parsed.skip_bumb:
        log_info("Bumping version")
        bump_version.main(True)
    if not parsed.skip_ruff:
        ruff.main(True, True)
    if not parsed.skip_build_release:
        log_info("Building release")
        subprocess.run("poe build_release_ddl").check_returncode()
    release_notes = get_release_notes(parsed.from_commits)
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
        new_branch_name = input("Enter new branch name\n> ")
        if new_branch_name:
            subprocess.run(f"git checkout -b {new_branch_name}").check_returncode()


if __name__ == "__main__":
    main()
