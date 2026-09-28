#!/usr/bin/env bash
# Forge uninstaller. Works alone, or run by the blacksmith uninstaller.
#
# Uninstalls forge@blacksmith, removes its snapshot folder, its
# `Bash(forge *)` rule, and its CLAUDE.md import line. The .env read-deny
# rules stay in ~/.claude/settings.json; remove them by hand if you want.
# Files forge wrote into your repos (.blacksmith/forge/) stay.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BS_SRC="$(dirname "$SCRIPT_DIR")"
PLUGIN=forge
# shellcheck source=../lib/install-common.sh
. "$BS_SRC/lib/install-common.sh"

case "${1:-}" in
  -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  "") ;;
  *) echo "unknown arg: $1" >&2; exit 1 ;;
esac

if command -v claude >/dev/null 2>&1; then
  bs_unregister
fi
bs_settings_remove
bs_import_remove
echo "==> forge removed."
