# P6 - Step 3 review: header, tabs, grid, row actions

**Depends on:** P5
**Unblocks:** P7, P8
**Status:** planned

## Scope

- `src/screens/shipmentInvoice/ShipmentInvoiceReview.web.tsx` — new. **One**
  consolidated dumb view: header strip + tab switch + grid + the row-edit dialog.
- `src/context/ShipmentInvoiceContext.tsx` — add review load + the mutation
  actions (`patchItem`, `confirmItem`, `excludeItem`, `reinstateItem`) and the
  refetch-after-mutation rule.
- `src/screens/shipmentInvoice/ShipmentInvoiceScreen.web.tsx` — render `review`.
- `__tests__/shipmentInvoice/review.test.ts` — new.
- `dist/**` — commit the rebuilt bundle (AC17).

(The previous plan split this across `StepReview`/`ReviewGrid`/`RowEditDialog`;
per Gate-1 feedback it is consolidated into one view file.)

## Design

`ShipmentInvoiceReview.web.tsx`:

- Header: `summary.itemCount`, `summary.totalAmount`, `summary.currency`,
  `summary.unresolvedCount`, `companyName`.
- Tabs: **Needs Action** (`?view=unresolved`), **All Rows** (`?view=all`),
  **Rate Sheet** (P7 fills this slot). Active payload refetched after every
  mutation and on tab switch.
- Grid columns `Row | Code | Desc | Qty | Unit | Rate | Amount | Eff.Rate |
  Flags | Actions`, inside a fixed-height `overflowY:'auto'` container — never a
  VirtualizedList nested in the page `ScrollView`. Per row `[Edit] [Confirm]
  [Exclude]` (or `[Reinstate]` when excluded); disabled unless
  `status==='AWAITING_REVIEW'`.
- Row edit: **reuse the `RenameModal` modal shell** (Paper `Portal`+`Modal`+
  `TextInput`+reason) rendered inline here (no new modal file), editing any of
  `{description,quantity,unit,rate}` and building **one** PATCH via
  `buildPatchBody(updates[], reason)` (P2); blank reason blocked client-side.
- Exclude/reinstate confirmations reuse `useWebAlert()`.

Mutation rule (in context): dispatch → on success refetch the active `view` →
pause polling while in flight. `confirm` sends `{reason, applySuggestion}`
(suggestion only when the row exposes exactly one).

## Tests

`__tests__/shipmentInvoice/review.test.ts` (mock the service; drive the context
and assert the exported action/body builders rather than rendering the grid):

- Tab → query mapping: Needs Action issues `?view=unresolved`, All Rows `?view=all`. (AC9)
- Header derives from `summary` (totals + unresolved count). (AC9)
- Multi-field edit produces exactly one PATCH with `updates[]` + shared reason. (AC10)
- Blank reason rejected before dispatch (no service call). (AC10)
- Illegal field / mixed valid+invalid `updates[]` rejected whole. (AC10)
- Confirm with and without `applySuggestion` produces the right body. (AC10)
- Exclude then reinstate each call the right endpoint with `{reason}` and trigger a refetch. (AC10)
- Actions disabled when `status !== 'AWAITING_REVIEW'`. (AC10)
- Refetch-after-mutation: a mocked success causes exactly one re-read of the active view. (AC10)

## Exit gate

1. `npx jest __tests__/shipmentInvoice/review.test.ts` exits `0`.
2. `npm run build:web` exits `0`.
3. Rebuilt `dist/` staged; no pre-existing `dist/` churn. (AC17)

## Escalation triggers

1. A mutation response shape differs from §4.3 (e.g. `confirm` returns a
   wrapper) — stop.
2. The grid cannot render 117 rows without nesting a virtualized list in the page
   `ScrollView` — stop; the container approach is a stated constraint.
3. A row action needs a status code the fixed `ApiError` still does not expose —
   stop (escalation #3/#5); do not widen `apiClient.ts` again.
4. Reusing the `RenameModal` shell would require changing the existing rename
   flow — stop; fall back to a Paper dialog inline and note it.
