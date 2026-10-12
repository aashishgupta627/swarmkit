# ADR <NNN>: <topic>

<!--
  Depth lives here, not in 00-plan.md. An ADR records a decision, the
  alternatives that were rejected, and the consequences — the material that
  makes a plan grow past its line cap.

  File as .swarm/adr/<NNN>-<topic-slug>.md, numbered sequentially. One
  decision per ADR. Do not update an accepted ADR's decision; supersede it
  with a new one and cross-reference.
-->

- **Status:** proposed | accepted | superseded by ADR-<NNN>
- **Date:** <YYYY-MM-DD>
- **Task:** <task-name> (or "repo-wide")

## Context

The forces in play. What made this a decision rather than an obvious step:
the constraints that collided, the unknowns, the thing that was already tried
and did not work. Two or three paragraphs at most.

## Decision

What was decided, stated as a rule someone could check.

## Alternatives considered

| Option | Merits | Demerits | Why rejected |
|--------|--------|----------|--------------|
| A | | | |
| B | | | |

Include the option a reasonable engineer would reach for first. If it is not
listed, the ADR has not done its job.

## Consequences

- **Accepted cost:** what this makes harder.
- **Follow-on obligations:** what must now be true elsewhere.
- **Revisit if:** the condition that would invalidate this decision.

## Verification

How a reviewer can check the decision was actually honoured in the code — a
test, a scan, a constraint in a phase file. A decision nobody can verify is a
preference.
