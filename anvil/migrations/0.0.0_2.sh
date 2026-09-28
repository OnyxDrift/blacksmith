#!/usr/bin/env bash
# Migration to 0.0.0_2: add an empty `origin:` frontmatter field to any
# canonical-schema note that doesn't already have one.
#
# Idempotent and non-destructive: only ever inserts a missing line, right
# after `source:`. Never touches a note that already has `origin:`. Never
# fills in a real value — old notes' real origins can't be safely
# reconstructed after the fact; bin/status flags them for a human to fill
# in later through the normal approval-gated note-editing path.
#
# Usage: 0.0.0_2.sh <ANVIL_ROOT>
set -euo pipefail
ANVIL_ROOT="${1:?usage: 0.0.0_2.sh <ANVIL_ROOT>}"

NOTE_DIRS="$ANVIL_ROOT/semantic $ANVIL_ROOT/procedural $ANVIL_ROOT/strategic $ANVIL_ROOT/episodic"
ALL_NOTES=$(find $NOTE_DIRS -maxdepth 1 -name '*.md' 2>/dev/null || true)

CHANGED=0
for f in $ALL_NOTES; do
  if grep -q "^origin:" "$f" 2>/dev/null; then
    continue
  fi
  if ! grep -q "^source:" "$f" 2>/dev/null; then
    # Not a note with the expected frontmatter shape — skip rather than guess.
    continue
  fi
  TMP=$(mktemp)
  awk '{ print; if ($0 ~ /^source:/) print "origin: " }' "$f" > "$TMP" && mv "$TMP" "$f"
  CHANGED=$((CHANGED + 1))
done

echo "0.0.0_2: added empty origin: field to $CHANGED note(s)"
