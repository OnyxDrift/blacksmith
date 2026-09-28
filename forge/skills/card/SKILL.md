---
name: card
description: "Context cards for large source files: write and use them yourself, without asking. Use before reading a large source file (read a fresh card instead), and right after reading one in full that has real logic and cross-file coupling (write or refresh its card)."
allowed-tools: Bash(forge *)
---
`$F` means `forge`. Cards live in
`.blacksmith/forge/cards/<same path as the source>.md`, never next to the code.

## Before reading a large file

Run `$F card-check <file>`:

- `fresh` — read the card instead of the file, unless the task needs the
  implementation itself.
- `stale` — the file changed since the card was written. Ignore the card,
  read the file, then refresh the card (below). A stale card is worse than
  none, because it gets trusted.
- `missing` — read the file.

## When to write a card

Write it yourself, right away, without asking: it is a byproduct of work
already done. You just read a source file in full, and all three hold:

1. It has real logic (shell, Python, Lua, and so on, with control flow).
   Never markdown, READMEs, or declarative config.
2. Re-reading it cold would cost real time: roughly 150+ lines, or shorter
   but non-obvious (a race-condition fix, async state, multi-step dispatch).
3. It is coupled to other files: called by or calling into several.

Do not go looking for files to card.

## Card format

Shorter than the source, or it is not doing its job:

```
# <path>
source-sha256: <first 12 chars from `$F hash <file>`>

<one-line purpose>

## Interface
<CLI args, functions exposed, env vars read, files written>

## Gotchas
<non-obvious behavior; link a writeup in .blacksmith/forge/writeups/ instead of repeating it>

## Calls / called by
<what calls this file, what it calls>
```

Get the path with `$F card-path <file>`, create folders as needed, and
write the card with the Write tool. When you edit a file that has a card,
refresh the card (content and hash) in the same change. Mention a new or
refreshed card in one line: `Forge: card for <file> written`.
