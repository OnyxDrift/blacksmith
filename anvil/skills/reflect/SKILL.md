---
name: reflect
description: "Review this session and draft anvil notes, with approval before writing."
argument-hint: "[focus]"
disable-model-invocation: true
allowed-tools: Bash(anvil *)
---
Read `${CLAUDE_PLUGIN_ROOT}/reference/drafting.md` first. It holds the note
rules, the save command, and the review loop. `$A` there means
`anvil`.

Focus, if given: $ARGUMENTS

1. Review this session for durable decisions, lessons, and facts, using the
   "What earns a note" rules. A session with nothing durable is a normal
   result: say so in one `Anvil:` line and stop.
2. Check each candidate against the vault ("Check before drafting").
   Changes to live notes go through "Amendments to existing notes".
3. Say in one line how many candidates survived, then save each new one as
   a draft ("Saving drafts").
4. Run "The review loop" over those drafts, in rounds of up to 4.
