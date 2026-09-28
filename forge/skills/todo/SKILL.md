---
name: todo
description: "Track work items in the repo's .blacksmith/forge/todo.md and done.md: list, add, finish, or drop items. Use to add a blocker you just found (broken wiring, a dead reference, a hardcoded user path, a structural defect), or when the user asks what is next or says an item is done."
argument-hint: "[list | add <item> | done <item> | drop <item>]"
allowed-tools: Bash(forge *)
---
`$F` means `forge`. Files: `$($F dir)/todo.md`,
`done.md`, and `done-archive.md`, one set per repo, whether the repo has
one component or many. Every message starts with `Forge:`.

Request: $ARGUMENTS (no argument means `list`)

## Who may do what

- **The user** may do anything below.
- **You, on your own**, may only **add** a REQUIREMENTS blocker you found
  while working, and only in a repo that already has
  `.blacksmith/forge/todo.md` (in other repos, offer instead). Say so in
  your reply: `Forge: added a blocker to todo.md: …`. Everything else waits
  for the user.

## todo.md shape

```
# REQUIREMENTS
> Blockers: things that would break for another user or on a clean install.

## <component>/
- [ ] **<short title>** — <what is wrong, where, and what fixes it>

---

# FUTURE STATE
> Valid goals, not blockers. Only on the user's word.

## <component>/
- [ ] **<short title>** — <detail>

---

# ABANDONED
> Tried and failed, rejected, or knowingly deferred.

## <component>/
- **[tried|rejected|known issue / deferred]** YYYY-MM-DD | <what, why it was dropped, what was decided instead>
```

Create the file in this shape if it is missing. Never remove a `##`
component heading, even when it is empty; an empty heading says the
component exists and is fully addressed.

## list

Show the open REQUIREMENTS items for the component you are working in
(then the rest), and name the one to do next. Offer FUTURE STATE only if
asked.

## add

Find or create the `## <component>/` heading. REQUIREMENTS is only for
blockers: dead references to removed tools, hardcoded user paths (for
example `/Users/<name>/`), broken or missing wiring, structural defects in
config. Cosmetic cleanup and nice-to-haves are not blockers. If the item is
not a blocker, ask the user whether it belongs in FUTURE STATE; never put it
there on your own judgement.

## done

When an item looks fully implemented as written, say so and propose a
commit message (the user's commit format); do not ask a yes/no question.
If it is only partly done, say what remains instead.

Then move it: remove it from todo.md entirely, and add it at the **top** of
its `## <component>/` section in done.md:

```
- [x] YYYY-MM-DD | <short-sha> | <one-line description of what was done>
  - <optional short sub-bullets: per-file or per-piece highlights>
```

- The SHA is the commit that did the work. A commit cannot contain its own
  SHA, so add the done.md entry in the **next** commit, once that SHA is
  settled. Never amend a commit to insert its own SHA, and never make a
  commit only to update done.md.
- Keep three layers apart: done.md is the one-line summary, the commit
  message is the why, the code is the truth. Never copy the commit message.
- Use `unknown` for an unknown date. Never delete done.md entries.
- When done.md passes ~50 entries, move entries older than 6 months to
  done-archive.md, keeping the same headings.

During multi-step work on one item, track the steps with the task tools, so
the user can commit at a natural sub-boundary.

## drop

Move the item to ABANDONED under its component, marked `[tried]`,
`[rejected]`, or `[known issue / deferred]`, with the date, what was
attempted, why it was dropped, and what was decided instead. This stops
later sessions from exploring the same dead end.
