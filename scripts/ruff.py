import subprocess
from scripts.utils import ARGS, ROOT_DIR, git_commit


def main(
    lint_fix=False,
    format=False,
) -> None:
    if lint_fix or "--lint_fix" in ARGS:
        subprocess.run(f"ruff {ROOT_DIR} --fix").check_returncode()
        git_commit("Fix linting issues with ruff")
        return
    if format or "--format" in ARGS:
        subprocess.run(f"ruff format {ROOT_DIR}").check_returncode()
        git_commit("Format with ruff")
        return
    subprocess.run(f"ruff {ROOT_DIR}").check_returncode()


if __name__ == "__main__":
    main()
