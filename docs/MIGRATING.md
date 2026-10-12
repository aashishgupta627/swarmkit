# Migrating a v1 swarm state to v2

A v1 state file (`.swarm/state/<task>.json` with no `schema_version`, or with
`schema_version: 1`) accumulated a paragraph per event and grew without bound.
The reference case ended at **46 KB / 32 entries / 28,430 characters of history
detail**, was re-read in full by every session, and had drifted out of order
twice. It is not resumable under v2 and will be rejected.

Migration is mechanical. It does not need the plan, and it should not need a
model — it is a re-shaping, not a judgement call.

## What v1 content maps to

| v1 | v2 | Notes |
|----|----|-------|
| `status` | `status` | unchanged |
| `stage` | `stage` | truncate to 100 chars. Long prose belongs in a log file. |
| `baseline` (0.1-0.8) | `baseline` | keep the summary fields; full output goes to a log file, referenced by `baseline.ref` |
| `builder_run_*_findings` | `blockers[]` | one line per item, with `resolved_by` = the commit that resolved it |
| prose inside `history[].detail` | `events[].detail` + `logs/` | ≤180 chars in state; the overflow becomes a log file |
| the set of phases already implemented | `done[]` | `{id, commit, tests}` — read from `git log`, not from prose |
| the set of phases outstanding | `remaining[]` | `{id, phase_file, gate}` from the plan's phase map |
| "user chose option 1" entries | `decisions[]` | `{at, decision, reason}` |
| `ownership.sole_writer` (prose) | `lock` + `.swarm/locks/<task>.lock` | a mechanism, not a description |

## Steps

**1. Install the kit** into the repo, then convert the plan into a split plan.
The v1 plan was 1,384 lines. Build `00-plan.md` (≤300 lines) with the phase map
and move each phase's detail into `<phase-id>-<slug>.md`. Keep the v1 plan file
as `99-legacy-plan.md` in the same directory — do not delete it; the split plan
should be traceable to it.

**2. Preserve the history you actually need.** Do not read the v1 file into a
model to summarise it. Instead:

```
# Everything the v1 file knew, preserved verbatim, for the record
mv .swarm/state/<task>.json .swarm/logs/<task>/000-legacy-state-v1.json
```

That file is the archive. The new state file points at it rather than restating
it.

**3. Derive `done[]` from git, not from prose.** The commits are the ground
truth the prose was trying to describe:

```
git log --oneline --reverse <plan-commit>..HEAD
```

For each phase commit, record `{id, commit, tests}` where `tests` comes from
the commit message or the phase's evidence. If the counts are not recoverable,
leave `tests` empty rather than copying a number from the v1 prose that you
have not re-measured.

**4. Derive `remaining[]` from the split plan's phase map.** One entry per
outstanding phase.

**5. Migrate blockers.** Each v1 finding becomes one line:

```json
{ "id": "DEV-A-config-keys", "state": "RESOLVED", "resolved_by": "83804f2",
  "note": "collapsed to the plan's single extraction.base-url" }
```

Anything genuinely still open keeps `state: "OPEN"` with an `owner`.

**6. Write the v2 state and validate it.**

```
.swarm/scripts/swarm.ps1 init -Task <task> -Force    # scaffold
# ... fill in done[], remaining[], blockers[], events[], decisions[] ...
.swarm/scripts/swarm.ps1 validate -Task <task>
```

`validate` fails on oversize state, over-long event details, a `remaining[]`
entry pointing at a phase file that does not exist, an `00-plan.md` over 300
lines, or a `done[]` commit that is not in the repository. Fix what it reports
rather than raising the budget.

## Do not lose these

The v1 run recorded several things that are not recoverable from the diff, and
they are the reason the archive is kept verbatim:

- A concurrency incident in which two orchestrator sessions wrote one tree and
  one overwrote the state file, dropping five entries.
- Environment constraints that were re-discovered and re-briefed several times
  (a build tool absent from `PATH`, a nearly full system drive forcing a
  non-default directory for an embedded database).
- Two plan revisions driven by the user reversing a decision, and the exact
  readings that were escalated instead of guessed.
- A blocked acceptance criterion with the verbatim failure, which must never be
  restated as a pass.

Each becomes either a `blockers[]` line, a `decisions[]` line, or a log file.
None of them need to live in the state file itself.

## Then

```
.swarm/scripts/swarm.sh  status -Task <task>   # orient, cheap
/swarm-resume <task>                            # continue under the lock
```
