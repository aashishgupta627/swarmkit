# P8 - Bulk confirm, approve, Step 4 done, download, retry-generate

**Depends on:** P6
**Unblocks:** P9
**Status:** planned

## Scope

- `src/screens/shipmentInvoice/ShipmentInvoiceReview.web.tsx` — header **Confirm
  benign** and **Approve** buttons.
- `src/screens/shipmentInvoice/ShipmentInvoiceScreen.web.tsx` — add the `done`
  step (approval complete + Download Tally Workbook).
- `src/context/ShipmentInvoiceContext.tsx` — `confirmMatched`, `approve`,
  `retryGenerate`, `download` actions.
- `__tests__/shipmentInvoice/approve.test.ts` — new.
- `dist/**` — commit the rebuilt bundle (AC17).

## Design

- **Confirm benign**: `POST …/confirm-matched` `{reason}`; show `confirmedCount`;
  `0` is a no-op message, **not** an error; then refetch the active view. The
  server selects the rows (client sends only the reason).
- **Approve**: disabled while `!canApprove(summary)` (P2) or a mutation is in
  flight. `POST …/approve`; both a fresh success and `idempotentReplay:true`
  advance to `done` with `outputDocumentId`. A `409`/blocking response refetches
  and shows the reason.
- **Step 4 `done`**: approval-complete message + **Download Tally Workbook**;
  resolves via `getOutputDocument(outputDocumentId)` (P3, A3/Q2 envelope-tolerant)
  then opens `s3PresignedUrl` once. Exposes `onDone` (used by P9).
- **Retry generate**: only from a `FAILED` generation stage; `POST
  …/retry-generate` (same shape as approve); no re-upload.

Deletion-download is a plain `window.open`/anchor on web; on the web build path
this is fine.

## Tests

`__tests__/shipmentInvoice/approve.test.ts` (mock the service):

- Confirm benign sends `{reason}` and reports `confirmedCount`. (AC11)
- `confirmedCount:0` → no-op message, no throw. (AC11)
- Approve disabled matrix: `unresolvedCount>0` and `itemCount===0` → disabled;
  clean → enabled. (AC11)
- Approve success (`idempotentReplay:false`) → `done` + `outputDocumentId`. (AC11)
- Approve `idempotentReplay:true` → also `done`, not an error. (AC11)
- Download resolves `s3PresignedUrl` from **both** envelopes (flat and
  `{success,document}`). (AC11)
- Download opens the presigned URL exactly once. (AC11)
- Retry-generate offered only from a `FAILED` generation failure; calls the
  endpoint and re-enters the flow without re-upload. (AC12)

## Exit gate

1. `npx jest __tests__/shipmentInvoice/approve.test.ts` exits `0`.
2. `npm run build:web` exits `0`.
3. Rebuilt `dist/` staged; no pre-existing `dist/` churn. (AC17)

## Escalation triggers

1. `approve` returns `409` on a clean review — stop; the disable rule and the
   server disagree, which changes AC11.
2. The output-document response carries no `s3PresignedUrl` in either envelope —
   stop (A3).
3. `retry-generate` needs state the context does not retain — stop and reconcile
   with P4/P5.

## Phase log

- **2026-10-10 — exit gate #3 / AC17 deviation recorded (QA round 1, F-002,
  MEDIUM).** The P8 feature commit `ac486f4` ("bulk confirm, approve, download
  and retry generate") contains `approve.test.ts` and the three `src/` files but
  **no rebuilt `dist/`**, so gate #3 ("Rebuilt `dist/` staged") and AC17 were not
  met *at that commit*. The P8 bundle was staged two phases later in P9
  (`da52aee`); the QA review confirmed the net `dist/` at HEAD matches a fresh
  `npm run build:web` exactly, so there is no user-visible or shipped-artifact
  impact. Recorded rather than rewritten (history stays intact). Going forward:
  any phase that runs `build:web` must stage the rebuilt bundle **in the same
  feature commit** as its source change.
