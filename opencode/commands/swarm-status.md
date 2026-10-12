---
description: Print the status of a swarm task in a few lines - where it is, what is left, what is blocked. Use for a cheap orientation without reading plans or logs.
agent: orchestrator
---

Report the status of the swarm task named by the arguments: `$ARGUMENTS`.

This is a read-only query. It is the cheapest way to find out where a task
stands, and it is designed to answer in a few hundred tokens instead of the
thousands it takes to read a plan and a state history.

Do this:

1. Run `powershell -NoProfile -File swarmkit/.swarm/scripts/swarm.ps1 status -Task
$ARGUMENTS` (or `swarmkit/.swarm/scripts/swarm.sh status -Task $ARGUMENTS`). If the
   task has no state file, say so and list `swarmkit/.swarm/tasks/`.

2. **Do not read anything else.** Not the task file, not
   `swarmkit/.swarm/plans/<task>/00-plan.md`, not the phase files, not
   `swarmkit/.swarm/logs/**`, not the git log. If the status output does not answer the
   question, run `validate` for a budget check and say what is missing.

3. If the status shows drift between the recorded HEAD and the real HEAD, run
   `git status --short` and mention whether the tree is clean. Do not start
   reconciling or dispatching anything — this command reports, it does not act.

4. Report in this shape, and nothing more:

```
Task:        <task>  (<status>)
Stage:       <stage>
HEAD:        <head>  drift=<no|YES (old -> new)>
Progress:    <done>/<done+remaining> units done
Next:        <first remaining id> -> <phase file>
Blocked:     <n> open (<id>: <one line> each, or "none">)
Lock:        <holder, or "free">
Plan:        <path to 00-plan.md, or MISSING>
```

If the user asked a specific question the status output cannot answer, say what
you would need to read and ask permission before reading it.
