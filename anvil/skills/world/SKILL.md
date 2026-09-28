---
name: world
description: "Show where your work stands and where your thinking is going: the latest handoff per project, the recent journal entries, a project's handoffs, or a journal search."
argument-hint: "[project | journal [word] [page N]]"
disable-model-invocation: true
allowed-tools: Bash(anvil *)
---
`$A` means `anvil`. Arguments: $ARGUMENTS

- No argument: run `$A world`.
- `journal`, optionally with a word and `page N`: run
  `$A world journal [<word>] [--page N]`. For example `journal business
  page 2` runs `$A world journal business --page 2`.
- Anything else is a project name, with or without a leading `--full`: run
  `$A world --full <project>`.

Show the output as is. Start with `Anvil:`. After the output, add at most
one line: the most useful next step you see (for example "the orion
handoff lists 3 open questions"). Do not restate the output.
