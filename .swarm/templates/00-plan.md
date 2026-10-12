# Plan: <task-name>

<!--
  THE ONLY PLAN FILE ANYONE READS IN FULL. Hard cap: 300 lines.
  The control script's `validate` verb fails the run if you exceed it, because
  this file's size is multiplied by every orchestrator and every builder read.

  If something does not fit here, it belongs in a phase file (per-phase detail)
  or an ADR (a decision and its rejected alternatives). Depth is not the
  problem; depth in the wrong file is.
-->

## 1. Mode

FEATURE | GREENFIELD

## 2. Synopsis

<Two sentences. What gets built, and the shape of the change.>

## 3. Baseline

Measured, not assumed. Re-measure only if a manifest or lockfile changes.

| Item | Value |
|------|-------|
| HEAD | `<sha>` |
| Working tree | clean / <n> modified |
| Build command | `<cmd>` → `<result>` |
| Tests | `<run>/<fail>/<error>/<skip>` |
| Manifest | `<pom.xml | package.json | go.mod>` at `<sha/short-id>` |
| Lint / format | `<cmd>` → `<result>` or "none configured" |

Pre-existing debt that must **not** be fixed in this task:

- <item, with location>

If you could not run the build, write `UNVERIFIED — <reason>` and never
substitute an expected result.

## 4. Architecture

The decisions and their reasons. This stays in the index because every phase
depends on it.

### 4.1 Layout

<Modules/packages added or changed, and the boundary rules.>

### 4.2 Data model

<Collections/tables/entities, their fields, and the indexes or constraints
that matter. One line per field only where a field carries a rule.>

### 4.3 API contracts

<Endpoints, methods, request/response shape, status codes that are load-bearing,
and the authority model.>

### 4.4 Concurrency, transactions, and failure

<Where the async boundary is, what is transactional, what compensates, and what
happens on partial failure. This is where real defects live — be specific.>

## 5. Phase map

The plan's spine. The orchestrator copies this into `state.remaining[]`, so
every phase must appear, every file must be real, and every gate must be a
command someone can run.

| Phase | File | Depends on | Unblocks | Exit gate | ACs |
|-------|------|-----------|----------|-----------|-----|
| P0 | `00-baseline.md` | — | P1 | baseline recorded above; no source change yet | — |
| P1 | `<slug>.md` | P0 | P2 | `<command>` green | AC<n> |
| P2 | `<slug>.md` | P0 | P3 | `<command>` green | AC<n> |

Independent phases: note explicitly which ones can run in any order, so the
orchestrator can rebalance dispatches.

A phase is **code + its tests + a passing gate, in one commit**. A phase whose
gate depends on a later phase's tests is mis-ordered.

## 6. Acceptance criteria

The plan's criteria govern over placeholders in the task file.

| AC | Criterion | Verified by | Phase |
|----|-----------|-------------|-------|
| AC1 | <measurable outcome> | `<command or request>` | P1 |

Quality gates are diff-based ("no new violations in touched files") unless
this plan also fixes baseline debt, in which case say which debt and why.

## 7. Risks and assumptions

Assumptions, explicitly labelled as assumptions:

- A1. <assumption> — verified by <how> / NOT verified.

Risks:

- <risk> — likelihood, impact, mitigation.

## 8. Escalation triggers

A builder must **stop and ask** rather than absorb, if any of these occur:

1. <condition>
2. <condition>

Write these as recognisable conditions, not generalities. "The plan and the
code disagree about scope" is usable; "something is unclear" is not.

## 9. Follow-ups

Explicitly out of scope, with the seam each one starts from. Work not named
here tends to leak into the diff.

| Follow-up | Starts from | Owns |
|-----------|-------------|------|

## 10. Revision log

One line per round. Depth of reasoning belongs here and in `state.decisions[]`,
not in a longer plan.

| Round | Date | What changed | Why |
|-------|------|--------------|-----|
| 1 | <date> | initial plan | — |
| 2 | <date> | <change> | <user feedback / new fact found> |
