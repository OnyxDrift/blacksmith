---
name: hydrate
description: "Mine Claude Code sessions from the last 30 days into anvil notes, with approval before writing."
disable-model-invocation: true
allowed-tools: Bash(anvil *)
---
Read `${CLAUDE_PLUGIN_ROOT}/reference/drafting.md` first. It holds the note
rules, the save command, and the review loop. `$A` there means
`anvil`.

`/anvil:hydrate` mines past Claude Code sessions that never ran
`/anvil:note` or `/anvil:reflect`. Claude Code deletes transcripts after 30
days; older sessions are gone, and that is accepted.

## 1. List sessions

Run `$A sessions --exclude ${CLAUDE_SESSION_ID}`. It scans the current
directory and every subdirectory (Claude Code stores sessions by exact
launch directory), one TSV row per session:
`engine  session_id  timestamp  status  gist  log_path  source_dir`.

If there are none, say so and stop. Otherwise show a numbered list, grouped
under one heading per `source_dir` (current directory first; skip headings
when there is only one), numbering continuous across groups:

```
N. 🟡 new — 2026-09-11 17:17 — "<gist>"
```

Status emoji: 🟡 new · 🟢 hydrated · 🟣 partial · 🔴 failed. Use the gist
as given; do not open sessions yet.

## 2. Pick one session

Ask with `AskUserQuestion`, header `Anvil Hydrate`: **Newest new session**
(name it: number and date) or **Pick another** (the user names a number).
Then run `$A session-read <log_path>` and say which session this is.

`session-read` replaces secrets with `[REDACTED…]` markers. Never try to
recover a redacted value. If it fails, record the session as `failed`
(step 5) and return to the list.

## 3. Candidates, newest knowledge wins

Find candidates with drafting.md's "What earns a note" rules. Sessions are
processed newest first on purpose: what is already canonical, or approved
earlier in this run, reflects newer understanding. For each candidate, run
the recall check. When an older session **disagrees** with a canonical note,
show both claims as a flagged conflict and let the user decide; never write
the old claim as current fact, and never drop it silently.

## 4. Save, then review in rounds

Save each surviving candidate as a draft ("Saving drafts"), with
`hydrated` in its tags. Then run "The review loop" over those drafts, in
rounds of up to 4. Changes to live notes go through "Amendments to
existing notes".

## 5. Record progress

Run `$A sessions --record <session_id> <status> <notes_written> "<detail>"`.
It appends one row to `hydrated.tsv` in anvil's state folder.

- `hydrated`: every candidate got a decision (also when there were none).
- `partial`: the user stopped before every candidate got a decision; say what is left in `detail`.
- `failed`: the session could not be read.

Re-processing a session appends a new row; the last row wins.

## 6. Checkpoint

Ask with `AskUserQuestion`: **Next new session**, **Pick another**, or
**Stop**. On stop, give one summary line: sessions processed (with status),
notes written, drafts saved, conflicts left for the user.
