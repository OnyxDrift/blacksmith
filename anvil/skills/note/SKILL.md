---
name: note
description: "Draft an anvil note for a durable lesson, decision, or fact worth keeping across sessions. Use when the user asks to remember, record, or note something, or right after a non-obvious fix or decision lands. The user approves before it goes live."
argument-hint: "<claim or topic>"
allowed-tools: Bash(anvil *)
---
Read `${CLAUDE_PLUGIN_ROOT}/reference/drafting.md` first. It holds the note
rules, the save command, and the review loop. `$A` there means
`anvil`.

What to capture: $ARGUMENTS

This may be a full claim or just a topic. For a topic, pull the real claim
from this conversation yourself.

## Choose the path

- **The user asked** (typed `/anvil:note`, or said "remember this", "note
  that", "save this"): follow the **approval path** below.
- **You decided on your own** that something is worth keeping: follow the
  **inbox path**. Do not interrupt the user with a menu.

## Approval path

1. Check for an existing note (drafting.md, "Check before drafting").
2. For a new note: save it as a draft (drafting.md, "Saving drafts"), then
   run "The review loop" on it. Two claims make two drafts, reviewed one at
   a time.
3. For a change to a note that is already live: follow "Amendments to
   existing notes".

## Inbox path

1. Check for an existing note. If one already says it, stop silently.
2. Write the draft **without** `--approved`. Amendments are not possible on
   this path; draft a new note that names the old one in its body instead.
3. Tell the user in one line: `Anvil: drafted _inbox/<file> — review with /anvil:inbox`.
