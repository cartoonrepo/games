import argparse
import platform
import subprocess
import shutil

from pathlib import Path

program_name  = "cartooon"
source        = "pong"

collections   = []
extra_flags   = ["-strict-style", "-vet", "-disallow-do"]
debug_flags   = ["-debug"]
release_flags = ["-o:speed", "-no-bounds-check"]

debug_flags   = debug_flags   + collections + extra_flags
release_flags = release_flags + collections + extra_flags

IS_WINDOWS = platform.system() == "Windows"
# if IS_WINDOWS:
    # flags.append("-subsystem:windows")

# ---------------------------------------------------------------------------------------------------
parser = argparse.ArgumentParser(
                    prog='make_exe',
                    description='Build script for odin projects',
                    epilog='')

parser.add_argument("-release",    action="store_true", help="Release build")
parser.add_argument("-debug",      action="store_true", help="Debug build")
parser.add_argument("-run",        action="store_true", help="Run the executable after compiling it")
parser.add_argument("-clean",      action="store_true", help="Clean build folder")
parser.add_argument("-hold",       action="store_true", help="Hold terminal until Enter pressed")

args = parser.parse_args()


def main():
    root_build_dir = Path("build")

    if args.release:
        build_dir = root_build_dir / "release"
        clean(build_dir)

        build_dir.mkdir(parents=True, exist_ok=True)

        binary_path = build_dir/program_name
        build(binary_path, release_flags)

    elif args.debug:
        build_dir = root_build_dir / "debug"
        build_dir.mkdir(parents=True, exist_ok=True)

        binary_path = build_dir/program_name

        build(binary_path, debug_flags)

    elif args.clean:
        clean(root_build_dir)


def build(binary: Path, flags):
    if IS_WINDOWS:
        if not binary.suffix:
            binary = binary.with_suffix(".exe")

    cmd = ["odin", "build", source, f"-out:{str(binary)}"] + collections + flags

    try:
        subprocess.run(cmd, check=True)
        print(" ".join(cmd))
    except subprocess.CalledProcessError:
        if args.hold:
            input("Press Enter to exit.")
        exit(1)
    run(binary)

def run(binary: Path):
    if binary.exists() and args.run:
        print(f"running: {str(binary)}")
        try:
            subprocess.run([str(binary)], check=True)
        except subprocess.CalledProcessError:
            exit(1)


def clean(dir: Path):
    if dir.exists():
        shutil.rmtree(dir)
        print(f"Removed directory: {dir}")
    else:
        print(f"No directory to clean at: {dir}")


if __name__ == "__main__":
    main()
