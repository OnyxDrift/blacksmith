#!/usr/bin/env python3
"""Blacksmith settings helper: edit Claude Code's user settings file in place,
with python3 only (no jq).

The target is ~/.claude/settings.json ($CLAUDE_CONFIG_DIR/settings.json when
that is set). Claude Code and other tools also write to it, so every command
changes only the keys it names and keeps everything else.

Subcommands:
  merge <base.json> [--dry-run]
        Merge a base file into the target:
          - objects merge key by key, recursively;
          - arrays become a union: base entries are appended if missing,
            existing entries keep their order;
          - scalars from the base win; a null in the base changes nothing.
  add-allow <rule>...    / remove-allow <rule>...
  add-deny <rule>...     / remove-deny <rule>...
        Add or remove entries in permissions.allow or permissions.deny.
  plugin-names <marketplace.json>
        Print the name of each plugin that a marketplace file lists.
  marketplace-path <name>
        Read `claude plugin marketplace list --json` on stdin and print the
        path of the marketplace with that name (nothing if absent).
  has-plugin <id>
        Read `claude plugin list --json` on stdin; exit 0 if <id> is in it.
  marketplace-write <source marketplace.json> <snapshot dir>
        Write <snapshot dir>/.claude-plugin/marketplace.json: the source
        file, with only the plugins whose folder is in the snapshot. Print
        the names it kept.

Common flags: --target <settings.json>.

Idempotent: a run that changes nothing writes nothing. Before a change, the
target is copied to settings.json.bak.<UTC timestamp>.
"""
import datetime
import difflib
import json
import os
import shutil
import sys

# Plain \n line ends, also on Windows, where bash would keep the \r.
sys.stdout.reconfigure(newline="\n")


def default_target():
    base = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.join(os.path.expanduser("~"), ".claude")
    return os.path.join(base, "settings.json")


def die(msg):
    print("error: " + msg, file=sys.stderr)
    sys.exit(1)


def load(path, missing_ok=False):
    if missing_ok and not os.path.exists(path):
        return {}
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        die("file not found: " + path)
    except json.JSONDecodeError:
        die(path + " is not valid JSON; fix it by hand first")


def umerge(x, y):
    if isinstance(x, dict) and isinstance(y, dict):
        out = dict(x)
        for k, v in y.items():
            out[k] = umerge(x.get(k), v)
        return out
    if isinstance(x, list) and isinstance(y, list):
        out = list(x)
        for e in y:
            if e not in out:
                out.append(e)
        return out
    if y is None:
        return x
    return y


def dump(data):
    return json.dumps(data, indent=2, ensure_ascii=False) + "\n"


def write(target, current, new, label, same, dry_run):
    """Write `new` to target if it differs from `current`. Returns True on change."""
    if json.dumps(current, sort_keys=True) == json.dumps(new, sort_keys=True):
        print("settings: %s (%s)" % (same, target))
        return False
    if dry_run:
        print("settings: would change %s:" % target)
        a = json.dumps(current, indent=2, sort_keys=True).splitlines()
        b = json.dumps(new, indent=2, sort_keys=True).splitlines()
        for line in difflib.unified_diff(a, b, "current", "merged", lineterm=""):
            print(line)
        return True
    os.makedirs(os.path.dirname(target), exist_ok=True)
    if os.path.exists(target):
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        backup = "%s.bak.%s" % (target, stamp)
        n = 1
        while os.path.exists(backup):
            n += 1
            backup = "%s.bak.%s-%d" % (target, stamp, n)
        shutil.copy2(target, backup)
        print("settings: backup at " + backup)
    # Write in place, not rename: keeps the target's inode, permissions, and
    # any symlink.
    with open(target, "w") as f:
        f.write(dump(new))
    print("settings: %s in %s" % (label, target))
    return True


def edit_rules(target, key, rules, add, dry_run):
    current = load(target, missing_ok=True)
    new = json.loads(json.dumps(current))
    perms = new.setdefault("permissions", {})
    if not isinstance(perms, dict):
        die("permissions in %s is not an object" % target)
    lst = perms.setdefault(key, [])
    if add:
        for r in rules:
            if r not in lst:
                lst.append(r)
        label = "added %s to permissions.%s" % (", ".join(rules), key)
        same = "%s already in permissions.%s" % (", ".join(rules), key)
    else:
        perms[key] = [r for r in lst if r not in rules]
        if not perms[key]:
            del perms[key]
        if not perms:
            del new["permissions"]
        label = "removed %s from permissions.%s" % (", ".join(rules), key)
        same = "%s not in permissions.%s" % (", ".join(rules), key)
    write(target, current, new, label, same, dry_run)


def read_stdin_json():
    text = sys.stdin.read().strip()
    if not text:
        return []
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return []


def main(argv):
    target = default_target()
    dry_run = False
    args = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--target":
            target = argv[i + 1]
            i += 2
            continue
        if a == "--dry-run":
            dry_run = True
        elif a in ("-h", "--help"):
            print(__doc__.strip())
            return 0
        else:
            args.append(a)
        i += 1
    if not args:
        print(__doc__.strip(), file=sys.stderr)
        return 1
    cmd, rest = args[0], args[1:]

    if cmd == "merge":
        if len(rest) != 1:
            die("usage: settings.py merge <base.json> [--dry-run] [--target T]")
        base = load(rest[0])
        current = load(target, missing_ok=True)
        write(target, current, umerge(current, base), "merged " + os.path.basename(rest[0]),
              "already up to date", dry_run)
        return 0
    if cmd in ("add-allow", "remove-allow", "add-deny", "remove-deny"):
        if not rest:
            die("usage: settings.py %s <rule>..." % cmd)
        edit_rules(target, cmd.split("-")[1], rest, cmd.startswith("add"), dry_run)
        return 0
    if cmd == "plugin-names":
        if len(rest) != 1:
            die("usage: settings.py plugin-names <marketplace.json>")
        for p in load(rest[0]).get("plugins", []):
            print(p["name"])
        return 0
    if cmd == "marketplace-path":
        if len(rest) != 1:
            die("usage: settings.py marketplace-path <name>")
        for m in read_stdin_json():
            if isinstance(m, dict) and m.get("name") == rest[0]:
                print(m.get("path", ""))
                break
        return 0
    if cmd == "has-plugin":
        if len(rest) != 1:
            die("usage: settings.py has-plugin <id>")
        found = any(isinstance(p, dict) and p.get("id") == rest[0] for p in read_stdin_json())
        return 0 if found else 1
    if cmd == "marketplace-write":
        if len(rest) != 2:
            die("usage: settings.py marketplace-write <source marketplace.json> <snapshot dir>")
        market = load(rest[0])
        snap = rest[1]
        market["plugins"] = [
            p for p in market.get("plugins", [])
            if os.path.isfile(os.path.join(snap, p["name"], ".claude-plugin", "plugin.json"))
        ]
        os.makedirs(os.path.join(snap, ".claude-plugin"), exist_ok=True)
        with open(os.path.join(snap, ".claude-plugin", "marketplace.json"), "w") as f:
            f.write(dump(market))
        for p in market["plugins"]:
            print(p["name"])
        return 0
    die("unknown subcommand: " + cmd)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
