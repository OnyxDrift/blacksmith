# Changelog

Human-readable history of anvil. Not parsed by any script — schema
changes are driven by `migrations/*.sh` (run by `bin/upgrade-vault`),
tooling changes are just whatever's in this repo's `bin/`/`templates/`
(pulled in by `bin/upgrade`). This file is the "why," those are the
mechanism, the note files are ground truth.

Two independent version axes, each with its own history below — see
"Versioning and upgrades" in `README.md` for why they're kept separate.

## Schema (`SCHEMA_VERSION`, note frontmatter shape)

### 0.0.0_3

Added `description:` (one line, required on every new note; recall shows it
in place of the whole note) and `supersedes:` (the older note a newer one
replaces; that note is archived on approval, never deleted). Migration
0.0.0_3 adds both fields empty to existing notes. `/anvil:backfill`
proposes real descriptions, with approval.

### 0.0.0_2

Added an `origin` frontmatter field to notes — what backs the claim (a git
repo for code, a book/webpage/PDF for anything else), distinct from
`source` (which tool or human wrote the note). `bin/note` auto-detects it
for code-sourced notes: prefers a git remote URL, falls back to the local
repo root, falls back to the plain working directory if not inside a git
repo at all. Always overridable with `--origin`.

Existing notes get an empty `origin:` field via this version's migration —
deliberately empty, not guessed, since there's no safe way to reconstruct
an old note's real origin after the fact. `bin/status`/`bin/audit` flag
notes still missing a real value; the `/fill-vault` Skill proposes values with
its reasoning shown, approval-gated same as every other anvil write.

### 0.0.0_1

Baseline note schema: `type`, `domain`, `subdomain`, `project`, `source`,
`status`, `updated`, `tags`.

## Tooling (the anvil scripts and Skills themselves; `version` in `.claude-plugin/plugin.json` since 0.0.0_8, `TOOLING_VERSION` before)

### 0.0.3

Anvil installs alone. `anvil/install.sh` copies the plugin into the
snapshot, sets up the vault, merges `settings.fragment.json` (the
`Bash(anvil *)` rule), adds `@~/.blacksmith/plugins/anvil/CLAUDE-pointer.md`
to `~/.claude/CLAUDE.md`, and installs `anvil@blacksmith`.
`anvil/uninstall.sh` reverses each step; the vault stays. The installers
need only claude, git, and Python 3.8+: no jq, no rsync. The first public
release, in the blacksmith repo.

Python is found, not assumed: the installer saves the first `python3`,
`python3.X`, `python`, or `py` that runs as 3.8+, and the `anvil`
dispatcher and the hooks (through `hooks/run`) use that path instead of
the `python3` shebang. Toward Windows with Git Bash: `.gitattributes`
keeps LF line endings, `PYTHONUTF8=1` makes Python read and write UTF-8,
Python output uses `\n` line ends, and `lib/hosts.py` is read from the
shared `lib/`, not through a symlink.

### 0.0.2_1

You can now see what recall found. A PostToolUse hook
(`hooks/show-recall`) shows the titles from each `anvil recall` or
`anvil show`, or the miss, as a `systemMessage`, at no model-token cost.
The global CLAUDE.md asks for one `Anvil:` line when a recalled note
changes what the model does.

### 0.0.2

Fewer turns in the draft flows. At the end of a long session, each turn
reads the whole context again, and `/anvil:reflect` made one turn per
recall, per save, and per review card.

- `reference/drafting.md`: run independent `anvil` commands as parallel
  tool calls in one message (each still alone, so `Bash(anvil *)` still
  matches). Recalls, saves, review cards, and answers are each one message.
- The review loop asks up to 4 drafts per question, one tab each
  (`Review i/n`; a `--supersedes` draft takes `Before i/n` and `After i/n`).
  This applies to note, reflect, hydrate, ingest, and inbox.
- READMEs name `! anvil world`, which reads handoffs with no model turn.

The review rounds are not yet checked by hand.

### 0.0.1

The first release, with forge 0.0.1 and blacksmith 0.0.1. Every command
was checked by hand on 2026-09-24. Cleanup for the release:

- Removed `anvil init` and `CLAUDE_BLOCK.md`. No skill or installer used
  them, and the global `~/.claude/CLAUDE.md` holds the anvil pointer for
  every project; a per-project copy only cost tokens on every turn.
- `anvil note --review` prints the plain-text review card by default. The
  `--question` flag, the markdown card, and the narrow `--preview` card
  (for a layout that was dropped) are gone.
- The vault installer lost the one-time moves from older layouts
  (`~/.anvil`, the XDG folders, the pre-plugin copies inside the vault);
  every vault had already moved. It no longer installs ripgrep, which
  nothing used, and no longer creates the unused `_review/` folder.
- README rewritten for this release: who triggers each command, the review
  card, recall ranking, the ingest funnel, handoff versus journal, undo.

### 0.0.0_36

`anvil sessions --record <id> <status> <notes> [detail]` appends a
session's progress row to `hydrated.tsv`. `/anvil:hydrate` used to append
the row with a shell redirect, which is not a bare `anvil` command, so it
would have prompted the user after the review. Found in the first manual
hydrate run.

### 0.0.0_35

Recall ranks whole-word matches above matches inside longer words, and
marks the latter "partial match". Before, `recall sed` matched "based" in
12 notes and could bury the one note about sed. Substring matches still
count, so `walk` finds `walk-forward`. Recall also undoes the escapes of a
quoted frontmatter value, so a description with `\(a\|b\)` reads as
`\(a\|b\)` was written.

### 0.0.0_34

`anvil sessions` gives a session's real opening line as its gist. It now
skips blocks the harness adds to a user turn (`<system-reminder>`,
local-command output) and a compaction summary, and drops paste markers.
Before, a named or compacted session showed "<system-reminder> The user
named this session…" in `/anvil:hydrate`'s list.

### 0.0.0_33

`/anvil:ingest` reads a long source as a funnel, following S. Keshav's
"How to Read a Paper" (skim first, then only what matters):

1. New `anvil sections <raw>` lists the sections with word counts, at no
   reading cost; `anvil sections <raw> <n>` prints only those sections.
2. Claude skims: abstract, introduction, conclusion.
3. The user picks the claims worth keeping from 2-8 candidates.
4. Claude reads only the sections behind the picks. Picks over ~1,500
   words go to a Haiku subagent that returns a 250-word extract, so the
   long text never enters the main context.

Before, ingest drafted 1-3 claims of Claude's choosing, and the user never
saw the other candidates. For the 28,000-word test paper, the skim costs
about 10% of a full read.

### 0.0.0_32

`anvil ingest` says when a site blocks scripts (HTTP 401, 403, or 429:
ResearchGate, SSRN, many publishers) and what to do instead: download the
file in a browser and ingest the local file. Before, it printed only
"could not reach … (HTTP Error 403: Forbidden)".

### 0.0.0_31

`origin: none` records that nothing backs a note (a general fact, a
personal log). `anvil note`, the link check, and backfill accept it;
`status` and `audit` no longer list it as missing, and recall does not
print it. Before, a deliberately empty origin warned forever. `status` no
longer lists episodic notes (handoffs, journal entries) as MOC orphans:
they stay out of the MOC files by design. Its text names `/anvil:recall`.

### 0.0.0_30

`/anvil:recall` reports what the notes say, never only that they exist.
Typed by the user, it presents each relevant note's substance. Run by
Claude during other work, it gives one line per note used: what it says and
how it applies. `/anvil:recall --full <word>` prints the notes whole. Found
in a manual check: a typed recall listed one note and stopped.

### 0.0.0_29

The origin check now checks that a linked file exists. On macOS it never
did: `link-check` used `\|` alternation, which BSD sed does not support, so
every `/src/<ref>/<path>` link passed as "repo readable". A note linked to
an unpushed orion writeup was approved with a dead link. Now it uses
`sed -E`, and an unpushed file fails the check as designed.

The question card keeps a `## Heading` on its own line. Before, the first
line of text under it was joined onto the heading.

### 0.0.0_28

Handoffs and a new journal, each with one job; `/anvil:world` reads both.

- `/anvil:handoff` gets a **Decisions** section (git records what changed,
  not why) and a ~350-word cap. It stays point-in-time detail for picking
  a project back up, not an activity log.
- New `/anvil:journal` records a thinking session with no project yet
  (ideas, options, where you leaned, open threads) as an episodic note
  tagged `journal`, through the review card. Unlike a handoff, an entry
  never goes stale.
- `/anvil:world` shows the latest handoff per project over 30 days (was
  14), then the last 10 journal entries. `/anvil:world <project>` prints
  the latest handoff without frontmatter and lists the earlier ones of the
  last 90 days; with no project it shows the most recent one (it crashed
  before). `/anvil:world journal [word] [page N]` lists or searches every
  entry, 20 per page.

Tried and dropped: a trail of every handoff in the overview. Older
handoffs go stale, so the list read as fragments.

### 0.0.0_27

Recall searches only the claim (title, description, tags, project,
subdomain, body), not the origin link, and ranks hits by where they match:
title, then description, tags, project or subdomain, then body; newest
first within a rank. It says how many more notes matched beyond the 4 it
shows. Before, it matched the whole file and kept the first 4 in file
order: `recall ares` matched every note whose origin URL holds
`<owner>/<repo>`, and the ares scope-rule note did not appear at all.

### 0.0.0_26

`/anvil:backfill project` fills an empty project, grouped by the value
taken from the note's origin (the repo, or the project folder in it).
`--batch project` accepts one lowercase name. A general fact with no
project stays empty.

### 0.0.0_25

A replacement draft (`--supersedes`) is reviewed as two tabs in one
question: Before (the live note in full, with its details) and After (the
new version in full), then submit. After has a Show before option. The
question dialog cuts off tall text and cannot scroll, so one card with both
notes lost its bottom half. Tried and dropped: red and green emoji markers
for a list of changes, which did not display cleanly.

Cards show the full origin link, not a short `forgejo:<owner>/<repo>` label.
The short label hid where the claim lives, and it looked the same as an old
ssh remote.

### 0.0.0_24

The question card keeps list items on their own lines. Before, a note's
`- ` items ran together in one paragraph.

### 0.0.0_23

A draft that replaces a live note (`--supersedes`) shows that note in full
on its review card, under BEFORE, above the draft under AFTER. Other cards
do not change. `anvil show` opens episodic notes too; drafts and archived
notes stay out.

### 0.0.0_22

The backfill card shows full origin values. With the short label, an old
ssh remote (`forgejo:<owner>/<repo>`) looked the same as its new web link, so
the card showed no visible change. Found in the first real origin backfill.

### 0.0.0_21

`/anvil:backfill` reviews a batch at a time. `anvil note --batch <field>
--card` reads `<note><TAB><value>` lines, checks every value, and prints
one plain-text card for the batch. The card goes in the question text, as
in the draft review. Origins are grouped by proposed value, so one answer
covers every note from the same repo. `--batch <field> --approved` writes
the batch and prints `anvil note --undo-batch <id> --approved`, which puts
the old values back. Before, backfill printed its proposals above the
question, where the dialog hid them, and split them into multi-selects of
4. A full card per note would have meant 91 questions for 46 descriptions
and 45 origins; batches make it about 10.

### 0.0.0_20

Approve is undoable: `anvil note --unapprove <note> --approved` moves a
live note back to `_inbox/` as a draft, removes its MOC link, and brings
back the note it superseded. It refuses when other notes link to it. A
mis-click on Approve had no fix before, and a direct edit of the vault is
blocked, as it should be.

### 0.0.0_19

The review card names the host kind in the origin: `forgejo:<owner>/<repo>`
or `gitea:<owner>/<repo>`, looked up in `~/.blacksmith/config/hosts.tsv`. A
URL on no configured host shows its path alone, as before.

### 0.0.0_18

The draft card is the question text itself (`anvil note --review
--question`), not a preview panel. The side panel was unreadable on a
phone (Moshi). The card is plain text, one field per line, with no hard
wraps, so it reflows at any width. Tested in the terminal and in Moshi.

Skills call `anvil` by name, not by its full plugin path, and
`allowed-tools` is `Bash(anvil *)`. `settings.base.json` allows
`Bash(anvil *)` and `Bash(forge *)` too, so an anvil command runs without
a prompt in any permission mode. The approval gate is the anvil question
and `anvil note`'s own checks, not a Bash prompt. `drafting.md` says to run
each command on its own: a `cd … &&` prefix or a script breaks the match
and asks the user again after they already answered.

### 0.0.0_17

The draft card now lives inside the question. In Claude Code the question
dialog hides the text above it, so a card printed in the message was never
seen. `anvil note --review --preview` renders a narrow plain-text card, and
the review loop puts it in the `preview` field of every option, so the
draft stays in view whichever option is highlighted.

Reject is undoable: a rejected draft moves to `_archive/rejected/` instead
of being deleted, and `anvil note --restore <file>` brings it back (a real
mis-click deleted a draft that had to be recreated by hand).

### 0.0.0_16

One review loop, one draft at a time. A real `/anvil:inbox` run still got a
one-line summary instead of the draft, so the formatting no longer depends
on instructions: `anvil note --review <draft> --of "1 of 3"` renders a draft
as markdown (header, description, metadata table with a live link check,
body) and the skill copies it verbatim. `reference/drafting.md` defines the
loop once: render, ask Approve / Keep in inbox / Reject, act, next. New
candidates in `/anvil:note`, `/anvil:reflect`, `/anvil:hydrate`, and
`/anvil:ingest` are saved as inbox drafts first and then go through the same
loop as `/anvil:inbox`, so every review looks the same. New:
`anvil note --list-drafts`.

### 0.0.0_15

Installed as a snapshot, not run from the clone. `ai/blacksmith/install.sh`
copies the plugins to `~/.blacksmith/plugins/` and registers that folder as
the `blacksmith` marketplace; a registration at the clone is moved. The
terminal PATH line points there too. Editing or switching branches in the
source clone now changes nothing live until `install.sh --update`, and
`.installed-from` records the source commit. This also follows the rule
that everything the plugins use outside a repo lives in `~/.blacksmith`.

`/anvil:inbox` shows each draft in full before asking (a real test showed a
one-line summary instead), and a single draft gets one Approve / Keep in
inbox / Reject question rather than a multi-select with a "None" option
plus a second question.

### 0.0.0_14

One home for everything: all per-user blacksmith files now live under
`~/.blacksmith` (`BLACKSMITH_HOME`), not spread across `~/.anvil`,
`~/.config/blacksmith`, `~/.local/state/anvil`, `~/.cache/blacksmith`, and
`~/.ssh`. The vault defaults to `~/.blacksmith/anvil/vault`; machine-local
state is `~/.blacksmith/anvil/state`; the repo cache is
`~/.blacksmith/cache/repos`; `config/anvil-home` is written only for a vault
kept elsewhere. The installer moves the older layout in once and asks
before moving the vault (or `--move-vault` / `--keep-vault`), because
Syncthing and Obsidian may point at `~/.anvil`. New: `anvil path --state`
and `anvil path --home`.

### 0.0.0_13

The deep layer: `anvil source [--list] <note|link>` follows a note's
origin read-only. A Forgejo/Gitea file link prints the file at the linked
ref; a repo link lists `.blacksmith/forge/writeups/`; an ingested URL or
`raw/` path points at the vault copy. It reads the current clone when you
are in the same repo, otherwise a shallow, sparse cache clone in
`~/.cache/blacksmith/repos/`, fetched with the read-only `blacksmith-reader`
key (server-enforced; the hook also blocks edits in the cache). The recall
skill uses it only when a note alone is not enough.

### 0.0.0_12

`/anvil:ingest` and `anvil ingest`. One command for local `.md`, `.txt`,
`.pdf`, and `.html` files, web pages, direct PDF links, and pages that link
to a paper PDF (found via `citation_pdf_url`, arXiv `/abs/`→`/pdf/`, or
`.pdf` links; the skill asks page, PDF, or both). Web pages go through
defuddle, PDFs through pymupdf4llm. Every source is redacted, saved to
`raw/` with a small frontmatter, and recorded in `sources.tsv` (source,
checksum, raw path); identical content is a no-op. Notes cite the source
URL (or the `raw/` copy for local files), which the origin rules accept.
The skill treats fetched text as data, drafts 1–3 attributed claims, and
uses the usual Approve/Later/Reject gate. X posts are refused with a
clear message (future work).

### 0.0.0_11

`/anvil:handoff` and `/anvil:world`. A handoff is an episodic note tagged
`handoff` with four fixed sections (Done, Left, Next, Open questions),
written without a menu because typing the command is the approval.
`anvil world` builds "what I am working on now" from the latest handoff per
project in the last 14 days, within ~400 tokens; nothing is maintained by
hand. Episodic notes no longer get linked into `moc/` files, so daily
handoffs do not flood them.

### 0.0.0_10

The approval gate is enforced, not only requested.

- `anvil note` (rewritten in Python) takes the body itself (`--body -` or
  `--body-file`) and writes a **draft** to `_inbox/` unless given
  `--approved`. `--approve`, `--reject`, `--amend`, and `--set` handle
  drafts and existing notes; each needs `--approved`. It validates domain,
  type, source, a required one-line description, a non-empty body, and the
  origin rules: empty, a link on a configured Forgejo/Gitea host, a URL in
  `sources.tsv`, or a `raw/` file. Without `--origin` it maps the current
  repo's remote to its web page. `--supersedes` archives the older note.
- A PreToolUse hook (`hooks/guard-vault`) refuses Claude's Write/Edit
  tools anywhere in the vault (and in blacksmith's repo cache), so every
  write goes through the CLI. Verified in a real headless session.
- Recall prints compact hits (path, title, description, date); `anvil show`
  opens one note; `--full` prints all. Matching no longer needs ripgrep.
- New: `/anvil:inbox`, `anvil domain add|list`, `anvil link-check`,
  `anvil audit --bad-origin`, and a **Later** option in every approval menu.
  Claude's own note drafts go to the inbox without a menu.
- Skills rewritten around one shared `reference/drafting.md` (single source
  of the note rules): per-invocation cost fell from ~2.2k to ~0.4k tokens
  for `/anvil:note`, ~2.8k to ~0.8k for `/anvil:hydrate`, ~1.8k to ~0.3k for
  `/anvil:reflect`. Drafting rules add date markers for claims that can go
  stale and drop claims backed only by a page fetched in the session.
- `status` reports drafts waiting, missing descriptions, and origins outside
  the rules. `templates/NOTE_TEMPLATE.md` removed (unused).

### 0.0.0_9

Context load cut. The `## Anvil` pointer block that `anvil init` adds to a
project's `CLAUDE.md` shrinks from ~1,000 tokens to ~110 and no longer
holds a machine path. It now says only when to reach for `/anvil:recall`
and `/anvil:note`; the detailed rules already live in the skills, which
load only when used. Re-run `anvil init` in each wired project to refresh
its block in place.

Invocation split, after Pocock's model-invoked vs user-invoked rule:
`/anvil:reflect`, `/anvil:hydrate`, `/anvil:backfill`, and `/anvil:vault`
set `disable-model-invocation: true` (Claude cannot fire them; their
descriptions leave context). `/anvil:recall` and `/anvil:note` keep
model-facing descriptions that name when to use them. Descriptions are
quoted YAML; skills gain `argument-hint`.

### 0.0.0_8

Anvil is a Claude Code plugin in the `blacksmith` marketplace
(`ai/blacksmith/`). Commands are prefixed: `/anvil:recall`, `/anvil:note`,
`/anvil:reflect`, `/anvil:hydrate`, and two renames, `/fill-vault` →
`/anvil:backfill` and `/anvil` → `/anvil:vault`.

- Package and vault are separate. Scripts are no longer copied into the
  vault; they run from the plugin (loaded in place from the ares clone).
  Every script finds the vault through `lib/common.sh`: `$ANVIL_HOME`,
  then `~/.config/blacksmith/anvil-home`, then `~/.anvil`.
- Only `bin/anvil` is on PATH; helpers moved to `libexec/`. CLI renames:
  `upgrade-vault` → `migrate`, `open-vault` → `open`,
  `install-additional-packages` → `extras`; new `version`, `sessions`,
  `session-read`. `anvil upgrade` is gone (plugin updates replace it).
- Skills call `${CLAUDE_PLUGIN_ROOT}/bin/anvil` and pre-approve it with
  `allowed-tools`, so anvil commands inside skills need no permission prompt.
- `TOOLING_VERSION` is replaced by the plugin manifest's `version`.
- `install.sh` is now vault-only setup. The remote `curl | bash` install
  and the `git:` upgrade source are removed (anvil lives in a private repo;
  install from a local clone). On first run it cleans up the pre-plugin
  layout: script copies inside the vault, the old unprefixed skills in
  `~/.claude/skills`, and the stale `tooling-source` state file. It
  repoints the PATH block at the plugin's `bin/`.
- Fixed: `recall` silently returned no results for vaults at long paths.
  macOS `xargs -I` drops any command over 255 bytes. Replaced with a plain
  loop; matching is now truly literal (`grep -F`), as documented.

### 0.0.0_7

Anvil is Claude Code only. Grok Build support is removed: its hydrate
path never worked against real data (it read `summary.json` keys and an
`updates.jsonl` shape that do not exist; the chat is in
`chat_history.jsonl`). OpenCode was only ever a placeholder. The real
storage formats of both are recorded in
`docs/findings/anvil/agent-session-storage.md` (ares repo) for later.
`--source` now accepts `claude|human`; `session-read` accepts only Claude
Code transcripts (`--engine claude` still works for older callers).

`/hydrate` now removes secrets before Claude reads a transcript: a new
`lib/redact.py` strips private keys, common API key and token shapes,
bearer tokens, credentials in URLs, secret-named assignments, and any
text inside `<private>…</private>`. `session-read` refuses to run
without it rather than print an unredacted transcript. `install.sh`
ships `lib/` into the vault next to `bin/`.

### 0.0.0_6

`install.sh` now works piped straight into bash with no local checkout —
`curl -fsSL https://raw.githubusercontent.com/OnyxDrift/anvil/main/install.sh | bash`.
It detects when it isn't running from an on-disk clone, fetches a
throwaway copy of the repo (`git clone`, or `curl`+`tar` if `git` isn't
on PATH) into a temp dir, re-runs itself from there, then deletes it.
Must be piped to `bash`, not generic `sh` — the script uses bash-only
array syntax that breaks under `dash`/POSIX-mode `sh`.

New `--remote-upgrades` flag (implied automatically for a piped install)
records the GitHub repo in `tooling-source` instead of a local clone
path, so the clone used for the initial install can be deleted right
after. `bin/upgrade` now understands that `git:<url>#<ref>` form: it
fetches a fresh temp copy from GitHub on every upgrade instead of
requiring the original clone to still exist on disk.

### 0.0.0_5

Fixed a real over-application bug in `CLAUDE_BLOCK.md`'s branding rule,
caught live in a separate project: "every message in this flow starts
with `Anvil:`" was ambiguous about what "this flow" meant, and an agent
in another repo applied it to an unrelated `.todo`/`.done` bookkeeping
task that never touched the anvil vault, just because the pointer block
happened to be present in that file. Reworded to explicitly scope the
rule to actual vault read/write actions (`/recall`/`/note`/`/reflect`/
`/hydrate`, or a plain-language request that results in calling
`anvil/bin/recall`/`anvil/bin/note`) — unrelated work in the same repo
follows whatever conventions apply to it elsewhere, not anvil's.

Also removed the "janitor maintains this list." filler line from every
generated `moc/*.md` file (pure boilerplate, no informational value) —
fixed at all four generation sites (`install.sh`, `bin/note`, `/note` and
`/reflect` Skill templates) and stripped from the live vault's existing
files.

### 0.0.0_4

Two fixes surfaced by real trading-monorepo usage, both formalizing
patterns validated in an actual session rather than invented in the
abstract:

- **`subdomain` may now be a topical sub-category, not just a literal
  tool/technology**, for a domain where notes usually aren't about
  software tooling at all (e.g. `trading`, `finance`) — `backtesting`,
  `portfolio-theory`, `performance-metrics` are valid subdomain values
  there, the same way `python`/`docker` are for `software`. Validated
  first: ten trading/quant mechanics notes used exactly this shape with
  no invented near-duplicates and no `project` confusion, before this got
  written down as an intentional rule. Updated everywhere the old
  tool-only definition was duplicated: `CLAUDE_BLOCK.md`,
  `NOTE_TEMPLATE.md`, `bin/note`'s own usage comment, `README.md`, and
  the `/note`/`/reflect`/`/hydrate` Skill templates.
- **The "stay silent about internal mechanics, `Anvil:`-prefix every
  message" discipline now applies to the natural-language fallback path
  in `CLAUDE_BLOCK.md` itself, not just inside the Skill files.** A real
  session triggered anvil's write flow through a plain natural-language
  request (no explicit `/note`/`/reflect` invocation), and since that
  discipline only lived inside the Skills, it leaked an internal detail
  ("this doesn't need a hydrated.tsv entry since it wasn't a /hydrate
  run") that a user has no reason to see. `CLAUDE_BLOCK.md` now carries
  the same rule directly, so it applies regardless of which path
  triggered the write.

This is also the first real-world use of `anvil init`'s stale-block-
refresh feature (added last version) to actually update a live
`CLAUDE.md` — used here to roll this exact change out to this repo's own
`## Anvil` section.

### 0.0.0_3

Two new `anvil` commands, both optional — nothing else here depends on
them: `anvil install-additional-packages` installs
[emeraldian](https://github.com/iamrohithrnair/emeraldian) (a TUI that
reads an Obsidian-format vault — the same plain markdown anvil already
writes, no conversion — and shows notes plus a force-directed graph, in
the terminal), via Homebrew if available, else prints manual `cargo`/
`curl | sh` instructions. `anvil open-vault [path]` opens a vault in it,
defaulting to this vault's root. Picked emeraldian over two other real
candidates (`clin-rs`, `obsitui`) after verifying all three actually
exist — `clin-rs` is heavier/more opinionated than a plain viewer needs
(encryption, canvas editing), `obsitui` has too little traction (12
stars, manual npm build only) to depend on.

### 0.0.0_2

`bin/sessions` (and `/hydrate`, which reads it) no longer only sees the
exact literal directory you're standing in. Claude Code and Grok Build key
session storage by the exact cwd a session was launched from, so a session
started at a monorepo's root and one started from a package inside it
were previously invisible to each other. `bin/sessions` now scans the
current directory and every subdirectory beneath it (not upward — run it
from whichever root you want to sweep), and the listing groups sessions
under a heading per source directory, current directory first. Matching
can't rely on the encoded folder name alone — `/` and a literal `-` both
encode to `-`, so a sibling directory named `<repo>-old` is
indistinguishable by name from a real subdirectory `old` (this false
positive was caught and fixed during testing); Claude Code sessions are
now confirmed against their own recorded `"cwd"` field, exact, no
guessing. Grok Build sessions still rely on name matching alone pending
real data to verify a similar field against. Renamed `/fill` → `/fill-vault` for
naming symmetry with `upgrade-vault`. Also fixed a real, session-long gap:
`uninstall.sh` had never been updated as new files/Skills were added, so
it was leaving most of anvil behind on uninstall.

`anvil init` no longer treats mere presence of a `## Anvil` section as
"done" — it now refreshes that section in place (bounded to exactly that
region, everything else in the file untouched) if the content is stale,
comparing against the current `CLAUDE_BLOCK.md` rather than just checking
the heading exists. Caught a real, live example: this repo's own
`CLAUDE.md` still pointed at the vault's pre-move path
(`~/Development/tools/anvil` instead of `~/.anvil`) and had been silently
"passing" every prior `anvil init` run. Fixed a `set -e`/`pipefail` bug
during testing — the same class of bug fixed earlier in `bin/status`'s
orphan check — where a `grep` finding no match inside a pipeline killed
the whole script instead of being treated as a normal empty result.

### 0.0.0_1

First version this axis is tracked at all — previously conflated with the
schema version under one `VERSION` file, which made "is the vault's data
current" and "is anvil itself current" impossible to tell apart. Split
into `SCHEMA_VERSION` + `TOOLING_VERSION`, with the old `bin/upgrade`
renamed to `bin/upgrade-vault` (schema migrations only) and a new
`bin/upgrade` added for pulling fresh tooling from the local source repo
(its path recorded at install time in a machine-local state file, kept
outside the vault folder so it never syncs via Syncthing) without a full
interactive re-install. `anvil -h` reorganized into subsections
(Notes / Vault health / Vault schema / Tooling / Project setup / Other)
to make the distinction visible there too.

Represents everything built in anvil's tooling up to this point: vault
structure (semantic/procedural/strategic/episodic), `bin/note`/
`bin/recall`/`bin/status`/`bin/anvil`/`bin/audit`, the `/recall`/`/note`/
`/reflect`/`/anvil`/`/hydrate`/`/fill-vault` Claude Code Skills,
`bin/sessions`/`bin/session-read` for mining past session history, and
the local usage tracker (`bin/usage`).
