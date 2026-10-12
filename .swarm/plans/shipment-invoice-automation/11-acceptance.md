# P11 - Acceptance and end-to-end verification

**Depends on:** P10
**Unblocks:** —
**Status:** planned

## Scope

Verification milestone; no application code changes unless an AC reveals a defect
belonging to an already-landed phase (fix it in that phase's files and re-run that
phase's gate, not here). Output: `swarmkit/.swarm/logs/shipment-invoice-automation/011-acceptance.md`.

## Design

Run the acceptance checklist against the local backend
(`spring.profiles.active=local`, port `9002`, SSL, bearer JWT from the keychain).
If no backend is available, mark E2E-only ACs `BLOCKED — no local backend` rather
than passing them.

Manual E2E script:

1. Log in as a user with `DOCUMENT_UPLOAD`+`DOCUMENT_READ`.
2. Confirm **Shipment Invoice** appears in the sidebar (P9) **and** as a home
   quick-action card (P10); both open Step 1. (AC7)
3. Choose company + both `.xlsx`; the file dialog accepts `.xlsx`; Run enables
   only then. (AC7)
4. Run; capture network order in devtools: `POST /automations/shipment-invoice`
   → `presigned-url`(`Rate List`, **exact Q1 body**) → `PUT` → `documents/process`
   → same trio with `Packing List`. (AC8, AC16)
5. Watch the stepper advance and stop at `AWAITING_REVIEW`; confirm polling is
   **every 15 s** in the network panel, not 2 s. (AC4, AC8)
6. Review: three tabs; Needs Action `?view=unresolved`, All Rows `?view=all`,
   Rate Sheet four sections; header totals correct. (AC9)
7. Edit a row (two fields, one reason) → `effective*` updates; blank reason
   blocked client-side. Confirm / exclude / reinstate each refresh the grid. (AC10)
8. Confirm benign → `confirmedCount`; a second click answers `0` with a no-op
   message. (AC11)
9. Repair a defective rate row by its section-④ `index`; reparse behind a
   confirmation; confirm a `FAILED` run offers Retry generate. (AC12)
10. Approve → Step 4; Download opens the `s3PresignedUrl` workbook. (AC11)
11. Audit dialog lists parser and human events with actor/role/timestamp. (AC13)
12. Negative: a non-owner request renders "not found" (not 403); a mutation
    outside `AWAITING_REVIEW` refreshes rather than hanging. (AC14)
13. Confirm `dist/` in every feature commit matches the tree (no drift). (AC17)

## Tests

No new automated tests; this phase executes the checklist above and records a
result per AC. Automated coverage for AC1-AC6 and AC8-AC16 exists from P1-P10 and
is re-run here.

## Exit gate

1. `npx jest` and `npm run build:web` both green.
2. Every AC in `00-plan.md` §6 is marked pass, or a deviation is recorded as an
   OPEN blocker with its AC id and evidence.

## Escalation triggers

1. Reproducing a failure needs a backend fixture that does not exist — record as
   `BLOCKED`, do not synthesise a pass.
2. An AC is ambiguous (two readings) and the implementation chose one — stop and
   ask which reading is authoritative.
3. A failure traces to a file outside the task's contract (AC6) — stop.
