#!/usr/bin/env python3

import argparse
import platform
import subprocess
import shutil
import sys

from pathlib import Path

# ----------------------------------------------------------------
program_name  = "floppy"

collections   = []
extra_flags   = ["-strict-style", "-disallow-do"]
debug_flags   = ["-debug"]
release_flags = ["-o:speed", "-vet", "-no-bounds-check"]

IS_WINDOWS = platform.system() == "Windows"
# if IS_WINDOWS:
#     extra_flags.append("-subsystem:windows")

# ----------------------------------------------------------------

debug_flags   = debug_flags   + collections + extra_flags
release_flags = release_flags + collections + extra_flags

parser = argparse.ArgumentParser(
                    prog='make_exe',
                    description='Build script for odin projects',
                    epilog='')

parser.add_argument("-release", action="store_true", help="release build")
parser.add_argument("-debug",   action="store_true", help="debug build")
parser.add_argument("-clean",   action="store_true", help="clean build folder")
parser.add_argument("-run",     action="store_true", help="run the executable after compiling it,  require `-debug | -release` flags")
parser.add_argument("-hold",    action="store_true", help="if error hold terminal until Enter pressed, require `-run` flag")

args = parser.parse_args()

def main():
    root_build_dir = Path("build")

    if args.release:
        build_dir = root_build_dir / "release"
        clean(build_dir)

        build_dir.mkdir(parents=True, exist_ok=True)

        build(build_dir, release_flags)

    elif args.debug:
        build_dir = root_build_dir / "debug"
        build_dir.mkdir(parents=True, exist_ok=True)

        build(build_dir, debug_flags)

    elif args.clean:
        clean(root_build_dir)

    else:
        print("pass either of these flags: -release | -debug | -clean | --help")


def build(binary_path: Path, flags):
    binary = binary_path/program_name
    if IS_WINDOWS:
        if not binary.suffix:
            binary = binary.with_suffix(".exe")

    build_option = "run" if args.run else "build"
    command = ["odin", build_option, program_name, f"-out:{str(binary)}"] + flags

    try:
        print(" ".join(command))
        subprocess.run(command, check=True)
    except subprocess.CalledProcessError:
        if args.hold:
            input("\nPress 'Enter' to exit...")
        sys.exit(1)
    except KeyboardInterrupt:
        print(f"\nforce quit: {str(binary)}")
        sys.exit(0)

    # run(binary)

# WARN: another way to run binary, right now it's not been used.
def run(binary: Path):
    if binary.exists() and args.run:
        print(f"running: {str(binary)}\n")
        try:
            subprocess.run([str(binary)], check=True)
        except subprocess.CalledProcessError:
            sys.exit(1)
        except KeyboardInterrupt:
            print(f"\nforce quit: {str(binary)}")
            sys.exit(0)


def clean(dir: Path):
    if dir.exists():
        shutil.rmtree(dir)
        print(f"Removed directory: {dir}")
    else:
        print(f"No directory to clean at: {dir}")


if __name__ == "__main__":
    main()
