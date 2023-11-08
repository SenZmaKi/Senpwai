from cx_Freeze import setup, Executable
from shared.global_vars_and_funcs import base_directory, SENPWAI_ICON_PATH
from os.path import join as join_paths
from typing import cast
from sys import platform

def duo_value_parser(file_path: str, split_str: str) -> list[tuple[str, str]]:
    extracted: list[tuple[str, str]] = []
    with open(file_path) as f:
        lines = f.readlines()
        for l in lines:
            if not l.startswith('#'):
                split = l.split(split_str)
                key_value = cast(tuple[str, str], tuple(
                    [split[0].strip(), split[1].strip()]))
                extracted.append(key_value)
    return extracted


def metadata_yml_parser() -> dict[str, str]:
    key_and_value = duo_value_parser('metadata.yml', ':')
    return dict(key_and_value)


metadata = metadata_yml_parser()
main_script_path = join_paths(base_directory, 'senpwai.py')
base = 'WIN32GUI' if platform == 'win32' else None
executables = [Executable(script=main_script_path, icon=SENPWAI_ICON_PATH,  base=base,
                          target_name=metadata['ProductName'], copyright=metadata['LegalCopyright'])]
build_directory = join_paths(base_directory, 'build', 'Senpwai')

options = {
    'build_exe': {
        'build_exe': build_directory,
        'include_files': 'assets',
        'zip_include_packages': 'PyQt6',
        'silent_level': 3
    }
}
if __name__ == "__main__":

    setup(
        name=metadata['ProductName'],
        version=metadata['Version'],
        options=options,
        executables=executables,
    )