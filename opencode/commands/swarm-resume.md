---
description: Resume an interrupted swarm task from its state file, reconciling the working tree first.
agent: orchestrator
---

Resume the swarm task named by the arguments: `$ARGUMENTS`.

This command exists because resuming is where a previous run wasted most of
its tokens — re-reading a 46 KB state file, re-deriving progress from git log,
and re-discovering environment facts that were already known.

Do exactly this, in order, and nothing more:

1. **Acquire the write lock.**
   `powershell -NoProfile -File swarmkit/.swarm/scripts/swarm.ps1 lock -Task $ARGUMENTS`
   On exit 3 (`LOCKED` or `STALE_LOCK`) stop and report the holder. Do not read
   the plan, do not dispatch. Ask the user whether to take over.
   On exit 2 (`ERROR: no state for task`) there is nothing to resume — say so
   and stop; offer `/swarm-run` to start the task fresh.

2. **Orient with one command.**
   `powershell -NoProfile -File swarmkit/.swarm/scripts/swarm.ps1 status -Task $ARGUMENTS`
   This prints status, HEAD drift, done/remaining counts, the todo list and
   open blockers. That output is your entire starting context. **Do not read
   the task file, the plan, the phase files, `swarmkit/.swarm/logs/**`, or the git log
to work out where you are.** `remaining[]` is the progress record.

3. **Reconcile, if `drift=YES` or the tree is dirty.** Another writer may have
   moved HEAD. Run `git status --short` and `git log --oneline -5`. Match what
   you find against `done[]` and `remaining[]`:

   - a commit present on disk and matching a `remaining[]` unit → it is done;
     move it to `done[]` with its commit and observed test counts.
   - uncommitted work in the tree → it is the in-flight unit's work. If it is
     coherent, finish and commit it. If it is debris from an interrupted
     session, say so and ask before discarding anything.
     Never assume uncommitted work is bad, and never discard it silently.

4. **Report in three lines** what you found: status, the next unit to build,
   and anything that needs the user's decision. Then continue with the normal
   pipeline from your orchestrator instructions.

Budget note: if `status` already shows the task is `COMPLETED`, stop and report
that. If it shows no remaining units, go to QA_REVIEW. Otherwise take the first
entry in `remaining[]` and dispatch the builder for it with a pointer prompt
naming its `phase_file` and `gate` — not a re-brief of the whole task.
