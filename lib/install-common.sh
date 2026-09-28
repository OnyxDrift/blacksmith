# Blacksmith install glue, sourced by each plugin's install.sh and
# uninstall.sh (anvil/, forge/). Not run on its own.
#
# Before sourcing, the caller sets:
#   BS_SRC   the blacksmith source folder (the parent of the plugin folder)
#   PLUGIN   the plugin name (anvil | forge)
#
# Installed layout, all under $BLACKSMITH_HOME/plugins (the snapshot):
#   <plugin>/                     a copy of the plugin (what Claude Code runs)
#   <plugin>/.installed-from      source folder, commit, and sync time
#   <plugin>/lib/find-python.sh, <plugin>/lib/hosts.py
#                                 the shared runtime files, copied into each
#                                 plugin: Claude Code runs a plugin from its
#                                 own cache copy (~/.claude/plugins/cache/
#                                 blacksmith/<plugin>/<version>), which holds
#                                 only the plugin folder
#   lib/                          a copy of the shared lib, for the installers
#   .claude-plugin/marketplace.json  the `blacksmith` marketplace, listing
#                                 only the plugins present in the snapshot
# Plugin ids stay <plugin>@blacksmith with one plugin installed or both.

BLACKSMITH_HOME="${BLACKSMITH_HOME:-$HOME/.blacksmith}"
SNAP="$BLACKSMITH_HOME/plugins"
MARKETPLACE="blacksmith"
SETTINGS_PY="$BS_SRC/lib/settings.py"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
# shellcheck source=find-python.sh
. "$BS_SRC/lib/find-python.sh"
PY=""

bs_need() {
  command -v "$1" >/dev/null 2>&1 || { echo "error: '$1' is required${2:+ ($2)}" >&2; exit 1; }
}

# Checks claude and git, finds Python 3.8+ (see find-python.sh), and saves
# its path for the plugin commands and hooks.
bs_require() {
  bs_need claude "install Claude Code first"
  bs_need git
  PY="$(bs_python)" || { bs_python_missing; exit 1; }
  bs_python_ok "$PY" || { echo "error: $PY is not a working Python 3.8+" >&2; exit 1; }
  bs_python_save "$PY"
}

# The same path in one style: Python and claude on Windows print C:\... while
# Git Bash uses /c/...; cygpath (Git Bash only) converts. Elsewhere a no-op.
bs_norm() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$1"
  else
    printf '%s' "$1"
  fi
}

# The rev of the source, with +uncommitted when the folder has local changes.
bs_rev() {
  local rev
  rev="$(git -C "$1" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  if [ -n "$(git -C "$1" status --porcelain -- . 2>/dev/null)" ]; then
    rev="$rev+uncommitted"
  fi
  printf '%s' "$rev"
}

# Regenerate the snapshot marketplace from the plugins present, and remove
# top-level files that belong to no plugin (left by installs before 0.0.3,
# which copied the whole blacksmith folder).
bs_write_marketplace() {
  local keep name entry
  keep="$("$PY" "$SETTINGS_PY" marketplace-write "$BS_SRC/.claude-plugin/marketplace.json" "$SNAP")"
  for entry in "$SNAP"/* "$SNAP"/.installed-from; do
    [ -e "$entry" ] || continue
    name="$(basename "$entry")"
    [ "$name" = lib ] && continue
    printf '%s\n' "$keep" | grep -qx "$name" && continue
    rm -rf "$entry"
  done
}

# Copy the plugin and the shared lib into the snapshot.
bs_snapshot_plugin() {
  local rev
  mkdir -p "$SNAP"
  "$PY" "$BS_SRC/lib/snapshot.py" "$BS_SRC/$PLUGIN" "$SNAP/$PLUGIN" \
    --exclude-top install.sh --exclude-top uninstall.sh
  "$PY" "$BS_SRC/lib/snapshot.py" "$BS_SRC/lib" "$SNAP/lib"
  mkdir -p "$SNAP/$PLUGIN/lib"
  cp "$BS_SRC/lib/find-python.sh" "$BS_SRC/lib/hosts.py" "$SNAP/$PLUGIN/lib/"
  rev="$(bs_rev "$BS_SRC")"
  printf 'source\t%s\ncommit\t%s\nsynced\t%s\n' "$BS_SRC/$PLUGIN" "$rev" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$SNAP/$PLUGIN/.installed-from"
  bs_write_marketplace
  echo "==> $PLUGIN snapshot: $SNAP/$PLUGIN (from $BS_SRC @ $rev)"
}

# Register the snapshot as the marketplace, then install or update the plugin.
bs_register() {
  local registered id
  registered="$(claude plugin marketplace list --json 2>/dev/null | "$PY" "$SETTINGS_PY" marketplace-path "$MARKETPLACE" || true)"
  [ -n "$registered" ] && registered="$(bs_norm "$registered")"
  if [ -n "$registered" ] && [ "$registered" != "$(bs_norm "$SNAP")" ]; then
    # Registered at the clone by an install before 0.0.1: move it.
    claude plugin marketplace remove "$MARKETPLACE" >/dev/null 2>&1 || true
    echo "  marketplace '$MARKETPLACE' was registered at $registered; moving it to the snapshot"
    registered=""
  fi
  if [ -z "$registered" ]; then
    claude plugin marketplace add "$SNAP" >/dev/null
    echo "  marketplace '$MARKETPLACE' registered at $SNAP"
  else
    claude plugin marketplace update "$MARKETPLACE" >/dev/null
  fi
  id="$PLUGIN@$MARKETPLACE"
  if claude plugin list --json 2>/dev/null | "$PY" "$SETTINGS_PY" has-plugin "$id"; then
    claude plugin update "$id" >/dev/null 2>&1 || true
    # Claude Code copies a plugin into its cache once per version. A
    # snapshot from another commit with the same version needs a reinstall,
    # or sessions keep running the old copy.
    if [ "$(bs_cached_commit "$id")" != "$(bs_commit_of "$SNAP/$PLUGIN/.installed-from")" ]; then
      claude plugin uninstall "$id" >/dev/null 2>&1 || true
      bs_claude_install "$id"
      echo "  reinstalled $id: the cached copy was from another commit"
    else
      echo "  $id up to date"
    fi
  else
    bs_claude_install "$id"
    echo "  installed $id"
  fi
  echo "    Claude Code runs it from $(bs_install_path "$id")"
}

bs_install_path() {
  claude plugin list --json 2>/dev/null | "$PY" "$SETTINGS_PY" install-path "$1" || true
}

# The commit line of an .installed-from file (empty when there is none).
bs_commit_of() {
  [ -f "$1" ] || return 0
  awk -F'\t' '$1 == "commit" { sub(/\r$/, "", $2); print $2 }' "$1"
}

bs_cached_commit() {
  local path
  path="$(bs_install_path "$1")"
  [ -n "$path" ] || return 0
  bs_commit_of "$(bs_norm "$path")/.installed-from"
}

# `claude plugin install`, retried: on Windows it fails at random with
# EPERM when antivirus holds a file of the fresh copy open (Claude Code
# issues #81774, #54053).
bs_claude_install() {
  local try out
  for try in 1 2 3; do
    if out="$(claude plugin install "$1" 2>&1)"; then
      return 0
    fi
    if [ "$try" -lt 3 ]; then
      echo "  install of $1 failed (try $try of 3); retrying in 5 seconds"
      sleep 5
    fi
  done
  printf '%s\n' "$out" | sed 's/^/    /' >&2
  cat >&2 <<EOF
error: could not install $1.
  On Windows, "EPERM ... rename" is a known Claude Code issue: something
  holds the new files open. Then:
    1. Close every Claude Code window and session, and run the installer again.
    2. Delete leftover folders: ~/.claude/plugins/cache/temp_local_* and
       ~/.claude/plugins/cache/$MARKETPLACE/$PLUGIN
    3. If it still fails, ask IT to exclude ~/.claude/plugins from antivirus
       scanning.
EOF
  exit 1
}

# Uninstall the plugin, remove its snapshot folder, and remove the
# marketplace and the snapshot when no plugin is left.
bs_unregister() {
  local id="$PLUGIN@$MARKETPLACE" left
  [ -n "$PY" ] || PY="$(bs_python)" || { bs_python_missing; exit 1; }
  if claude plugin list --json 2>/dev/null | "$PY" "$SETTINGS_PY" has-plugin "$id"; then
    claude plugin uninstall "$id" >/dev/null 2>&1 && echo "  uninstalled $id" || true
  fi
  [ -d "$SNAP" ] || return 0
  rm -rf "${SNAP:?}/$PLUGIN"
  bs_write_marketplace
  left="$("$PY" "$SETTINGS_PY" plugin-names "$SNAP/.claude-plugin/marketplace.json")"
  if [ -z "$left" ]; then
    claude plugin marketplace remove "$MARKETPLACE" >/dev/null 2>&1 && echo "  removed marketplace $MARKETPLACE" || true
    rm -rf "$SNAP"
    echo "  removed the snapshot $SNAP"
  else
    claude plugin marketplace update "$MARKETPLACE" >/dev/null 2>&1 || true
    echo "  removed $SNAP/$PLUGIN"
  fi
}

# Claude Code settings: merge the plugin's fragment; on uninstall, remove only
# its own allow rule. Deny rules stay: dropping a safety rule unasked is worse
# than keeping it.
bs_settings_add() {
  "$PY" "$SETTINGS_PY" merge "$BS_SRC/$PLUGIN/settings.fragment.json" | sed 's/^/  /'
}
bs_settings_remove() {
  [ -n "$PY" ] || PY="$(bs_python)" || { bs_python_missing; exit 1; }
  "$PY" "$SETTINGS_PY" remove-allow "Bash($PLUGIN *)" | sed 's/^/  /'
}

# The import line for the plugin's global pointer, as it goes into
# ~/.claude/CLAUDE.md (with ~ when the snapshot is under $HOME).
bs_import_line() {
  local path="$SNAP/$PLUGIN/CLAUDE-pointer.md"
  case "$path" in "$HOME"/*) path="~${path#"$HOME"}" ;; esac
  printf '@%s' "$path"
}

# Add the import line once. A CLAUDE.md that already has it (for example one
# kept in git that lists it) is left alone.
bs_import_add() {
  local line file="$CLAUDE_DIR/CLAUDE.md"
  line="$(bs_import_line)"
  if [ -f "$file" ] && grep -qxF "$line" "$file"; then
    echo "  CLAUDE.md already imports the $PLUGIN pointer"
    return 0
  fi
  mkdir -p "$CLAUDE_DIR"
  if [ -s "$file" ]; then
    printf '\n%s\n' "$line" >> "$file"
  else
    printf '%s\n' "$line" >> "$file"
  fi
  echo "  CLAUDE.md now imports the $PLUGIN pointer ($line)"
}

bs_import_remove() {
  local line tmp file="$CLAUDE_DIR/CLAUDE.md"
  line="$(bs_import_line)"
  [ -f "$file" ] && grep -qxF "$line" "$file" || return 0
  tmp="$(mktemp)"
  # Drop the line, and the blank lines it leaves at the end of the file.
  grep -vxF "$line" "$file" | awk 'NF { for (; n > 0; n--) print ""; print; next } { n++ }' > "$tmp" || true
  cat "$tmp" > "$file"
  rm -f "$tmp"
  echo "  removed the $PLUGIN pointer import from $file"
}

# The early anvil (before blacksmith) installed six user skills into
# ~/.claude/skills. User skills get no plugin prefix, so they show as
# /recall, /note, ... next to /anvil:recall, /anvil:note. Move each one
# that is from the early anvil (its SKILL.md names the early tooling path,
# such as ~/.anvil/bin/recall or ~/.anvil/bin/audit) into a backup folder. A skill with the same
# name from anywhere else stays.
bs_legacy_anvil_skills() {
  local dir="$CLAUDE_DIR/skills" backup="" name f
  for name in recall note reflect anvil hydrate fill-vault; do
    f="$dir/$name/SKILL.md"
    [ -f "$f" ] || continue
    grep -qE '/bin/(anvil|audit|note|recall|session-read|sessions|status|upgrade|upgrade-vault|usage)' "$f" || continue
    grep -q 'anvil' "$f" || continue
    if [ -z "$backup" ]; then
      backup="$BLACKSMITH_HOME/legacy/claude-skills-$(date -u +%Y%m%dT%H%M%SZ)"
      mkdir -p "$backup"
    fi
    mv "$dir/$name" "$backup/$name"
    echo "  moved the early anvil skill /$name out of $dir"
  done
  if [ -n "$backup" ]; then
    echo "    (backup: $backup; the plugin's /anvil:… skills replace them)"
  fi
}

# Host setup, once per machine, when hosts.tsv is missing.
bs_hosts() {
  if [ ! -f "$BLACKSMITH_HOME/config/hosts.tsv" ]; then
    echo
    "$PY" "$SNAP/lib/hosts.py" setup "$@" || echo "  host setup incomplete; finish later with: $BS_SRC/install.sh --hosts"
  fi
}
