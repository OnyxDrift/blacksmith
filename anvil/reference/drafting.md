# Drafting anvil notes

Shared rules for every anvil skill that drafts notes (`note`, `reflect`,
`hydrate`, `ingest`). `$A` below means `anvil`.

Run every `$A` command on its own: no `cd` before it, no `&&`, `;`, or
pipe after it, and no `python` or shell script in its place. A single
`anvil …` command matches the `Bash(anvil *)` permission rule and runs
without a prompt. Anything else makes the user approve an opaque command
after they already answered the anvil question.

To run several `$A` commands, make them **parallel tool calls in one
message**, one command per call. Each message is a turn, and each turn
reads the whole session context again. At the end of a long session, the
number of turns is the main cost of a flow, so batch every step below
that does not depend on an earlier answer.

## What earns a note

A note holds one durable claim: a fact that stays true, a procedure, or a
decision and its reason. Draft a note for:

- a lesson or fix whose cause was not obvious;
- a decision and why it was made;
- a fact about a tool, system, or project that a later session would need.

Leave these out of the vault:

- a recap of what was done (the conversation and git hold that);
- test or throwaway artifacts;
- anything whose only support is a web page fetched in this session. Point
  the user to `/anvil:ingest <url>`, which keeps a copy and records the source;
- secrets. Drop the detail entirely; never put a key, token, or password in a
  draft, even one the redaction missed.

Two distinct claims make two notes.

## Check before drafting

Run `$A recall "<keyword>"` for each candidate (a distinctive word, not a
sentence), all in one message. Then:

- nothing relevant: draft a new note;
- a note already says it: drop the candidate;
- a note says it with a gap or error: draft an **amendment** to that note;
- a note on the same topic disagrees: show both claims to the user and let
  them decide. Never overwrite or drop silently.

## Fields

| Field | Rule |
|---|---|
| title | One line. The claim itself, not a topic. |
| description | One line, under 150 characters: what the note claims and when it applies. Recall shows this instead of the body, so make it specific. |
| type | `semantic` (fact), `procedural` (how-to), `strategic` (decision + why), `episodic` (dated event). |
| domain | A line from `$A domain list`. If none fits, ask the user; add one only after they agree, with `$A domain add <name>`. |
| subdomain | A tool, technology, or language (`python`, `ssh`); for non-software domains a topical sub-category (`backtesting`). Run `$A status` and reuse an existing subdomain before inventing one. Never a project. |
| project | One of the user's own projects (`anvil`, `orion`). A claim about anvil itself uses `anvil`. Never a tool. |
| tags | A few search keywords, comma-separated. |
| origin | Leave `--origin` off to link the current repo on the user's Forgejo/Gitea host (or leave it empty when there is none). Pass a Forgejo/Gitea link to a specific file or writeup when that is what backs the claim. `none` records that nothing backs the note (a general fact). Web pages are not allowed here; use `/anvil:ingest`. `$A note` refuses anything else. |
| supersedes | The name of an older note this one replaces. That note is archived on approval. |

## Body

Short, plain sentences. One fact per sentence. The claim and why it holds,
under ~200 words. When a claim can go stale (a version, a count, a current
state), date it: "Forgejo runs 1.22 (as of 2026-09)".

## Saving drafts

Every new candidate is first saved as an inbox draft. Recall does not see
drafts. Pass the body on stdin with a quoted heredoc, so nothing in it is
expanded:

```
$A note --type <t> --domain <d> --subdomain <s> --project <p> --tags "<a,b>" \
  --title "<title>" --description "<one line>" --source claude [--origin <o>] \
  [--supersedes <name>] --body - <<'NOTE'
<body>
NOTE
```

Save all new drafts in one message. Each prints `drafted _inbox/<file>`.
Keep those paths for the review loop.
Leave `--approved` off here: only the review loop publishes, after the user
answers. (`/anvil:handoff` is the one exception; it publishes directly.)

## The review loop

Use this loop every time the user decides on drafts: in `/anvil:note`,
`/anvil:reflect`, `/anvil:hydrate`, `/anvil:ingest`, and `/anvil:inbox`.
Take the drafts in order, in **rounds of up to 4 tabs**, because one
`AskUserQuestion` call holds at most 4 questions. A plain draft takes one
tab; a draft with `--supersedes` takes two. Draft *i* of *n* keeps its
number across rounds. For each round:

1. In one message, run `$A note --review <draft> --of "<i> of <n>"` for
   every draft in the round. Each prints the draft as a plain-text card:
   header, title, description, details, and the full body, ending with
   "What should happen to this draft?".
   A draft with `--supersedes` is two cards, because the dialog cuts off
   tall text and cannot scroll. Also run the same command with
   `--part before`, which prints the live note alone. Its two tabs are:
   - Tab `Before <i>/<n>`: the `--part before` card. Options: **Next: after**,
     **Keep in inbox**.
   - Tab `After <i>/<n>`: the card without `--part`, the new version. Options:
     **Approve**, **Keep in inbox**, **Reject**, **Show before**.
   Act on the After answer. On Show before, ask the same two tabs again in
   the next round. Keep in inbox on either tab keeps the draft.
2. Ask the whole round in **one** `AskUserQuestion` call, one question per
   tab, header `Review <i>/<n>` for a plain draft. Together these tabs are
   the Anvil Review question. **Each question text is
   that card, exactly as printed.** Do not summarise, shorten, or reformat
   it, and do not print it again in your message: the dialog shows it at
   full width, with the options under it, in the terminal and in mobile
   clients alike. Give a plain draft three options, with no `preview`
   field:
   **Approve** (goes live; undo with `$A note --unapprove <note> --approved`),
   **Keep in inbox** (decide later), **Reject**
   (moved to `_archive/rejected/`; undo with `$A note --restore <file>`).
   If a review command exited 3 (the origin link fails), leave out
   **Approve** for that draft, and say in your message why the link fails
   and what fixes it.
3. Act on all the answers in one message, then report one `Anvil:` line
   per draft:
   - Approve: `$A note --approve <draft> --approved`
   - Keep in inbox: nothing to run
   - Reject: `$A note --reject <draft> --approved` (tell the user the
     undo command it prints)
   - Free text is an edit request. Apply it with
     `$A note --set <draft> <field> <value> --approved` (origin,
     description, subdomain, project, tags, supersedes) or
     `$A note --amend <draft> --body - --approved <<'NOTE' ... NOTE`, then
     put the same draft first in the next round.
4. Start the next round. After the last one, give one summary line:
   approved, kept, rejected.

## Amendments to existing notes

An amendment changes a note that is already live, so it is not a draft.
Show only the lines that change, ask **Approve / Reject** with header
`Anvil Review`, and on Approve run
`$A note --amend <name> --body - --approved <<'NOTE' ... NOTE` (add
`--description "..."` when it changes).

The vault is written only through `$A`. Claude's file tools are blocked
there by design; `$A note` enforces the schema and the origin rules.

## Reporting

Every message in an anvil flow starts with `Anvil:`. Report outcomes, not
mechanics: one line per note, with the vault-relative path from the command
output, for example `Anvil: wrote semantic/2026-09-23-title.md (linked from
moc/Software.md)` or `Anvil: drafted _inbox/2026-09-23-title.md for /anvil:inbox`.
