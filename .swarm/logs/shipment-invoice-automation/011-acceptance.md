# P11 — Acceptance and end-to-end verification

**Phase:** `11-acceptance.md`
**Depends on:** P10 (`9ab2883`)
**Date:** 2026-10-10
**HEAD at run:** `fe497d8` (P10 checkpoint)
**Status:** DONE — automated gates green; live-backend E2E recorded as an OPEN blocker (no authenticated session)

## 1. Environment

| Item | Value |
|------|-------|
| Local backend | Spring Boot `com.akubecontent.emailai.AIAgent` (`contentAIAgent`), HTTPS `https://localhost:9002`, PID 20272 |
| Backend health | `GET /actuator/health` → `200 {"status":"UP", mongo UP, diskSpace UP}` |
| Auth | `spring-security-oauth2-resource-server`; `GET /api/v1/automations/shipment-invoice` → `401` without a bearer JWT |
| Auth service | `https://cakube-authorization.duckdns.org:9443` (reachable, `401`); login is OTP-over-SMS |
| Web build | webpack 5.103.0, production, `dist/` |
| Test runner | jest 29.6.3, `react-native` preset |

### Authenticated-session blocker

The manual E2E script needs a logged-in browser session — a bearer JWT in the
keychain shim (`localStorage['cakube.web.credentials']`). None can be
established in this environment:

- Login is OTP-over-SMS (`/api/otp/generateAndSendOtp` → `/api/otp/verify`); no
  phone/OTP is available, and sending an OTP to a real number is out of scope.
- No test/dev token exists in the repo (searched; none), and the local backend
  exposes no JWKS or dev-token endpoint (all probes `401`).
- No browser-automation framework is installed (no playwright/puppeteer), so the
  UI steps cannot be driven even if a token were available.

Per the phase rule ("mark E2E-only ACs BLOCKED … rather than passing them"), the
live-backend execution of AC7-AC14 is recorded as an OPEN blocker (§5). The
automated coverage for those ACs (P1-P10) is re-run here and is green.

## 2. Exit gate

| # | Command | Result |
|---|---------|--------|
| 1 | `npx jest` | 10 passed / 3 failed suites; 106 passed / 5 failed tests — the 3 failing suites are pre-existing and unrelated (§4) |
| 1 | `npx jest __tests__/shipmentInvoice` | **10 passed / 10 suites, 106 passed / 106 tests** |
| 1 | `npm run build:web` | **exit 0**, webpack 5.103.0, 2 size warnings, 14 755 ms |
| 2 | AC table (§3) | every AC marked pass or recorded as an OPEN blocker |

Gate: **met** — the feature's jest suites and the build are green; every AC is
marked pass or recorded as an OPEN blocker. The full-suite failures are
pre-existing and the plan's AC5 is diff-based ("no worse than the baseline
recorded in P0/P1"; §7 risk: "Harness restore reveals pre-existing failures …
gates stay diff-based").

## 3. Acceptance criteria

| AC | Status | Evidence |
|----|--------|----------|
| AC1 | PASS | `npx tsc --noEmit` → **136 errors = P0 baseline (136)**; **0** in `shipmentInvoice*` files |
| AC2 | PASS | `npx eslint <touched files>` → **exit 0** (0 errors, 6 warnings) for every task file; the only error is pre-existing `counts` in `HomeV1.web.tsx` (§4.1) |
| AC3 | PASS | `npm run build:web` exit 0; lazy chunk `app.7b540d…bundle.js` contains "Shipment Invoice Automation", "Confirm benign", "Re-run parse", "Retry generate", "Download Tally Workbook"; main bundle contains `shipment-invoices` |
| AC4 | PASS | `npx jest __tests__/shipmentInvoice` → **106/106** (logic, service, context, progress, review, rateSheet, approve, errors, homeCard, apiError) |
| AC5 | PASS | Full `npx jest` no worse than P0/P1: feature suites green; 3 pre-existing failing suites unchanged (§4.2) |
| AC6 | PASS | `git diff --name-only 6d0d4f1..HEAD` confined to §4.1 files + `__tests__/shipmentInvoice/**` + P1 harness (`jest.setup.js`, `__mocks__/*`); no `AppNavigator.tsx`, `RoleBasedNavigator.tsx`, `types/navigation.ts`, non-`.web` screen, or `package.json`/lock change |
| AC7 | PASS (automated) / BLOCKED (live E2E) | `context.test.ts` (Run gating: entity + both `.xlsx`), `errors.test.ts` (sidebar item for a no-permission user), `homeCard.test.ts` (card visible + callback). Live browser check blocked — B1 |
| AC8 | PASS (automated) / BLOCKED (live E2E) | `context.test.ts` asserts create → presign(`Rate List`) → PUT → process → presign(`Packing List`) → PUT → process; `progress.test.ts` asserts 15 000 ms poll and the `AWAITING_REVIEW` stop. Live network capture blocked — B1 |
| AC9 | PASS (automated) / BLOCKED (live E2E) | `review.test.ts` (tabs → `?view=unresolved` / `?view=all`, header totals), `rateSheet.test.ts` (4 `/reconciliation` sections). Live render blocked — B1 |
| AC10 | PASS (automated) / BLOCKED (live E2E) | `review.test.ts` (one multi-field PATCH, blank reason blocked, confirm/exclude/reinstate refetch). Live click-through blocked — B1 |
| AC11 | PASS (automated) / BLOCKED (live E2E) | `approve.test.ts` (confirm benign `{reason}` + `confirmedCount` incl. `0` no-op; Approve gating; fresh + idempotent replay → done; download flat + envelope). Live blocked — B1 |
| AC12 | PASS (automated) / BLOCKED (live E2E) | `rateSheet.test.ts` (section-④ `index` repair, reparse confirm, 409), `approve.test.ts` (Retry generate on `FAILED` generation stages). Live blocked — B1 |
| AC13 | PASS (automated) / BLOCKED (live E2E) | `rateSheet.test.ts` maps the audit envelope to rows with actor/role/timestamp. Live dialog blocked — B1 |
| AC14 | PASS (automated) / BLOCKED (live E2E) | `errors.test.ts` (404 not-found, 403, `REASON_REQUIRED`, `INVALID_BUSINESS_DATA`, `INVALID_STATE_TRANSITION` + refresh flag), `progress.test.ts` (coded `FAILED` error), `review.test.ts` (409 refetch). Live blocked — B1 |
| AC15 | PASS | `apiError.test.ts` 5/5: `ApiError` preserves HTTP status + body; `data.code` / `data.errorCode` readable |
| AC16 | PASS | `logic.test.ts` `buildPresignBody` emits the exact Q1 body and excludes `financialYear` / `month` / `aiDocumentType` |
| AC17 | PASS (end state) / deviation | `dist/` committed in P4 (`b4e7a2e`), P6 (`5f5717f`), P9 (`da52aee`), P10 (`9ab2883`); P8 (`ac486f4`) omitted dist (its build output landed in P9). HEAD `dist/` matches the current source — a fresh `npm run build:web` reproduced the identical bundle hash `app.dbca767…` with no new churn |

## 4. Pre-existing debt / deviations (not introduced by this task)

1. **AC2 — `counts` unused in `HomeV1.web.tsx:65`** (`@typescript-eslint/no-unused-vars`).
   Present at the P9 checkpoint (`a706b1d`) and introduced by `e01b375`
   ("Last stage commit"); the counter row that consumed it is commented out.
   Part of the P0 baseline's 121 eslint errors. Not fixed here (pre-existing debt).
2. **AC5 — 3 pre-existing failing jest suites** (5 tests), all unrelated to
   shipment-invoice:
   - `__tests__/services/auth.test.ts` (5 tests) — tests an older `authService`
     shape (`/users`, `/send-otp`); last touched `5747ef8` (2026-06-09).
   - `__tests__/mocks/axios.js` — a mock file with no tests; last touched
     `3407a5c` (2026-05-22).
   - `__tests__/App.test.tsx` — `RNGestureHandlerModule` missing under jest;
     last touched `30caa76` (2025-06-24).
3. **AC17 — P8 omitted `dist/`.** `ac486f4` (P8) changed only source + tests; the
   rebuilt bundle was committed in P9. End-state `dist/` is consistent with source.

## 5. OPEN blockers

| id | AC(s) | Blocker | Evidence |
|----|-------|---------|----------|
| B1 | AC7-AC14 | Live-backend E2E cannot be executed: no authenticated session obtainable (OTP/SMS login, no test token, no JWKS/dev-token endpoint, no browser-automation framework). | `GET https://localhost:9002/api/v1/automations/shipment-invoice` → `401`; `/actuator/health` → `200` UP; auth API reachable but OTP-only; no playwright/puppeteer in `node_modules` |

## 6. Commands run

```
npx jest
npx jest __tests__/shipmentInvoice
npx jest __tests__/shipmentInvoice/homeCard.test.ts __tests__/shipmentInvoice/errors.test.ts
npm run build:web
npx tsc --noEmit
npx eslint <touched files>
git diff --name-only 6d0d4f1..HEAD
git show --stat <P4/P6/P8/P9/P10>
curl -sk https://localhost:9002/actuator/health
curl -sk https://localhost:9002/api/v1/automations/shipment-invoice
```
