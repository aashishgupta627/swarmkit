# P3 - Service module

**Depends on:** P1
**Unblocks:** P4
**Status:** planned

## Scope

- `src/services/documentUploadService.ts` — add one reusable `uploadFileToS3`
  helper (reuse, not re-implement; also benefits existing callers).
- `src/services/shipmentInvoiceService.ts` — new.
- `__tests__/shipmentInvoice/service.test.ts` — new.

No other file may change. Independent of P2 — if P2 lands first, import its types;
otherwise keep this module's shapes structural and let P2 align them, but **do not
duplicate** type definitions. Do not touch `apiClient.ts` (P1 owns it).

## Design

`shipmentInvoiceService.ts` is the **only** place the feature's URLs appear
(ADR-002). One exported function per endpoint in `00-plan.md` §4.3 (17 calls),
all through `agentApi` from `./apiClient` — except the raw S3 PUT.

```
createAutomation(entityId)                       POST /automations/shipment-invoice
getPresignedUrl(presignBody)                     POST /documents/presigned-url
processDocument(s3Key)                           POST /documents/process
getAutomationStatus(requestId)                   GET  /automations/{requestId}
getReview(requestId, view)                       GET  /shipment-invoices/{id}/review?view=
getReconciliation(requestId)                     GET  …/reconciliation
getAudit(requestId)                              GET  …/audit
patchItem(requestId, itemId, body)               PATCH …/items/{itemId}
confirmItem(requestId, itemId, reason, applySuggestion?)  POST …/confirm
excludeItem / reinstateItem(requestId, itemId, reason)    POST …/exclude|/reinstate
confirmMatched(requestId, reason)                POST …/confirm-matched
correctRate(requestId, index, body)              POST …/rates/{index}/correct
reparse(requestId)                               POST …/reparse
approve(requestId)                               POST …/approve
retryGenerate(requestId)                         POST …/retry-generate
getOutputDocument(documentId)                    GET  /documents/{id}
```

The presign body is **not** composed here — the caller passes the output of
`buildPresignBody` (P2, AC16); this module only POSTs it. The existing
`documentService.getPresignedUrl` is not reused (different body shape).

**Reuse the S3 byte upload** — add `uploadFileToS3(presignedUrl, file,
contentType)` to `documentUploadService.ts`, mirroring the existing upload logic
there/`UserContext.uploadDocument`: `PUT` the raw bytes with `Content-Type`; a
non-`ok` response throws with status + body text. Feature service calls it.

Notes:

- `getOutputDocument` must accept **both** a flat document and
  `{success,document}` and return a normalised `{id, fileName, s3PresignedUrl}`
  (A3/Q2). Reuse `documentService.getDocumentById`'s envelope knowledge.
- No retry wrappers; `agentApi` already configures `axios-retry`.
- `handleApiError` (fixed in P1) now attaches `status`/`data`; service does not
  catch and re-wrap.

## Tests

`__tests__/shipmentInvoice/service.test.ts`:

- `jest.mock('../../src/services/apiClient', () => ({ agentApi: { get: jest.fn(),
  post: jest.fn(), patch: jest.fn(), put: jest.fn() } }))`.
- For each HTTP call assert **method, path, body/params**:

| Test | Assertion | AC |
|------|-----------|-----|
| create | `POST /api/v1/automations/shipment-invoice`, `{entityId}` | AC4 |
| presign | `POST /api/v1/documents/presigned-url`; body is the passed object verbatim (AC16 body asserted in P2) | AC4, AC16 |
| process | `POST /api/v1/documents/process`, `{s3Key}` | AC4 |
| status | `GET /api/v1/automations/{id}` | AC4 |
| review | `GET …/review?view=unresolved` and `?view=all` (both) | AC4, AC9 |
| reconciliation / audit | `GET` the two paths | AC4 |
| patch | `PATCH …/items/{itemId}`, body incl. `updates[]` | AC4 |
| confirm | `POST …/confirm` with `reason` + `applySuggestion` | AC4 |
| exclude/reinstate | `POST` correct suffix with `{reason}` | AC4 |
| confirmMatched | `POST …/confirm-matched`, `{reason}` | AC4 |
| correctRate | `POST …/rates/{index}/correct`; index in path | AC4 |
| reparse / approve / retry | `POST` the three paths | AC4 |
| getOutputDocument | normalised `s3PresignedUrl` from **both** envelope shapes | AC4, AC11 |
| `uploadFileToS3` | `PUT` the URL with the raw file + `Content-Type` header | AC4 |
| `uploadFileToS3` negative | throws with status text on `!response.ok` | AC4 |

## Exit gate

`npx jest __tests__/shipmentInvoice/service.test.ts` exits `0`.

## Escalation triggers

1. `agentApi`'s interceptor transforms errors so the thrown shape cannot be
   asserted — stop; do not modify `apiClient.ts` here (P1/ADR-003 own it).
2. Any endpoint in §4.3 returns a shape that cannot be typed without inventing
   fields — stop.
3. Adding `uploadFileToS3` to `documentUploadService` would change behaviour for
   existing callers beyond an additive export — stop (escalation #4 in §8).
4. The fetch-to-S3 helper cannot run under the `react-native` preset without
   extra global mocks — stop rather than editing `jest.config.js`.
