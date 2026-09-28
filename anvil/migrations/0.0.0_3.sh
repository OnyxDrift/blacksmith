#!/usr/bin/env bash
# Migration to 0.0.0_3: add empty `description:` and `supersedes:` fields.
#
# description: one line, shown by recall in place of the whole note.
# supersedes:  the older note a newer note replaces (that note is archived).
#
# Idempotent and non-destructive: inserts a missing line at the end of the
# frontmatter, never touches an existing value, never guesses a value.
# /anvil:backfill proposes real descriptions, with approval.
#
# Usage: 0.0.0_3.sh <ANVIL_ROOT>
set -euo pipefail
ANVIL_ROOT="${1:?usage: 0.0.0_3.sh <ANVIL_ROOT>}"

CHANGED=0
for dir in semantic procedural strategic episodic _inbox _review _archive; do
  [ -d "$ANVIL_ROOT/$dir" ] || continue
  for f in "$ANVIL_ROOT/$dir"/*.md; do
    [ -f "$f" ] || continue
    head -n 1 "$f" | grep -qx -- '---' || continue
    grep -q '^source:' "$f" || continue   # not the expected note shape; skip
    NEED=""
    grep -q '^description:' "$f" || NEED="$NEED description"
    grep -q '^supersedes:' "$f" || NEED="$NEED supersedes"
    [ -z "$NEED" ] && continue
    TMP="$(mktemp)"
    awk -v need="$NEED" '
      NR == 1 { print; infm = 1; next }
      infm && $0 == "---" {
        n = split(need, keys, " ")
        for (i = 1; i <= n; i++) if (keys[i] != "") print keys[i] ":"
        infm = 0
      }
      { print }' "$f" > "$TMP" && cat "$TMP" > "$f"
    rm -f "$TMP"
    CHANGED=$((CHANGED + 1))
  done
done

echo "0.0.0_3: added empty description:/supersedes: to $CHANGED note(s)"
