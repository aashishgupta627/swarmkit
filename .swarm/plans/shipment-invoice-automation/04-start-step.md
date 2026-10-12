# P4 - Context layer + Step 1 start & upload

**Depends on:** P2, P3
**Unblocks:** P5
**Status:** planned

## Scope

- `src/context/ShipmentInvoiceContext.tsx` — new. Owns the whole flow: state
  machine, file selection, and the start/upload orchestration. Modelled on
  `src/context/HomeContext.tsx`.
- `src/screens/shipmentInvoice/ShipmentInvoiceScreen.web.tsx` — new. **Dumb**
  view: renders `start | uploading` (later phases add `progress`/`review`/`done`)
  from context values only — no URLs, no `agentApi`, no business rules.
- `src/components/DocumentUploader.web.tsx` — add an optional `accept?: string`
  override so the existing picker can take `.xlsx` (reuse, not a new picker).
  Native `DocumentUploader.tsx` is **not** touched (web-only task; its interface
  is separate, so no TS parity edit is required).
- `__tests__/shipmentInvoice/context.test.ts` — new.
- `dist/**` — commit the rebuilt bundle (Q3/AC17).

The provider is **not** mounted into `AppNavigator.web.tsx` in this phase (P9
wires the route); the screen is exercised through the context in tests.

## Design

`ShipmentInvoiceContext` value:

```
state: { step:'start'|'uploading'|'progress'|'review'|'done'|'failed',
         entityId, rateFile, packingFile, requestId, status, stage,
         error, isBusy }
actions: { setEntity, setRateFile, setPackingFile, run, retry, back }
```

`run()` (orchestration; sequential, and the only place services are called from
the UI layer):

```
runAutomation({ entityId, rateFile, packingFile }, service):
  { requestId } = service.createAutomation(entityId)          // once
  for each of [ (rateFile,'Rate List'), (packingFile,'Packing List') ]:
     body    = buildPresignBody({ tag, requestId, entityId, file,
                                  uploadedBy, uploaderRole })  // P2, from AuthUser
     presign = service.getPresignedUrl(body)
     await uploadFileToS3(presign.presignedUrl, file, contentType) // P3 reuse
     await service.processDocument(presign.objectKey)
  → step 'progress'
```

On failure keep `requestId` and the failed sub-step index so `retry` resumes from
that sub-step only — never re-creates the request. `isRunReady` gates Run.
`uploadedBy`/`uploaderRole` are read once from `useAuth()`'s `AuthUser`
(`individualId`, `role`) — A2.

Reuse: both file inputs render the existing `DocumentUploader` with
`accept='.xlsx'`; confirmations use `useWebAlert()`. No new picker/modal files.

## Tests

`__tests__/shipmentInvoice/context.test.ts` — render the provider with a test
consumer via `react-test-renderer` + `act` (available, devDep `19.1.0`); mock the
service with `jest.mock`:

- Happy path order: `createAutomation` first, then exactly `presign → PUT →
  process` for the **rate list**, then the same trio for **packing list**; the two
  presign bodies carry different `documentTags`. (AC8)
- `isRunReady`: Run disabled until company + both files; enabled when all three. (AC7)
- Failure at the packing-list `process`: `requestId` preserved, no second
  `createAutomation`, and `retry` re-invokes from the failed sub-step only. (AC8)
- Failure at the rate-list `PUT`: `retry` neither re-creates nor uploads packing. (AC8)
- A `process` `404` surfaces an error and stays on `start`. (AC8, AC14)
- `setEntity`/`setRateFile`/`setPackingFile` update state and re-evaluate
  `isRunReady`. (AC7)
- The feature passes `accept` (`.xlsx`) to each picker; the prop is additive.
  Assert this at the element level **only if** `DocumentUploader.web.tsx` resolves
  under the preset; otherwise it is covered by `tsc`/build and the P11 E2E step. (AC4)

## Exit gate

1. `npx jest __tests__/shipmentInvoice/context.test.ts` exits `0`.
2. `npm run build:web` exits `0`.
3. Rebuilt `dist/` staged in the same commit; no pre-existing `dist/` churn
   staged. (AC17)

## Escalation triggers

1. Deriving `uploadedBy`/`uploaderRole` from `AuthUser` is impossible (A2) — stop
   (escalation #2 in §8); do not invent values.
2. Adding `accept` to `DocumentUploader.web.tsx` changes behaviour for existing
   (KYC / upload) callers beyond an additive override — stop (escalation #4).
3. `react-test-renderer` cannot drive the provider under the `react-native`
   preset without extra config — stop; do not edit `jest.config.js`.
4. The web build fails for a reason originating in a file this phase did not
   create — record against P0 and stop if pre-existing.
