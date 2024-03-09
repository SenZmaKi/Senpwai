import subprocess

from scripts.utils import get_current_branch_name, log_info, log_error, ROOT_DIR
from scripts import bump_version

BRANCH_NAME = get_current_branch_name()


def publish_branch() -> None:
    git_status = subprocess.run("git status", capture_output=True, text=True).stdout
    if "working tree clean" not in git_status:
        log_error("You have uncommited changes", True)
    log_info(f"Pushing {BRANCH_NAME}")
    subprocess.run(f"git push origin {BRANCH_NAME}").check_returncode()
    subprocess.run(f"gh pr create --title {BRANCH_NAME}").check_returncode()
    subprocess.run("gh pr merge --auto --merge --delete-branch").check_returncode()


def publish_release() -> None:
    with open("changelog.md", "r") as f:
        release_notes = f.read()
        log_info(f"Publishing release {BRANCH_NAME}\n\n{release_notes}")
        subprocess.run(
            f"gh release create {BRANCH_NAME} --notes {release_notes}"
        ).check_returncode()
        subprocess.run(
            f'gh release upload  {BRANCH_NAME} {ROOT_DIR.joinpath("setups/Senpwai-setup.exe")} {ROOT_DIR.joinpath("setups/Senpwai-setup.exe")}'
        ).check_returncode()


def main() -> None:
    if BRANCH_NAME == "master":
        log_error("On master branch, switch to version branch", True)

    bump_version.main(True)
    subprocess.run("poe generate_release_ddl").check_returncode()
    publish_branch()
    publish_release()
    subprocess.run("poetry build && poetry publish")


if __name__ == "__main__":
    main()
