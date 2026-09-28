#!/usr/bin/env bash
# Blacksmith uninstaller: asks which plugins to remove (both, anvil, or
# forge), then runs each plugin's own uninstall.sh. Each removes its plugin,
# snapshot folder, permission rule, and CLAUDE.md import; anvil also removes
# its PATH block and recorded vault location. With no plugin left, the
# marketplace and the snapshot (~/.blacksmith/plugins) go too.
# Notes, host config, and the read-only key stay.
#
#   --plugins a,b  remove these plugins without asking
#   --purge        also delete all anvil vault content (asks to confirm)
#   --keep-folder / --delete-folder   with --purge, see anvil/uninstall.sh
#   --hosts        also remove the host config, the ~/.ssh/config block, and
#                  the read-only key (~/.blacksmith/keys/blacksmith_reader)
#
# The .env read-deny rules that forge added stay in ~/.claude/settings.json.
set -euo pipefail

BS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOVE_HOSTS=false
PLUGINS=""
ANVIL_ARGS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --hosts) REMOVE_HOSTS=true; shift ;;
    --plugins) PLUGINS="$(printf '%s' "$2" | tr ',' ' ')"; shift 2 ;;
    --python) export BLACKSMITH_PYTHON="$2"; shift 2 ;;
    --purge|--keep-folder|--delete-folder) ANVIL_ARGS+=("$1"); shift ;;
    --path) ANVIL_ARGS+=("$1" "$2"); shift 2 ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

# shellcheck source=lib/find-python.sh
. "$BS_DIR/lib/find-python.sh"
PY="$(bs_python)" || { bs_python_missing; exit 1; }
ALL_PLUGINS="$("$PY" "$BS_DIR/lib/settings.py" plugin-names "$BS_DIR/.claude-plugin/marketplace.json" | tr '\n' ' ')"
if [ -z "$PLUGINS" ]; then
  if [ -t 0 ]; then
    echo "Which plugins do you want to remove?"
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
  case " $ALL_PLUGINS " in *" $p "*) ;; *) echo "error: unknown plugin '$p' (known: $ALL_PLUGINS)" >&2; exit 1 ;; esac
  echo "==> $p"
  if [ "$p" = anvil ]; then
    bash "$BS_DIR/anvil/uninstall.sh" ${ANVIL_ARGS[@]+"${ANVIL_ARGS[@]}"}
  else
    bash "$BS_DIR/$p/uninstall.sh"
  fi
done

if [ "$REMOVE_HOSTS" = true ]; then
  BLACKSMITH_HOME="${BLACKSMITH_HOME:-$HOME/.blacksmith}"
  rm -f "$BLACKSMITH_HOME/config/hosts.tsv" "$BLACKSMITH_HOME/keys/blacksmith_reader" "$BLACKSMITH_HOME/keys/blacksmith_reader.pub"
  rmdir "$BLACKSMITH_HOME/keys" 2>/dev/null || true
  if [ -f "$HOME/.ssh/config" ]; then
    TMP="$(mktemp)"
    awk '
      /^# >>> blacksmith hosts / {skip=1; next}
      /^# <<< blacksmith hosts <<<$/ {skip=0; next}
      !skip {print}' "$HOME/.ssh/config" > "$TMP"
    cat "$TMP" > "$HOME/.ssh/config"
    rm -f "$TMP"
  fi
  echo "  removed host config, ssh block, and read-only key"
  echo "  (the blacksmith-reader user and its key still exist in the Forgejo/Gitea web UI; remove them there if unused)"
fi
echo "==> blacksmith: removed$(printf ' %s' $PLUGINS)."
