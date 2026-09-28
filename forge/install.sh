#!/usr/bin/env bash
# Forge installer. Works alone, or run by the blacksmith installer
# (../install.sh), which asks first which plugins to install. Safe to re-run.
#
# In order:
#   1. copies the plugin and the shared lib into the snapshot
#      (~/.blacksmith/plugins/forge, ~/.blacksmith/plugins/lib)
#   2. merges settings.fragment.json into ~/.claude/settings.json: the
#      `Bash(forge *)` rule, and read-deny rules for .env files, which
#      /forge:env depends on
#   3. adds `@~/.blacksmith/plugins/forge/CLAUDE-pointer.md` to
#      ~/.claude/CLAUDE.md, once
#   4. registers the `blacksmith` marketplace and installs forge@blacksmith
#   5. host setup (../lib/hosts.py), if ~/.blacksmith/config/hosts.tsv is
#      missing; `forge link` needs it
#
# Flags: --skip-settings, --skip-hosts, --non-interactive, --python <path>
# (a Python 3.8+ the search does not find), and the host flags --kind
# --web-url --ssh-host --ssh-port --ssh-user --owner.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BS_SRC="$(dirname "$SCRIPT_DIR")"
PLUGIN=forge
# shellcheck source=../lib/install-common.sh
. "$BS_SRC/lib/install-common.sh"

SKIP_HOSTS=false
SKIP_SETTINGS=false
HOST_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --skip-hosts) SKIP_HOSTS=true; shift ;;
    --python) export BLACKSMITH_PYTHON="$2"; shift 2 ;;
    --skip-settings) SKIP_SETTINGS=true; shift ;;
    --non-interactive) HOST_ARGS+=("$1"); shift ;;
    --kind|--web-url|--ssh-host|--ssh-port|--ssh-user|--owner)
      HOST_ARGS+=("$1" "$2"); shift 2 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

bs_require
bs_snapshot_plugin
echo
echo "==> forge plugin"
if [ "$SKIP_SETTINGS" = false ]; then
  bs_settings_add
  bs_import_add
fi
bs_register
if [ "$SKIP_HOSTS" = false ]; then
  bs_hosts ${HOST_ARGS[@]+"${HOST_ARGS[@]}"}
fi

echo
echo "==> forge ready. Start a new Claude Code session (or run /reload-plugins)."
echo "    Try: /forge:todo   /forge:writeup <topic>"
