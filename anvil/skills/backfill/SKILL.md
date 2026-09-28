---
name: backfill
description: "Propose values for empty or outdated anvil note fields (description, origin, project), with approval before writing."
argument-hint: "[description|origin|project]"
disable-model-invocation: true
allowed-tools: Bash(anvil *)
---
Schema migrations add new fields **empty**; they never guess. This skill is
the other half: it proposes real values, with reasons, and writes only what
the user approves. `$A` means `anvil`. Every message starts with `Anvil:`.

Field to fill: $ARGUMENTS (default `description`).

Backfill changes metadata only, and one command undoes a whole batch. So
the user approves a **batch** at a time, not a note at a time. Run every
`$A` command on its own: no `cd`, no `&&`, no pipe, no script.

## 1. Find the gaps

- `description`: `$A audit --field description`
- `origin`: `$A audit --field origin` (empty) and `$A audit --bad-origin`
  (values outside today's rules, such as local paths or ssh remotes)
- `project`: `$A audit --field project`

If nothing is listed, say so and stop.

## 2. Propose only what is defensible

Open each note with `$A show <name>`.

- **description**: one line under 150 characters, drawn from the note's own
  claim: what it claims and when it applies. Summarizing the note is
  defensible; adding facts the note does not state is not.
- **origin**: a defensible value is a Forgejo/Gitea link to the repo (or
  file) the note came from, when the old value names that repo
  unambiguously (a local clone path, an ssh remote, a repo-relative path
  whose repo is clear from `project`). For a note with nothing to link
  (a general fact, a book, a personal log), propose `none`: it records
  that decision, so the missing-origin warning stops. Group those in one
  batch.
- **project**: one of the user's own projects, taken from the note's origin
  (the repo, or the project folder inside it). Reuse a name other notes
  already use. A general fact with no project stays empty; list it at the
  end, with no question.

## 3. Make the batches

- `description`: batches of at most 8 notes, in audit order.
- `origin` and `project`: one batch per proposed value (all notes that
  get `…/<owner>/<repo>` together). Split a group above 12 notes.

Count the batches first, so each card can say "batch *i* of *n*".

## 4. Review each batch

1. Run the card, with the proposals as `<note name><TAB><value>` lines:

   ```
   $A note --batch <field> --card --of "<i> of <n>" <<'TSV'
   <name>	<value>
   TSV
   ```

   It checks every value first. On an error, fix that proposal and run it
   again; never show a batch that did not check clean.
2. Ask with `AskUserQuestion`, header `Anvil Review`. **The question text is
   the card, exactly as printed.** Do not print it again in your message.
   Four options, with no `preview`: **Approve all** (write this batch),
   **One at a time** (the same card for each note of this batch alone, with
   `--of "<k> of <m>"`, and Approve / Skip per note), **Skip batch**
   (write nothing), **Stop** (end here).
3. Free text is a list of changes, such as "skip 3; 5: <new value>". Apply
   it to the proposals and show the card again for the same batch.
4. On approval, write the batch with the same lines:

   ```
   $A note --batch <field> --approved <<'TSV'
   <name>	<value>
   TSV
   ```

   Report one `Anvil:` line: how many notes changed, and the undo command
   it printed.

## 5. Summary

One `Anvil:` line: checked, proposed, approved, skipped, and left empty for
lack of a real signal.
