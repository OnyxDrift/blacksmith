"""Shared helpers for anvil's Python scripts: paths, frontmatter, rules.

Mirrors lib/common.sh for vault resolution:
  $ANVIL_HOME, then $BLACKSMITH_HOME/config/anvil-home, then
  $BLACKSMITH_HOME/anvil/vault. BLACKSMITH_HOME defaults to ~/.blacksmith.
"""
import json
import os
import re
import subprocess
import sys

# Plain \n line ends, also on Windows, where bash would keep the \r.
sys.stdout.reconfigure(newline="\n")

PKG = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def hosts_py():
    """The shared hosts.py: the plugin's own lib/ copy (made by the
    installer, because Claude Code runs a cache copy of the plugin folder
    alone), else ../lib in a source checkout."""
    own = os.path.join(PKG, "lib", "hosts.py")
    return own if os.path.isfile(own) else os.path.join(os.path.dirname(PKG), "lib", "hosts.py")
HOME = os.path.expanduser("~")
BLACKSMITH_HOME = os.environ.get("BLACKSMITH_HOME") or os.path.join(HOME, ".blacksmith")
CONFIG_DIR = os.path.join(BLACKSMITH_HOME, "config")
CACHE_DIR = os.path.join(BLACKSMITH_HOME, "cache")
SEARCHED = ("semantic", "procedural", "strategic")
TYPES = ("semantic", "procedural", "strategic", "episodic")
STATUSES = ("draft", "canonical", "disputed", "archived")
SOURCES = ("claude", "human")
FIELD_ORDER = ["type", "domain", "subdomain", "project", "source", "origin", "status",
               "updated", "tags", "description", "supersedes"]
DESCRIPTION_MAX = 200


def vault():
    v = os.environ.get("ANVIL_HOME")
    if not v:
        conf = os.path.join(CONFIG_DIR, "anvil-home")
        if os.path.exists(conf):
            with open(conf) as f:
                v = f.readline().strip()
    v = v or os.path.join(BLACKSMITH_HOME, "anvil", "vault")
    if v == "~" or v.startswith("~/"):
        v = HOME + v[1:]
    return v


def state_dir():
    return os.path.join(BLACKSMITH_HOME, "anvil", "state")


def die(msg, code=1):
    print("error: " + msg, file=sys.stderr)
    sys.exit(code)


# --- frontmatter ---------------------------------------------------------

def read_note(path):
    """Return (fields: dict, order: list, body: str)."""
    with open(path) as f:
        text = f.read()
    if not text.startswith("---\n"):
        return {}, [], text
    end = text.find("\n---\n", 4)
    if end < 0:
        return {}, [], text
    fields, order = {}, []
    for line in text[4:end].splitlines():
        m = re.match(r"^([A-Za-z_][\w-]*):\s?(.*)$", line)
        if not m:
            continue
        k, v = m.group(1), m.group(2).split("  #")[0].rstrip()
        fields[k] = unquote(v)
        order.append(k)
    return fields, order, text[end + 5:]


def unquote(v):
    v = v.strip()
    if len(v) >= 2 and v[0] == '"' and v[-1] == '"':
        try:
            return json.loads(v)
        except Exception:
            return v[1:-1]
    if len(v) >= 2 and v[0] == "'" and v[-1] == "'":
        return v[1:-1].replace("''", "'")
    return v


def render_value(k, v):
    if k == "tags":
        items = parse_tags(v)
        return "[" + ", ".join(items) + "]"
    if k == "description" and v:
        return json.dumps(v, ensure_ascii=False)
    return v


def parse_tags(v):
    if isinstance(v, list):
        items = v
    else:
        v = (v or "").strip()
        if v.startswith("[") and v.endswith("]"):
            v = v[1:-1]
        items = v.split(",")
    return [t.strip().strip("'\"") for t in items if t.strip().strip("'\"")]


def write_note(path, fields, order, body):
    keys = [k for k in FIELD_ORDER if k in fields or k in ("description", "supersedes")]
    keys += [k for k in order if k not in keys]
    lines = ["---"]
    for k in keys:
        lines.append(("%s: %s" % (k, render_value(k, fields.get(k, "")))).rstrip())
    lines.append("---")
    text = "\n".join(lines) + "\n" + body.lstrip("\n")
    if not text.endswith("\n"):
        text += "\n"
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        f.write(text)
    os.replace(tmp, path)


# --- rules ---------------------------------------------------------------

def domains():
    path = os.path.join(vault(), "domains.txt")
    out = []
    if os.path.exists(path):
        for line in open(path):
            line = line.split("#", 1)[0].strip()
            if line:
                out.append(line)
    return out


def hosts_web_urls():
    conf = os.path.join(CONFIG_DIR, "hosts.tsv")
    urls = []
    if os.path.exists(conf):
        for line in open(conf):
            if line.startswith("#") or not line.strip():
                continue
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 3:
                urls.append(parts[2].rstrip("/"))
    return urls


def source_urls():
    path = os.path.join(vault(), "sources.tsv")
    out = set()
    if os.path.exists(path):
        for line in open(path):
            if line.startswith("#") or not line.strip():
                continue
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 2:
                out.add(parts[1])
    return out


def origin_problem(origin):
    """Return None if origin is allowed, else a one-line reason.

    Allowed: empty; `none` (checked: nothing backs this note); a link on a
    configured Forgejo/Gitea host; a URL recorded in the vault's sources.tsv
    (from /anvil:ingest); a file under raw/.
    """
    o = (origin or "").strip()
    if not o or o == "none":
        return None
    if o.startswith("raw/"):
        if os.path.exists(os.path.join(vault(), o)):
            return None
        return "origin %s does not exist in the vault" % o
    if o in source_urls():
        return None
    for web in hosts_web_urls():
        if o == web or o.startswith(web + "/"):
            return None
    if re.match(r"^https?://", o):
        return ("origin %s is neither on a configured Forgejo/Gitea host nor an ingested source. "
                "Session notes may link only to your own repos; keep web sources with /anvil:ingest." % o)
    return ("origin %r is not allowed: use a Forgejo/Gitea link, an ingested source URL, "
            "a raw/ path, none, or leave it empty" % o)


def detect_origin():
    """Map the current directory's git remote to its web URL, or ''."""
    try:
        remote = subprocess.run(["git", "remote", "get-url", "origin"], capture_output=True,
                                text=True, timeout=5).stdout.strip()
    except Exception:
        return ""
    if not remote:
        return ""
    hosts = hosts_py()
    try:
        res = subprocess.run([sys.executable, hosts, "web-url", remote], capture_output=True,
                             text=True, timeout=15)
    except Exception:
        return ""
    return res.stdout.strip() if res.returncode == 0 else ""


def slugify(title):
    s = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
    return s[:80].rstrip("-") or "note"
