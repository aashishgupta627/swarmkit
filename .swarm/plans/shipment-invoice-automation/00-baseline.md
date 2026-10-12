# P0 - Baseline

**Depends on:** —
**Unblocks:** P1
**Status:** planned

## Scope

No source or test files change in this phase. Its only output is a measured
baseline recorded in a log file and, if it differs from the architect's
planning-time table, an update to `00-plan.md` §3.

Files written (not application code):

- `swarmkit/.swarm/logs/shipment-invoice-automation/000-baseline.md` — the raw
  captured output and counts.

No files under `src/`, `__tests__/`, `package.json`, or config are to be edited.

The architect's planning-time table in `00-plan.md` §3 already records
HEAD `c50b572`, `main` ahead of `origin/main` by 3, and a **dirty working tree**
(tracked `dist/` churn, deleted root `.swarm/*`, untracked scratch files). P0
confirms or corrects it — it does not "clean" the tree.

## Design

Run the commands exactly as the builders will and record **raw** results. Do not
substitute an expected value for a result you did not observe. If a command
cannot run, record `NOT RUN — <reason>`.

| Command | What to capture |
|---------|-----------------|
| `git rev-parse HEAD` / `git status --porcelain` | sha, branch, ahead/behind, dirty-file count |
| `git ls-files dist` | confirm `dist/` is tracked (Q3 consequence) |
| `npx tsc --noEmit` | total error count (baseline for AC1) |
| `npx eslint .` | total error/warning count (baseline for AC2) |
| `npm test` | run / pass / fail / error / skip, **or** the config-resolution failure |
| `npm run build:web` | exit code; note `dist/` output churn |

`npm test` is expected to fail at config resolution (missing `jest.setup.js` /
`__mocks__`); record that verbatim — it is the P0 baseline. The **AC5 baseline is
the post-P1 count**, so P0 also captures the pre-P1 failure mode.

## Tests

No tests are added. This phase disables the test gate by design; it exists to
make later diff-based gates meaningful.

## Exit gate

1. `swarmkit/.swarm/logs/shipment-invoice-automation/000-baseline.md` exists and
   contains a row for each command above, each with an observed result or
   `NOT RUN — <reason>`.
2. `git diff --name-only -- src __tests__` produces **empty** output.

Run: `git diff --name-only -- src __tests__` → expected empty.

## Escalation triggers

1. `npm test` fails for a reason other than the missing `jest.setup.js` /
   `__mocks__` files — record it, and stop if it is not obviously the harness.
2. `npm run build:web` is already failing before any change — record the error
   and stop; the P4/P9 build gates cannot be expressed against a broken baseline.
3. The working tree differs from the `00-plan.md` §3 snapshot in a way that
   changes which files the feature may touch (e.g. `apiClient.ts` already
   modified) — stop and reconcile before P1.
