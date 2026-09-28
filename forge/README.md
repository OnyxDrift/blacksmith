<p align="center">
  <img src="docs/images/forge.jpg" alt="Forge" width="360">
</p>

<h1 align="center">Forge</h1>

Forge is a Claude Code plugin that carries working conventions into every
repo: how to record hard-won lessons, track work, summarise large files, and
set up credentials. It is part of [blacksmith](../README.md).

> **Version 0.0.3**, with anvil 0.0.4; 0.0.2 was the first public release. Every
> command was first checked by hand on 2026-09-24; `card` and `todo` also
> fired on their own in headless sessions. [CHANGELOG.md](CHANGELOG.md) has the history.

Forge replaces convention text that used to be copied into every repo's
`CLAUDE.md` (~3,300 tokens per session in ares). A skill loads only when it
is used, so its rules cost almost nothing until then.

## Commands

**Trigger** says who can start a command: **You** means the skill is
user-only (`disable-model-invocation`), so Claude cannot run it on its own;
**Claude** means Claude starts it when its description matches the moment.

| Command | Trigger | Does | Writes to |
|---|---|---|---|
| `/forge:writeup [bug\|design\|research] <topic>` | You | Records a bug root cause, a design decision, or research, as a long-form doc for future sessions. If anvil is installed, drafts a linked note into anvil's inbox. | `.blacksmith/forge/writeups/<component>/` |
| `/forge:todo [list\|add\|done\|drop]` | You or Claude. On its own, Claude may only `add` a blocker it finds, in a repo that already has `todo.md`, and says so. | Lists, adds, finishes, or abandons work items. `done` moves the item to `done.md` with date and commit SHA. | `.blacksmith/forge/todo.md`, `done.md` |
| `/forge:card` | Claude, automatically | Writes a short, checksummed summary of a large or tricky file, so a later session reads the card instead of the file. Checks the checksum before trusting a card. | `.blacksmith/forge/cards/<source path>.md` |
| `/forge:env <component> <KEY> [purpose]` | You | Sets up a credential the safe way: `.gitignore` first, then `.env.sample`, conditional loading, and README docs. | The component's folder |

## What a writeup is for

Writeups are the deep layer of blacksmith memory. They are rare, deliberate,
and written only when you ask. Three kinds, from real use:

| Kind | Example | Read again when |
|---|---|---|
| Bug root cause | A status bar went blank because GNU `timeout` was missing | The same symptom returns, or someone edits that code |
| Design reasoning | Why a data model cannot just "add more assets" | Someone wants to change that design |
| Research | A survey of similar tools, checked against source | The same question comes up again |

## Repo layout it creates

```
<repo>/.blacksmith/forge/
  todo.md          one per repo, a ## heading per component
  done.md
  done-archive.md
  writeups/<component>/<slug>.md
  cards/<source path>.md
```

The same layout is used in single-component repos and monorepos.

## Design choices

- **Writeups are user-invoked only.** Long documents should not appear
  without intent. Short anvil notes may be drafted automatically because
  they wait in an inbox.
- **Cards are automatic.** They are summaries, not claims, and save tokens.
  A checksum makes a stale card easy to detect.
- **One `todo.md` per repo.** The old rule produced a `.todo` per component
  in some repos and one at the root in others.
- **Links writeups to anvil.** `forge link` builds a writeup's web link
  from the shared `~/.blacksmith/config/hosts.tsv`. The linked anvil note
  waits in anvil's inbox; `/anvil:inbox` checks the link resolves (the
  writeup is pushed) before it can be approved.
- **Automatic only where it is cheap and safe.** Cards are summaries and
  todo blockers are one line; both are automatic. Writeups and credential
  setup are user-invoked. Claude adds todo items only in repos that already
  use `todo.md`.

## The `forge` CLI

Mechanical helpers the skills call; also usable in a terminal.

| Command | Does |
|---|---|
| `forge root` / `forge dir` | Repo root / its `.blacksmith/forge` folder |
| `forge hash <file>` | First 12 hex chars of the file's sha256 |
| `forge card-path <file>` | Where that file's card lives |
| `forge card-check <file>` | `fresh`, `stale`, or `missing` (exit 0, 1, 2) |
| `forge link <file>` | The file's web link on your Forgejo/Gitea host |
| `forge components` | Existing writeup component folders |

## Install

```
git clone https://github.com/OnyxDrift/blacksmith.git
cd blacksmith
./install.sh              # choose "forge only" or "both"
# or, for forge alone with no question:
forge/install.sh
```

The installer adds the `Bash(forge *)` permission rule, read-deny rules
for `.env` files (which `/forge:env` depends on), and one import line in
`~/.claude/CLAUDE.md`. The [blacksmith README](../README.md#install) lists
every change. `forge/uninstall.sh` removes the plugin, the allow rule, and
the import line; the `.env` deny rules stay, on purpose.

## Global pointer

Skills fire more reliably with a short pointer in the global
`~/.claude/CLAUDE.md`, so the installer imports
[CLAUDE-pointer.md](CLAUDE-pointer.md) there. In testing, the card skill
did not fire from its description alone; with the pointer, and wording
that says "write it yourself, without asking", it did.
