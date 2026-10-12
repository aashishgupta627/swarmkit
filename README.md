# SwarmKit

A multi-agent swarm setup for OpenCode, rebuilt around two constraints that a
real run violated:

1. **One writer per working tree.** Enforced by a lock, not by a paragraph in a
   state file.
2. **A token budget for the run itself.** Enforced by schema caps and a split
   plan, not by good intentions.

Drop it into any repository. No dependencies beyond the agents themselves.

## Why it looks like this

The design comes from measuring a run that took four days, produced 30 commits
and 96 files, and spent most of its budget re-reading things it already knew.

| Problem observed | Fix here | Mechanism |
|---|---|---|
| Two orchestrators on one tree; one overwrote the state file and dropped 5 entries | Single-writer lease with live-PID check | `swarm.ps1 lock` — exit 3 halts the session |
| 46 KB state file, rewritten whole at every transition | 4 KB hard cap, `detail` ≤180 chars, ≤30 events | `maxLength`/`maxItems` in `schema/state.schema.json`, checked by `validate` |
| 140 KB / 1,384-line plan read in full by every session and every builder | `00-plan.md` ≤300 lines + one file per phase | Builder is pointed at one phase file; `validate` enforces the cap |
| 3.5 KB findings block duplicating the history | One `blockers[]` line each, with `resolved_by` | Typed field, no free-form duplication |
| Phases committed code without tests; 3 phases sat with unmet gates for days | Phase = code + tests + passing gate, in one commit | Builder contract; reviewer treats a missing test as a BLOCKER |
| Baseline re-measured before nearly every phase (1m44s a time) | Measured once, in `00-plan.md`; re-run only if a manifest changes | `baseline.manifest` field |
| Orchestrator re-ran 20 greps to check each builder's narrative | Builder returns a fixed evidence block; orchestrator runs one `git show --stat` | `schema/evidence.schema.json` |
| Environment facts rediscovered and re-briefed on every dispatch | `env` and `blockers` recorded once in state | `env` object |
| 12 of 30 commits were bookkeeping | Commit message carries the detail; state does not repeat it | Documented in the orchestrator's checkpoint rules |
| A review file declared in artifacts that was never created | QA is a required stage with its own evidence block | Pipeline stage 4 |

## Layout

```
swarmkit/
  install.ps1 / install.sh      copy into a target repo
  schema/
    state.schema.json           the 4 KB state contract (caps are the point)
    evidence.schema.json        the fixed subagent report format
  opencode/
    agents/                     orchestrator, architect, builder, qa-reviewer, fixer
    commands/                   swarm-run, swarm-resume, swarm-status
  .swarm/
    scripts/swarm.ps1|.sh       init, lock, unlock, status, validate, compact, new-phase, log
    tasks/_template.md          task template
    templates/00-plan.md        the ≤300-line plan index template
    adr/_template.md            decision records
    logs/README.md              what belongs in logs, and what does not
    locks/README.md             the lease protocol
  docs/MIGRATING.md             converting a v1 state file to v2
```

## Install

```powershell
.\install.ps1 -Target C:\repos\my-project -RegisterTask my-task
```

```bash
./install.sh /path/to/my-project -t my-task
```

Existing files are reported, never silently overwritten; pass `-Force` to
replace them. See `docs/MIGRATING.md` if the repo already has a v1 state file.

**In this repo the kit was NOT installed with the scripts.** The runtime lives
at `swarmkit/.swarm/` and OpenCode loads the agents/commands from the root
`.opencode/` copy. `swarmkit/opencode/` is the source — after editing it,
re-copy `agents/` and `commands/` into `.opencode/` or the changes will not
load.

## Use

```
/swarm-run <task>       # full pipeline from scratch
/swarm-resume <task>    # continue: lock, orient, reconcile, carry on
/swarm-status <task>    # a dozen lines, no reads of plans or logs
```

Or drive the state directly:

```bash
S=.swarm/scripts/swarm.sh            # or swarm.ps1 on Windows
$S init     -Task my-task
$S lock     -Task my-task            # exit 3 = someone else is writing
$S status   -Task my-task
$S validate -Task my-task            # budget and integrity checks
$S compact  -Task my-task            # fold old events into a log file
$S unlock   -Task my-task
```

## The four rules that make it cheap

**The plan is split, and only the index is read whole.** `00-plan.md` is capped
at 300 lines and holds the architecture, the phase map, and the decisions. Each
phase's detail lives in its own file. A builder is given a path, not a document
— so the per-dispatch read is one small file instead of 35k tokens of plan.

**The state file is a status board, not a diary.** Typed fields for progress,
blockers, decisions and environment; one short line per transition; the
overflow goes to a log file that no agent reads to decide what to do. Progress
is reconstructed from `remaining[]`, never by re-reading `git log`.

**Subagents return evidence, not narrative.** One fixed block: unit, status,
commit, files, commands actually run, whether the gate passed, and what stayed
unverified. The orchestrator checks one thing — `git show --stat <commit>` —
instead of re-running the subagent's greps.

**A phase is code plus its tests plus a passing gate, in one commit.** This is
the single change that most prevents a run from stalling with several phases of
untested code. The builder contract requires it and the reviewer treats its
absence as a BLOCKER.

## Requirements

- Git. The pipeline commits a checkpoint per unit.
- PowerShell 5.1+ (Windows) or bash + `sed`/`grep` (macOS, Linux).
- Nothing else. The agents and the two scripts are the whole system.

## Limitations, stated plainly

- The lock is advisory to agents and binding on tools. It stops two swarm
  sessions colliding. It does not stop a human running a build, and it does not
  survive `git reset --hard`.
- `swarm.sh` implements `compact` less precisely than `swarm.ps1`; on non-Windows
  platforms prefer editing the state file by hand after folding.
- The QA and Fixer agents describe end-to-end validation generically. On the
  first run in a new stack, expect to tell the reviewer how the app boots.
- Token savings are structural, not measured. The caps make the reduction
  predictable — a 300-line index instead of a 1,384-line plan, a 4 KB state file
  instead of 46 KB — but the actual per-session figure depends on the task.
