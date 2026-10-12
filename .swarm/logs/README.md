# Logs

Narrative detail that does not belong in `.swarm/state/<task>.json`.

The state file has a hard 4 KB budget, enforced by
`.swarm/scripts/swarm.ps1 validate`. When a transition needs more than one line
of 180 characters, the overflow goes here and the state event references it by
path. Agents **never read these files to decide what to do** — logs are the
record, not the input. Read `.swarm/state/<task>.json` and run the `status`
verb instead.

## Layout

```
.swarm/logs/<task>/
  001-P1.md                 # created by: swarm.ps1 log -Task <task> -PhaseId P1
  002-events-fold.md        # created by: swarm.ps1 compact
  00-baseline.md            # full build/test/dependency output
```

Numbering is positional and sequential. `log` and `compact` allocate the next
number, so filenames sort chronologically.

## What belongs here

- Full command output for a build, test run, dependency tree, or lint pass.
- A builder's long-form report when the evidence block cannot carry it.
- Folded event history, moved out of the state file by `compact`.
- Baseline detail: the complete numbers behind the summary in `00-plan.md`.

## What does not

Anything the state file's typed fields already express — status, done/remaining
lists, blockers, decisions. Duplicating a fact in both places means one of them
is wrong within a week.

## House style

- One subject per file, named by the phase or verb that produced it.
- Lead with what a reader needs to decide something.
- No secrets, no credentials, no connection strings. Quote command output, but
  redact values if a command can echo them.
