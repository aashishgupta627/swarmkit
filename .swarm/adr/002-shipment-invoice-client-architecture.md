# ADR 002: Shipment Invoice client architecture — explicit step machine + one service module

- **Status:** accepted
- **Date:** 2026-10-09
- **Task:** shipment-invoice-automation

## Context

The screen is a long-lived, multi-stage flow: create a request, upload two
files sequentially, poll a stage machine, render a mutable 117-row review, and
generate an output workbook. The backend owns all derived state
(`resolutionState`, `issueFlags`, `summary`, `currentStage`); the client must
never recompute those, only display the latest server truth and refetch after
every mutation. The repo has no global store and no server-state library, and
`AppNavigator.web.tsx` renders every page inside its own `ScrollView`.

The collisions that forced a decision: (a) which state model drives the four
steps, (b) where network access lives so a contract fix is one file, (c) how
polling and mutations avoid clobbering each other.

## Decision

1. **One consolidated screen view + a feature context.** A
   `ShipmentInvoiceContext` (`src/context/ShipmentInvoiceContext.tsx`) owns the
   step machine (`start | uploading | progress | review | done | failed`) and all
   orchestration; `ShipmentInvoiceScreen.web.tsx` (shell) and
   `ShipmentInvoiceReview.web.tsx` (header/tabs/grid/rate-sheet/dialogs) are
   **dumb** — props/context only, no URLs, no `agentApi`, no business rules. The
   provider is mounted locally around the screen in `AppNavigator.web.tsx`
   (mirrors `HomeProvider`), not globally. Step transitions are pure functions in
   `src/utils/shipmentInvoiceLogic.ts` and unit-tested. Entry points are additive:
   a sidebar item (P9, in a **new** sidebar group, not *Document Management*) and
   a home quick-action card (P10). Both are **visible to all users for now**: the
   single `canAccessShipmentInvoice` helper returns `true` (no permission check)
   and is retained as the one seam a dedicated `SHIPMENT_INVOICE` permission will
   gate both through later (FU6), so the rule is still not duplicated.
2. **One service module** (`src/services/shipmentInvoiceService.ts`) owns every
   `/api/v1` URL for this feature. Screens never import `agentApi`. Feature types
   live in `src/types/shipmentInvoiceTypes.ts`. The **S3 byte upload is reused**
   from `documentUploadService.uploadFileToS3`; the presign body is built by the
   pure, tested `buildPresignBody` (exact Q1 shape — no `financialYear`/`month`/
   `aiDocumentType`).
3. **Polling = `setInterval` every 15 s** (`POLL_INTERVAL_MS = 15000`; 2 s caused
   needless calls) with a monotonic sequence guard; stale responses are dropped,
   the interval is cleared on unmount/step change, and polling pauses while a
   review mutation is in flight. Every mutation awaits its response then refetches
   the active review payload.
4. **Reuse existing UI**: both `.xlsx` inputs reuse `DocumentUploader` (given an
   additive `accept` prop), confirmations reuse `useWebAlert()`, and the row-edit
   dialog reuses the `RenameModal` modal shell inline — no new picker/modal files.
5. **No global store, no router, no new dependency.** The screen receives its
   navigation callback from the `Page` union, exactly like sibling `.web.tsx`
   screens.

## Alternatives considered

| Option | Merits | Demerits | Why rejected |
|--------|--------|----------|--------------|
| A. Consolidated screen + feature context + service module (chosen) | Testable pure logic; one URL owner; dumb screen carries no logic; no new deps | Manual polling/refetch; one more file (context) | Matches repo conventions (mirrors `HomeContext`); smallest diff that isolates logic |
| B. react-query/SWR for the review + status GETs | Dedupe, cache, retry, stale-while-revalidate | New dependency; repo policy is no unnecessary deps | Deferred; revisit if FU2 grows polling complexity |
| C. Redux/Zustand for the run | Central, devtools, persists across steps | Adds a store and boilerplate for one screen | No second consumer of this state |
| D. URL-router-driven steps (`/shipment-invoice/review`) | Deep links, reload resumes | No router exists; would rewrite the nav shell (ADR-001) | Turns a screen feature into a migration |
| E. Screens call `agentApi` directly | Fewer files | URLs scattered; a contract fix touches many files | Fails the "one file to fix drift" goal |
| F. Keep all logic in the screen component (status quo before Gate 1) | One file | Screen mixed flow, network and rendering; hard to test | Rejected per Gate-1 feedback: the screen must know nothing |
| G. Build new xlsx picker/modal components | Full control | Duplicates the existing `DocumentUploader`/`RenameModal` seams | Rejected per Gate-1 feedback: reuse what exists |

## Consequences

- **Accepted cost:** a reload mid-run loses the flow (FU2); polling and refetch
  are hand-rolled and must be covered by tests (P5/P6). The context is one more
  layer between screens and services.
- **Follow-on obligations:** phase P3 is the only place URLs may appear; phase
  P2/P5 own the pure transition and poll-guard functions; the review view must
  stay dumb (grep-clean of `agentApi`/URLs). `apiClient.ts` **is** modified —
  `handleApiError` now throws `ApiError` (ADR-003) so backend error **codes** are
  available to `errorMessageFor` (P9), replacing the old message-mapping (FU3
  closed). Both entry points are open to all users pending **FU6** (a dedicated
  `SHIPMENT_INVOICE` permission); `canAccessShipmentInvoice` is the only place
  that changes when it lands.
- **Revisit if:** a second screen consumes this state, or the flow must survive a
  reload — then introduce server-state/persistence and supersede this ADR.

## Verification

- AC6: the diff adds no dependency to `package.json`; it touches `apiClient.ts`
  only for `handleApiError` (ADR-003) and no other shared file beyond §4.1.
- AC4: `logic.test.ts` covers transitions, gating and payload builders;
  `service.test.ts` asserts every path/method/body; `context.test.ts` /
  `progress.test.ts` cover the context, 15 s cadence and poll guard.
- Grep gate: `rg "agentApi" src/screens/shipmentInvoice` returns nothing.
- Grep gate: `rg "2000|setInterval" src/utils/shipmentInvoiceLogic.ts
  src/context/ShipmentInvoiceContext.tsx src/screens/shipmentInvoice` shows the
  only poll interval as `POLL_INTERVAL_MS = 15000` (no 2 s timer).
