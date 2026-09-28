#!/usr/bin/env python3
"""Print each blacksmith plugin and its skills, for the installer's question.

Usage: describe.py <blacksmith folder> [plugin]...

Reads the plugin list from .claude-plugin/marketplace.json and each skill
from <plugin>/skills/*/SKILL.md frontmatter (name, argument-hint,
description, disable-model-invocation), so the text cannot drift from the
skills. Prints the first sentence of each description.
"""
import glob
import json
import os
import re
import sys
import textwrap

# Plain \n line ends, also on Windows, where bash would keep the \r.
sys.stdout.reconfigure(newline="\n")

WIDTH = 78


def frontmatter(path):
    with open(path) as f:
        text = f.read()
    m = re.match(r"---\n(.*?)\n---", text, re.S)
    fields = {}
    if not m:
        return fields
    for line in m.group(1).splitlines():
        k, sep, v = line.partition(":")
        if not sep or line[:1].isspace():
            continue
        v = v.strip()
        if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
            v = v[1:-1]
        fields[k.strip()] = v
    return fields


def first_sentence(text):
    m = re.match(r"(.+?[.!?])(\s|$)", text)
    return m.group(1) if m else text


def main(argv):
    if not argv:
        print(__doc__.strip(), file=sys.stderr)
        return 1
    root, only = argv[0], set(argv[1:])
    with open(os.path.join(root, ".claude-plugin", "marketplace.json")) as f:
        plugins = json.load(f)["plugins"]
    for p in plugins:
        name = p["name"]
        if only and name not in only:
            continue
        print(textwrap.fill("%s — %s" % (name, p.get("description", "")), WIDTH,
                            subsequent_indent="    "))
        for skill in sorted(glob.glob(os.path.join(root, name, "skills", "*", "SKILL.md"))):
            fm = frontmatter(skill)
            cmd = "/%s:%s" % (name, fm.get("name", os.path.basename(os.path.dirname(skill))))
            if fm.get("argument-hint"):
                cmd += " " + fm["argument-hint"]
            who = "You" if fm.get("disable-model-invocation") == "true" else "You or Claude"
            print("  " + cmd)
            print(textwrap.fill("%s. %s" % (who, first_sentence(fm.get("description", ""))), WIDTH,
                                initial_indent="      ", subsequent_indent="      ",
                                break_on_hyphens=False))
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
