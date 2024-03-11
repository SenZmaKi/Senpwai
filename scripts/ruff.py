import subprocess
from scripts.utils import ARGS, ROOT_DIR


def main(
    lint_fix=False,
    format=False,
) -> None:
    if lint_fix or "--lint_fix" in ARGS:
        subprocess.run(f"ruff {ROOT_DIR} --fix").check_returncode()
        subprocess.run(
            'git commit -am "Fix linting issues with ruff" '
        )
        return
    if format or "--format" in ARGS:
        subprocess.run(f"ruff format {ROOT_DIR}").check_returncode()
        subprocess.run('git commit -am "Format with ruff" ')
        return
    subprocess.run(f"ruff {ROOT_DIR}").check_returncode()


if __name__ == "__main__":
    main()
