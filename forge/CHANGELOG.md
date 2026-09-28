# Changelog

Human-readable history of forge. The skills and `bin/forge` are the
mechanism; this file is the why.

## 0.0.3

Claude Code runs a plugin from its own cache copy
(`~/.claude/plugins/cache/blacksmith/<plugin>/<version>`), which holds only
the plugin folder. The installer now copies the shared runtime files
(`find-python.sh`, `hosts.py`) into the plugin's `lib/`, and reinstalls
when the cached copy is from another commit. `claude plugin install` is
retried three times for the Windows EPERM rename bug (Claude Code issues
#81774, #54053), then names the fixes.

## 0.0.2

Forge installs alone. `forge/install.sh` copies the plugin into the
snapshot, merges `settings.fragment.json` (the `Bash(forge *)` rule and
`.env` read-deny rules), adds `@~/.blacksmith/plugins/forge/CLAUDE-pointer.md`
to `~/.claude/CLAUDE.md`, and installs `forge@blacksmith`.
`forge/uninstall.sh` removes the plugin, the allow rule, and the import;
the deny rules stay. The first public release, in the blacksmith repo.
`forge link` runs `lib/hosts.py` with the Python the installer found.

## 0.0.1

The first release, with anvil 0.0.1. The README names who triggers each command
(`todo` may also run on Claude's own initiative, to add a blocker).

## 0.0.0_3

Skills call `forge` by name, and `allowed-tools` is `Bash(forge *)`.
`settings.base.json` allows `Bash(forge *)`, so forge commands run without
a prompt.

## 0.0.0_2

Host config and the read-only key move with the rest of blacksmith into
`~/.blacksmith` (`config/hosts.tsv`, `keys/blacksmith_reader`); `forge link`
reads them there. forge keeps no other files outside a repo.

## 0.0.0_1

First version. Replaces convention text that every repo's `CLAUDE.md` used
to carry (~3,300 tokens per session in ares) with four skills that load
only when used:

- `/forge:writeup` (user-invoked): long-form writeups of a bug's root
  cause, a design decision, or research, in
  `.blacksmith/forge/writeups/<component>/`. Offers a linked anvil note,
  drafted into anvil's inbox.
- `/forge:todo` (model-invoked, limited): `.blacksmith/forge/todo.md` and
  `done.md`, one set per repo. Claude may only add blockers, only where
  `todo.md` exists.
- `/forge:card` (model-invoked, automatic): checksummed context cards in
  `.blacksmith/forge/cards/<path>.md`, out of the source tree.
- `/forge:env` (user-invoked): the `.env` / `.env.sample` procedure.

`bin/forge` does the arithmetic: card paths and checksums, and web links
through the shared `hosts.py`. The two model-invoked skills were verified
in real headless sessions, which also showed that a skill description alone
did not trigger the card skill; the global `CLAUDE.md` pointer plus "write
it yourself, without asking" wording did.
