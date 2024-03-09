import subprocess

from scripts.utils import (
    ARGS,
    REPO_URL,
    get_current_branch_name,
    log_info,
    log_error,
    ROOT_DIR,
    overwrite,
)
from scripts import bump_version
from scripts import announce

BRANCH_NAME = get_current_branch_name()


def publish_branch() -> None:
    git_status_process = subprocess.run("git status", capture_output=True, text=True)
    git_status_process.check_returncode()
    if "Changes" in git_status_process.stdout:
        log_error("You have uncommited changes", True)
    subprocess.run(f"git push origin {BRANCH_NAME}").check_returncode()
    subprocess.run(f'gh pr create --title {BRANCH_NAME} --body "" ').check_returncode()
    subprocess.run("gh pr merge --auto --merge --delete-branch").check_returncode()


def get_release_notes() -> str:
    if "--from_commits" in ARGS:
        subprocess.run("git log --on")

    with open(ROOT_DIR.joinpath("scripts/changelog.md"), "r+") as f:
        release_notes = f.read()
        full_change_log_link = f"\n\n**Full Changelog**: {REPO_URL}/compare/v{bump_version.get_prev_version()}...v{bump_version.get_new_version()}"
        full_release_notes = release_notes + full_change_log_link
        overwrite(f, full_release_notes)
        return full_release_notes


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
    log_info("Bumping version")
    bump_version.main(True)
    if "--skip_build" not in ARGS:
        log_info("Generating release")
        subprocess.run("poe generate_release_ddl").check_returncode()
    log_info(f"Publishing branch {BRANCH_NAME}")
    publish_branch()
    log_info(f"Publishing release {BRANCH_NAME}\n")
    release_notes = get_release_notes()
    publish_release(release_notes)
    # log_info("Building pip dist")
    # subprocess.run("poetry build ").check_returncode()
    # log_info("Publishing to PyPi")
    # subprocess.run("poetry publish").check_returncode()
    log_info("Announcing")
    announce.main(f"Version {bump_version.get_new_version()} is Out!", release_notes)


if __name__ == "__main__":
    main()
