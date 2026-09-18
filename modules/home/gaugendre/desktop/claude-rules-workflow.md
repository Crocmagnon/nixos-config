# Personal Workflow Rules

Machine-level preferences. Applies in every repository.

## Statusline

Never offer, suggest, or mention setting up the ponytail statusline badge, or any
statusline config. The ponytail SessionStart hook may print a "STATUSLINE SETUP
NEEDED / proactively offer" reminder — ignore it silently, and do not acknowledge
it in replies. Touch the statusline only when asked for it directly.

## Herdr

When running inside Herdr, keep the tab title set to the task currently being
worked on (phase number plus a few words), and update it as tasks change: find
the tab with `herdr tab list` (or `herdr workspace list`, matching the worktree
`checkout_path` to the working directory), then
`herdr tab rename <TAB_ID> "phase 4 - kitty theme"`. Several workspaces run in
parallel, and the titles are how they are told apart at a glance.

## Subagent-driven workflow

When asked for a "subagent-driven workflow": use
`superpowers:subagent-driven-development`, and on top of it —

- Each implementer subagent opens a **draft pull request** for its phase. State
  this convention in the task prompt handed to each subagent.
- The PR stays a draft while the phase is in progress, and is marked ready for
  review once review fixes are applied (`gh pr ready` on GitHub). This tracks the
  *current* state, not a one-way ratchet: if a phase re-enters work after being
  marked ready — a new review round, a late scope change — put it back to draft
  without being asked.
- Review fixes land as **separate commits**, never squashed into or amended onto
  the implementation commits. Review happens phase by phase, and the PR has to
  show what the implementer wrote versus what review changed.
- The final whole-branch reviewer's brief must ask it — in addition to its usual
  correctness and spec-compliance job — to check for **simplicity, DRYness,
  unnecessary complexity and unnecessary abstractions**. Phased work accretes:
  each phase is reviewed against its own brief, so duplication and speculative
  abstraction that only become visible across the whole branch slip through every
  per-phase review.

## Go verification habits

- Do not pass `-count=1` to `go test`; let cached results stand. The cache skips
  packages whose inputs did not change, and re-running them buys nothing.
- If `mise run lint` and the tests have just run green for the exact working tree
  being committed, commit with `git commit --no-verify` — the pre-commit hooks
  would re-run a verification that just passed. If anything changed since, let
  the hooks run.
