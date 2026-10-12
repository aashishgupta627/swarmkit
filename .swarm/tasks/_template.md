# Task: <task-name>

## Objective

One or two sentences describing what gets built.

## Requirements

- R1. <requirement>
- R2. <requirement>

Number them. Acceptance criteria reference these ids, so a stable id is what
lets a criterion be traced through plan, phase, commit and review without
re-reading prose.

## Constraints

- Must follow the existing project architecture.
- No unnecessary dependencies.
- Do not modify unrelated modules.
- <project-specific hard constraint, e.g. money must be BigDecimal end to end>

## Out of scope

Name it here or it gets absorbed. This section is read by the architect when
deciding the scope boundary, and by the reviewer when checking the diff.

- <thing explicitly not in this task>
- <follow-up task that owns it, and the seam it starts from>

## Acceptance Criteria

Concrete and measurable. No placeholders — a placeholder criterion cannot be
reviewed and will either be skipped or invented.

Each criterion must be verifiable by a reviewer running a specific command, an
API call, or a named end-to-end step. Prefer:

- `<test command> -k <scenario>` passes, asserting <behaviour>
- `<METHOD> <path>` returns <status> and <shape>
- `<quality gate>` reports <state> for changed files only

Map each criterion to the requirement it discharges, and note which phase of
the plan should deliver it (the architect assigns the final phase, so leave a
placeholder here rather than guessing):

- AC1 → R1. <criterion>
- AC2 → R1. <criterion>

## Locks and constraints on the solution

Anything the solution must not do, phrased as a hard rule rather than a
preference. These are what the reviewer checks the design against, so state
them here even if the requirement section already hints at them.

- L1. <rule>
- L2. <rule>

## Open questions

Anything genuinely ambiguous, with the two readings if there are two. The
architect escalates rather than guessing; answering these here saves a round
trip.

- Q1. <question> — reading A: <...> / reading B: <...>
