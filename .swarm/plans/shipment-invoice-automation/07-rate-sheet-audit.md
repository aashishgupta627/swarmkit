# P7 - Rate Sheet tab, rate repair, reparse, audit

**Depends on:** P6
**Unblocks:** P9
**Status:** planned

## Scope

- `src/screens/shipmentInvoice/ShipmentInvoiceReview.web.tsx` — fill the Rate
  Sheet tab and add the Audit affordance (same consolidated view file as P6).
- `src/context/ShipmentInvoiceContext.tsx` — add reconciliation/audit load, the
  inline rate-repair action, and reparse.
- `__tests__/shipmentInvoice/rateSheet.test.ts` — new.

## Design

Rate Sheet tab renders `GET …/reconciliation` four sections:

1. `rateCodesNotInPackingList` (orphan rates),
2. `packingCodesNotInRateList` (shipped-without-rate),
3. `packTrayMismatches` on joined pairs,
4. `defectiveRateRows` addressed by **`index`**.

Section ④ rows carry an inline repair form → `POST …/rates/{index}/correct` with
only the repaired fields + `reason`; on success refetch `/reconciliation` **and**
the active `/review` view (repair re-matches affected rows).

Re-run parse behind `useWebAlert().confirm`; on `202` the context returns to the
`progress` step (`REPARSE_SCHEDULED` is not in the enum — any accepted response
means "go poll"). A `409` surfaces `INVALID_STATE_TRANSITION` and refetches.

Audit dialog (reuse the `RenameModal` shell/Paper `Modal`) lists `GET …/audit`
events (`sequence,eventType,actorUserId,actorRole,reason,occurredAt`).

## Tests

`__tests__/shipmentInvoice/rateSheet.test.ts` (mock the service):

- Section ④ maps a `defectiveRateRows` entry to a repair call whose path `index`
  is exactly that entry's `index`. (AC12)
- Repair body has only the changed fields + mandatory reason; blank reason
  rejected client-side. (AC12)
- A successful repair triggers a `/reconciliation` refetch **and** a review
  refetch. (AC12)
- Reparse requires confirmation (not called when `confirm` resolves false); when
  confirmed, the context moves to `progress` and re-polls. (AC12)
- Reparse `409` surfaces the transition code and triggers a review refetch. (AC12, AC14)
- Audit response maps to rows including actor/role/timestamp. (AC13)
- All four reconciliation sections render their arrays; empty arrays render an
  empty state, not a crash. (AC9)

## Exit gate

`npx jest __tests__/shipmentInvoice/rateSheet.test.ts` exits `0`.

## Escalation triggers

1. The repair endpoint omits the recomputed `code`/`rate` the task promises —
   stop.
2. Section ④'s `index` cannot be tied to the `extractedRates` position from the
   response alone — stop; do not guess an index mapping.
3. Reparse needs polling a status outside `isProgressing` (A4) — stop and
   reconcile with P2/P5.
