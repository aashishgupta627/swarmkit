# QA Review — shipment-invoice-automation

**Re-review (round 2).** Reviewed HEAD `d7b3dc8` (feature base `6d0d4f1`).
Round-1 review was at `561fcdf`; the fixer added `2c606d0` (F-001) and `3ff6947`
(F-002/phase logs), and the checkpoint `d7b3dc8`.

## 1. Review Summary

**Verdict: APPROVED WITH NOTES**

All round-1 actionable defects are resolved:

- **F-001 (409 review refresh, MEDIUM)** — **RESOLVED.** `errorRequiresReviewRefresh`
  is now wired into all six row-mutation error paths (`patchItem`, `confirmItem`,
  `excludeItem`, `reinstateItem`, `correctRate`, `confirmMatched`), each storing
  `readErrorCode(err) ?? err.message`; two regression tests were added
  (`errors.test.ts`). Re-ran the suite: **108/108** feature tests pass.
- **F-002 (P8 commit missing rebuilt `dist/`, MEDIUM)** — **RESOLVED.** The
  deviation is now recorded in the P8 phase log (`08-approve-download.md`), and
  HEAD `dist/` matches a fresh `npm run build:web` exactly.
- **F-003 (live-backend E2E, MEDIUM `env_or_dependency`)** — **still open as a
  recorded limitation, not a code defect** (per the round-2 instruction). The
  backend is actually reachable here (`/actuator/health` → 200, Mongo UP), but
  every `/api/v1` route returns **401** without a bearer JWT, and no test
  user/token/JWKS is available, so the authenticated journey (create → presign →
  PUT → process → poll → review → approve → download) cannot be driven over the
  real transport. It is carried as a MEDIUM `env_or_dependency` limitation so the
  verdict stays bounded; it requires **no fixer action**.

Everything I could execute is green: 108/108 feature tests, full-suite failures
identical to the pre-existing baseline, eslint exit 0, `tsc` at the exact P0
count (136, zero in feature files), production build exit 0 with a reproducible
committed bundle, and a real webpack dev-server boot serving the feature strings.
The diff is confined to the plan's §4.1 file set.

## 2. Requirements Coverage

| AC | Criterion | Verdict | Discharged by |
|----|-----------|---------|---------------|
| AC1 | `tsc --noEmit` ≤ P0 count; new files zero | PASS — 136 = baseline; 0 in `shipmentInvoice*` | P9 |
| AC2 | `eslint <touched files>` exits 0 | PASS — exit 0, 0 errors, 6 warnings | P9 |
| AC3 | `build:web` exit 0; screen in bundle | PASS — exit 0; strings present in dev bundle | P4,P6,P8,P9,P10 |
| AC4 | Unit/service/context tests pass | PASS — 108/108 | P1–P10 |
| AC5 | Full `jest` no worse than baseline | PASS — 3 pre-existing failing suites unchanged | P9 |
| AC6 | Diff confined to §4.1 + `dist/**` | PASS — diff matches §4.1 | P9 |
| AC7 | Sidebar + home card for all users; Run gated | PASS — `errors.test.ts`, `homeCard.test.ts`, `isRunReady` | P4,P9,P10 |
| AC8 | Network order create→presign→PUT→process ×2; stepper stops at AWAITING_REVIEW | PASS — `context.test.ts`, `progress.test.ts` | P4,P5 |
| AC9 | Three tabs `?view=unresolved`/`?view=all`/`/reconciliation`; header totals | PASS — `review.test.ts`, `rateSheet.test.ts` | P6,P7 |
| AC10 | One multi-field PATCH; blank reason blocked; confirm/±suggestion/exclude/reinstate refetch | PASS — `review.test.ts` | P6 |
| AC11 | Confirm benign `{reason}` + `confirmedCount` (0 = no-op); approve gating; done + download | PASS — `approve.test.ts` | P8 |
| AC12 | Rate repair by section-④ index; reparse confirmed; FAILED offers Retry generate | PASS — `rateSheet.test.ts`, `approve.test.ts` | P7,P8 |
| AC13 | Audit dialog lists events with actor/role/timestamp | PASS — `rateSheet.test.ts` | P7 |
| AC14 | Codes surface; 404 "not found"; **409 refreshes review**; no pending-spinning | PASS (was PARTIAL in R1) — all six row mutations now store the code and refetch on 409/`INVALID_STATE_TRANSITION`; regression-tested | P9 |
| AC15 | `handleApiError` throws `ApiError{message,status,data}` | PASS — `apiError.test.ts` | P1 |
| AC16 | `buildPresignBody` emits exactly the Q1 body | PASS — `logic.test.ts` | P2,P3 |
| AC17 | Rebuilt `dist/` committed in the same feature commit per building phase | PASS (with recorded P8 deviation) — fix commit `2c606d0` stages the rebuilt bundle; HEAD matches a fresh build | P4–P10 |
| AC7–AC14 (live) | E2E against the local backend | **BLOCKED — no authenticated session** (F-003 limitation); not passed, not failed | P11 |

## 3. Findings

### Confirmed defects

**F-003 — MEDIUM — `env_or_dependency` — Live E2E (AC7–AC14) not executable: no authenticated session** *(carried from round 1; recorded as an accepted environment limitation, not a code defect)*
- Location: environment / `swarmkit/.swarm/state/shipment-invoice-automation.json` (blocker B1).
- What: The local Spring backend **is** reachable in this environment — `curl -k https://localhost:9002/actuator/health` → **200** (`{"status":"UP", mongo UP, diskSpace UP}`) — but every `/api/v1/...` route answers **401** without a bearer JWT, and no OTP/SMS login, test user, token or JWKS fixture is available. The authenticated journey cannot be driven over the real transport. Recorded as blocker `B1`; the P11 exit gate explicitly allows "deviations recorded as blockers".
- Why it matters: AC7–AC14 over the real transport (network order, 15 s cadence, presign-body acceptance, approve/download) remain verified only by mocked unit/integration tests.
- Suggested fix (environmental, no code change): provision a local test user/token and run the P11 checklist, recording per-AC results. No fixer loop is expected for this item.

### Round-1 findings — resolution status

| Id | Round-1 title | Status | Evidence |
|----|---------------|--------|----------|
| F-001 | AC14 "409 refreshes review" not wired for row mutations; `errorRequiresReviewRefresh` dead code | **RESOLVED** | `2c606d0` adds the code-store + conditional refetch to all six catches; `errorRequiresReviewRefresh` now called at `ShipmentInvoiceContext.tsx:544,575,597,621,664,728`; 2 new `errors.test.ts` cases; suite 108/108 |
| F-002 | P8 commit `ac486f4` missing rebuilt `dist/` | **RESOLVED** | `08-approve-download.md` phase log records the deviation; new commit `2c606d0` stages the rebuilt bundle; HEAD `dist/` reproduces a fresh build exactly |
| F-003 | Live E2E not executable | **still open** (limitation) | Kept as MEDIUM `env_or_dependency`; backend reachable but 401 without a session |

### Suggestions (not routed)

- **S-001 (LOW)** — `src/services/shipmentInvoiceService.ts:123`: `getAudit` is typed `Promise<AuditEvent[]>` but the documented response is `{requestId, events:[...]}` (task §3.7); the context normalizes via `as unknown` (`ShipmentInvoiceContext.tsx:319-325`). Type the service as the envelope and normalize inside the service, mirroring `normaliseOutputDocument`. (Carried from round 1; unchanged by the fix.)
- **S-002 (LOW)** — `src/context/ShipmentInvoiceContext.tsx:795-808`: `retryGenerate` stores `readErrorCode(err)` but does not refresh on a 409 (unlike `approve`/`reparse`/the six row mutations). It runs from the `failed` step where no review grid is mounted, so impact is low; consider a refresh for consistency.
- **S-003 (LOW)** — `dist/`: each building commit adds its new bundle but leaves the superseded bundle tracked (e.g. `app.dbca767…` remains tracked after `2c606d0` repointed `index.html` to `app.830cd859…`). This matches the established P4–P10 pattern and is pre-existing churn, but the tree now carries ~20 stale bundles; a future cleanup could stage the deletions.

## 4. Tests Executed

```
> npx jest __tests__/shipmentInvoice
Test Suites: 10 passed, 10 total
Tests:       108 passed, 108 total
Time:        6.779 s

> npx jest
Test Suites: 3 failed, 10 passed, 13 total
Tests:       5 failed, 108 passed, 113 total
Failing suites (all pre-existing, untouched by the diff):
  __tests__/services/auth.test.ts   (mock data failure at src/services/auth.ts:77)
  __tests__/mocks/axios.js          ("must contain at least one test")
  __tests__/App.test.tsx            ("RNGestureHandlerModule could not be found")

Per-file (from `jest --json`):
  apiError 5 | logic 16 | service 16 | context 7 | progress 11
  review 9 | rateSheet 10 | approve 19 | errors 11 | homeCard 4

> npx eslint src/screens/shipmentInvoice src/services/shipmentInvoiceService.ts
    src/types/shipmentInvoiceTypes.ts src/utils/shipmentInvoiceLogic.ts
    src/context/ShipmentInvoiceContext.tsx src/navigator/AppNavigator.web.tsx
    src/components/DocumentUploader.web.tsx
✖ 6 problems (0 errors, 6 warnings)   EXIT=0

> npx tsc --noEmit
136 errors total (all pre-existing; 0 in shipmentInvoice* files)   EXIT=2

> npm run build:web
webpack 5.103.0 compiled with 2 warnings (asset/entrypoint size) in 14411 ms  EXIT=0
bundle: dist/app.830cd859065e8dbffece.bundle.js

> E2E frontend smoke (§7): npm run start:web → HTTP 200 / + bundle 200; strings present; port torn down
> Backend probe (§7): https://localhost:9002/actuator/health → 200 UP; /api/v1/... → 401
```

## 5. Test Results

Builder's recorded counts (`state.json` `done[]`) vs. re-run:

| Phase | File | Claimed | Observed |
|-------|------|---------|----------|
| P1 | apiError.test.ts | 5 | 5 ✓ |
| P2 | logic.test.ts | 16 | 16 ✓ |
| P3 | service.test.ts | 16 | 16 ✓ |
| P4 | context.test.ts | 7 | 7 ✓ |
| P5 | progress.test.ts | 11 | 11 ✓ |
| P6 | review.test.ts | 9 | 9 ✓ |
| P7 | rateSheet.test.ts | 10 | 10 ✓ |
| P8 | approve.test.ts | 19 | 19 ✓ |
| P9 | errors.test.ts | 11 (updated from 9 in `d7b3dc8`) | 11 ✓ |
| P10 | homeCard.test.ts | 4 | 4 ✓ |
| P11 | total | 106 | 108 (106 + 2 fix regression tests) |

All per-file counts reproduce. The `state.json` total for P11 still reads **106**
(the pre-fix suite size); the FIX-1 event records **108/108** and the P9 entry was
updated to 11, with the discrepancy documented in the P9 phase log. The two extra
tests are the F-001 regressions; the 3 pre-existing failing suites and 5 failing
tests are identical to round 1 and to the P0/P1 baseline.

## 6. Phase Gates

| Phase | Gate (summary) | Claimed | Observed |
|-------|----------------|---------|----------|
| P0 | baseline recorded; empty src/__tests__ diff | done | baseline log present; commit `48c1ef3` |
| P1 | `jest --listTests` exit 0; apiError green | done | 5/5 ✓ |
| P2 | logic.test.ts green | done | 16/16 ✓ |
| P3 | service.test.ts green | done | 16/16 ✓ |
| P4 | context/start green; build 0; dist staged | done | 7/7; build 0; dist in `b4e7a2e` ✓ |
| P5 | transition/poll green (15 s) | done | 11/11 ✓ |
| P6 | grid/row-action green; build 0; dist staged | done | 9/9; dist in `5f5717f` ✓ |
| P7 | repair/reparse/audit green | done | 10/10 ✓ |
| P8 | approve/download green; **dist staged** | done | 19/19 ✓; dist **not** in `ac486f4` — deviation recorded in the P8 phase log (F-002, resolved) |
| P9 | errors/nav green; eslint 0; tsc ≤ P0; build 0; dist staged | done | errors 11/11 ✓; eslint 0; tsc 136; build 0; dist in `da52aee` ✓; AC14 now fully wired (F-001 resolved) |
| P10 | home-card green; build 0; dist staged | done | 4/4; dist in `9ab2883` ✓ |
| P11 | all ACs pass or deviations recorded as blockers | done | B1 recorded; live E2E still not executable (F-003 limitation) |

`git show --stat` confirms every phase commit carries its required test file;
`2c606d0` carries the fix tests **and** the rebuilt `dist/`.

## 7. Complete-Setup E2E Results

Project type: React Native Web frontend (webpack 5, jest 29) with an **external**
Spring/Mongo/S3 backend. Documented run command: `npm run start:web` (dev server
`127.0.0.1:8080`).

- **Boot / health (frontend)**: `npm run start:web` started as a subprocess and
  polled until ready; `http://127.0.0.1:8080/` → **HTTP 200** (557 bytes), webpack
  "compiled successfully".
- **Bundle**: the referenced dev bundle → **HTTP 200** (9 607 265 bytes). Strings
  present: `Shipment Invoice` ✓, `Invoice Automation` ✓, `confirm-matched` ✓,
  `retry-generate` ✓, `presigned-url` ✓, and the new fix symbols
  `INVALID_STATE_TRANSITION` ✓ and `errorRequiresReviewRefresh` ✓.
- **Full user journey over the real transport**: **NOT EXECUTABLE** — requires the
  backend (HTTPS :9002, bearer JWT). The backend is up and reachable
  (`/actuator/health` → 200, `{"status":"UP","components":{"mongo":{"status":"UP"},...}}`),
  but every `/api/v1/...` route answers **401** (`/api/v1/automations/shipment-invoice`
  → 401; `/api/v1/auth/token` → 401) and no test user/token/JWKS is available.
  Recorded as F-003 / blocker B1.
- **Error paths over real transport**: **NOT EXECUTABLE** for the same reason
  (no token). Error behaviour is covered by mocked integration tests
  (`errors.test.ts` 11, `approve.test.ts` 19, `apiError.test.ts` 5).
- **Frontend production build**: `npm run build:web` → **exit 0**, 2 size warnings.
- **Cleanup**: dev-server process killed; port 8080 confirmed closed
  (`PORT8080_LISTEN=False`); the three `dist` files that `output.clean` removed
  during my verification were restored, leaving `git status` at its pre-review
  state (31 entries, no new stray files).

## 8. Lint / Type-check / Build Results

- `npx eslint <P9 gate path>`: **exit 0**, 0 errors, 6 warnings (3 in
  `AppNavigator.web.tsx`, 3 in `ShipmentInvoiceReview.web.tsx`; inline-style /
  shadow style warnings).
- `npx tsc --noEmit`: **136 errors**, exactly the P0 baseline; **0** in
  `shipmentInvoice*` files. Touched shared files carry only pre-existing errors
  (`apiClient.ts` 11, `AppNavigator.web.tsx` 7).
- `npm run build:web`: **exit 0**, 2 warnings (asset/entrypoint size limits),
  14 411 ms. The fresh bundle hash `app.830cd859065e8dbffece` matches the
  committed `dist/index.html` and the bundle committed in `2c606d0`; a rebuild
  produces no `dist/` drift.

## 9. Scope Discipline

`git diff --name-only 6d0d4f1...HEAD` = the §4.1 set: 11 feature test files,
`jest.setup.js`, `__mocks__/{fileMock,styleMock}.js`, 6 new `src/` files, 5
modified shared files (`apiClient.ts`, `documentUploadService.ts`,
`DocumentUploader.web.tsx`, `HomeV1.web.tsx`, `AppNavigator.web.tsx`), `dist/**`,
and swarm plan/state/log artifacts. Off-limits files (`AppNavigator.tsx`,
`RoleBasedNavigator.tsx`, `types/navigation.ts`, non-`.web` screens,
`package.json`) are untouched (verified by name filter — no matches).

The round-2 delta (`561fcdf...HEAD`) is exactly: `errors.test.ts`,
`ShipmentInvoiceContext.tsx`, the rebuilt `dist/` bundle + `index.html`,
`state.json`, and the two phase logs — all in scope. No pre-existing debt was
silently "fixed" beyond the items the plan owns (jest harness, `handleApiError`).

## 10. Independent Re-verification

Re-ran independently, with real output captured:
- Feature jest suite — **108/108**; per-file counts match `state.json` (errors 11).
- Full jest — 3 pre-existing failing suites / 108 pass, unchanged from round 1.
- P9 eslint gate — exit 0; `tsc --noEmit` — 136, zero in feature files.
- `build:web` — exit 0; committed bundle reproducible.
- Web dev-server boot + bundle smoke — HTTP 200; new fix symbols present.
- Backend probe — `/actuator/health` 200 UP; API 401 (auth blocker, not a code failure).
- `git show --stat` for `2c606d0`, `3ff6947` and every phase commit — fix tests +
  rebuilt `dist/` staged; phase test files present.
- Source inspection — `errorRequiresReviewRefresh` called at all six row-mutation
  catches; deps arrays include `view`/`loadReviewPayload`.

## 11. Approval Status

**APPROVED WITH NOTES** — 0 BLOCKER, 0 HIGH, 1 MEDIUM, 0 LOW (the MEDIUM is the
F-003 environmental limitation, not a code defect). Round-1 F-001 and F-002 are
resolved and re-verified. No fixer loop is required for F-003; it closes only when
a provisioned local test session is available. Recommended next step: **complete**,
with the live-E2E limitation recorded.

---

```
EVIDENCE
unit: QA
status: DONE
commit: d7b3dc8
files: [swarmkit/.swarm/reviews/shipment-invoice-automation.md, swarmkit/.swarm/reviews/shipment-invoice-automation.findings.json]
checks:
  - {cmd: "npx jest __tests__/shipmentInvoice", result: "PASS 10 suites, 108/108, 6.779s", counts: "108/0/0/0"}
  - {cmd: "npx jest", result: "3 pre-existing failing suites unchanged (auth, mocks/axios, App)", counts: "108 pass / 5 fail / 13 suites"}
  - {cmd: "npx eslint <P9 gate path>", result: "EXIT 0, 0 errors, 6 warnings", counts: ""}
  - {cmd: "npx tsc --noEmit", result: "136 errors = P0 baseline; 0 in feature files", counts: ""}
  - {cmd: "npm run build:web", result: "EXIT 0, 2 size warnings, 14411ms, bundle app.830cd859", counts: ""}
  - {cmd: "e2e smoke: npm run start:web + HTTP GET / and bundle", result: "PASS HTTP 200, fix symbols in bundle, port torn down", counts: ""}
  - {cmd: "curl -k https://localhost:9002/actuator/health; .../api/v1/automations/shipment-invoice", result: "health 200 UP; api 401 (no auth session -> F-003 limitation)", counts: ""}
  - {cmd: "git show --stat 2c606d0 3ff6947 <phase commits>", result: "fix tests + rebuilt dist staged; all phase test files present", counts: ""}
  - {cmd: "swarm.ps1 validate-findings -Task shipment-invoice-automation", result: "OK findings=1 round=2 verdict=APPROVED WITH NOTES", counts: ""}
gate_met: true
unverified: ["live E2E AC7-AC14 not run: backend reachable (health 200) but no authenticated session (F-003 limitation, blocker B1)"]
next: APPROVED WITH NOTES - F-001 and F-002 resolved; F-003 is an accepted environment limitation. Complete.
```
