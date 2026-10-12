# Locks

The single-writer lease. One file per task: `.swarm/locks/<task>.lock`.

## Why this exists

A previous run had two orchestrator sessions writing the same working tree at
once. Commits appeared under an agent that had not made them, source files were
rewritten mid-edit, and one session overwrote the state file and silently
dropped five history entries. Nothing caught it, because ownership was a prose
paragraph inside the state file — a description of a rule, not a mechanism.

A lock file with a live PID is a mechanism.

## Protocol

Acquire before any read or write:

```
powershell -NoProfile -File .swarm/scripts/swarm.ps1 lock   -Task <task>
powershell -NoProfile -File .swarm/scripts/swarm.ps1 unlock -Task <task>
```

Release on **every** exit path, including stopping to ask a question you cannot
resolve. A held lock with a dead process is indistinguishable from a held lock
with a live one until the PID is checked, so releasing matters.

## Exit codes

| Code | Output | Meaning | Action |
|------|--------|---------|--------|
| 0 | `OK lock` | lease acquired | continue |
| 3 | `LOCKED ... alive=true` | another session is live and writing | **stop**, report the holder, ask the user |
| 3 | `STALE_LOCK ... alive=false` | holder died without releasing | **stop**, ask the user; `-Force` only after they confirm |

Never break a stale lock on your own judgement. The holder being dead is
evidence about a process, not about whether another agent is running.

## File format

```json
{
  "task": "<task>",
  "holder": "orch-<pid>-<epoch>",
  "pid": 12345,
  "since": "2026-10-01T09:00:00Z",
  "repo": "/abs/path/to/repo"
}
```

The lease is mirrored into `state.lock` so a state file copied or restored from
another machine still shows who held it. `state.lock.holder` being non-empty
with no corresponding live process is itself a signal worth reporting.

## Limits

The lock is advisory to agents and binding on tools. It prevents two swarm
sessions colliding. It does not stop a human running a build or an editor
touching files, and it does not survive `git reset --hard` or a force-push.
Treat a lock as a strong signal to coordinate, not as isolation.
