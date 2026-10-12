# P9 - Nav wiring, sidebar entry, error/permission surfacing, responsive

**Depends on:** P5, P6, P7, P8
**Unblocks:** P10
**Status:** planned

## Scope

- `src/navigator/AppNavigator.web.tsx` — add `'shipmentInvoice'` to the `Page`
  union, a lazy import, a `titleMap` entry, a sidebar item in a **new** sidebar
  group (not *Document Management*), shown to all users via
  `canAccessShipmentInvoice` (P2, returns `true`), a `handleBack` case →
  `home`, and wrap the rendered screen in `<ShipmentInvoiceProvider>`.
- `src/screens/shipmentInvoice/ShipmentInvoiceReview.web.tsx` + the shell —
  status/code-based error surfacing and small-screen tab overflow.
- `__tests__/shipmentInvoice/errors.test.ts` — new.
- `dist/**` — commit the rebuilt bundle (AC17).

The **home quick-action card is P10**, not here: this phase stops at the sidebar
entry so the two entry points land as separately verifiable commits.

`AppNavigator.tsx`, `RoleBasedNavigator.tsx`, `types/navigation.ts`, non-`.web`
screens, `apiClient.ts` (beyond P1) and `package.json` are **off-limits** (AC6).

## Design

- Nav item `{label:'Shipment Invoice', page:'shipmentInvoice'}` in a **new**
  sidebar group (e.g. "Invoice Automation"), not Document Management, always
  shown — `canAccessShipmentInvoice` (P2) returns `true`; the future
  `SHIPMENT_INVOICE` permission gates it later (FU6);
  `handleBack` → `home`; screen `onDone`/`onBack` → `home`. Mount the provider
  **locally around the screen** (mirrors `HomeProvider` mounted in `App.web.tsx`)
  — no global store. The home case in `renderPage()` is unchanged this phase
  (P10 adds the card and its `onShipmentInvoicePress` callback).
- Error surfacing now uses the P1 `ApiError` (`status` + `data`) instead of
  message sniffing: `errorMessageFor(error, context)` reads
  `status`/`readErrorCode`:
  - `404` → "not found" (ownership masking), never "forbidden".
  - `403` → "you don't have permission".
  - `400 REASON_REQUIRED` / `INVALID_BUSINESS_DATA` → field-level (client already
    validates reason first).
  - `409 INVALID_STATE_TRANSITION` → "state changed" **and** refresh the review.
  - `FAILED` run → show `AutomationStatusResponse.error` code.
- Responsive: tabs wrap/scroll on narrow widths; grid keeps its fixed-height
  scroll container; no nested VirtualizedList in the page `ScrollView`.

## Tests

- `__tests__/shipmentInvoice/errors.test.ts` for `errorMessageFor`: `ApiError`
  status 404 → "not found"; 403 → permission; `REASON_REQUIRED`/
  `INVALID_BUSINESS_DATA` → validation; `INVALID_STATE_TRANSITION` → refetch flag;
  unknown → generic. (AC14)
- Nav entry: the sidebar item is present for **all** users
  (`canAccessShipmentInvoice` returns `true`), and the item is still rendered
  through the helper so the future permission seam stays in one place. (AC7)
  (The home-card entry is tested in P10.)

## Exit gate

1. `npx eslint src/screens/shipmentInvoice src/services/shipmentInvoiceService.ts
   src/types/shipmentInvoiceTypes.ts src/utils/shipmentInvoiceLogic.ts
   src/context/ShipmentInvoiceContext.tsx src/navigator/AppNavigator.web.tsx
   src/components/DocumentUploader.web.tsx`
   exits `0`. (AC2)
2. `npx tsc --noEmit` no more errors than the P0 baseline; new
   `shipmentInvoice*`/`ShipmentInvoiceContext` files report zero. (AC1)
3. `npm run build:web` exits `0`. (AC3)
4. `npx jest` no worse than the P0/P1 baseline. (AC5)
5. `git diff --name-only <base>...HEAD` contains only the §4.1 files. (AC6)
6. Rebuilt `dist/` staged; no pre-existing `dist/` churn. (AC17)

## Escalation triggers

1. The sidebar item cannot render without a permission check while
   `canAccessShipmentInvoice` returns `true`, or the new sidebar group cannot be
   added without restructuring the existing groups — stop; do not invent a
   permission (future `SHIPMENT_INVOICE`, FU6).
2. `tsc`/`eslint` exceed the baseline because of **new** files — fix within the
   touched set; if the excess is pre-existing, record it, do not widen the diff (AC6).
3. Distinguishing 404 from 403 needs a status the fixed `ApiError` does not carry —
   stop; do not re-widen `apiClient.ts`.
4. The diff would need `AppNavigator.tsx`, `RoleBasedNavigator.tsx`,
   `types/navigation.ts`, a non-`.web` screen, or a `package.json` dependency —
   stop (escalation #8 in §8).
5. Narrow-width tab overflow cannot be handled without nesting a virtualized
   list in the page `ScrollView` — stop; the fixed-height container is a stated
   constraint.

## Phase log

- **2026-10-10 — QA round 1 fix (F-001, MEDIUM).** This phase's `409 →
  surface the code + refresh the review` rule was only wired for `reparse` and
  `approve`; the six row mutations (`patchItem`, `confirmItem`, `excludeItem`,
  `reinstateItem`, `correctRate`, `confirmMatched`) stored `err.message` and
  never refetched, leaving `errorRequiresReviewRefresh` dead in `src/`. All six
  now store `readErrorCode(err) ?? err.message` (S-002) and refetch the active
  view when `errorRequiresReviewRefresh(err)` is true. Two regression tests were
  added to `errors.test.ts` (409 refresh + coded-400 no-refresh), so the file's
  count is **11 here, vs. the 9 recorded for P9** in `state.json`.
