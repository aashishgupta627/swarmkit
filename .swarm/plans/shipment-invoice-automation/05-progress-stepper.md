# P5 - Step 2 live progress stepper (15 s poll)

**Depends on:** P4
**Unblocks:** P6
**Status:** planned

## Scope

- `src/context/ShipmentInvoiceContext.tsx` — add the poll loop and status
  transitions (the context owns the timer; the screen never polls).
- `src/screens/shipmentInvoice/ShipmentInvoiceScreen.web.tsx` — render the
  `progress` step from context values (spinner/ticks, `requestId`, company name).
- `__tests__/shipmentInvoice/progress.test.ts` — new.

## Design

Context poll:

- `GET /automations/{requestId}` every **`POLL_INTERVAL_MS` = 15 000 ms** (P2
  constant; 2 s caused needless calls) while `isProgressing(status)`.
- `createPollGuard()` (P2): tag each request; drop a response whose tag is not
  current (an out-of-order response must not clobber newer state).
- Clear the interval on unmount and on leaving the step. Pause polling while a
  review mutation is in flight (used in P6+).
- Transitions via `nextStep(status)`: `AWAITING_REVIEW → review`
  (`COMPLETED → done`, `FAILED → failed`) — P6 adds the review render; until then
  the shell holds the review payload and keeps the stepper with a "ready" tick.

Stepper: fixed order `DOCUMENT_UPLOAD → S3_EVENT → CLASSIFICATION_BYPASS →
FILES_READY → PDF_EXTRACTION → PACKING_LIST_PROCESSING → AWAITING_REVIEW`; a
spinner on the active stage and a tick on `index < current`, via `stageIndex`
(P2).

## Tests

`__tests__/shipmentInvoice/progress.test.ts` (fake timers, mocked service):

- Poll cadence: with `jest.useFakeTimers()`, advancing **15 000 ms** triggers
  exactly one additional `getAutomationStatus`; advancing 14 999 ms triggers
  none. (AC4)
- `POLL_INTERVAL_MS` is the only interval used (no 2 s interval fires). (AC4)
- `stageIndex`-based tick states: earlier stages ticked, current active, later
  idle. (AC4)
- Transition map: `AWAITING_REVIEW → review`, `COMPLETED → done`, `FAILED →
  failed`, mid-flight stays `progress`. (AC4, AC8)
- Poll guard: an older response resolving after a newer one is ignored. (AC4)
- Unmount clears the interval (no state update after unmount; clearing timers
  leaves no pending callback). (AC4)
- A `FAILED` status with a coded `error` string surfaces that code. (AC14)

## Exit gate

`npx jest __tests__/shipmentInvoice/progress.test.ts` exits `0`.

## Escalation triggers

1. The backend returns a `currentStage` outside the declared union in practice —
   stop; do not silently coerce unknown stages.
2. The poll loop cannot be tested with `jest.useFakeTimers()` under the preset —
   stop rather than adding a timer dependency.
3. `AWAITING_REVIEW` is reached while P6 is absent and the shell has no sensible
   interim rendering — stop and confirm sequencing.
