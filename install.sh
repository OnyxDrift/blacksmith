#!/usr/bin/env bash
# Blacksmith installer: asks which plugins you want, then runs each plugin's
# own installer (anvil/install.sh, forge/install.sh). Safe to re-run.
#
#   ./install.sh                     ask, then install (anvil asks its own
#                                    vault questions only if you pick it)
#   ./install.sh --plugins forge     install without the question
#   ./install.sh --update            after `git pull`: refresh the plugins
#                                    that are installed, with no questions
#   ./install.sh --hosts             (re)configure the Forgejo/Gitea host only
#
# In order:
#   1. checks the prerequisites: claude, git, and Python 3.8+ (found as
#      python3, python3.X, python, or py; see lib/find-python.sh)
#   2. shows each plugin and its skills, and asks: both, anvil, or forge
#   3. runs each selected plugin's install.sh (snapshot, settings rule,
#      CLAUDE.md import, plugin install)
#   4. host setup (lib/hosts.py), once, if ~/.blacksmith/config/hosts.tsv
#      does not exist yet
#
# Each plugin installer also works alone. Sessions run the snapshot in
# ~/.blacksmith/plugins, not this folder: edits here change nothing live
# until the next install or --update.
set -euo pipefail

BS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLACKSMITH_HOME="${BLACKSMITH_HOME:-$HOME/.blacksmith}"
SNAP="$BLACKSMITH_HOME/plugins"

MODE=full
PLUGINS=""
NONINTERACTIVE=false
SKIP_HOSTS=false
PLUGIN_ARGS=()
ANVIL_ARGS=()
HOST_ARGS=()

usage() {
  sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'
  cat <<EOF

Flags:
  --plugins a,b         install these plugins without asking (anvil, forge)
  --update              refresh the installed plugins only
  --hosts               run the host setup only (use to change the host)
  --skip-hosts          do not ask for a host now
  --python <path>       the Python 3.8+ to use, when the search finds none
  --skip-settings       leave ~/.claude/settings.json and CLAUDE.md alone
  --non-interactive     never prompt (installs every plugin unless --plugins)
Vault flags (passed to anvil/install.sh):
  --path <dir> --domains "a,b" --single-machine --multi-machine
  --new-vault --existing-vault --add-to-path --skip-add-to-path
Host flags (passed to lib/hosts.py setup):
  --kind forgejo|gitea --web-url URL --ssh-host H --ssh-port P --ssh-user U --owner O
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --plugins) PLUGINS="$(printf '%s' "$2" | tr ',' ' ')"; shift 2 ;;
    --update) MODE=update; shift ;;
    --hosts) MODE=hosts; shift ;;
    --skip-hosts) SKIP_HOSTS=true; shift ;;
    --python) export BLACKSMITH_PYTHON="$2"; shift 2 ;;
    --skip-settings) PLUGIN_ARGS+=("$1"); shift ;;
    --non-interactive) NONINTERACTIVE=true; PLUGIN_ARGS+=("$1"); HOST_ARGS+=("$1"); shift ;;
    --path|--domains) ANVIL_ARGS+=("$1" "$2"); shift 2 ;;
    --single-machine|--multi-machine|--new-vault|--existing-vault|--add-to-path|--skip-add-to-path)
      ANVIL_ARGS+=("$1"); shift ;;
    --kind|--web-url|--ssh-host|--ssh-port|--ssh-user|--owner)
      HOST_ARGS+=("$1" "$2"); shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

need() { command -v "$1" >/dev/null 2>&1 || { echo "error: '$1' is required${2:+ ($2)}" >&2; exit 1; }; }
need claude "install Claude Code first"
need git
# shellcheck source=lib/find-python.sh
. "$BS_DIR/lib/find-python.sh"
PY="$(bs_python)" || { bs_python_missing; exit 1; }
bs_python_ok "$PY" || { echo "error: $PY is not a working Python 3.8+" >&2; exit 1; }
export BLACKSMITH_PYTHON="$PY"

ALL_PLUGINS="$("$PY" "$BS_DIR/lib/settings.py" plugin-names "$BS_DIR/.claude-plugin/marketplace.json" | tr '\n' ' ')"

run_hosts() {
  echo
  "$PY" "$BS_DIR/lib/hosts.py" migrate
  if [ "$MODE" = hosts ]; then
    "$PY" "$BS_DIR/lib/hosts.py" setup --force ${HOST_ARGS[@]+"${HOST_ARGS[@]}"}
  else
    "$PY" "$BS_DIR/lib/hosts.py" setup ${HOST_ARGS[@]+"${HOST_ARGS[@]}"}
  fi
}

if [ "$MODE" = hosts ]; then
  run_hosts
  exit $?
fi

# One-time move for installs before 0.0.1: an anvil PATH block that points at
# the clone or at ~/.anvil/bin is repointed at the snapshot.
repoint_path_block() {
  local start="# >>> anvil PATH (managed by anvil/install.sh) >>>"
  local end="# <<< anvil PATH <<<"
  local line="export PATH=\"$SNAP/anvil/bin:\$PATH\""
  local rc tmp
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] && grep -qF "$start" "$rc" || continue
    tmp="$(mktemp)"
    awk -v s="$start" -v e="$end" -v l="$line" '
      $0 == s { print; print l; skip=1; next }
      $0 == e { skip=0 }
      !skip { print }' "$rc" > "$tmp"
    if ! cmp -s "$tmp" "$rc"; then
      cat "$tmp" > "$rc"
      echo "  repointed the anvil PATH line in $rc at the snapshot (open a new shell)"
    fi
    rm -f "$tmp"
  done
}

valid_plugin() {
  case " $ALL_PLUGINS " in *" $1 "*) return 0 ;; esac
  return 1
}

# --- which plugins ---
if [ "$MODE" = update ]; then
  if [ -z "$PLUGINS" ]; then
    for p in $ALL_PLUGINS; do
      if [ -f "$SNAP/$p/.claude-plugin/plugin.json" ]; then PLUGINS="$PLUGINS $p"; fi
    done
  fi
  if [ -z "$PLUGINS" ]; then
    echo "error: no blacksmith plugin is installed; run $BS_DIR/install.sh" >&2
    exit 1
  fi
  PLUGIN_ARGS+=(--non-interactive)
  SKIP_HOSTS=true
elif [ -z "$PLUGINS" ]; then
  if [ "$NONINTERACTIVE" = false ] && [ -t 0 ]; then
    echo
    echo "Blacksmith has two plugins. Each works alone."
    echo
    "$PY" "$BS_DIR/lib/describe.py" "$BS_DIR"
    echo "Which plugins do you want to install?"
    echo "  1) Both"
    echo "  2) anvil only"
    echo "  3) forge only"
    while true; do
      read -r -p "Choose [1/2/3]: " CHOICE
      case "$CHOICE" in
        1) PLUGINS="$ALL_PLUGINS"; break ;;
        2) PLUGINS="anvil"; break ;;
        3) PLUGINS="forge"; break ;;
        *) echo "Enter 1, 2, or 3." ;;
      esac
    done
  else
    PLUGINS="$ALL_PLUGINS"
  fi
fi
for p in $PLUGINS; do
  valid_plugin "$p" || { echo "error: unknown plugin '$p' (known: $ALL_PLUGINS)" >&2; exit 1; }
done

# --- each plugin's own installer ---
for p in $PLUGINS; do
  echo
  echo "==================== $p ===================="
  if [ "$p" = anvil ]; then
    bash "$BS_DIR/anvil/install.sh" --skip-hosts ${PLUGIN_ARGS[@]+"${PLUGIN_ARGS[@]}"} ${ANVIL_ARGS[@]+"${ANVIL_ARGS[@]}"}
  else
    bash "$BS_DIR/$p/install.sh" --skip-hosts ${PLUGIN_ARGS[@]+"${PLUGIN_ARGS[@]}"}
  fi
done
repoint_path_block

# --- host config, once ---
"$PY" "$BS_DIR/lib/hosts.py" migrate
if [ "$SKIP_HOSTS" = false ] && [ ! -f "$BLACKSMITH_HOME/config/hosts.tsv" ]; then
  run_hosts || echo "  host setup incomplete; finish later with: $BS_DIR/install.sh --hosts"
fi

echo
echo "==> blacksmith ready:$(printf ' %s' $PLUGINS). Start a new Claude Code session (or run /reload-plugins)."
echo "    After a git pull: $BS_DIR/install.sh --update"
exit 0
