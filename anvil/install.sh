#!/usr/bin/env bash
# Anvil installer. Works alone, or run by the blacksmith installer
# (../install.sh), which asks first which plugins to install.
#
# In order:
#   1. copies the plugin and the shared lib into the snapshot
#      (~/.blacksmith/plugins/anvil, ~/.blacksmith/plugins/lib)
#   2. sets up the vault (your data), asking up to five questions:
#   - vault folders, index.md, domains.txt, moc/<Domain>.md
#   - everything under ~/.blacksmith ($BLACKSMITH_HOME): the vault at
#     anvil/vault by default, machine-local state at anvil/state, and
#     config/anvil-home only when the vault lives somewhere else
#   - optional PATH block so `anvil` works in terminals
#   - optional Syncthing install for a multi-machine vault
#   3. merges settings.fragment.json into ~/.claude/settings.json
#      (the `Bash(anvil *)` permission rule)
#   4. adds `@~/.blacksmith/plugins/anvil/CLAUDE-pointer.md` to
#      ~/.claude/CLAUDE.md, once
#   5. registers the `blacksmith` marketplace and installs anvil@blacksmith
#   6. host setup (../lib/hosts.py), if ~/.blacksmith/config/hosts.tsv is
#      missing
#
# Safe to re-run: notes, index.md, domains.txt, and moc/*.md are created
# once and never overwritten. Answers can come from flags, env vars, or
# prompts (asked only in an interactive terminal).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BS_SRC="$(dirname "$SCRIPT_DIR")"
PLUGIN=anvil
# shellcheck source=../lib/install-common.sh
. "$BS_SRC/lib/install-common.sh"
DEFAULT_ANVIL_HOME="$BLACKSMITH_HOME/anvil/vault"
DEFAULT_DOMAINS="software, finance, trading, business, health"
CONFIG_DIR="$BLACKSMITH_HOME/config"
STATE_DIR="$BLACKSMITH_HOME/anvil/state"

ANVIL_HOME="${ANVIL_HOME:-}"
MODE="${ANVIL_MODE:-}"                 # single | multi
VAULT_ACTION="${ANVIL_VAULT_ACTION:-}" # new | existing
DOMAINS_INPUT="${ANVIL_DOMAINS:-}"     # only used if domains.txt is missing
ADD_TO_PATH="${ANVIL_ADD_TO_PATH:-}"   # true | false
NONINTERACTIVE=false
SKIP_HOSTS=false
SKIP_SETTINGS=false
HOST_ARGS=()

usage() {
  cat <<EOF
Usage: install.sh [--single-machine|--multi-machine] [--new-vault|--existing-vault]
                  [--path <dir>] [--domains "a,b,c"] [--add-to-path|--skip-add-to-path]
                  [--non-interactive] [--skip-hosts] [--skip-settings]
                  [--python <path>]
                  [--kind … --web-url … --ssh-host … --ssh-port … --ssh-user … --owner …]

Installs the anvil plugin and sets up its vault on this machine. Works
alone, or run by the blacksmith installer. Safe to re-run.

With no flags, it asks up to five questions:
  1. Single machine, or shared across machines (Syncthing)?
  2. New vault, or point at an existing one?
  3. Vault path? (default: $DEFAULT_ANVIL_HOME)
  4. Only if domains.txt is missing: starting domains? (default: $DEFAULT_DOMAINS)
  5. Add 'anvil' to PATH for terminals (~/.bashrc and/or ~/.zshrc)?

Everything lives under $BLACKSMITH_HOME (override with BLACKSMITH_HOME).
A vault kept elsewhere is recorded in $CONFIG_DIR/anvil-home and reused;
questions 2 and 3 are then skipped. Env vars: ANVIL_HOME, ANVIL_MODE,
ANVIL_VAULT_ACTION, ANVIL_DOMAINS, ANVIL_ADD_TO_PATH. --non-interactive
never prompts and uses the defaults.

--skip-settings leaves ~/.claude/settings.json and ~/.claude/CLAUDE.md
alone. --skip-hosts does not ask for a Forgejo/Gitea host now. --python
names the Python 3.8+ to use when the search does not find one. Host flags
pass to ../lib/hosts.py setup.

To add a domain later: add a line to domains.txt, then re-run this script
to create its moc/<Domain>.md.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --path) ANVIL_HOME="$2"; shift 2 ;;
    --single-machine) MODE=single; shift ;;
    --multi-machine) MODE=multi; shift ;;
    --new-vault) VAULT_ACTION=new; shift ;;
    --existing-vault) VAULT_ACTION=existing; shift ;;
    --domains) DOMAINS_INPUT="$2"; shift 2 ;;
    --add-to-path) ADD_TO_PATH=true; shift ;;
    --skip-add-to-path) ADD_TO_PATH=false; shift ;;
    --non-interactive) NONINTERACTIVE=true; HOST_ARGS+=("$1"); shift ;;
    --skip-hosts) SKIP_HOSTS=true; shift ;;
    --python) export BLACKSMITH_PYTHON="$2"; shift 2 ;;
    --skip-settings) SKIP_SETTINGS=true; shift ;;
    --kind|--web-url|--ssh-host|--ssh-port|--ssh-user|--owner)
      HOST_ARGS+=("$1" "$2"); shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [ -t 0 ] && [ "$NONINTERACTIVE" = false ]; then
  INTERACTIVE=true
else
  INTERACTIVE=false
fi

bs_require
bs_snapshot_plugin

mkdir -p "$CONFIG_DIR" "$STATE_DIR"

# Reuse a vault location recorded by an earlier run, unless one was given.
if [ -z "$ANVIL_HOME" ] && [ -f "$CONFIG_DIR/anvil-home" ]; then
  ANVIL_HOME="$(head -n 1 "$CONFIG_DIR/anvil-home")"
  [ -n "$ANVIL_HOME" ] && VAULT_ACTION="${VAULT_ACTION:-existing}"
fi
case "$ANVIL_HOME" in "~"|"~/"*) ANVIL_HOME="$HOME${ANVIL_HOME#\~}" ;; esac

ask_choice() {
  # ask_choice <prompt> <var-name> <value-for-1> <value-for-2>
  local choice
  while true; do
    read -r -p "$1 [1/2]: " choice
    case "$choice" in
      1) printf -v "$2" '%s' "$3"; return ;;
      2) printf -v "$2" '%s' "$4"; return ;;
      *) echo "Enter 1 or 2." ;;
    esac
  done
}

# --- 1: single or multi machine ---
if [ -z "$MODE" ]; then
  if [ "$INTERACTIVE" = true ]; then
    cat <<EOF

Is this vault used on more than one machine?
  1) Single machine — nothing else to install.
  2) Multi machine  — installs Syncthing here and prints the sharing steps.
EOF
    ask_choice "Choose" MODE single multi
  else
    MODE=single
  fi
fi

# --- 2: new or existing vault ---
if [ -z "$VAULT_ACTION" ]; then
  if [ "$INTERACTIVE" = true ]; then
    cat <<EOF

Create a new vault, or use one that already exists (restored, or synced in
from another machine)?
  1) New vault
  2) Existing vault
EOF
    ask_choice "Choose" VAULT_ACTION new existing
  else
    VAULT_ACTION=new
  fi
fi

# --- 3: path ---
if [ -z "$ANVIL_HOME" ]; then
  if [ "$INTERACTIVE" = true ]; then
    read -r -p "Vault path [$DEFAULT_ANVIL_HOME]: " INPUT_PATH
    ANVIL_HOME="${INPUT_PATH:-$DEFAULT_ANVIL_HOME}"
  else
    ANVIL_HOME="$DEFAULT_ANVIL_HOME"
  fi
fi
case "$ANVIL_HOME" in "~"|"~/"*) ANVIL_HOME="$HOME${ANVIL_HOME#\~}" ;; esac

VAULT_LOOKS_POPULATED=false
if [ -d "$ANVIL_HOME/semantic" ] || [ -d "$ANVIL_HOME/procedural" ] || [ -f "$ANVIL_HOME/index.md" ]; then
  VAULT_LOOKS_POPULATED=true
fi
if [ "$VAULT_ACTION" = "existing" ] && [ "$VAULT_LOOKS_POPULATED" = false ]; then
  echo "==> NOTE: no vault content found at $ANVIL_HOME; creating a fresh vault there."
fi

# --- 4: domains (only when domains.txt is missing) ---
if [ ! -f "$ANVIL_HOME/domains.txt" ] && [ -z "$DOMAINS_INPUT" ]; then
  if [ "$INTERACTIVE" = true ]; then
    cat <<EOF

Starting domains: broad, few, stable areas to organize notes by. Add more
later by editing domains.txt and re-running this script.
EOF
    read -r -p "Domains, comma-separated [$DEFAULT_DOMAINS]: " DOMAINS_INPUT
  fi
  DOMAINS_INPUT="${DOMAINS_INPUT:-$DEFAULT_DOMAINS}"
fi

# --- 5: PATH for terminals ---
if [ -z "$ADD_TO_PATH" ]; then
  if [ "$INTERACTIVE" = true ]; then
    echo
    read -r -p "Add 'anvil' to PATH for terminals (~/.bashrc / ~/.zshrc)? [Y/n]: " CHOICE
    case "$CHOICE" in n|N|no|No) ADD_TO_PATH=false ;; *) ADD_TO_PATH=true ;; esac
  else
    ADD_TO_PATH=false
  fi
fi

echo
echo "==> anvil vault at $ANVIL_HOME ($MODE-machine)"

# --- vault content: created once, never overwritten ---
mkdir -p "$ANVIL_HOME"/{semantic,procedural,strategic,episodic,raw,_inbox,_archive,moc}

if [ ! -f "$ANVIL_HOME/index.md" ]; then
  cp "$SCRIPT_DIR/templates/index.md" "$ANVIL_HOME/index.md"
  echo "  created index.md"
fi

if [ ! -f "$ANVIL_HOME/domains.txt" ]; then
  IFS=',' read -ra RAW_DOMAINS <<< "$DOMAINS_INPUT"
  {
    echo "# Anvil domains — broad, stable life/work areas. One per line."
    echo "# Meant to stay few. If a note doesn't fit any of these, ask the user"
    echo "# before adding a new line here — use --subdomain for anything more"
    echo "# specific instead (a language, tool, project, or narrower topic)."
    echo "#"
    echo "# To add one: add a line below, then re-run install.sh — it creates"
    echo "# the matching moc/<Domain>.md automatically for anything new here."
    for d in "${RAW_DOMAINS[@]}"; do
      d="$(echo "$d" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')"
      [ -z "$d" ] && continue
      echo "$d"
    done
  } > "$ANVIL_HOME/domains.txt"
  echo "  created domains.txt"
fi

# moc/ files follow domains.txt, so adding a domain and re-running is enough.
while IFS= read -r d || [ -n "$d" ]; do
  d="${d%%#*}"
  d="$(echo "$d" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [ -z "$d" ] && continue
  TITLE="$(echo "$d" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
  if [ ! -f "$ANVIL_HOME/moc/$TITLE.md" ]; then
    printf '# %s\n' "$TITLE" > "$ANVIL_HOME/moc/$TITLE.md"
    echo "  created moc/$TITLE.md"
  fi
done < "$ANVIL_HOME/domains.txt"

# A fresh vault starts at the package schema: nothing to migrate.
if [ "$VAULT_LOOKS_POPULATED" = false ] && [ ! -f "$ANVIL_HOME/.anvil-applied-version" ]; then
  tr -d '[:space:]' < "$SCRIPT_DIR/SCHEMA_VERSION" > "$ANVIL_HOME/.anvil-applied-version"
fi

# --- where the vault is, for every anvil script on this machine ---
# Recorded only when it is not the default $BLACKSMITH_HOME/anvil/vault.
if [ "$ANVIL_HOME" = "$DEFAULT_ANVIL_HOME" ]; then
  rm -f "$CONFIG_DIR/anvil-home"
else
  printf '%s\n' "$ANVIL_HOME" > "$CONFIG_DIR/anvil-home"
  echo "  recorded vault path in $CONFIG_DIR/anvil-home"
fi

# --- PATH block for terminals ---
MARK_START="# >>> anvil PATH (managed by anvil/install.sh) >>>"
MARK_END="# <<< anvil PATH <<<"
PATH_LINE="export PATH=\"$SNAP/anvil/bin:\$PATH\""
if [ "$ADD_TO_PATH" = true ]; then
  TOUCHED=""
  for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$RC" ] || continue
    if grep -qF "$MARK_START" "$RC"; then
      # Refresh the block in place, in case the package moved.
      TMP="$(mktemp)"
      awk -v s="$MARK_START" -v e="$MARK_END" -v l="$PATH_LINE" '
        $0 == s { print; print l; skip=1; next }
        $0 == e { skip=0 }
        !skip { print }' "$RC" > "$TMP"
      if ! cmp -s "$TMP" "$RC"; then
        cat "$TMP" > "$RC"
        echo "  updated the anvil PATH block in $RC"
      fi
      rm -f "$TMP"
    else
      printf '\n%s\n%s\n%s\n' "$MARK_START" "$PATH_LINE" "$MARK_END" >> "$RC"
      echo "  added anvil to PATH in $RC"
    fi
    TOUCHED="$TOUCHED $RC"
  done
  if [ -z "$TOUCHED" ]; then
    echo "  WARNING: no ~/.bashrc or ~/.zshrc; add this line yourself: $PATH_LINE"
  fi
fi

# --- Syncthing for a multi-machine vault ---
if [ "$MODE" = "multi" ]; then
  echo
  if command -v syncthing >/dev/null 2>&1; then
    echo "==> Syncthing already installed."
  elif command -v brew >/dev/null 2>&1; then
    echo "==> Installing Syncthing via Homebrew..."
    brew install syncthing
    brew services start syncthing
  else
    echo "==> Install Syncthing manually: https://syncthing.net/downloads/"
  fi
  cat <<EOF

==> Share the vault with Syncthing (pairing needs one click on each machine):
    1. Open http://localhost:8384. On a headless machine, run this from a
       machine with a browser instead, then open http://localhost:8385 there:
         ssh -L 8385:localhost:8384 $(whoami)@$(hostname)
    2. Add Folder -> label 'anvil' -> path '$ANVIL_HOME'. Share only this
       folder, never all of $BLACKSMITH_HOME: its state/, keys/, and
       config/ are machine-local.
    3. Actions > Show ID: copy this machine's device ID.
    4. On each other machine: install Syncthing, add this device, accept the
       'anvil' folder share, then run blacksmith/install.sh there and
       choose 'existing vault'.
    5. Trusting a device shares nothing by itself: edit the folder ->
       Sharing -> tick the new device.
EOF
fi

echo
echo "==> Vault ready: $ANVIL_HOME"

# The early anvil (before blacksmith) kept its vault and tooling in ~/.anvil.
# Report it; moving notes is the user's call.
LEGACY="$HOME/.anvil"
if [ -d "$LEGACY" ] && [ "$(cd "$LEGACY" && pwd -P)" != "$(cd "$ANVIL_HOME" && pwd -P)" ]; then
  LEGACY_NOTES="$(find "$LEGACY/semantic" "$LEGACY/procedural" "$LEGACY/strategic" "$LEGACY/episodic" -name '*.md' 2>/dev/null | wc -l | tr -d ' ' || true)"
  cat <<EOF

==> NOTE: an early anvil install is still at $LEGACY ($LEGACY_NOTES notes).
    This install does not use it. To keep those notes, either:
      - re-run this installer, choose "existing vault", and give $LEGACY
        as the path (then run: anvil migrate), or
      - copy its semantic/, procedural/, strategic/, and episodic/ notes
        into $ANVIL_HOME, then run: anvil migrate
    Its bin/ and CLAUDE_BLOCK.md are no longer used. A project where you ran
    the early 'anvil init' has a "## Anvil" section in its CLAUDE.md that
    points at $LEGACY/bin; remove that section.
EOF
fi

echo
echo "==> anvil plugin"
if [ "$SKIP_SETTINGS" = false ]; then
  bs_settings_add
  bs_import_add
  bs_legacy_anvil_skills
fi
bs_register
if [ "$SKIP_HOSTS" = false ]; then
  bs_hosts ${HOST_ARGS[@]+"${HOST_ARGS[@]}"}
fi

echo
echo "==> anvil ready. Start a new Claude Code session (or run /reload-plugins)."
echo "    Try: /anvil:vault   /anvil:recall <topic>   /anvil:note <claim>"
if [ "$ADD_TO_PATH" = true ]; then
  echo "    In a new terminal: anvil status"
else
  echo "    In a terminal: $SNAP/anvil/bin/anvil status"
fi
PENDING="$("$SNAP/anvil/bin/anvil" status 2>/dev/null | grep -F 'run: anvil migrate' || true)"
[ -n "$PENDING" ] && echo "    Vault schema is behind the package: run 'anvil migrate' when ready."
exit 0
