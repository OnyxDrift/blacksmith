#!/usr/bin/env python3
"""Blacksmith snapshot copy: replace <dest> with a copy of <src>, with
python3 only (no rsync).

Usage: snapshot.py <src> <dest> [--exclude-top <name>]...

Leaves out .git, __pycache__, *.pyc, and .DS_Store at every level, and each
--exclude-top name at the top level only. Symlinks are copied as symlinks.

The copy is built in a temporary folder next to <dest>, then swapped into
place with two renames. A running session never sees a half-copied snapshot,
and files that no longer exist in <src> do not survive in <dest>.
"""
import os
import shutil
import sys

SKIP_ANYWHERE = {".git", "__pycache__", ".DS_Store"}


def main(argv):
    top_skip = set()
    args = []
    i = 0
    while i < len(argv):
        if argv[i] == "--exclude-top":
            top_skip.add(argv[i + 1])
            i += 2
            continue
        if argv[i] in ("-h", "--help"):
            print(__doc__.strip())
            return 0
        args.append(argv[i])
        i += 1
    if len(args) != 2:
        print(__doc__.strip(), file=sys.stderr)
        return 1
    src = os.path.abspath(args[0])
    dest = os.path.abspath(args[1].rstrip("/"))
    if not os.path.isdir(src):
        print("error: not a folder: " + src, file=sys.stderr)
        return 1

    def ignore(folder, names):
        skip = {n for n in names if n in SKIP_ANYWHERE or n.endswith(".pyc")}
        if os.path.abspath(folder) == src:
            skip |= top_skip & set(names)
        return skip

    parent = os.path.dirname(dest)
    os.makedirs(parent, exist_ok=True)
    tmp = "%s.new-%d" % (dest, os.getpid())
    old = "%s.old-%d" % (dest, os.getpid())
    shutil.copytree(src, tmp, symlinks=True, ignore=ignore)
    if os.path.lexists(dest):
        os.rename(dest, old)
    os.rename(tmp, dest)
    if os.path.lexists(old):
        shutil.rmtree(old)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
