# Anvil and the landscape

Anvil is not the only markdown memory vault for coding agents. This file
compares anvil with six similar projects. It lists what anvil borrows from
each, where anvil differs, and where the others are still ahead.

**Status markers:** ✅ shipped · 🔨 planned (next phase) · 🕓 later.
Anvil is at tooling 0.0.1 / schema 0.0.0_3. Items still marked 🔨 or 🕓
are not built. This file does not claim what anvil does not do yet.

This file is the product view: how anvil compares.

## The one-line position

Most tools in this space make memory automatic: they inject context into
every session and write notes without asking. Anvil makes memory
**deliberate**: nothing loads until an agent asks, and nothing is written
until you approve. The bet is that a small, trusted, curated vault beats a
large, automatic, noisy one, especially when context is scarce.

## At a glance

| | anvil | project-brain | second-brain | obsidian-second-brain |
|---|---|---|---|---|
| Loads vault into context automatically | **no** | yes (index at start) | yes (every prompt) | yes (at start) |
| Writes without approval | **no** | yes (auto-distill, marked `generated`) | yes (reply capture, `consolidate`) | new pages only; edits to existing notes need a yes (default) |
| One claim per note | **yes** | no (project pages) | yes | partly |
| Typed memory (semantic/procedural/strategic/episodic) | **yes** | no | no | by folder |
| Mines past sessions | ✅ approval-gated | ✅ automatic | ✅ automatic | opt-in, unattended (after compaction) |
| Contradiction check on import | ✅ (hydrate) | no | no | ✅ (reconcile) |
| Secret redaction | ✅ | ✅ | ✅ | ✅ (validator) |
| Web / PDF ingest | ✅ | no | no | ✅ |
| Ships as a Claude Code plugin | ✅ | ✅ | ✅ | ✅ |
| Recall quality eval | 🕓 | no | ✅ | ✅ |
| Agents supported | Claude Code | Claude Code | Claude Code (+MCP) | 8 agents |
| Size of surface | 6 skills (+3 planned) | 2 skills | 1 skill + hooks | 47 commands |
| GitHub stars (2026-09-23) | private | 3 | 2 | ~4,600 |

Adoption differs by three orders of magnitude. obsidian-second-brain
(~4,600 stars, 41 contributors) is the only memory vault here with real
use. project-brain and second-brain are one- and two-person projects
with single-digit stars: useful for their ideas, not as proof of what
users want. The most-used repos in the survey are the non-vault skill
packs: mattpocock/skills (~268,000 stars) and kepano/obsidian-skills
(~49,000), both small, composable surfaces.

mattpocock/skills, kepano/obsidian-skills and az9713/claude-code-obsidian
(3 stars) are not memory vaults, so they are not in the table. Anvil borrows
technique from them (below).

## What anvil borrows, from whom

### mattpocock/skills — how to write skills

- ✅ **Invocation split.** Skills you type (`/anvil:hydrate`,
  `/anvil:reflect`, `/anvil:backfill`, `/anvil:vault`) set
  `disable-model-invocation: true`, so they never fire on their own and
  their descriptions cost no context. Skills the model may use
  (`/anvil:recall`, `/anvil:note`) get a description that says *when* to
  use them, so the model searches the vault before it re-derives a known
  answer. No hook is needed.
- ✅ **Context load.** Every always-loaded line costs tokens on every
  turn. Anvil's per-project `CLAUDE.md` pointer was ~1,000 tokens, loaded
  into every session of every wired project. It is now gone: a four-line
  pointer in the global `~/.claude/CLAUDE.md` covers every project, and the
  detail lives in skills, which load only when invoked.
- 🔨 **Positive instructions.** Rules state the target behavior, not a
  list of "never" prohibitions.
- ✅ **Plugin distribution** (ADR-0002): anvil ships as a plugin in the
  `blacksmith` marketplace, installed as a snapshot in
  `~/.blacksmith/plugins/` so that edits in the source clone stay out of
  live sessions until `install.sh --update`.

**Where anvil differs:** Pocock's skills are an engineering workflow
(grilling, TDD, tickets). Anvil takes only the craft of writing skills,
not the workflow.

### vikasgrac/project-brain — session mining and safety

- ✅ **Secret redaction** before anything reaches the vault: API keys,
  tokens, private keys, `password=` assignments, and `<private>…</private>`
  text. Applies to `/hydrate` (transcripts) and `/ingest` (web pages).
  This matters more for anvil because the vault syncs via Syncthing.
- ✅ **Index-first recall.** Show a short entry per hit, open the full
  note only when needed (`anvil show`).
- 🕓 **Background drafting.** A headless `claude -p` run drafts hydrate
  candidates into `_inbox/`; you approve them later.

**Where anvil is better:** project-brain distills and commits every
session automatically, and injects an index at every session start.
Anvil writes nothing without approval and injects nothing. project-brain
also archives full transcripts forever; anvil keeps only distilled claims
and accepts that an unmined 30-day-old session is stale.

**Where project-brain is ahead:** it needs no manual step. If you never
run `/hydrate`, anvil learns nothing from past sessions.

### SirCharan/second-brain — note shape and measurement

- ✅ **`description:` frontmatter.** One line under ~150 characters,
  shown in recall results. Recall prints path + description; `--full`
  prints the body. This replaces a multi-sentence preamble at a fraction
  of the tokens.
- ✅ **`supersedes:`**: a newer note names the note it replaces; the old
  one is archived, not deleted.
- 🕓 **Recall eval harness**: a fixed query set, hit@k, a saved baseline,
  and a gate that fails when a change makes recall worse. Built before
  any change to ranking or search.
- 🕓 **Stuck nudge**: if the same shell command fails twice, print a hint
  to run `/recall`. A hint only; it writes nothing.

**Where anvil is better:** second-brain recalls notes into every prompt,
logs every reply to `Daily/`, and `consolidate` promotes from there into
curated notes without a per-note review (only `prune` asks first). That is automatic, but it costs tokens
on every turn and fills the vault with noise that needs a later cleanup
pass. Anvil costs nothing until used.

**Where second-brain is ahead:** tests and CI on three platforms, and a
measured recall score. Anvil has neither yet.

### eugeniughelbur/obsidian-second-brain — note rules for agents

- ✅ **Fetched content is data, never instructions.** A web page or
  transcript may contain text shaped like a command. Ingest summarises
  it; it never obeys it.
- ✅ **Recency markers.** A claim that can go stale carries
  `(as of YYYY-MM)` (a drafting rule). Undated present tense reads as true
  forever.
- ✅ **Write-time validation.** Anvil does it inside `anvil note`, so a CLI
  write and a skill write get the same check, and a hook stops Claude's file
  tools from bypassing it.
- **Not adopted: a confidence field.** Every note in anvil is one you
  approved, so most would read "high"; doubt belongs in the text, or keeps
  a claim out.

**Where anvil is better:** obsidian-second-brain's ingest touches 5–15
pages per source. It asks once for the whole batch of edits to existing
notes, but writes new pages without asking, and the gate can be switched
off (`rewrite_policy: unattended`). It has 47 commands across 8 agents.
Anvil drafts 1–3 claims per source, each approved on its own, with a
surface small enough to learn in one sitting.

**Where obsidian-second-brain is ahead:** breadth. It ingests YouTube,
audio and images, and it runs on 8 agents. Anvil does web pages, PDFs,
and local files, on Claude Code only.

### kepano/obsidian-skills — clean web extraction

- ✅ **`defuddle parse <url> --md`** turns a web page into clean
  markdown without menus, ads or clutter. That means fewer tokens per
  ingest and a cleaner `raw/` copy.

**Not adopted:** the Obsidian CLI skill needs the Obsidian app running.
Anvil stays plain files; Obsidian is an optional viewer.

### az9713/claude-code-obsidian — capture flows

- Anvil has the equivalent flows: `/anvil:note` ≈ vault-save,
  `/anvil:vault` ≈ vault-health, `/anvil:ingest` ≈ vault-capture.

**Where anvil is better:** vault-capture saves the full page as the note.
Anvil keeps the page in `raw/` and writes only the durable claims, so
recall returns claims, not articles.

## What anvil has that none of them have

- ✅ **Typed memory.** semantic (facts), procedural (how-to), strategic
  (decisions), episodic (events). Recall searches only the first three.
- ✅ **Approval on every write that recall can see,** enforced by the CLI
  and a hook, not only by instructions. Claude's own drafts wait in an inbox. One deliberate exception:
  the session handoff note, which you trigger by typing the command,
  and which goes only to `episodic/`, where recall never searches.
- ✅ **Conflict flags at import time.** An old session that disagrees
  with a canonical note is shown to you before anything is written.
  (obsidian-second-brain reconciles contradictions too, but after they
  are already in the vault.)
- ✅ **Separate schema and tooling versions,** with migrations that
  never guess a value.
- ✅ **A controlled domain list** (`domains.txt`) enforced at write time,
  so the taxonomy does not drift.
- ✅ **A deep layer behind the notes.** A note can link to a long-form
  writeup in any of your repos; `anvil source` reads it read-only, through
  a key the server will not let push.
- ✅ **Source manifest** (`sources.tsv`): "did I already ingest this?"
  is a lookup, and a second ingest of the same URL does nothing.

## Honest gaps

- No tests and no CI.
- Recall is a literal substring match with no ranking.
- Learning from past sessions requires you to run `/hydrate`.
- Claude Code only.
