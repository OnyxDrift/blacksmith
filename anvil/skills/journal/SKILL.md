---
name: journal
description: "Record what this session explored (ideas, options weighed, where the user leaned, open threads) as a dated anvil journal entry, with approval before writing."
argument-hint: "[topic]"
disable-model-invocation: true
allowed-tools: Bash(anvil *)
---
`$A` means `anvil`. Every message starts with `Anvil:`.

A journal entry is the thinking trail: an early-phase session with no
repo or project yet, such as a business idea, a direction, or a project
under consideration. Facts and fixes go to `/anvil:note`; where an existing
project stands goes to `/anvil:handoff`. Unlike a handoff, an entry never
goes stale: it records where your thinking was at the time. It is
episodic, so recall never returns it. `/anvil:world` lists the last 10;
`/anvil:world journal [word]` lists or searches them all. When an idea
becomes a project, keep its topic name as the project name.

Topic, if given: $ARGUMENTS

1. Write the body from this session, in short plain sentences, under ~300
   words. Write it as the user's own account of their thinking ("Explored
   whether…", "Leaning toward… because…"), not as a status report. Use
   these sections, and leave out any that would be empty:

   ```
   ## Explored
   - <a question or idea looked at, one line each>

   ## Options weighed
   - <an option, and what spoke for or against it>

   ## Leaning
   <where the user landed or is leaning, and why>

   ## Open threads
   - <something left to think about, one line each>
   ```

   Leave out secrets, and hard facts a note should hold (offer
   `/anvil:note` for those instead).
2. Save it as a draft:

   ```
   $A note --type episodic --domain <domain> --project <topic> --tags journal \
     --title "<the question or idea, in a few words>" \
     --description "<one line: what was explored and where it landed>" \
     --source claude --body - <<'NOTE'
   <body>
   NOTE
   ```

   `<topic>` is the user's project, or a short topic name for a session
   with no project (for example `ideas`, `homelab`). `<domain>` is a line
   from `$A domain list`. Leave `--origin` off.
3. Read `${CLAUDE_PLUGIN_ROOT}/reference/drafting.md`, section "The review
   loop", and run it on this one draft. Free text such as "just save it"
   means Approve.
