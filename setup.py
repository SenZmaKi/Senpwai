from cx_Freeze import setup, Executable
from os.path import join as join_paths
from typing import cast
import sys
from sys import path

base_dir = 'src'
sys.path.append(base_dir)


def duo_value_parser(file_path: str, split_str: str) -> list[tuple[str, str]]:
    extracted: list[tuple[str, str]] = []
    with open(file_path) as f:
        lines = f.readlines()
        for l in lines:
            if not l.startswith('#'):
                split = l.split(split_str, 1)
                key_value = cast(tuple[str, str], tuple(
                    [split[0].strip(), split[1].strip()]))
                extracted.append(key_value)
    return extracted


def get_metadata() -> dict[str, str]:
    key_and_value = duo_value_parser('metadata.yml', ':')
    return dict(key_and_value)


metadata = get_metadata()
main_script_path = join_paths(base_dir, 'senpwai.py')
base = 'WIN32GUI' if sys.platform == 'win32' else None
executables = [Executable(script=main_script_path, icon=metadata['Icon'],  base=base,
                          target_name=metadata['Name'], copyright=metadata['Copyright'])]
build_directory = join_paths('build', 'Senpwai')

options = {
    'build_exe': {
        'build_exe': build_directory,
        'include_files': join_paths(base_dir, 'assets'),
        'zip_include_packages': 'PyQt6',
        'silent_level': 3
    }
}
if __name__ == "__main__":
    setup(
        name=metadata['Name'],
        version=metadata['Version'],
        options=options,
        executables=executables,
    )
