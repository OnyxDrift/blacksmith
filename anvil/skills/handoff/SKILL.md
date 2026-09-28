---
name: handoff
description: "Record where this session leaves off (done, decisions, left, next step, open questions) as a dated anvil handoff. No approval menu: typing the command is the approval."
argument-hint: "[what the next session will focus on]"
disable-model-invocation: true
allowed-tools: Bash(anvil *)
---
`$A` means `anvil`. Every message starts with `Anvil:`.

A handoff is point-in-time detail for picking a project back up: what
this session did, what was decided and why, and where the next one should
start. It is not an activity log; git and the CHANGELOG hold the full
record. It is an episodic note, so recall never returns it;
`/anvil:world` shows the latest one per project. The user typed this
command, so write it directly, with no menu. For a thinking session with
no project yet, `/anvil:journal` is the better fit.

Next session's focus, if given: $ARGUMENTS

1. Write the body from this session, in short plain sentences, under ~350
   words, in exactly these sections (`/anvil:world` reads them by name):

   ```
   ## Done
   - <what got done, one line each; group related commits into one line>

   ## Decisions
   - <a choice the user made, and why, one line each>

   ## Left
   - <what remains, one line each>

   ## Next
   <the single next concrete step>

   ## Open questions
   - <decisions the user still owes, one line each>
   ```

   Leave out secrets and detail already recorded in commits or files;
   point at those by path or commit instead. Decisions are the exception:
   git records what changed, not why, so name each choice and its reason.
   Leave a section empty rather than padding it.

2. Write it:

   ```
   $A note --type episodic --domain <domain> --project <project> --tags handoff \
     --title "Handoff: <project> — <short topic>" \
     --description "<one line: where things stand>" --source claude \
     --body - --approved <<'NOTE'
   <body>
   NOTE
   ```

   `<project>` is the user's project this session worked on (the repo or
   component name, for example `anvil` or `orion`). `<domain>` is a line
   from `$A domain list`, usually `software`. Leave `--origin` off: the
   current repo is linked automatically.

3. Report one line: `Anvil: handoff saved to episodic/<file>`.
