# P10 - Home quick-action card entry

**Depends on:** P9
**Unblocks:** P11
**Status:** planned

## Scope

- `src/screens/home/HomeV1.web.tsx` — add an `onShipmentInvoicePress?: () => void`
  prop and a **Shipment Invoice** entry in the existing `actionCards` array,
  always visible via `canAccessShipmentInvoice(permissions)` (P2, returns
  `true`). The array currently filters by a single `permissionKey`, so this entry
  uses its own visibility predicate without changing `Send`/`Classify`/`View`.
  `handleActionPress` routes the new title to the new callback.
- `src/navigator/AppNavigator.web.tsx` — pass
  `onShipmentInvoicePress={() => setCurrentPage('shipmentInvoice')}` in the
  `home` case (the `Page` value + sidebar landed in P9).
- `__tests__/shipmentInvoice/homeCard.test.ts` — new.
- `dist/**` — commit the rebuilt bundle (AC17).

The sidebar item (P9) and this card are the two entry points; both call the one
P2 `canAccessShipmentInvoice` helper (returns `true` for now), so the future
permission stays in one place.

## Design

- Card entry: `title: 'Shipment Invoice'`, `icon: 'file-excel-outline'`, always
  visible for now (`canAccessShipmentInvoice(permissions)` returns `true`; the
  future `SHIPMENT_INVOICE` permission gates it later, FU6). Extend the existing
  filter (e.g. a `visible` boolean per entry, or a tiny local `permissionKey` map)
  so the three existing cards keep their single-key filter semantics.
- Press → `onShipmentInvoicePress`; when the prop is absent (other hosts) the
  card is a no-op, matching the other optional `on*Press` props.
- No new component file; the card reuses the existing `actionCard` styles.

## Tests

`__tests__/shipmentInvoice/homeCard.test.ts`:

- Card visible for **all** users (`canAccessShipmentInvoice` returns `true` even
  when `canSend`/`canView` are false). (AC7)
- Pressing the card calls `onShipmentInvoicePress`; an absent callback is a no-op
  and the existing `Send`/`Classify`/`View` handlers are unchanged. (AC7)
- If `HomeV1.web.tsx` cannot be rendered under the `react-native` preset, test an
  exported pure selection helper for the same matrix instead — do not add a
  test-only export that changes production behaviour. (AC7)

## Exit gate

1. `npx jest __tests__/shipmentInvoice/homeCard.test.ts` exits `0`.
2. `npm run build:web` exits `0`.
3. Rebuilt `dist/` staged; no pre-existing `dist/` churn. (AC17)

## Escalation triggers

1. Adding the card requires restructuring `actionCards`, `handleActionPress` or
   the layout beyond an additive entry — stop (escalation #9 in §8).
2. `HomeV1.web.tsx` cannot be exercised in jest without editing
   `jest.config.js` — stop; test a pure helper instead.
3. The card needs a `Page`/route/permission change owned by P9 — stop and
   reconcile; do not re-touch `Page` from here.
