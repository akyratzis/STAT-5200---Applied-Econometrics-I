#!/usr/bin/env python3
"""Check or restore initial capitals on visible course directories.

Only directory names change; filenames and file contents are preserved.
Hidden configuration directories are excluded. Git's index is updated explicitly
so case-only renames also work on a case-insensitive macOS filesystem.
"""

import argparse
import os
from pathlib import Path
import subprocess


def normalized_path(path):
    parts = path.split("/")
    if any(part.startswith(".") for part in parts[:-1]):
        return path
    return "/".join(
        [part[:1].upper() + part[1:] for part in parts[:-1]] + parts[-1:]
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fix", action="store_true", help="apply folder renames")
    args = parser.parse_args()
    root = subprocess.check_output(
        ["git", "rev-parse", "--show-toplevel"], text=True
    ).strip()
    os.chdir(root)

    entries = subprocess.check_output(["git", "ls-files", "--stage", "-z"])
    changes = []
    destinations = {}
    for entry in entries.split(b"\0"):
        if not entry:
            continue
        metadata, raw_path = entry.split(b"\t", 1)
        mode, blob, stage = metadata.split()
        if stage != b"0":
            raise SystemExit("Resolve Git merge conflicts before normalizing folders.")
        path = os.fsdecode(raw_path)
        target = normalized_path(path)
        if target in destinations and destinations[target] != path:
            raise SystemExit(f"Conflicting paths would become {target}; no changes made.")
        destinations[target] = path
        if target != path:
            changes.append((path, target, mode, blob))

    folders = []
    for base, directories, _ in os.walk("."):
        directories[:] = [name for name in directories if not name.startswith(".")]
        for name in directories:
            if name[:1] != name[:1].upper():
                path = Path(base) / name
                target = path.with_name(name[:1].upper() + name[1:])
                if target.exists() and not os.path.samefile(path, target):
                    raise SystemExit(f"Conflicting directory {target}; no changes made.")
                temporary = path.with_name(".__capitalizing_" + name)
                if temporary.exists():
                    raise SystemExit(f"Temporary path already exists: {temporary}")
                folders.append((path, target, temporary))

    if not folders and not changes:
        print("All visible course folders start with capital letters.")
        return

    for path, target, _ in sorted(folders, key=lambda item: str(item[0])):
        print(f"{path} -> {target.name}")
    if not args.fix:
        raise SystemExit(
            "Run python3 .github/Scripts/normalize_folder_names.py --fix to repair."
        )

    # Children must be renamed before their parent paths change.
    for path, target, temporary in sorted(
        folders, key=lambda item: len(item[0].parts), reverse=True
    ):
        path.rename(temporary)
        temporary.rename(target)

    # Preserve the indexed blob: existing staged/unstaged contents stay separate.
    records = []
    for path, target, mode, blob in changes:
        records.append(b"0 " + b"0" * len(blob) + b"\t" + os.fsencode(path) + b"\0")
        records.append(mode + b" " + blob + b"\t" + os.fsencode(target) + b"\0")
    if records:
        subprocess.run(
            ["git", "update-index", "-z", "--index-info"],
            input=b"".join(records),
            check=True,
        )
    print(f"Restored {len(folders)} directory names and {len(changes)} Git paths.")


if __name__ == "__main__":
    main()
