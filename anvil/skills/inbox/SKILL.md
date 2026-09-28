---
name: inbox
description: "Review draft anvil notes waiting in the inbox, up to 4 per question: approve, keep, edit, or reject each."
disable-model-invocation: true
allowed-tools: Bash(anvil *)
---
Drafts in the inbox came from Claude's own initiative, from a **Keep in
inbox** answer, or from forge's `/forge:writeup`. Recall does not see them
until they are approved here. `$A` means `anvil`.

1. Run `$A note --list-drafts`. If it prints nothing, say
   `Anvil: the inbox is empty.` and stop.
2. Read `${CLAUDE_PLUGIN_ROOT}/reference/drafting.md`, section
   "The review loop", and run that loop over the listed drafts, in rounds of up to 4.
