from argparse import ArgumentParser
import subprocess
from scripts.common import ROOT_DIR, git_commit


def parser_main() -> None:
    parser = ArgumentParser("Run ruff on the project")
    parser.add_argument("-f", "--format", action="store_true", help="Format the code")
    parser.add_argument("-l", "--lint", action="store_true", help="Lint the code")
    parser.add_argument(
        "-lf", "--lint_fix", action="store_true", help="Fix linting issues"
    )
    parsed = parser.parse_args()
    main(parsed.lint_fix, parsed.format, parsed.lint)


def main(
    lint_fix=False,
    format=False,
    lint=False,
) -> None:
    if lint_fix:
        subprocess.run(f"ruff {ROOT_DIR} --fix").check_returncode()
        git_commit("Fix linting issues with ruff")
        return
    if format:
        subprocess.run(f"ruff format {ROOT_DIR}").check_returncode()
        git_commit("Format with ruff")
        return
    if lint:
        subprocess.run(f"ruff {ROOT_DIR}").check_returncode()
        return


if __name__ == "__main__":
    parser_main()
