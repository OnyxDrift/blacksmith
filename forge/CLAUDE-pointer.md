## Forge conventions

- **Work items** live in `.blacksmith/forge/todo.md` and `done.md` at the
  repo root. In a repo that has `todo.md`: check it at the start of a
  session, and when you find a blocker (a hardcoded user path, a dead
  reference, broken wiring, a structural defect), add it yourself with the
  `forge:todo` skill and say so. In a repo without one, offer instead. When
  an item looks fully done, say so and propose a commit message; do not ask
  a yes/no question.
- **Hard-won lessons** (a tricky root cause, a non-obvious design choice,
  research that took real effort) belong in a writeup. Suggest
  `/forge:writeup` to the user; only they can run it.
- **Context cards are yours to keep, automatically.** Before reading a large
  source file, use the `forge:card` skill to check for a fresh card and read
  that instead. After reading a qualifying file in full, write or refresh its
  card yourself, right away, without asking.
- **Secrets:** never read a `.env` file. To add a credential to a component,
  use `/forge:env`.
