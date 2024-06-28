import subprocess

from scripts.common import (
    ARGS,
    REPO_URL,
    get_current_branch_name,
    log_info,
    log_error,
    ROOT_DIR,
    overwrite,
)
from scripts import bump_version, ruff
from scripts import announce

BRANCH_NAME = get_current_branch_name()


def publish_branch() -> None:
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


def get_release_notes() -> str:
    with open(ROOT_DIR.joinpath("RELEASE_NOTES.md"), "r+") as f:
        if "--from_commits" not in ARGS:
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
    if BRANCH_NAME == "master":
        log_error("On master branch, switch to version branch", True)
    if "--skip_bump" not in ARGS:
        log_info("Bumping version")
        bump_version.main(True)
    if "--skip_ruff" not in ARGS:
        ruff.main(True, True)
    if "--skip_build" not in ARGS:
        log_info("Generating release")
        subprocess.run("poe generate_release_ddl").check_returncode()
    release_notes = get_release_notes()
    if "--skip_branch" not in ARGS:
        log_info(f"Publishing branch {BRANCH_NAME}")
        publish_branch()
    if "--skip_release" not in ARGS:
        log_info(f"Publishing release {BRANCH_NAME}")
        publish_release(release_notes)
    if "--skip_pypi" not in ARGS:
        log_info("Publishing to PyPi")
        subprocess.run("poetry publish")
    if "--skip_announce" not in ARGS:
        log_info("Announcing")
        announce.main(
            f"Version {bump_version.get_new_version()} is Out!", release_notes
        )
    log_info(f"Finished release {BRANCH_NAME}")
    if "--skip_new_branch" not in ARGS:
        new_branch_name = input("Enter new branch name\n> ")
        if new_branch_name:
            subprocess.run(f"git checkout -b {new_branch_name}").check_returncode()


if __name__ == "__main__":
    main()
