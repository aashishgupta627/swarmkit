---
description: Run the swarm pipeline on a task, pausing only at design approval and for critical findings.
agent: orchestrator
---

Run the swarm workflow on the task named by the arguments.

Task argument: `$ARGUMENTS` — a task name (e.g. `material-inventory`) resolving
to `swarmkit/.swarm/tasks/$ARGUMENTS.md`. Trim whitespace. If the argument is empty or
the file does not exist, list `swarmkit/.swarm/tasks/` and ask which to run.

Start here:

1. **Acquire the write lock** before anything else.
   `powershell -NoProfile -File swarmkit/.swarm/scripts/swarm.ps1 lock -Task $ARGUMENTS`
   (or `swarmkit/.swarm/scripts/swarm.sh lock -Task $ARGUMENTS`). On exit 3, stop and
   report the holder; do not dispatch anything. On exit 0, continue. On exit 2
   (`ERROR: no state for task`), run
   `powershell -NoProfile -File swarmkit/.swarm/scripts/swarm.ps1 init -Task $ARGUMENTS`
   and lock again.
2. **Orient** with `swarmkit/.swarm/scripts/swarm.ps1 status -Task $ARGUMENTS`. That is your whole
   starting context — do not read the plan or the logs yet.
3. If state already exists and `status` is not `COMPLETED`, you are resuming:
   reconcile the working tree against `remaining[]` and carry on from the first
   outstanding unit.

Then follow your orchestrator instructions:

1. PLANNING — `architect` writes `swarmkit/.swarm/plans/<task>/00-plan.md` (≤300 lines)
   plus one phase file per phase. Record the phase map into `remaining[]`.
2. AWAITING_APPROVAL — HITL Gate 1: approve the design and the acceptance
   criteria before any implementation. Max 2 revision rounds.
3. IMPLEMENTING — one `builder` dispatch per phase. Code + tests + passing gate
   per commit. Pointer prompts only; do not re-brief what is on disk.
4. QA_REVIEW — `qa-reviewer` writes `swarmkit/.swarm/reviews/<task>.md` and re-runs the
   gates itself.
5. FIX — `fixer` addresses findings; loop review/fix up to 3 cycles.
6. FINAL_VALIDATION / COMPLETED — confirm the final evidence, `validate`,
   `compact`, final commit, `unlock`.

Pause for the user only at Gate 1 and Gate 2 (a BLOCKER/HIGH finding, or a
builder escalating an architectural decision). Do not interrupt for LOW/MEDIUM
findings, notes, or routine fixer loops.

Per unit, keep it cheap: dispatch, apply the subagent's evidence block to
state, verify with one `git show --stat <commit>`, commit, next. Run
`swarm.ps1 validate` after writing state and `compact` when events accumulate —
state has a 4 KB budget and exceeding it is a bug, not a formatting nit.

Before stopping for any reason, run `unlock` so the next session can start.
