# Shipment Invoice Automation — Screen Flow & API

A complete user flow guide for the Shipment Invoice automation screen: select a
company, upload the two workbook files, watch the parse run live, review the
draft in three tabs, approve, and download the Tally workbook.

Backend: Spring Boot 3.2.3, MongoDB Atlas (`document_db`), S3 buckets
(pending / classified), `spring.profiles.active=local` on port `9002` (SSL).
All endpoints are under `/api/v1` and require a bearer token (JWT, kid
`local-dev-kid-1` in local dev). Every action is owner-scoped; a non-owner is
`404` (existence is never disclosed), an owner missing a permission is `403`.

## Frontend: Build only the webpage for this. No mobile pages are required.

## 1. Broad layout (screen map)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  SHIPMENT INVOICE                                                       (user)│
│                                                                            │
│  ┌──────────────────────────────────────  STEP 1 · START  ──────────────┐  │
│  │  Company                      [ LOTUS ▾ ]                            │  │
│  │                                                                      │  │
│  │  Rate List         [ Browse ./Drop ]  Packing List   [ Browse ./Drop ]│  │
│  │  (price book .xlsx)              (shipment .xlsx)                    │  │
│  │                                                                      │  │
│  │                            [  Run Automation  ]                     │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                            │
│  ┌─────────────────────────────── STEP 2 · LIVE PROGRESS ──────────────┐  │
│  │  SI-20261007-000002 · LOTUS                                          │  │
│  │  ● Uploading rate list   ● Uploading packing list                    │  │
│  │  ● S3 event              ● Classifying / routing both files          │  │
│  │  ● Extracting rate table ● Parsing packing list · matching 117 rows  │  │
│  │                                                          [ spinner ] │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                            │
│  ┌─────────────────────────────── STEP 3 · REVIEW ────────────────────┐  │
│  │  LOTUS · GSTIN …          Item 117 · Total ₹3,526,697.36           │  │
│  │  unresolved: 0                  [ ✓ Confirm benign 117 ] [ Approve ]│  │
│  │                                                                      │  │
│  │  [ Needs Action ]  [ All Rows ]  [ Rate Sheet ]        (Audit ·§)   │  │
│  │  ┌────────────────────────────────────────────────────────────────┐ │  │
│  │  │ Row|Code|Desc|Qty|Unit|Rate|Amount|Eff.Rate|Flags|  Actions    │ │  │
│  │  │ …  grid  ·  per-row: [ Edit ] [ Confirm ] [ Exclude ]           │ │  │
│  │  └────────────────────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                            │
│  ┌─────────────────────────────── STEP 4 · DONE ───────────────────────┐  │
│  │  Approval complete — Tally workbook generated                      │  │
│  │  [ Download Tally Workbook (xlsx) ]        · request COMPLETED     │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
```

- **Step 1 — Start.** A company dropdown (the logged-in partner's authorized
  entities) plus two file pickers: _Rate List_ and _Packing List_. The Run
  button is enabled when the company and both files are chosen.
- **Step 2 — Progress.** A stepper over the automation stages
  (`DOCUMENT_UPLOAD → S3_EVENT → CLASSIFICATION_BYPASS → FILES_READY →
PDF_EXTRACTION → PACKING_LIST_PROCESSING → AWAITING_REVIEW`). Polled; each
  stage shows a spinner while active and a tick when passed.
- **Step 3 — Review (three tabs).** Driven by `/review?view=…`:
  - **Needs Action** — `view=unresolved` (rows still blocking approval).
  - **All Rows** — `view=all` (every retained row, resolved and unresolved).
  - **Rate Sheet** — the extracted rate list and its join health, driven by
    `/reconciliation` (orphan rates, shipped-without-rate, pack/tray
    mismatches, defective rate rows by `index`).
  - The header strip shows summary totals + unresolved count and holds the
    bulk **Confirm benign** and **Approve** buttons.
  - _(Optional 4th pause —)_ **Audit** (`/audit`, the append-only trail).
- **Step 4 — Done.** After approval the request is `COMPLETED`, the workbook
  is registered as a document tagged `Shipment Invoice`, and a **Download**
  opens the generated `.xlsx` through the document's presigned URL.

---

## 2. End-to-end sequence

```
UI                                   Service (S3 · Mongo · parse job)
──                                ───────────────────────────────────
company ▸ entityId
  │  POST /automations/shipment-invoice        → 201 AutomationResponse(requestId)
  │───────────────────────────────────────────→
  │  POST /documents/presigned-url   {rate list}   → presigned PUT url
  │───────────────────────────────────────────→
  │  PUT file (S3 pending bucket)
  │  POST /documents/process {s3Key}           → 202 (classified path uses tag "Rate List")
  │  POST /documents/presigned-url   {packing list} → presigned PUT url
  │  POST /documents/process {s3Key}           → 202 (tag "Packing List")
  │
  │   poll GET /automations/{requestId} ───────→ WAITING_FOR_FILES → FILES_READY
  │   poll GET /automations/{requestId} ───────→ PROCESSING_IN_PROGRESS (extract/parse/match)
  │   poll GET /shipment-invoices/{id}/review ─→ AWAITING_REVIEW, items[] loaded
  │
  │  review tabs (GET /review, /reconciliation, /audit)
  │  per-row: PATCH …/items/{id} · POST …/confirm · …/exclude · …/reinstate
  │  bulk:    POST …/confirm-matched {reason}
  │  repair:  POST …/rates/{index}/correct
  │  re-run:  POST …/reparse (optional, preserves human corrections)
  │
  │  POST …/approve                              → 200 {approved, outputDocumentId}
  │  GET  /documents/{outputDocumentId}          → s3PresignedUrl
  │  download workbook
```

Both input files stream through the same ingestion: presign → upload to the
pending bucket → `/documents/process` (in production the S3 event does this)
→ the classified key embeds the file's single tag
(`shipment-invoice/<entity>/<requestId>/<Rate List|Packing List>/<file>`)
→ the automation goes `FILES_READY`, then the async parse job prices and
writes the review draft, then `AWAITING_REVIEW`.

---

## 3. Endpoints — request & response

### 3.1 Company selection

The dropdown is populated from the logged-in user's **authorized entities**
(`EntityAccessResolver.resolveAuthorizedEntityIds(user, authorizationHeader)`),
the same scoping used by the search endpoints. The chosen company is passed as
`entityId` everywhere below.

### 3.2 Create the automation

`POST /api/v1/automations/shipment-invoice` · permission `DOCUMENT_UPLOAD`

```json
// request
{ "entityId": "LOTUS" }
```

```json
// 201 Created
{
  "requestId": "SI-20261007-000002",
  "automationType": "SHIPMENT_INVOICE",
  "entityId": "LOTUS",
  "status": "CREATED"
}
```

### 3.3 Pre-sign an upload (one call per file)

`POST /api/v1/documents/presigned-url` · permission `DOCUMENT_UPLOAD`

The body may be flat or wrapped as `{"request": {"data": {…}}}`. For Shipment
Invoice uploads carry the correlation id and **one document tag** naming which
of the two files this is.

```json
// request — rate list
{
  "documentType": "SHIPMENT_INVOICE",
  "fileName": "Rate_List_LOTUS_sep25.xlsx",
  "contentType": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  "fileSize": 204800,
  "aiDocumentType": "SHIPMENT_INVOICE",
  "documentTags": ["Rate List"],
  "requestId": "SI-20261007-000002",
  "metadata": { "financialYear": "2025-26", "month": "SEPTEMBER" }
}
```

```json
// 200 OK
{
  "presignedUrl": "https://<bucket>.s3….amazonaws.com/pending/…?X-Amz-…",
  "fileUrl": "https://….amazonaws.com/pending/shipment-invoice/LOTUS/SI-20261007-000002/Rate List/Rate_List_LOTUS_sep25.xlsx",
  "objectKey": "pending/shipment-invoice/LOTUS/SI-20261007-000002/Rate List/Rate_List_LOTUS_sep25.xlsx",
  "expiresIn": 900
}
```

Repeat with `documentTags: ["Packing List"]` for the packing list. The
workbooks are uploaded straight back to `presignedUrl` with `PUT`.

### 3.4 Trigger ingestion ("uploading / extracting")

`POST /api/v1/documents/process` · body `{"s3Key": "<pending object key>"}`

The S3 event normally calls this automatically after each upload; the UI can
invoke it directly too. Response `202 Accepted` (`404` for a true orphan key).

### 3.5 Poll progress

`GET /api/v1/automations/{requestId}` · permission `DOCUMENT_READ`

```json
// status = "ready to review", "processing", "waiting for second file", …
{
  "requestId": "SI-20261007-000002",
  "automationType": "SHIPMENT_INVOICE",
  "status": "AWAITING_REVIEW",
  "currentStage": "AWAITING_REVIEW",
  "rateListDocumentId": "64e6…",
  "packingListDocumentId": "64e6…",
  "outputDocumentId": null,
  "error": null,
  "timestamps": {
    "createdAt": "2026-10-08T09:00:00",
    "updatedAt": "2026-10-08T09:01:00",
    "completedAt": null
  }
}
```

`status ∈ {CREATED, WAITING_FOR_FILES, FILES_READY, PROCESSING_IN_PROGRESS,
AWAITING_REVIEW, COMPLETED, FAILED}`; `currentStage` drills into
`{DOCUMENT_UPLOAD, S3_EVENT, CLASSIFICATION_BYPASS, FILES_READY,
PDF_EXTRACTION, PACKING_LIST_PROCESSING, AWAITING_REVIEW,
INVOICE_GENERATION, GENERATING, OUTPUT_UPLOAD, CALLBACK, COMPLETED, FAILED}`.
Poll this (and the review draft below) with a short interval while a stage
spinner is visible.

### 3.6 Review draft (tabs)

`GET /api/v1/shipment-invoices/{requestId}/review?view=unresolved|all`

Default `unresolved` powers **Needs Action**; `view=all` powers **All Rows**.
In-flight (`CREATED`…`PROCESSING_IN_PROGRESS`) is a `200` with an empty
`items` list and zeroed summary — not a `409`.

```json
{
  "requestId": "SI-20261007-000002",
  "status": "AWAITING_REVIEW",
  "currentStage": "AWAITING_REVIEW",
  "companyName": "LOTUS",
  "currency": null,
  "error": null,
  "items": [
    {
      "itemId": "…",
      "sourceRowNo": 22,
      "itemCode": "FGC10842",
      "description": "Angoori Gulab Jamun",
      "packSize": "0.5",
      "trayCount": "16",
      "unit": "Tray",
      "quantity": 88,
      "rate": 297,
      "amount": 26136.0,
      "correctedQuantity": null,
      "correctedRate": null,
      "correctedDescription": null,
      "correctedUnit": null,
      "correctionReason": null,
      "effectiveQuantity": 88,
      "effectiveRate": 297,
      "effectiveAmount": 26136.0,
      "rateCodeMatched": "FGC10842",
      "matchStatus": "MATCHED",
      "resolutionState": "UNRESOLVED",
      "excluded": false,
      "issueFlags": ["HEADER_ANOMALY", "PACK_TRAY_MISMATCH"],
      "suggestedRate": null,
      "suggestedSource": null,
      "suggestedCandidateCount": null
    }
  ],
  "summary": {
    "companyName": "LOTUS",
    "currency": null,
    "totalQuantity": 8115.28,
    "totalAmount": 3526697.36,
    "itemCount": 117,
    "unresolvedCount": 7
  },
  "outputDocumentId": null
}
```

`effective*` is what the workbook will carry (corrections win over source).
Any non-empty `issueFlags` keeps a row `UNRESOLVED` and blocking approval.

**Flag taxonomy** (all reviewer-facing):
`RATE_NOT_FOUND`, `RATE_MATCH_FAILED`, `DUPLICATE_RATE`, `EXPIRED_RATE`,
`NOT_YET_EFFECTIVE`, `UNPARSEABLE_RATE_DATE`, `RATE_CODE_AUTO_CORRECTED`,
`PACK_TRAY_MISMATCH`, `POSSIBLE_TOTAL_ROW`, `DUPLICATE_ROW`,
`DERIVED_TOTAL_COLUMN`, `MISSING_CODE`, `INVALID_QUANTITY`, `HEADER_ANOMALY`,
`RATE_CHANGED_AFTER_CORRECTION`, `NEW_ON_REPARSE`, `SUGGESTED_RATE`,
`SUGGESTED_RATE_AMBIGUOUS`.

### 3.7 Audit (append-only trail)

`GET /api/v1/shipment-invoices/{requestId}/audit`

```json
{
  "requestId": "SI-20261007-000002",
  "events": [
    {
      "sequence": 0,
      "eventType": "PARSED",
      "itemId": null,
      "fieldName": null,
      "oldValue": null,
      "newValue": null,
      "reason": null,
      "actorUserId": "system-1",
      "actorRole": "SYSTEM",
      "occurredAt": "2026-10-08T09:01:00"
    },
    {
      "sequence": 4,
      "eventType": "BULK_CONFIRMED",
      "itemId": null,
      "fieldName": null,
      "oldValue": null,
      "newValue": null,
      "reason": "…benign markers…",
      "actorUserId": "user-1",
      "actorRole": "USER",
      "occurredAt": "…"
    }
  ]
}
```

### 3.8 Rate sheet tab

`GET /api/v1/shipment-invoices/{requestId}/reconciliation`

```json
{
  "requestId": "SI-20261007-000002",
  "generatedAt": "2026-10-08T09:02:00",
  "rateCount": 158,
  "packingCodeCount": 117,
  "rateCodesNotInPackingList": [
    {
      "code": "FGC99999",
      "description": "…",
      "rate": 123,
      "packSize": "0.5",
      "trayCount": "10"
    }
  ],
  "packingCodesNotInRateList": [
    {
      "itemId": "…",
      "sourceRowNo": 94,
      "itemCode": "FGC5090",
      "description": "…",
      "quantity": 6
    }
  ],
  "packTrayMismatches": [
    {
      "code": "FGC10842",
      "field": "PACK_SIZE",
      "packingValue": "0.5",
      "rateValue": "500.00"
    }
  ],
  "defectiveRateRows": [
    {
      "index": 132,
      "productCode": null,
      "description": "…",
      "rate": null,
      "defect": "D9"
    }
  ]
}
```

The four sections are the join audit: ① orphan rates, ② shipped-without-rate,
③ pack/tray disagreements on joined pairs, ④ defective rate rows addressed by
`index`. Deficiencies in the rate list are repaired in place (3.13), which
re-matches affected packing rows automatically.

### 3.9 Correct a row (single **or** multi-field, one call)

`PATCH /api/v1/shipment-invoices/{requestId}/items/{itemId}`
· permission `DOCUMENT_UPDATE` · only while `AWAITING_REVIEW` (else `409`)

Single field (existing contract):

```json
{ "field": "rate", "value": "59.97", "reason": "rate list superseded" }
```

Several fields at once (value edits for one row are a **single call**):

```json
{
  "updates": [
    { "field": "rate", "value": "59.97" },
    { "field": "quantity", "value": "10" }
  ],
  "reason": "confirmed volume and superseded rate with the supplier"
}
```

Rules: `field ∈ {description, quantity, unit, rate}`; `value` is a **string**
(BigDecimal, parsed server-side); `reason` mandatory (blank → `400
REASON_REQUIRED`); everything is validated before any write — one illegal
field leaves the row untouched; each applied field writes its own `CORRECTED`
audit entry (old → new) under the shared reason; `amount` is recomputed.

```json
// 200 OK — the corrected row, effective* = what the workbook will use
{
  "itemId": "…",
  "effectiveRate": 59.97,
  "effectiveQuantity": 10,
  "effectiveAmount": 599.7,
  "resolutionState": "RESOLVED",
  "issueFlags": []
}
```

### 3.10 Confirm a row as-is / apply suggestion

`POST /api/v1/shipment-invoices/{requestId}/items/{itemId}/confirm`

```json
// request
{ "reason": "rate confirmed on the phone", "applySuggestion": true }
```

`applySuggestion:true` writes the row's one pending `suggestedRate` through the
correction envelope (`CORRECTED` audit, corrected fields); on any row without
exactly one suggestion it is a `400 INVALID_BUSINESS_DATA`. Response: the row.

### 3.11 Exclude / Reinstate a row

`POST /api/v1/shipment-invoices/{requestId}/items/{itemId}/exclude`
`POST /api/v1/shipment-invoices/{requestId}/items/{itemId}/reinstate`

Bodies carry only `reason` (blank → `400 REASON_REQUIRED`). Excluded rows are
retained in the record and audit, and are omitted only from the generated
workbook; reinstate returns the row to `UNRESOLVED` (re-blocks approval).

### 3.12 Bulk confirm — matched rows with only benign markers

`POST /api/v1/shipment-invoices/{requestId}/confirm-matched`

```json
// request
{
  "reason": "packing list is sacrosanct; matched rows with only benign markers accepted in bulk"
}
```

```json
// 200 OK
{ "requestId": "SI-20261007-000002", "confirmedCount": 7 }
```

Resolves every `MATCHED` row whose flags are a subset of the benign set
(`DUPLICATE_RATE`, `HEADER_ANOMALY`, `NEW_ON_REPARSE`, `PACK_TRAY_MISMATCH`).
Idempotent: a second call on the now-clean set answers `0`, and a `0` writes no
audit entry. Never touches `RATE_NOT_FOUND`, expired, ambiguous, missing-code
or auto-corrected rows. One click behind the **Confirm benign** button.

### 3.13 Repair a defective rate row

`POST /api/v1/shipment-invoices/{requestId}/rates/{index}/correct`

`{index}` is the position in the persisted `extractedRates` list that section ④
reports. The body holds only the fields being repaired:

```json
{
  "productCode": "FGC10842",
  "rate": "297.00",
  "reason": "code was null on the sheet"
}
```

```json
// 200 OK
{
  "requestId": "SI-20261007-000002",
  "index": 132,
  "code": "FGC10842",
  "rate": 297.0
}
```

The repair re-matches every unadjudicated packing row it affects; the next
`/reconciliation` and `/review` reads reflect it.

### 3.14 Re-parse (correct-and-redo)

`POST /api/v1/shipment-invoices/{requestId}/reparse`

Accepted from any non-terminal state (`202`); terminal states are `409`
`INVALID_STATE_TRANSITION` (with a recorded `REPARSE_BLOCKED` audit entry).

```json
// 202 Accepted
{ "requestId": "SI-20261007-000002", "status": "REPARSE_SCHEDULED" }
```

**Human corrections are preserved** across a re-parse; a re-parse whose
extracted rate differs from a human-corrected value flags the row
`RATE_CHANGED_AFTER_CORRECTION` instead of silently overwriting.

### 3.15 Approve → generate

`POST /api/v1/shipment-invoices/{requestId}/approve`

Refuses (blocking rows present) while `unresolvedCount > 0`, or on zero rows.
Generates the workbook **from the corrected values** and registers it as a
document tagged `Shipment Invoice`.

```json
// 200 OK
{
  "requestId": "SI-20261007-000002",
  "approved": true,
  "idempotentReplay": false,
  "outputDocumentId": "64e6…"
}
```

`idempotentReplay:true` means another approve already did the work (200, not
409). After approval `GET /automations/{requestId}` reports `status: COMPLETED`
and `outputDocumentId`.

### 3.16 Retry a failed generation

`POST /api/v1/shipment-invoices/{requestId}/retry-generate`

Only from `FAILED` with a generation-stage failure; needs no re-upload (the
corrected rows are retained). Same `ApproveResponse` shape.

### 3.17 Download the Tally workbook

`GET /api/v1/documents/{outputDocumentId}` (or
`GET /api/v1/search/documents/{outputDocumentId}`)

```json
// 200 OK
{
  "id": "64e6…",
  "fileName": "SI-20261007-000002-Tally.xlsx",
  "entityId": "LOTUS",
  "aiDocumentType": "SHIPMENT_INVOICE",
  "documentTags": ["Shipment Invoice"],
  "status": "CLASSIFIED",
  "contentType": "…spreadsheetml.sheet",
  "fileSize": 81920,
  "s3PresignedUrl": "https://<classified-bucket>….xlsx?X-Amz-…",
  "timestamps": { … }
}
```

The open/save action is the `s3PresignedUrl` — a short-lived GET to the
classified bucket.

---

## 4. Typical payloads the screen uses, at a glance

| Screen element                    | Source                                                                         |
| --------------------------------- | ------------------------------------------------------------------------------ |
| Company dropdown                  | authorized entities (login scope)                                              |
| Upload rate / packing list        | `automations/shipment-invoice` → `presigned-url` → `PUT` → `documents/process` |
| Progress stepper                  | `GET automations/{id}` (status/stage), `GET …/review`                          |
| Needs Action tab                  | `GET …/review?view=unresolved`                                                 |
| All Rows tab                      | `GET …/review?view=all`                                                        |
| Rate Sheet tab                    | `GET …/reconciliation`                                                         |
| Header summary                    | `…/review` → `summary` (totals + unresolved)                                   |
| Bulk confirm benign               | `POST …/confirm-matched`                                                       |
| Row edit (multi-field)            | `PATCH …/items/{id}` (`updates[]`)                                             |
| Row confirm / exclude / reinstate | `POST …/items/{id}/confirm` · `…/exclude` · `…/reinstate`                      |
| Rate-row repair                   | `POST …/rates/{index}/correct`                                                 |
| Re-run parse                      | `POST …/reparse`                                                               |
| Approve                           | `POST …/approve`                                                               |
| Download workbook                 | `GET /documents/{outputDocumentId}` → `s3PresignedUrl`                         |

## 5. Error contract (coded)

`400` — `REASON_REQUIRED`, `INVALID_BUSINESS_DATA` (bad field/value/updates),
missing request fields · `404` — non-owner or unknown automation (ownership
masking) · `403` — owner lacks the authority (`DOCUMENT_UPLOAD` /
`DOCUMENT_READ` / `DOCUMENT_UPDATE`) · `409` — `INVALID_STATE_TRANSITION`
(mutation outside `AWAITING_REVIEW`, reparse on a terminal status) · `500`
and coded shipment-invoice failures — flagged as `RATE_MATCH_FAILED`,
`INVOICE_GENERATION_FAILED`, etc. in `AutomationStatusResponse.error` when the
request lands `FAILED`.
