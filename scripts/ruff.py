from argparse import ArgumentParser
import subprocess
from scripts.common import ROOT_DIR, git_commit


def main(
    lint_fix=False,
    format=False,
    lint=False,
) -> None:
    parser = ArgumentParser("Run ruff on the project")
    parser.add_argument("-f", "--format", action="store_true", help="Format the code")
    parser.add_argument("-l", "--lint", action="store_true", help="Lint the code")
    parser.add_argument("-lf", "--lint_fix", action="store_true", help="Fix linting issues")
    parsed = parser.parse_args()
    if lint_fix or parsed.lint_fix:
        subprocess.run(f"ruff {ROOT_DIR} --fix").check_returncode()
        git_commit("Fix linting issues with ruff")
        return
    if format or parsed.format:
        subprocess.run(f"ruff format {ROOT_DIR}").check_returncode()
        git_commit("Format with ruff")
        return
    if lint or parsed.lint:
        subprocess.run(f"ruff {ROOT_DIR}").check_returncode()
        return


if __name__ == "__main__":
    main()
