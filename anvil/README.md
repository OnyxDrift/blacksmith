<p align="center">
  <img src="docs/images/anvil.jpg" alt="Anvil" width="360">
</p>

<h1 align="center">Anvil</h1>

Anvil is long-term memory for Claude Code: a shared markdown vault of small,
atomic notes. Claude searches it when it needs to and adds to it only with
your approval. A lesson learned in one session is available in the next, in
any project. Anvil is part of [blacksmith](../README.md).

> **Version 0.0.3** (tooling), schema 0.0.0_3. The first public release,
> in [blacksmith](https://github.com/OnyxDrift/blacksmith). Every command
> below was first checked by hand on 2026-09-24.
> [CHANGELOG.md](CHANGELOG.md) has the history.

## Contents

- [Principles](#principles)
- [Three kinds of memory](#three-kinds-of-memory)
- [Commands](#commands)
- [How writes are gated](#how-writes-are-gated)
- [The review card](#the-review-card)
- [How recall works](#how-recall-works)
- [What a note looks like](#what-a-note-looks-like)
- [Vault layout](#vault-layout)
- [Command details](#command-details)
- [The `anvil` CLI](#the-anvil-cli)
- [Install](#install)
- [Versioning and upgrades](#versioning-and-upgrades)
- [Syncing across machines](#syncing-across-machines)
- [Viewing the vault in Obsidian](#viewing-the-vault-in-obsidian)
- [Uninstall](#uninstall)
- [Design choices and prior art](#design-choices-and-prior-art)

## Principles

- **Never preloaded.** Nothing from the vault enters a session until Claude
  or you ask for it. The vault can grow without growing every prompt.
- **Nothing goes live without your answer.** Every note waits as a draft
  until you approve it in the Anvil Review question. The one exception is
  `/anvil:handoff`: typing the command is the approval.
- **One question, no other prompts.** The Anvil Review question is the only
  gate. Every `anvil` command is allowed by a permission rule, so no Bash
  prompt appears around it, in any permission mode.
- **Every decision can be undone.** Reject, Approve, and a backfill batch
  each have an undo command.
- **One claim per note.** Small notes are easy to find, check, and replace.
- **Plain files.** Markdown with YAML frontmatter, plus a few TSV files. No
  database. Syncs with Syncthing. Opens in Obsidian if you want a graph.
- **Claude Code only, for now.** Other agents wait until anvil is complete
  on Claude Code.
- **Small surface.** A command is added only when a real, repeated need
  shows up.

## Three kinds of memory

| Kind | What it holds | Written by | Read by |
|---|---|---|---|
| **Notes** | Facts, fixes, and decisions that stay true | `/anvil:note`, `/anvil:reflect`, `/anvil:ingest`, `/anvil:hydrate` | `/anvil:recall` |
| **Handoffs** | Where a project stands and why: point-in-time detail for picking it back up | `/anvil:handoff` | `/anvil:world` |
| **Journal** | Where your thinking went, before a project exists: ideas, options, leanings | `/anvil:journal` | `/anvil:world` |

Notes are the long-term layer. Two more layers sit around them: the context
window (short-term, automatic) and forge writeups in a repo's
`.blacksmith/forge/writeups/` (deep, long-form, written only when you ask).
A note can link to a writeup, and `anvil source` follows that link
read-only. Claude goes only as deep as the task needs.

## Commands

**Trigger** says who can start a command:

- **You**: the skill is user-only (`disable-model-invocation`). Claude
  cannot run it on its own, and its description costs no context.
- **You or Claude**: Claude may also start it, when the skill's
  description matches the moment.

| Command | Trigger | Does | Writes to |
|---|---|---|---|
| `/anvil:recall [--full] <topic>` | You or Claude | Finds up to 4 approved notes and reports what they say | Nothing |
| `/anvil:note <claim>` | You or Claude | Drafts a note. Asked by you: reviewed at once. Claude's own idea: left in the inbox | Draft, then the vault on Approve |
| `/anvil:reflect [focus]` | You | Drafts notes from this session | Drafts, then the vault |
| `/anvil:hydrate` | You | Drafts notes from past Claude Code sessions (last 30 days), secrets removed | Drafts, then the vault |
| `/anvil:ingest <url\|path>` | You | Keeps a clean copy of a page, PDF, or file; you pick the claims | `raw/`, drafts, then the vault |
| `/anvil:inbox` | You | Reviews waiting drafts, up to 4 per question | The vault |
| `/anvil:handoff [focus]` | You | Records where the project stands: done, decisions, left, next, open questions | `episodic/` |
| `/anvil:journal [topic]` | You | Records a thinking session: explored, options weighed, leaning, open threads | `episodic/`, after review |
| `/anvil:world [project \| journal [word] [page N]]` | You | Latest handoff per project and the recent journal; one project in full; journal list or search | Nothing |
| `/anvil:backfill [description\|origin\|project]` | You | Proposes values for empty note fields, a batch at a time | Existing notes |
| `/anvil:vault` | You | Counts, domain tree, warnings, size, versions | Nothing |

Claude Code prefixes plugin commands with the plugin name, which keeps them
from clashing with other skills called `/note` or `/recall`. Every message
these commands send starts with `Anvil:`.

## How writes are gated

| Path | Gate | Where the note lands |
|---|---|---|
| You run `/anvil:note`, `/anvil:reflect`, `/anvil:hydrate`, `/anvil:ingest`, `/anvil:journal`, or `/anvil:inbox` | The Anvil Review question, up to 4 drafts as tabs | Approve → the vault. Keep in inbox → `_inbox/`. Reject → `_archive/rejected/` |
| Claude drafts a note on its own | None at draft time | `_inbox/` only; you review it with `/anvil:inbox` |
| You run `/anvil:backfill` | One question per batch of field values | The existing notes |
| You run `/anvil:handoff` | Typing it is the approval | `episodic/`, which recall never searches |

**The gate is enforced, not only requested:**

- `anvil note` saves every new note to `_inbox/` as a draft. Every change
  to the vault (`--approve`, `--reject`, `--amend`, `--set`, `--unapprove`,
  `--batch`, `--undo-batch`) needs `--approved`, which the skills pass only
  after you answer.
- A Claude Code hook (`hooks/guard-vault`) refuses Claude's Write and Edit
  tools inside the vault, so every write goes through `anvil note`, which
  checks the schema and the origin rules.
- A second hook (`hooks/show-recall`) shows you which notes each
  `anvil recall` or `anvil show` returned: the titles, or the miss. The
  terminal folds tool output away, so without it you could not see what
  the model read. The hook costs no model tokens.
- `permissions.allow` holds `Bash(anvil *)` and `Bash(forge *)` (merged into
  `~/.claude/settings.json` by the installer), and the skills run each
  `anvil` command on its own, never chained or scripted. So the only prompt
  is the Anvil Review question, also in accept-edits mode.

**Undo:**

| Decision | Undo |
|---|---|
| Reject | `anvil note --restore <file>` brings the draft back to the inbox |
| Approve | `anvil note --unapprove <note> --approved` moves it back to the inbox and removes its MOC link |
| A backfill batch | `anvil note --undo-batch <id> --approved` puts the old values back |

**Duplicates and amendments.** Before drafting, the skills run recall. If a
live note already makes the claim with a gap or an error, the change is an
amendment to that note, shown as the lines that change. A new note that
replaces an old one names it in `supersedes`; on approval the old note is
archived, never deleted.

## The review card

`anvil note --review <draft> --of "i of n"` prints a draft as a plain-text
card, and the skill passes it unchanged as the text of the Anvil Review
question. Options: **Approve**, **Keep in inbox**, **Reject**, or type an
edit. The layout follows three limits of Claude Code's question dialog:

- **It hides the message above it**, so the card is the question itself.
  The CLI renders it, so Claude cannot summarise the draft.
- **It may show markdown raw, and phones use a proportional font**, so the
  card is plain text: one `Key · value` field per line, no column
  alignment, and no hard wraps. It reads the same in a terminal and in a
  phone client such as Moshi. The origin shows as the full link, with ✅ or
  ❌ for whether it resolves.
- **It cannot scroll**, so a draft that replaces a live note is two tabs in
  one question: **Before** (the live note, `--part before`) and **After**
  (the new version, with a **Show before** option).

A draft whose origin link does not resolve (for example, a writeup that is
not pushed yet) cannot be approved; it waits in the inbox.

## How recall works

- Searches only `semantic/`, `procedural/`, and `strategic/`, and only notes
  with `status: canonical`. Drafts, handoffs, journal entries, `raw/`
  copies, and archived notes are never returned.
- **Literal, case-insensitive match** on the claim only: title,
  description, tags, project, subdomain, and body. The origin link is not
  searched, because every note from one repo shares that URL.
- **Ranked:** a hit ranks by where it first matches (title, then
  description, tags, project or subdomain, then body), newest first within
  a rank. A match only inside longer words ("sed" in "based") ranks below
  every whole-word match and is marked `partial match`.
- **At most 4 hits**, about 40 tokens each: path, title, description, date,
  and origin. When more notes match, recall says how many it left out, so
  the next search can use a more specific word.
- **The skill reports substance.** Typed by you, `/anvil:recall` presents
  what each relevant note says. Run by Claude during other work, it gives
  one line per note used and how it applies. `/anvil:recall --full <word>`
  prints the notes whole.
- A miss is informative: the vault has no settled answer yet.
- Every recall is logged locally (`anvil usage`), so the hit rate shows
  whether the vault earns its keep.

## What a note looks like

```yaml
---
type: procedural        # semantic | procedural | strategic | episodic
domain: software        # must be a line in domains.txt
subdomain: syncthing    # a tool/technology, or a topical sub-category
project: anvil          # one of your own projects, or empty
source: claude          # which tool or human wrote it
origin: https://git.example.com/me/myrepo   # what backs the claim
status: canonical       # draft | canonical | disputed | archived
updated: 2026-09-23
tags: [sync, lan]
description: "One line under ~150 chars, shown in recall results"
supersedes:             # the note this one replaces
---
# One-line claim title

The claim and why, in under ~200 words. Claims that can go stale carry a
date: "Forgejo runs 1.22 (as of 2026-09)".
```

| Field | Rule |
|---|---|
| `type` | semantic = facts that stay true; procedural = how to do something; strategic = decisions and why; episodic = handoffs, journal entries, dated events |
| `domain` | Broad, few, stable. Must match `domains.txt`; `anvil note` refuses anything else. Adding a domain is your call, not Claude's. |
| `subdomain` | A tool, technology, or language (`python`, `ssh`); for non-software domains, a topical sub-category (`backtesting`). Never one of your projects. |
| `project` | One of your own projects (`anvil`, `orion`), or a topic name for a journal entry. Never a tool. Empty for a general fact. |
| `tags` | Free keywords that help a future search. |
| `origin` | What backs the claim, not who wrote it. See below. |
| `description` | One line, required. What recall shows. A vague description makes a good note unfindable. |
| `supersedes` | The older note this one replaces. On approval the old note is archived and back-linked, never deleted. |

**Origin rules (enforced by `anvil note`):**

| Note comes from | Allowed `origin` |
|---|---|
| A session (`note`, `reflect`, `hydrate`, `handoff`, `journal`, Claude's drafts) | A Forgejo/Gitea link to the repo or file, or empty |
| `/anvil:ingest` of a URL | The page or PDF link, recorded in `sources.tsv` |
| `/anvil:ingest` of a local file | The clean copy in the vault's `raw/` folder |
| A forge writeup | The link to that writeup on Forgejo/Gitea |
| Nothing: a general fact, a personal log | `none`, which records that decision and stops the missing-origin warning |

Web pages Claude fetches during a session never become note content; keep a
web source with `/anvil:ingest`. Without `--origin`, `anvil note` links the
current repo on your configured host, or leaves `origin` empty.

## Vault layout

```
~/.blacksmith/anvil/vault/
  index.md          map of the vault
  domains.txt       allowed domains, one per line
  moc/<Domain>.md   one map of content per domain; approved notes link here
  semantic/         facts                      ← recall searches
  procedural/       how-to                     ← recall searches
  strategic/        decisions                  ← recall searches
  episodic/         handoffs, journal entries, dated events
  raw/              clean copies of ingested sources
  sources.tsv       one row per saved copy: source, checksum, raw path
  _inbox/           drafts waiting for review
  _archive/         archived notes; rejected/ holds rejected drafts
```

Machine-local state sits next to the vault, never inside it, so Syncthing
(which shares only `vault/`) never shares it: `~/.blacksmith/anvil/state/`
holds `usage.tsv` (read/write log), `hydrated.tsv` (which sessions were
mined), and `batches/` (the undo data of each backfill batch). `anvil path`,
`anvil path --state`, and `anvil path --home` print these locations.

## Command details

### `/anvil:recall [--full] <topic>`

Run it whenever the vault may already hold the answer. It searches on the
single most distinctive word of the question, tries up to 3 words, opens
the relevant notes, and reports what they say (see
[How recall works](#how-recall-works)).

### `/anvil:note <claim or topic>`

Dictate the claim, or name a topic and let Claude find the claim in the
conversation. Claude checks recall first. Asked by you, the draft goes
straight to the Anvil Review question. When Claude decides on its own that
something is worth keeping, it saves a draft to the inbox and tells you in
one line, without a question. Two claims make two notes. A claim about
anvil itself uses `project: anvil`.

### `/anvil:reflect [focus]`

Run it at the end of a session. Claude reviews the conversation, drops
anything that only recaps what was done, checks each candidate against
recall, then reviews the survivors, up to 4 cards per question. Finding nothing
durable is a normal result.

### `/anvil:hydrate`

Mines past Claude Code sessions that never ran `/anvil:note` or
`/anvil:reflect`. Claude Code deletes transcripts after 30 days; an older
session is gone, and that is accepted.

- Scans the current directory **and every subdirectory**, because Claude
  Code stores sessions by exact launch directory. Run it from a monorepo
  root to sweep every package. Each session is confirmed against its
  recorded `cwd`.
- Lists sessions with a status (🟡 new, 🟢 hydrated, 🟣 partial, 🔴 failed)
  and a gist (the session's real opening line), newest first.
- An older session's claim that disagrees with a live note is shown as a
  conflict, for you to decide.
- Drafts are tagged `hydrated`. `anvil sessions --record` saves the progress.
- Secrets (API keys, tokens, private keys, `password=` values, text in
  `<private>…</private>`) are removed before Claude reads a transcript
  (`lib/redact.py`). Pattern matching is not a guarantee; the review is the
  final check.

### `/anvil:ingest <url | path>`

| You give it | It uses |
|---|---|
| Local `.md` or `.txt` | A plain copy |
| Local `.pdf`, or a URL that serves a PDF | pymupdf4llm (headings, tables, reading order) |
| Local `.html`, or a web page | defuddle (clean markdown, no menus or ads) |
| A page that links to a paper PDF | A question: page, PDF, or both (found via `citation_pdf_url`, `.pdf` links, and arXiv `/abs/` → `/pdf/`) |

Every source has secrets removed, is saved to `raw/` with a small
frontmatter, and gets a row in `sources.tsv`, so a second ingest of the same
content says `unchanged` and saves nothing.

A long source is read as a **funnel**, after S. Keshav's "How to Read a
Paper":

1. `anvil sections <raw>` lists the sections with word counts, at no
   reading cost.
2. Claude reads only the abstract, introduction, and conclusion.
3. You pick the claims worth keeping from 2-8 candidates, each shown with
   its sections and word count.
4. Claude reads only the sections behind your picks. Picks over ~1,500
   words go to a Haiku subagent, which returns a short extract, so the long
   text never enters the main context.
5. The drafts go through the review card, attributed to the source, not
   stated as settled fact.

On a 28,000-word paper this took about 10% of a full read into the main
context. Run `/anvil:ingest` on the same source again to mine more claims;
the ones that already have a note are left out.

A site that blocks scripts (HTTP 401, 403, or 429, such as ResearchGate)
gets a clear error: download the file in a browser and ingest the local
file. `anvil ingest` needs Node.js (for defuddle, through `npx`) and uv
(for pymupdf4llm). Page text is treated as data, never as instructions.

### `/anvil:inbox`

Lists the drafts in `_inbox/` and reviews them, up to 4 cards per question. A draft
whose origin link does not resolve (a writeup not pushed yet) cannot be
approved and stays in the inbox. Drafts never expire; `/anvil:vault` shows
how many are waiting.

### `/anvil:handoff`, `/anvil:journal`, and `/anvil:world`

`/anvil:handoff` writes one dated note to `episodic/`, tagged `handoff`,
with fixed sections: **Done**, **Decisions** (each choice and why, which git
does not record), **Left**, **Next** (one concrete step), and **Open
questions**. It is point-in-time detail for picking a project back up, not
an activity log; git and the CHANGELOG hold the full record. Only the
latest handoff per project matters.

`/anvil:journal` drafts one dated note to `episodic/`, tagged `journal`,
from a thinking session with no project yet: a business idea, a direction,
a project under consideration. It records what was explored, the options
weighed, where you leaned and why, and the open threads. A topic name such
as `ideas` stands in for the project. Unlike a handoff, an entry never goes
stale. When an idea becomes a project, keep its topic name as the project
name.

`/anvil:world` shows the latest handoff for each project of the last 30
days (description, next step, counts), then the last 10 journal entries.
`/anvil:world <project>` prints that project's latest handoff whole and
lists its earlier handoffs of the last 90 days. `/anvil:world journal [word]
[page N]` lists every journal entry, 20 per page, or only those that match
the word.

The `anvil world` CLI prints the same output. Type `! anvil world
--full <project>` in the Claude Code prompt to read a handoff with no model
turn. At the start of a session, the first model turn also writes the full
system context to the prompt cache, so the skill is the more costly path.
Use the skill when you want its one-line next step.

### `/anvil:backfill [description|origin|project]`

Schema migrations add new fields **empty**; they never guess values.
Backfill proposes a real value for each empty field, only when a real
signal exists (the note's own claim, its repo, a traceable source), and
writes only what you approve. A field changes metadata, not a claim, so you
approve a **batch** at a time: one card for up to 8 descriptions, or for
all notes that get the same origin or project. Each batch prints its undo
command. A note with nothing to link gets `origin: none`.

### `/anvil:vault`

Read-only: note counts by type and status, a domain → subdomain tree, and
warnings for drafts waiting, missing descriptions or origins, origins
outside the rules, drift (a domain not in `domains.txt`), and orphans (a
live fact not linked from any `moc/` file). Also the vault size, a rough
token estimate for the whole vault, and both version axes.

### The deep layer: `anvil source`

A note whose `origin` is a Forgejo/Gitea link can be followed, read-only:
a **file link** prints that file at the linked ref, a **repo link** lists
the repo's `.blacksmith/forge/writeups/`, and an **ingested URL** or
**`raw/` path** points at the vault's clean copy. For another repo, anvil
keeps a shallow, sparse clone in `~/.blacksmith/cache/repos/<owner>/<repo>`,
fetched with the `blacksmith-reader` key, which can only read.

## The `anvil` CLI

Every command also works from a terminal, without Claude. In Claude Code
sessions the plugin puts `anvil` on PATH; for terminals, the installer can
add a PATH line. `anvil help` lists everything.

| Command | Does |
|---|---|
| `anvil recall [--full] "<word>"` | Search live notes (at most 4, ranked) |
| `anvil show <name>` | Print one live note in full, handoffs and journal entries included |
| `anvil note --type … --domain … --title "…" --description "…" --body -` | Save a draft |
| `anvil note --review <draft> [--of "i of n"] [--part before]` | Print a draft as the review card |
| `anvil note --approve` / `--reject` / `--restore` / `--unapprove` / `--amend` / `--set` | Work with drafts and live notes (`anvil note --help`) |
| `anvil note --batch <field> --card` / `--approved`, `--undo-batch <id>` | Backfill a batch of field values, and undo it |
| `anvil note --list-drafts` / `--drafts` | List the inbox |
| `anvil ingest <url\|path> [--pick page\|pdf\|both]` | Save a clean copy of a source to `raw/` |
| `anvil sections <raw> [n[,n…]]` | List a raw copy's sections, or print only some |
| `anvil source [--list] <note\|link>` | Follow a note to what backs it, read-only |
| `anvil world [<project> \| journal [word] [--page N]]` | Handoffs and journal |
| `anvil domain add <name>` / `domain list` | Add a domain (and its `moc/` file) / list domains |
| `anvil status` | Counts, domain tree, warnings, versions |
| `anvil audit --field <name>` / `--bad-origin` | Notes missing a field / with an origin outside the rules |
| `anvil link-check <origin>` | Check that an origin resolves |
| `anvil usage` | Local read/write counts and recall hit rate |
| `anvil migrate [--dry-run]` | Run schema migrations on the vault |
| `anvil sessions [--exclude <id>]` / `--record …` / `session-read <path>` | Claude Code sessions for hydrate |
| `anvil path` / `anvil version` | Vault root / tooling and schema versions |
| `anvil extras` / `anvil open [path]` | Install / open emeraldian, a terminal vault viewer (optional) |

The drafting rules the skills follow are in `reference/drafting.md`.

**Package vs vault.** The scripts live in the plugin: its source is
`anvil/` in the blacksmith clone, and the installed copy that runs is
`~/.blacksmith/plugins/anvil/`. The vault holds only your data. Every
script finds the vault the same way: `$ANVIL_HOME`, else the path in
`~/.blacksmith/config/anvil-home` (written only for a vault kept
elsewhere), else `~/.blacksmith/anvil/vault`. `BLACKSMITH_HOME` overrides
`~/.blacksmith`.

## Install

```
git clone https://github.com/OnyxDrift/blacksmith.git
cd blacksmith
./install.sh              # choose "anvil only" or "both"
# or, for anvil alone with no question:
anvil/install.sh
```

The [blacksmith README](../README.md#install) lists what an install
changes. The vault setup asks up to five questions:
single machine or several (Syncthing), new or existing vault, vault path
(default `~/.blacksmith/anvil/vault`), starting domains, and whether to add
`anvil` to your terminal PATH. Every question has a flag (`--single-machine`,
`--existing-vault`, `--path`, `--domains`, `--add-to-path`,
`--non-interactive`, and more). Re-running is safe: it never touches notes,
`index.md`, `domains.txt`, or `moc/`.

A project needs no setup for anvil: no `anvil init`, no block in its
`CLAUDE.md`. The installer adds `@~/.blacksmith/plugins/anvil/CLAUDE-pointer.md`
to the global `~/.claude/CLAUDE.md`, which points at `/anvil:recall` and
`/anvil:note` for every project, and the skills describe themselves.

**Updating:** `git pull`, then `./install.sh --update`. New sessions, or
`/reload-plugins`, pick it up.

**Requirements:** macOS, Linux, or Windows with Git Bash (not verified
yet); bash 3.2 or newer, Claude Code, git, and Python 3.8+ (found as
`python3`, `python`, or `py`; see the blacksmith README). For `/anvil:ingest`: Node.js (npx) and uv. Optional:
Syncthing, Obsidian, emeraldian.

## Versioning and upgrades

Two independent version axes:

- **Schema** (`SCHEMA_VERSION`): the shape of note frontmatter. The vault
  records the schema it is migrated to in `.anvil-applied-version`.
  `anvil migrate` runs outstanding `migrations/*.sh` in order.
- **Tooling** (`version` in `.claude-plugin/plugin.json`): the scripts,
  skills, and hooks.

The one rule: **migrations never guess.** They add structure (an empty
field, a rename) and never make up values. `anvil status` flags what is
still empty; `/anvil:backfill` proposes real values with your approval.

## Syncing across machines

Anvil has no sync logic; it is plain files. Use Syncthing, sharing only the
vault folder.

- Pair each machine's device ID once in Syncthing's web UI
  (`http://localhost:8384`), then share the folder.
- **Two separate steps:** trusting a device ("Connected") shares nothing.
  On the machine that has the vault, edit the folder → **Sharing** → tick
  the new device. Only then does the other machine get an offer.
- **Headless machine:** tunnel the GUI from a machine with a browser:
  `ssh -L 8385:localhost:8384 <user>@<host>`, then open
  `http://localhost:8385`.
- When you move a shared folder, let only one machine hold the content and
  let the other receive it; run content-changing steps such as
  `anvil migrate` only after both show Up to Date.
- On a conflict in `semantic/`, `procedural/`, or `strategic/`, the copy on
  your primary machine wins.
- If Syncthing delivered the vault before you install on a new machine,
  answer **existing vault**.

## Viewing the vault in Obsidian

Optional; agents never need it. **Open folder as vault**, pick
`~/.blacksmith/anvil/vault`, and decline plugins. Graph view shows the notes
linked from each `moc/` file as hubs. Search `status:canonical` lists the
same set recall searches. `anvil open` is a terminal alternative.

## Uninstall

`anvil/uninstall.sh` (or `./uninstall.sh`, then "anvil only") uninstalls
the plugin and removes its permission rule, its import line, the PATH
block, and the recorded vault location. Your notes
stay. `--purge` also deletes vault content after you type the vault path
back to confirm (`--keep-folder` empties it, `--delete-folder` removes the
folder too). `./uninstall.sh --hosts` also removes the host config and the
read-only key.

## Design choices and prior art

- [COMPARISON.md](COMPARISON.md): how anvil compares with six similar
  tools, what it borrows from each, and where they are still ahead.

Key choices, in one line each:

- **Deliberate over automatic.** Automatic tools pay for speed with curation
  debt; anvil keeps drafts in an inbox that recall never sees.
- **Descriptions before bodies.** Recall shows one line per note; full text
  only on demand.
- **Enforced, not requested.** The gate lives in `anvil note`, a hook, and
  permission rules, not only in instructions.
- **The gate matches the risk.** A new claim gets its own card; a metadata
  backfill is approved a batch at a time, with one-command undo.
- **Read only what matters.** Long sources go through the section funnel.
- **Established tools for extraction.** defuddle for web pages,
  pymupdf4llm for PDFs, Syncthing for sync.
- **One vault.** Do not use Claude Code's built-in memory as a second store.
