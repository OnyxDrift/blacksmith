#!/usr/bin/env bash
# Anvil uninstaller. Works alone, or run by the blacksmith uninstaller.
#
# Default: uninstalls anvil@blacksmith, removes its snapshot folder, its
# `Bash(anvil *)` rule, and its CLAUDE.md import line, then the anvil PATH
# block from ~/.bashrc / ~/.zshrc and the recorded vault location
# (~/.blacksmith/config/anvil-home). The vault and every note stay on disk.
#
# --purge deletes vault content too. Irreversible.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BS_SRC="$(dirname "$SCRIPT_DIR")"
PLUGIN=anvil
# shellcheck source=../lib/install-common.sh
. "$BS_SRC/lib/install-common.sh"
CONFIG_FILE="$BLACKSMITH_HOME/config/anvil-home"
ANVIL_HOME="${ANVIL_HOME:-}"
if [ -z "$ANVIL_HOME" ] && [ -f "$CONFIG_FILE" ]; then
  ANVIL_HOME="$(head -n 1 "$CONFIG_FILE")"
fi
ANVIL_HOME="${ANVIL_HOME:-$BLACKSMITH_HOME/anvil/vault}"
PURGE=false
DELETE_FOLDER=false
DELETE_FOLDER_SET=false

MARK_START="# >>> anvil PATH (managed by anvil/install.sh) >>>"
MARK_END="# <<< anvil PATH <<<"

usage() {
  cat <<EOF
Usage: uninstall.sh [--path <dir>] [--purge] [--delete-folder|--keep-folder]

Default: removes the anvil PATH block (only that marked block) and the
recorded vault location. Notes, index.md, domains.txt, and moc/ stay.

--purge          delete all vault content in $ANVIL_HOME (asks you to type
                 the path to confirm). Irreversible.
--keep-folder    with --purge: empty the folder but keep it (and any
                 .stfolder marker), so Obsidian/Syncthing keep their path
--delete-folder  with --purge: remove the folder itself too
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --path) ANVIL_HOME="$2"; shift 2 ;;
    --purge) PURGE=true; shift ;;
    --delete-folder) DELETE_FOLDER=true; DELETE_FOLDER_SET=true; shift ;;
    --keep-folder) DELETE_FOLDER=false; DELETE_FOLDER_SET=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

remove_path_block() {
  local rc="$1" tmp
  if [ -f "$rc" ] && grep -qF "$MARK_START" "$rc"; then
    tmp="$(mktemp)"
    awk -v s="$MARK_START" -v e="$MARK_END" '
      $0 == s {skip=1; next}
      $0 == e {skip=0; next}
      !skip {print}' "$rc" > "$tmp"
    cat "$tmp" > "$rc"
    rm -f "$tmp"
    echo "  removed the anvil PATH block from $rc"
  fi
}

if command -v claude >/dev/null 2>&1; then
  bs_unregister
fi
bs_settings_remove
bs_import_remove
remove_path_block "$HOME/.bashrc"
remove_path_block "$HOME/.zshrc"
if [ -f "$CONFIG_FILE" ]; then
  rm -f "$CONFIG_FILE"
  echo "  removed $CONFIG_FILE"
fi

if [ "$PURGE" = false ]; then
  echo "==> Vault kept at $ANVIL_HOME. Run with --purge to delete it."
  exit 0
fi

if [ ! -d "$ANVIL_HOME" ]; then
  echo "Nothing to purge: $ANVIL_HOME does not exist."
  exit 0
fi

read -r -p "This deletes ALL notes in $ANVIL_HOME. Type the vault path to confirm: " CONFIRM
if [ "$CONFIRM" != "$ANVIL_HOME" ]; then
  echo "Confirmation did not match. Aborted."
  exit 1
fi

if [ "$DELETE_FOLDER_SET" = false ] && [ -t 0 ]; then
  cat <<EOF

Delete the folder itself, or empty it and keep the folder (safer if
Obsidian or Syncthing still point at this exact path)?
  1) Keep the folder, empty its contents
  2) Delete the folder
EOF
  while true; do
    read -r -p "Choose [1/2]: " CHOICE
    case "$CHOICE" in
      1) DELETE_FOLDER=false; break ;;
      2) DELETE_FOLDER=true; break ;;
      *) echo "Enter 1 or 2." ;;
    esac
  done
fi

if [ "$DELETE_FOLDER" = true ]; then
  rm -rf "$ANVIL_HOME"
  echo "==> Removed $ANVIL_HOME entirely."
else
  find "$ANVIL_HOME" -mindepth 1 -maxdepth 1 ! -name '.stfolder' -exec rm -rf {} +
  echo "==> Emptied $ANVIL_HOME; the folder (and .stfolder, if present) was kept."
fi
