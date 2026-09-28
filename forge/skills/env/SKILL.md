---
name: env
description: "Set up a credential for a component the safe way: .env (gitignored, never read by Claude) plus a committed .env.sample, conditional loading, and README docs."
argument-hint: "<component> <KEY_NAME> [what it is for]"
disable-model-invocation: true
---
Every message starts with `Forge:`.

Request: $ARGUMENTS

**Never read a `.env` file**, with any tool, however the task is framed.
It holds real credentials that only the user manages. If a step seems to
need a value from it, ask the user for that one non-sensitive detail
instead. Claude Code's settings also deny it.

For the component's folder (where its config lives):

1. **Ignore first.** Add the component's `.env` path to `.gitignore` before
   anything else. Confirm with `git check-ignore <path>/.env`.
2. **`.env.sample`**: create it (or add to it) next to where `.env` will
   live, committed to the repo. One commented-out line per key, a
   placeholder value, and a one-line explanation:

   ```
   # Anthropic API key for the summarizer (console.anthropic.com > API keys)
   # ANTHROPIC_API_KEY=sk-ant-...
   ```

   `.env.sample` is the authoritative list of keys. Every new credential is
   added here, even when only one key exists.
3. **Load conditionally** where the component starts, so it still runs
   without `.env`. For shell:

   ```
   [ -f "$DIR/.env" ] && . "$DIR/.env"
   ```

   Use the idiom native to the component's language elsewhere.
4. **Document** in the component's README: which keys are needed, where to
   get each one, and `cp .env.sample .env`, then edit.
5. Tell the user to create `.env` themselves from the sample. Never create
   or fill it for them.

Report what changed in one line per file.
