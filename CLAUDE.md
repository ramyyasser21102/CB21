## Development workflow

Work is agentic: keep going through the phases until the app is done, stopping only at the hand-back points below.

### Phases and steps

- The plan is divided into **phases**. A phase has one or more **steps**. A step may also be standalone, with no phase.
- The plan lives in `docs/plan.md`. Mark each step todo, in progress, done or blocked as you go, and update it in the same branch as the work.
- Do steps in order. Don't start a step while an earlier one in its phase is blocked on the user.

### Branches and commits

- Every feature, fix, hotfix and doc change gets its own branch off an up-to-date `main`: `feat/<slug>`, `fix/<slug>`, `hotfix/<slug>`, `docs/<slug>`, `chore/<slug>`.
- One branch per step. The branch holds only commits for that change. Unrelated edits go on another branch.
- Commits are small, each one a coherent change, with imperative messages. No AI attribution (see the global instructions).
- Merge into `main` with `--no-ff` only after the testing rules below pass. Never commit straight to `main`.

### Testing and hand-back

- A feature isn't done until it's tested. Write automated tests first where it makes sense (see the `tdd` skill) and run them.
- Some things can't be verified by an agent: GUI behavior, menu bar and window appearance, global shortcuts, pasteboard permission prompts, launch at login, notarization and signing. Mark these as **non-testable**.
- If a non-testable item would block the step or hide a defect, **don't loop**. After at most two failed attempts at the same problem, stop, write down what was tried and what to check, and hand back to the user to act and think about the test.
- Don't mark a step done with an unverified non-testable item. Mark it done with a manual-test note for the user, and continue with steps that don't depend on it.
- Never hand-wave a failing test. Report failures with the output.

## Agent skills

### Issue tracker

Issues live in Linear (team `RY21`), accessed through the Linear MCP tools. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
