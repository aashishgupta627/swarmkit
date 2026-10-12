# Plan: shipment-invoice-automation

## 1. Mode

**FEATURE** — an existing React Native 0.80 + react-native-web app (webpack 5 web
build, jest 29). The Spring Boot / MongoDB / S3 backend in the task file is an
**external service, not in this repo**. This task builds **one web page**.

## 2. Synopsis

A web-only Shipment Invoice automation page: pick an entity + two `.xlsx`
workbooks, run ingestion, watch a live 15 s stepper, review the draft in three
tabs with per-row/bulk adjudication, approve, and download the Tally workbook.
The **screen is dumb**; a new `ShipmentInvoiceContext` owns the flow and calls a
new `shipmentInvoiceService`. The existing `DocumentUploader` picker,
`useWebAlert` dialog and `RenameModal` modal pattern are reused. `handleApiError`
is fixed so backend error **codes** reach callers. Entry is a sidebar item (P9)
and a home quick-action card (P10).

## 3. Baseline

Architect's planning-time snapshot, **corrected by P0** on 2026-10-09. P0 re-ran
every command; the values below are the observed P0 baseline, raw output in
`swarmkit/.swarm/logs/shipment-invoice-automation/000-baseline.md`.

| Item | Value |
|------|-------|
| HEAD | `6d0d4f1330384d8644c4fb79c437b68288c7200d` (`6d0d4f1`), branch `main`, **ahead of `origin/main` by 6** |
| Working tree | **dirty**, 32 `git status --porcelain` entries — tracked deletions of root `.swarm/{adr,plans,state}` (3) and 11 `dist/**` files; `dist/index.html` modified; 11 untracked `dist/**` bundles/maps; untracked `invoices.db`, scratch images (`Login Screen.jpeg`, `Screenshot.jpeg`), `COMMUNICATION_NOTIFICATION_SERVICE_SPEC.md`, `swarmkit/.swarm/locks/*.lock` and the untracked `swarmkit/.swarm/logs/shipment-invoice-automation/` dir |
| Manifest | `package.json` @ HEAD (unchanged; last touched `e01b375`) — react-native 0.80.0, react-native-web ^0.21.2, react 19.1.0, typescript ^5.0.4, jest ^29.6.3, webpack ^5.102.1 |
| Build | `npm run build:web` → **exit 0**; webpack 5.103.0 compiled with 2 warnings (asset/entrypoint size) in 36 467 ms; `dist/` churn unchanged (cached bundle hash reused) |
| Tests | `npm test` (jest, `react-native` preset) → **exit 1**, config-resolution failure: `Module ./jest.setup.js in the setupFiles option was not found.` `jest.config.js` declares `setupFiles: ['./jest.setup.js']` and maps images/styles to `__mocks__/{fileMock,styleMock}.js` — all three verified absent, so the config cannot resolve before any test runs |
| Lint / format | `npx eslint .` → **exit 1**, **121 errors / 25 803 warnings** (25 924 problems; includes tracked minified `dist/**`; counts captured with `-f compact` because the default `stylish` formatter echoes full minified source lines) + prettier (singleQuote, trailingComma all) |
| Typecheck | `npx tsc --noEmit` → **exit 2**, **136 errors**, all under `src/` (whole-repo not clean: e.g. `SingleDocumentInput` passes `disabled` that `DocumentUploader` does not declare) |
| CI | none — no `.github/` or pipeline config |

Pre-existing debt, with the exceptions this task now **owns**:

- Broken jest harness (`jest.setup.js`, `__mocks__/{fileMock,styleMock}.js` missing) — **fixed in P1** (Q5).
- `handleApiError` collapses every response into a generic `Error` — **fixed in P1**, now in contract (Q3/ADR-003).
- `dist/` is tracked and inconsistent; per **Q3** the rebuilt `dist/` is committed with each building phase (P4/P6/P8/P9/P10).
- `mock-api` points at a non-existent server file; unrelated notification work (`e01b375`) is untouched.

## 4. Architecture

### 4.1 Layout and boundaries

New:

```
src/types/shipmentInvoiceTypes.ts                 response/request types, status & stage unions, tags
src/utils/shipmentInvoiceLogic.ts                 pure helpers (stepper, presign body, gating, poll guard, code reader, entry gate)
src/services/shipmentInvoiceService.ts            every shipment-invoice URL + document ingestion calls
src/context/ShipmentInvoiceContext.tsx            flow state machine, polling, all orchestration
src/screens/shipmentInvoice/ShipmentInvoiceScreen.web.tsx   dumb shell: start | uploading | progress | done
src/screens/shipmentInvoice/ShipmentInvoiceReview.web.tsx   dumb view: header, tabs, grid, rate sheet, dialogs
```

Reused / modified shared files:

```
src/services/apiClient.ts                  handleApiError -> throws ApiError{message,status,data}
src/services/documentUploadService.ts      + uploadFileToS3 (byte PUT helper) — reused, not re-implemented
src/components/DocumentUploader.web.tsx    + accept? prop (additive) so the picker can take .xlsx
src/screens/home/HomeV1.web.tsx            + Shipment Invoice quick-action card (Q4/FU1) [P10]
src/navigator/AppNavigator.web.tsx         + Page, lazy import, title, sidebar item, provider wrapper, back, home callback
dist/**                                    rebuilt bundle committed with each building phase (Q3)
```

Rules: the **context** is the only feature consumer of services; the **screen is
dumb** (props/context only, no URLs, no `agentApi`, no business rules);
`shipmentInvoiceService` is the only place shipment-invoice URLs appear. No
global store, no router, no new dependency. Dialogs reuse `useWebAlert()`
(confirmations) and the `RenameModal` Paper `Portal`+`Modal` pattern (reason
entry); **no new modal component files**. The two `.xlsx` pickers reuse
`DocumentUploader.web.tsx` (the existing `type="file"` component), which gains an
additive `accept?` prop; native `DocumentUploader.tsx` is untouched (web-only).
No new xlsx picker is built.

### 4.2 Data model

None server-side (backend external). Client types mirror §4.3. The only state is
the in-memory step machine `start | uploading | progress | review | done`
(plus `failed`) held in `ShipmentInvoiceContext`; the context also holds
`entityId`, both `FileType` selections, `requestId`, status/stage, the active
review payload + `view`, `reconciliation`, `audit`, `isBusy` and `error`.
`effective*` fields are what the workbook carries (corrections win); a non-empty
`issueFlags` keeps a row `UNRESOLVED`.

### 4.3 API contracts

Base `agentApi` (bearer JWT from the keychain shim); paths under `/api/v1`.
Authority: non-owner → `404` (existence masked); owner lacking
`DOCUMENT_UPLOAD`/`DOCUMENT_READ`/`DOCUMENT_UPDATE` → `403`; `400 REASON_REQUIRED`
/ `INVALID_BUSINESS_DATA`; `409 INVALID_STATE_TRANSITION`; `500` coded failure in
`AutomationStatusResponse.error` when `FAILED`. **Codes are now readable** via
`ApiError.data` (ADR-003).

| # | Call | Notes |
|---|------|-------|
| 1 | `POST /automations/shipment-invoice` `{entityId}` | → `201 {requestId,automationType,entityId,status}` |
| 2 | `POST /documents/presigned-url` | **exact body below**; → `{presignedUrl,fileUrl,objectKey,expiresIn}` |
| 3 | `PUT {presignedUrl}` | raw bytes, `Content-Type`; via reused `documentUploadService.uploadFileToS3` |
| 4 | `POST /documents/process` `{s3Key}` | `202`; `404` orphan key → step failure |
| 5 | `GET /automations/{requestId}` | `{status,currentStage,outputDocumentId,error,timestamps}` |
| 6 | `GET /shipment-invoices/{id}/review?view=unresolved\|all` | in-flight is `200` with empty `items`, never `409` |
| 7 | `GET …/reconciliation` | 4 join-audit sections |
| 8 | `GET …/audit` | append-only events |
| 9 | `PATCH …/items/{itemId}` | `{field,value,reason}` **or** `{updates:[{field,value}],reason}` |
| 10 | `POST …/items/{itemId}/confirm` `{reason,applySuggestion?}` | returns the row |
| 11 | `POST …/items/{itemId}/exclude` \| `/reinstate` `{reason}` | returns the row |
| 12 | `POST …/confirm-matched` `{reason}` | `{confirmedCount}`; `0` is a no-op, writes no audit |
| 13 | `POST …/rates/{index}/correct` | fields being repaired + `reason` |
| 14 | `POST …/reparse` | `202`; `409` when terminal (records `REPARSE_BLOCKED`) |
| 15 | `POST …/approve` | `{approved,idempotentReplay,outputDocumentId}`; refuses while `unresolvedCount>0` or zero rows |
| 16 | `POST …/retry-generate` | only from a `FAILED` generation stage |
| 17 | `GET /documents/{outputDocumentId}` | accept flat **or** `{success,document}` envelope (Q2) |

**Authoritative presign body (Q1)** — `documentTags` = the one file's tag
(`Rate List` | `Packing List`). No `financialYear`, no `month`, no
`aiDocumentType`:

```json
{
  "documentType": "SHIPMENT_INVOICE",
  "requestId": "SI-20261007-000002",
  "fileName": "LOTUS_FINAL_PL.xlsx",
  "contentType": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  "fileSize": 48213,
  "documentTags": ["Packing List"],
  "metadata": { "entityId": "ENT-002", "uploadedBy": "Aashish Gupta-ASDFG1234H-9660466293", "uploaderRole": "PARTNER" }
}
```

`uploadedBy` = `AuthUser.individualId`, `uploaderRole` = `AuthUser.role` (A2).
The existing `documentUploadService.getPresignedUrl` is **not** reused for this
body (it emits a different shape); `buildPresignBody` is a pure, tested helper
and `shipmentInvoiceService` POSTs it. Only the byte-upload step is reused.

`field ∈ {description,quantity,unit,rate}`; `value` always a **string**;
`reason` mandatory — validated client-side **and** the backend
`REASON_REQUIRED` code is now surfaced. Benign set = `{DUPLICATE_RATE,
HEADER_ANOMALY, NEW_ON_REPARSE, PACK_TRAY_MISMATCH}` ∩ `matchStatus==='MATCHED'`.

### 4.4 Context, concurrency, failure

Uploads are **sequential** (rate list, then packing list); the `requestId` is
created once and kept on any upload failure so Run retries from the failed
sub-step only. Progress polls `GET /automations/{requestId}` every **15 000 ms**
(`POLL_INTERVAL_MS = 15000`, named constant; 2 s caused needless calls) while
`status ∈ {CREATED,WAITING_FOR_FILES,FILES_READY,PROCESSING_IN_PROGRESS}`; a
monotonic `createPollGuard()` token drops stale responses and the interval is
cleared on unmount / step change. On `AWAITING_REVIEW` the context loads the
review payload; `COMPLETED → done`; `FAILED → inline coded error + retry-generate`.
Every review mutation awaits its response, then refetches the active payload
(server recomputes `resolutionState`/`issueFlags`/`summary`); polling pauses
while a mutation is in flight. Approve is idempotent server-side
(`idempotentReplay`); the client shows Step 4 on either a fresh or replayed
success. See ADR-002 for the context/step decision and ADR-003 for the error
contract.

## 5. Phase map

| Phase | File | Depends on | Unblocks | Exit gate | ACs |
|-------|------|-----------|----------|-----------|-----|
| P0 | `00-baseline.md` | — | P1 | baseline log filled with real build/test/lint numbers; `git diff --name-only -- src __tests__` empty | — |
| P1 | `01-test-harness.md` | P0 | P2,P3 | `npx jest --listTests` exits 0 **and** `npx jest __tests__/shipmentInvoice/apiError.test.ts` green | AC15 |
| P2 | `02-types-logic.md` | P1 | P4,P5,P6 | `npx jest __tests__/shipmentInvoice/logic.test.ts` green | AC4,AC16 |
| P3 | `03-service.md` | P1 | P4 | `npx jest __tests__/shipmentInvoice/service.test.ts` green | AC4,AC16 |
| P4 | `04-start-step.md` | P2,P3 | P5 | context/start jest green **and** `npm run build:web` exits 0 **and** rebuilt `dist/` staged | AC3,AC7,AC8,AC17 |
| P5 | `05-progress-stepper.md` | P4 | P6 | transition/poll jest green (15 s) | AC4,AC8 |
| P6 | `06-review-grid.md` | P5 | P7,P8 | grid/row-action jest green **and** build exits 0 **and** `dist/` staged | AC9,AC10,AC17 |
| P7 | `07-rate-sheet-audit.md` | P6 | P9 | repair/reparse/audit jest green | AC9,AC12,AC13 |
| P8 | `08-approve-download.md` | P6 | P9 | bulk-confirm/approve/download jest green **and** `dist/` staged | AC11,AC12,AC17 |
| P9 | `09-nav-errors-responsive.md` | P5,P6,P7,P8 | P10 | errors/nav jest green; eslint 0; `tsc --noEmit` ≤ P0; build green; `dist/` staged | AC1,AC2,AC3,AC5,AC6,AC7,AC14,AC17 |
| P10 | `10-home-card.md` | P9 | P11 | home-card jest green **and** build exits 0 **and** `dist/` staged | AC3,AC7,AC17 |
| P11 | `11-acceptance.md` | P10 | — | all §6 ACs pass against the local backend, or deviations recorded as blockers | AC7-AC14 |

P2 and P3 are independent (either order). P4→P5→P6→P7→P8 are sequential. P7 and
P8 both depend on P6 and both edit the same review/context files, so they may be
reordered but **not** run in parallel. P9 wires the route, sidebar and error
surfacing; **P10 is the dedicated home quick-action card phase**; both entry
points are additive and sequential.

## 6. Acceptance criteria

Requirements (ids stable; referenced by phases): R1 web-only; R2 start gating;
R3 ingestion order; R4 progress stepper; R5 three tabs + header; R6 per-row
edits; R7 bulk confirm; R8 rate repair + reparse; R9 approve/download/retry;
R10 audit; R11 coded error contract; R12 conventions + green gates; R13 context
layer (dumb screen); R14 reuse existing picker/modal/upload; R15 sidebar item +
home card.

| AC | Criterion | Req | Phase |
|----|-----------|-----|-------|
| AC1 | Whole-repo `tsc --noEmit` no worse than the P0 count; new files report zero | R12 | P9 |
| AC2 | `npx eslint <touched files>` exits 0 | R12 | P9 |
| AC3 | `npm run build:web` exits 0 and builds the new screen into the bundle | R1,R12 | P4,P6,P8,P9,P10 |
| AC4 | New unit/service/context tests pass (stepper, benign classifier, gating, presign body, service paths/bodies, 15 s poll guard, context transitions, entry gate) | R3-R9,R13 | P1-P10 |
| AC5 | Full `npx jest` no worse than the baseline recorded in P0/P1 | R12 | P9 |
| AC6 | Diff confined to §4.1 file set + `dist/**`; no `AppNavigator.tsx`, `RoleBasedNavigator.tsx`, `types/navigation.ts`, non-`.web` screen, or new `package.json` dependency | R1 | P9 |
| AC7 | Sidebar (P9) **and** home card (P10) show the entry for **all** users (`canAccessShipmentInvoice` returns `true`; dedicated `SHIPMENT_INVOICE` permission later, FU6); Run disabled until company + both `.xlsx` files are chosen | R1,R2,R15 | P4,P9,P10 |
| AC8 | Network order: create → presign(`Rate List`)→PUT→process → presign(`Packing List`)→PUT→process; stepper stops at `AWAITING_REVIEW` | R3,R4 | P4,P5 |
| AC9 | Three tabs use `?view=unresolved`, `?view=all`, `/reconciliation` (4 sections); header shows `itemCount`,`totalAmount`,`unresolvedCount` | R5 | P6,P7 |
| AC10 | One multi-field PATCH refreshes `effective*`/`issueFlags`; blank reason blocked client-side; confirm/±suggestion, exclude, reinstate each refetch | R6 | P6 |
| AC11 | Confirm benign sends `{reason}`, reports `confirmedCount` (`0` = no-op); Approve disabled at `unresolvedCount>0` or 0 rows; success → Step 4 with working Download | R7,R9 | P8 |
| AC12 | Rate repair posts the section-④ `index`; reparse is confirmed first; `FAILED` offers Retry generate | R8,R9 | P7,P8 |
| AC13 | Audit dialog lists events with actor/role/timestamp | R10 | P7 |
| AC14 | Backend **codes** surface (`REASON_REQUIRED`, `INVALID_BUSINESS_DATA`, `INVALID_STATE_TRANSITION`); 404 renders "not found"; 409 refreshes review; no request left pending-spinning | R11 | P9 |
| AC15 | `handleApiError` throws `ApiError` preserving HTTP `status` and the backend `data` body, so error codes reach callers | R11 | P1 |
| AC16 | `buildPresignBody` emits **exactly** the Q1 body: `documentType/requestId/fileName/contentType/fileSize/documentTags[]/metadata{entityId,uploadedBy,uploaderRole}`; no `financialYear`/`month`/`aiDocumentType` | R3 | P2,P3 |
| AC17 | Every phase that runs `npm run build:web` commits the rebuilt `dist/` in the same feature commit (Q3); no stale pre-existing `dist/` churn is staged | R12 | P4-P10 |

## 7. Risks and assumptions

Assumptions (labelled):

- A1. `agentApi`/`environment.agentApiBaseUrl` is the base for the `/api/v1`
  shipment-invoice routes — inferred from `documentService`/`documentUploadService`
  already posting `/api/v1/...` through `agentApi`; NOT verified live.
- A2. `metadata.uploadedBy = AuthUser.individualId` (JWT `sub`/`individualId`
  per `getUserFromToken`) and `uploaderRole = AuthUser.role`. The Q1 sample
  (`Aashish Gupta-ASDFG1234H-9660466293`, `PARTNER`) is consistent but unconfirmed.
- A3. Output document may return flat (`/documents/{id}`) or as
  `{success,document}` (Q2); the download helper accepts both.
- A4. After `reparse`, `GET /automations/{id}` returns a non-terminal status
  (`REPARSE_SCHEDULED` is not in the enum): treat "any non-terminal" as progress.
- A5. `approve` has no listed permission; gate on review state, surface `403`.
- A6. `useCompanies()` ids are the `entityId` values the automation expects.
- A7. The backend error code field is one of `data.code` / `data.errorCode`
  (tolerant reader); exact field unverified.
- A8. Adding an `accept?` override to `DocumentUploader.web.tsx` is additive; the
  native component and existing callers are untouched.
- A9. Sidebar item → a **new** sidebar group (not *Document Management*); home
  card → HomeV1.web's `actionCards`. Both visible to all now:
  `canAccessShipmentInvoice` returns `true`; dedicated `SHIPMENT_INVOICE` perm later (FU6).

Risks:

- **`handleApiError` is app-wide** — high/medium. Mitigation: `ApiError extends
  Error` keeps message/`instanceof`; message strings unchanged; `apiError.test.ts`
  + full-suite AC5 gate.
- **Contract drift** (backend external) — high/medium. §4.3 is transcribed from
  the task. A2/A7/A16 are the likeliest 400/rejection. Mitigation: one service
  module, defensive parsing, exact presign body test.
- **Reuse mismatch** — medium/low. `.web` picker `accept` is additive; if it
  disturbs existing callers, stop (A8).
- **Committed `dist/` churn** — high/medium. `output.clean:true` deletes old
  bundles; the tree already carries unrelated `dist/` churn. Stage **only** own
  build output (AC17).
- **117-row grid inside the page `ScrollView`** — medium. Fixed-height
  `overflowY:'auto'` container; never nest a VirtualizedList.
- **Home card regresses HomeV1** — low. Additive card + new callback only; if the
  existing `actionCards`/layout must change structurally, stop (P10 escalation).
- **Harness restore reveals pre-existing failures** — medium/low. Recorded in
  P0/P1; gates stay diff-based.

## 8. Escalation triggers

Stop and ask rather than absorb if:

1. The presign endpoint rejects the Q1 body or requires `financialYear`/`month`/
   `aiDocumentType` — the authoritative body is contradicted.
2. `uploadedBy`/`uploaderRole` cannot be derived from `AuthUser` (A2) — do not
   invent values.
3. The backend error code is not reachable at `data.code`/`data.errorCode`
   (A7) — provide the payload shape; do not guess.
4. Touching `documentUploadService`/`DocumentUploader.web` would change behaviour
   for existing (KYC/upload) callers beyond additive props/helpers.
5. `apiClient.ts` changes break other screens or existing test expectations
   (beyond the apiError test).
6. `npm run build:web` or `npx jest` cannot run (missing deps, config beyond
   P1's harness fix).
7. Rebuilt `dist/` cannot be isolated from the pre-existing `dist/` churn.
8. Work would need `AppNavigator.tsx`, `RoleBasedNavigator.tsx`,
   `types/navigation.ts`, a non-`.web` screen, or a `package.json` dependency.
9. The home card cannot be added to `actionCards` without restructing existing
   `HomeV1.web.tsx` layout/logic (P10).

## 9. Follow-ups

| Follow-up | Starts from | Owns |
|-----------|-------------|------|
| FU2 Resume an in-progress run after reload (`sessionStorage`) | `ShipmentInvoiceContext` init | UX |
| FU4 Mobile page for this flow | `AppNavigator.tsx` + `types/navigation.ts` | mobile |
| FU5 Generalize the reason modal if a third consumer appears | `RenameModal.tsx` | shared |
| FU6 Dedicated `SHIPMENT_INVOICE` permission gates both entries (sidebar + home card) | `canAccessShipmentInvoice` helper (P2, returns `true`) | auth |

(FU1 home card and FU3 error codes moved into scope: Q4 and P1/ADR-003.)

## 10. Revision log

| Round | Date | What changed | Why |
|-------|------|--------------|-----|
| 1 | 2026-10-09 | initial split plan | re-plan the 2026-10-08 single-file plan (`3c670f7`) into `00-plan` + phase files |
| 2 | 2026-10-09 | poll 15 s (was 2 s); introduce `ShipmentInvoiceContext` (dumb screen); consolidate 9 screen files to 2 views; reuse `DocumentUploader`/`useWebAlert`/`RenameModal`; `handleApiError`→`ApiError` in contract; exact Q1 presign body; home card + sidebar in scope; commit `dist/` per phase; baseline HEAD → `c50b572` | Gate 1 feedback items 1-6 + Q1-Q5 answers |
| 3 | 2026-10-09 | split the home card into dedicated P10 (P9 = nav/sidebar/errors); renumber acceptance P11; drop redundant `documentTypes.ts` edit; state `.web`-only `accept?`; add `canAccessShipmentInvoice` helper; correct baseline ahead-by | Gate 1 "home card phase" + verified reuse/minimal-diff |
| 4 | 2026-10-09 | entry open to all: `canAccessShipmentInvoice` returns `true` (no `canSend`/`canView`); sidebar item moves to a **new** sidebar group; add FU6 for the future `SHIPMENT_INVOICE` permission; update A9, AC7, P2/P9/P10 + ADR-002 | Gate 1 approval: "keep open for all now; modify later for an additional permission"; new sidebar group |
| 5 | 2026-10-09 | §3 corrected by P0 measurements: HEAD `6d0d4f1` (ahead 6); build exit 0; jest config-resolution failure; eslint 121 errors / 25 803 warnings; tsc 136 errors | P0 baseline recorded — real numbers replace the planning-time `NOT RUN` rows |
