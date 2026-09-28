---
name: recall
description: "Search approved anvil notes before researching or re-deriving an answer. Use when a question may already be settled: a past decision, a known fix, a tool quirk, a how-to, or a project fact. Use when the user asks what we know, decided, or learned before."
argument-hint: "[--full] <topic or keyword>"
allowed-tools: Bash(anvil *)
---
`$A` means `anvil`. Recall is a literal,
case-insensitive substring match, not semantic search. Search on the single
most distinctive word or short phrase from the question (a tool name, an
error string, a decision), not the whole sentence.

Question: $ARGUMENTS

**`--full` in the arguments:** the user wants the raw notes. Run
`$A recall --full "<keyword>"` and show the output as is, after one
`Anvil: found N note(s)` line. Stop there.

Otherwise:

1. Run `$A recall "<keyword>"`. It prints at most 4 approved notes, each as
   path, title, description, and date: about 40 tokens a hit.
2. If nothing matches and another keyword from the question looks promising,
   try it. Hits are ranked: title first, then description, tags, project,
   and body; whole-word matches rank above matches inside longer words,
   which are marked "partial match". If it says more notes match, search a
   more specific word.
   Stop after 3 searches.
3. Open the notes whose description bears on the question, with
   `$A show <name>`. Skip the rest.
4. Report what the notes say, never only that they exist. Lead with
   `Anvil: found N relevant note(s)`, or `Anvil: no approved notes match
   "<keyword>"` (a miss is useful information, not an error).
   - **The user typed `/anvil:recall`:** they want to know what the vault
     says. Present each relevant note's substance: its claim, the reasons,
     and what to do, under its title. Add related notes you know of.
   - **You ran recall yourself during other work:** give one line per note
     used: its title, what it says, and how it applies here. Then continue
     with the task, using the notes. The user can run
     `/anvil:recall --full <keyword>` to read them whole.

**Going deeper.** A note's `origin` may link to a writeup in one of the
user's repos (the deep layer: rare, deliberate, long-form lessons). When the
note alone is not enough, run `$A source <name>`: it prints that writeup
read-only, even from another repo. `$A source --list <name>` lists the other
writeups in that repo. Use it when it will change what you do, not by default.
