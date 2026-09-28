# Find a Python 3.8+ for blacksmith. Sourced by the installers, the anvil
# and forge commands, and the anvil hook launcher. Not run on its own.
#
# bs_python prints the interpreter path, in this order:
#   1. $BLACKSMITH_PYTHON (set by `install.sh --python <path>`)
#   2. the path saved in $BLACKSMITH_HOME/config/python by the installer
#   3. a search: python3, python3.14 … python3.8, python, py
# Each search candidate must run and report 3.8 or newer. This skips the
# Windows `python3` that only opens the Microsoft Store, and a `python`
# that is Python 2. The names alone prove nothing.
#
# bs_python_save writes the found path to config/python, so later runs skip
# the search.

# UTF-8 for every file and pipe, also on Windows, where Python otherwise
# opens files as cp1252 and fails to print characters such as ✅ or —.
export PYTHONUTF8=1

bs_python_ok() {
  "$1" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' >/dev/null 2>&1
}

bs_python_search() {
  local c p
  for c in python3 python3.14 python3.13 python3.12 python3.11 python3.10 python3.9 python3.8 python py; do
    p="$(command -v "$c" 2>/dev/null)" || continue
    case "$p" in */WindowsApps/*) continue ;; esac
    if bs_python_ok "$p"; then
      printf '%s' "$p"
      return 0
    fi
  done
  return 1
}

bs_python() {
  local saved="${BLACKSMITH_HOME:-$HOME/.blacksmith}/config/python" p
  if [ -n "${BLACKSMITH_PYTHON:-}" ]; then
    printf '%s' "$BLACKSMITH_PYTHON"
    return 0
  fi
  if [ -f "$saved" ]; then
    IFS= read -r p < "$saved" || true
    p="${p%$'\r'}"
    if [ -n "$p" ] && { [ -x "$p" ] || [ -x "$p.exe" ]; }; then
      printf '%s' "$p"
      return 0
    fi
  fi
  bs_python_search
}

bs_python_save() {
  local dir="${BLACKSMITH_HOME:-$HOME/.blacksmith}/config"
  mkdir -p "$dir"
  printf '%s\n' "$1" > "$dir/python"
}

bs_python_missing() {
  cat >&2 <<'EOF'
error: no Python 3.8 or newer found (tried python3, python3.X, python, py).
  Install Python 3, or name it once:  ./install.sh --python "/full/path/to/python"
EOF
}
