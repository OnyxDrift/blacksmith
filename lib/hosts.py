#!/usr/bin/env python3
"""Blacksmith host config: which Forgejo/Gitea server holds your repos, and
how an agent reads from it without write access.

Shared by the blacksmith plugins through one documented file:

    ~/.blacksmith/config/hosts.tsv   (machine-local, never synced)

The read-only key is ~/.blacksmith/keys/blacksmith_reader. Only the
`Host` block goes in ~/.ssh/config, because ssh reads nothing else.
BLACKSMITH_HOME overrides ~/.blacksmith.

Columns: name kind web_url ssh_host ssh_port ssh_user owner ssh_alias key_path

Subcommands:
  setup [--force] [--non-interactive] [--name N] [--kind forgejo|gitea]
        [--web-url URL] [--ssh-host H] [--ssh-port P] [--ssh-user U] [--owner O]
        Create the read-only key, the ~/.ssh/config block, and hosts.tsv.
  show                     Print the configured hosts.
  check [name]             Test that the read-only key can authenticate.
  migrate                  Move hosts.tsv and the key from the older layout
                           (~/.config/blacksmith, ~/.ssh) into ~/.blacksmith
                           and rewrite the ~/.ssh/config block. Idempotent.
  web-url <git-remote>     Map a git remote to its web page URL (exit 1 if
                           the remote is not on a configured host).
  ssh-remote <web-url>     Map a repo web URL to "<ssh_alias>:<owner>/<repo>"
                           for read-only git access (exit 1 if unknown).

The read-only guarantee comes from the server: the key belongs to a bot user
(`blacksmith-reader`) that has only Read access, so a push is refused.
"""
import os
import re
import socket
import subprocess
import sys

# Plain \n line ends, also on Windows, where bash would keep the \r.
sys.stdout.reconfigure(newline="\n")

HOME = os.path.expanduser("~")
BLACKSMITH_HOME = os.environ.get("BLACKSMITH_HOME") or os.path.join(HOME, ".blacksmith")
CONFIG_DIR = os.path.join(BLACKSMITH_HOME, "config")
KEYS_DIR = os.path.join(BLACKSMITH_HOME, "keys")
HOSTS_FILE = os.path.join(CONFIG_DIR, "hosts.tsv")
SSH_DIR = os.path.join(HOME, ".ssh")
SSH_CONFIG = os.path.join(SSH_DIR, "config")
KEY_PATH = os.path.join(KEYS_DIR, "blacksmith_reader")
BOT_USER = "blacksmith-reader"
COLUMNS = ["name", "kind", "web_url", "ssh_host", "ssh_port", "ssh_user", "owner", "ssh_alias", "key_path"]
MARK_START = "# >>> blacksmith hosts (managed by ai/blacksmith/lib/hosts.py) >>>"
MARK_END = "# <<< blacksmith hosts <<<"


def load_hosts():
    rows = []
    if not os.path.exists(HOSTS_FILE):
        return rows
    with open(HOSTS_FILE) as f:
        for line in f:
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) < len(COLUMNS):
                continue
            rows.append(dict(zip(COLUMNS, parts)))
    return rows


def save_hosts(rows):
    os.makedirs(CONFIG_DIR, exist_ok=True)
    with open(HOSTS_FILE, "w") as f:
        f.write("# blacksmith hosts — written by ai/blacksmith/lib/hosts.py setup\n")
        f.write("#" + "\t".join(COLUMNS) + "\n")
        for r in rows:
            f.write("\t".join(r[c] for c in COLUMNS) + "\n")


def ssh_resolve(alias):
    """Resolve an ssh config alias to (hostname, port) via `ssh -G`."""
    try:
        out = subprocess.run(["ssh", "-G", alias], capture_output=True, text=True, timeout=10).stdout
    except Exception:
        return alias, ""
    host, port = alias, ""
    for line in out.splitlines():
        k, _, v = line.partition(" ")
        if k == "hostname":
            host = v
        elif k == "port":
            port = v
    return host, port


def parse_remote(remote):
    """Return (host, port, path) for a git remote, or None."""
    remote = remote.strip()
    m = re.match(r"^(ssh|git|https?)://(?:[^@/]+@)?([^/:]+)(?::(\d+))?/(.+)$", remote)
    if m:
        scheme, host, port, path = m.groups()
        return host, port or "", path, scheme
    m = re.match(r"^(?:[^@/]+@)?([^/:]+):(?!//)(.+)$", remote)  # scp-like: [user@]host:path
    if m:
        host, path = m.groups()
        rhost, rport = ssh_resolve(host)
        return rhost, rport, path, "scp"
    return None


def repo_path(path):
    path = path.strip("/")
    if path.endswith(".git"):
        path = path[:-4]
    return path


def web_url(remote):
    p = parse_remote(remote)
    if not p:
        return None
    host, port, path, scheme = p
    for r in load_hosts():
        web = r["web_url"].rstrip("/")
        web_host = re.sub(r"^https?://", "", web).split("/")[0]
        web_hostname, _, web_port = web_host.partition(":")
        if scheme in ("http", "https"):
            if host == web_hostname and (port or ("443" if scheme == "https" else "80")) == (web_port or ("443" if web.startswith("https") else "80")):
                return web + "/" + repo_path(path)
        elif host == r["ssh_host"] and (port or "22") == (r["ssh_port"] or "22"):
            return web + "/" + repo_path(path)
    return None


def ssh_remote(url):
    for r in load_hosts():
        web = r["web_url"].rstrip("/")
        if url.startswith(web + "/"):
            rest = url[len(web) + 1:]
            parts = rest.split("/")
            if len(parts) >= 2:
                return "%s:%s/%s" % (r["ssh_alias"], parts[0], repo_path(parts[1]))
    return None


def ask(prompt, default, interactive):
    if not interactive:
        return default
    shown = " [%s]" % default if default else ""
    try:
        val = input("%s%s: " % (prompt, shown)).strip()
    except EOFError:
        val = ""
    return val or default


def write_ssh_block(rows):
    os.makedirs(SSH_DIR, mode=0o700, exist_ok=True)
    lines = [MARK_START]
    for r in rows:
        lines += [
            "Host %s" % r["ssh_alias"],
            "  HostName %s" % r["ssh_host"],
            "  Port %s" % (r["ssh_port"] or "22"),
            "  User %s" % r["ssh_user"],
            "  IdentityFile %s" % r["key_path"],
            "  IdentitiesOnly yes",
        ]
    lines.append(MARK_END)
    block = "\n".join(lines) + "\n"
    existing = open(SSH_CONFIG).read() if os.path.exists(SSH_CONFIG) else ""
    if MARK_START in existing and MARK_END in existing:
        pre = existing.split(MARK_START)[0]
        post = existing.split(MARK_END, 1)[1].lstrip("\n")
        new = pre + block + post
    else:
        new = existing + ("\n" if existing and not existing.endswith("\n") else "") + ("\n" if existing else "") + block
    if new != existing:
        with open(SSH_CONFIG, "w") as f:
            f.write(new)
        os.chmod(SSH_CONFIG, 0o600)
        print("  wrote the blacksmith block in %s" % SSH_CONFIG)


def ensure_key():
    if os.path.exists(KEY_PATH):
        return
    os.makedirs(KEYS_DIR, mode=0o700, exist_ok=True)
    os.chmod(KEYS_DIR, 0o700)
    comment = "%s@%s" % (BOT_USER, socket.gethostname().split(".")[0])
    subprocess.run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-C", comment, "-f", KEY_PATH], check=True)
    print("  generated read-only key %s (no passphrase, so agents can use it)" % KEY_PATH)


def check(row):
    try:
        res = subprocess.run(["ssh", "-T", "-o", "BatchMode=yes", "-o", "ConnectTimeout=8", row["ssh_alias"]],
                             capture_output=True, text=True, timeout=20)
    except Exception as e:
        return False, str(e)
    out = (res.stdout + res.stderr).strip()
    ok = "successfully authenticated" in out.lower()
    return ok, out.splitlines()[0] if out else "(no output)"


def web_steps(row):
    pub = open(KEY_PATH + ".pub").read().strip()
    web = row["web_url"].rstrip("/")
    return """
Finish in the {kind} web interface (a script cannot do these):

  1. Create the bot user '{bot}': Site Administration > User Accounts >
     Create User Account ({web}/admin/users on Forgejo; {web}/-/admin/users on
     newer Gitea). It needs no special rights.
  2. Sign in as '{bot}', open {web}/user/settings/keys, and add this SSH key:

       {pub}

  3. Sign back in as '{owner}'. For each repo the agent may read, open
     Settings > Collaborators and add '{bot}' with Read access.
     (Later: an organization team with Read on all repos covers new repos.)
""".format(kind=row["kind"].capitalize(), bot=BOT_USER, web=web, pub=pub, owner=row["owner"])


def cmd_setup(args):
    force = "--force" in args
    interactive = sys.stdin.isatty() and "--non-interactive" not in args
    opts = {}
    it = iter(args)
    for a in it:
        if a.startswith("--") and a not in ("--force", "--non-interactive"):
            opts[a[2:].replace("-", "_")] = next(it, "")
    rows = load_hosts()
    if rows and not force:
        print("blacksmith hosts: already configured (%s). Use --force to redo." % HOSTS_FILE)
        cmd_show()
        return 0

    print("\n==> blacksmith host setup: the Forgejo/Gitea server that holds your repos")
    kind = ask("Kind (forgejo or gitea)", opts.get("kind", "forgejo"), interactive).lower()
    if kind not in ("forgejo", "gitea"):
        print("error: kind must be forgejo or gitea", file=sys.stderr)
        return 1
    web = ask("Web address (the web UI you sign in to), e.g. https://git.example.com", opts.get("web_url", ""), interactive).rstrip("/")
    if not re.match(r"^https?://", web):
        print("blacksmith hosts: no web address given; skipped. Run again with --hosts.", file=sys.stderr)
        return 0 if not interactive else 1
    default_host = re.sub(r"^https?://", "", web).split("/")[0].split(":")[0]
    ssh_host = ask("SSH host", opts.get("ssh_host", default_host), interactive)
    ssh_port = ask("SSH port", opts.get("ssh_port", "22"), interactive)
    ssh_user = ask("SSH user", opts.get("ssh_user", "git"), interactive)
    owner = ask("Repo owner (your username)", opts.get("owner", ""), interactive)
    if not owner:
        print("blacksmith hosts: no repo owner given; skipped. Run again with --hosts.", file=sys.stderr)
        return 0 if not interactive else 1
    name = opts.get("name", kind)
    row = {
        "name": name, "kind": kind, "web_url": web, "ssh_host": ssh_host, "ssh_port": ssh_port,
        "ssh_user": ssh_user, "owner": owner, "ssh_alias": "blacksmith-%s" % name, "key_path": KEY_PATH,
    }
    rows = [r for r in rows if r["name"] != name] + [row]

    ensure_key()
    write_ssh_block(rows)
    save_hosts(rows)
    print("  wrote %s" % HOSTS_FILE)
    print(web_steps(row))

    if interactive:
        ans = ask("Press Enter when done to test access (or type 'skip')", "", True)
        if ans.lower() != "skip":
            ok, msg = check(row)
            print("  %s: %s" % ("PASS" if ok else "FAIL", msg))
            if not ok:
                print("  Re-test later with: ai/blacksmith/lib/hosts.py check")
    else:
        print("Test later with: ai/blacksmith/lib/hosts.py check")
    return 0


def cmd_migrate():
    import shutil
    legacy_conf = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.join(HOME, ".config"), "blacksmith")
    legacy_key = os.path.join(SSH_DIR, "blacksmith_reader")
    moved = False
    if os.path.exists(os.path.join(legacy_conf, "hosts.tsv")) and not os.path.exists(HOSTS_FILE):
        os.makedirs(CONFIG_DIR, exist_ok=True)
        shutil.move(os.path.join(legacy_conf, "hosts.tsv"), HOSTS_FILE)
        print("  moved %s/hosts.tsv to %s" % (legacy_conf, CONFIG_DIR))
        moved = True
    if os.path.exists(legacy_key) and not os.path.exists(KEY_PATH):
        os.makedirs(KEYS_DIR, mode=0o700, exist_ok=True)
        os.chmod(KEYS_DIR, 0o700)
        for ext in ("", ".pub"):
            if os.path.exists(legacy_key + ext):
                shutil.move(legacy_key + ext, KEY_PATH + ext)
        print("  moved the read-only key to %s" % KEY_PATH)
        moved = True
    try:
        os.rmdir(legacy_conf)
    except OSError:
        pass
    rows = load_hosts()
    if rows:
        changed = False
        for r in rows:
            if r["key_path"] != KEY_PATH and os.path.basename(r["key_path"]) == "blacksmith_reader":
                r["key_path"] = KEY_PATH
                changed = True
        if changed:
            save_hosts(rows)
        if changed or moved:
            write_ssh_block(rows)
    return 0


def cmd_show():
    rows = load_hosts()
    if not rows:
        print("blacksmith hosts: not configured (%s missing)" % HOSTS_FILE)
        return 1
    for r in rows:
        print("%s: %s %s  ssh %s@%s:%s as %s  owner %s" % (
            r["name"], r["kind"], r["web_url"], r["ssh_user"], r["ssh_host"], r["ssh_port"], r["ssh_alias"], r["owner"]))
    return 0


def cmd_check(args):
    rows = load_hosts()
    if args:
        rows = [r for r in rows if r["name"] == args[0]]
    if not rows:
        print("blacksmith hosts: nothing to check", file=sys.stderr)
        return 1
    rc = 0
    for r in rows:
        ok, msg = check(r)
        print("%s %s: %s" % ("PASS" if ok else "FAIL", r["name"], msg))
        rc |= 0 if ok else 1
    return rc


def main(argv):
    if not argv or argv[0] in ("-h", "--help", "help"):
        print(__doc__)
        return 0
    cmd, args = argv[0], argv[1:]
    if cmd == "setup":
        return cmd_setup(args)
    if cmd == "show":
        return cmd_show()
    if cmd == "migrate":
        return cmd_migrate()
    if cmd == "check":
        return cmd_check(args)
    if cmd == "web-url" and args:
        u = web_url(args[0])
        if u:
            print(u)
            return 0
        return 1
    if cmd == "ssh-remote" and args:
        u = ssh_remote(args[0])
        if u:
            print(u)
            return 0
        return 1
    print("unknown command; see --help", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
