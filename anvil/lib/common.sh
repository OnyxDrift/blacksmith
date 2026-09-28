# Shared setup for anvil's libexec scripts. Source it, do not run it.
#
# Sets:
#   ANVIL_PKG    the anvil package (plugin) root: bin/, libexec/, lib/,
#                migrations/, templates/, skills/
#   BLACKSMITH_HOME  every per-user blacksmith file (default ~/.blacksmith)
#   ANVIL_ROOT   the vault root (notes live here; no package files)
#   ANVIL_STATE  machine-local state dir (usage.tsv, hydrated.tsv), never synced
#
# The vault root resolves in this order:
#   1. $ANVIL_HOME
#   2. the single line in $BLACKSMITH_HOME/config/anvil-home (a vault kept
#      somewhere else, recorded by install.sh)
#   3. $BLACKSMITH_HOME/anvil/vault
# The package and the vault are separate on purpose: the package is code
# from the blacksmith snapshot (or Claude Code's plugin cache); the vault is data
# that Syncthing shares between machines.

ANVIL_PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BLACKSMITH_HOME="${BLACKSMITH_HOME:-$HOME/.blacksmith}"
# The shared runtime files (find-python.sh, hosts.py): the installer copies
# them into the plugin's own lib/, because Claude Code runs a cache copy of
# the plugin folder alone. In a source checkout they sit in ../lib.
if [ -f "$ANVIL_PKG/lib/find-python.sh" ]; then
  BS_LIB="$ANVIL_PKG/lib"
else
  BS_LIB="$(dirname "$ANVIL_PKG")/lib"
fi
# shellcheck source=../../lib/find-python.sh
. "$BS_LIB/find-python.sh"
# The Python 3.8+ that the installer found (empty when there is none; the
# scripts that need it say so).
ANVIL_PY="$(bs_python || true)"

anvil_need_python() {
  [ -n "$ANVIL_PY" ] || { bs_python_missing; exit 1; }
}

anvil_resolve_vault() {
  if [ -n "${ANVIL_HOME:-}" ]; then
    printf '%s' "$ANVIL_HOME"
    return
  fi
  local conf="$BLACKSMITH_HOME/config/anvil-home"
  if [ -f "$conf" ]; then
    local p
    p="$(head -n 1 "$conf" | tr -d '\r')"
    # Expand a leading ~ written by hand.
    case "$p" in "~"|"~/"*) p="$HOME${p#\~}" ;; esac
    if [ -n "$p" ]; then
      printf '%s' "$p"
      return
    fi
  fi
  printf '%s' "$BLACKSMITH_HOME/anvil/vault"
}

ANVIL_ROOT="$(anvil_resolve_vault)"
ANVIL_STATE="$BLACKSMITH_HOME/anvil/state"

# Package tooling version, read from the plugin manifest.
anvil_tooling_version() {
  sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$ANVIL_PKG/.claude-plugin/plugin.json" 2>/dev/null | head -n 1
}

anvil_require_vault() {
  if [ ! -d "$ANVIL_ROOT" ]; then
    echo "error: anvil vault not found at $ANVIL_ROOT" >&2
    echo "  Set ANVIL_HOME, or run blacksmith/install.sh to create or point at one." >&2
    exit 1
  fi
}
