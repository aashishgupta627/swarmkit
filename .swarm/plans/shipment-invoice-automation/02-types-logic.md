# P2 - Types and pure logic

**Depends on:** P1
**Unblocks:** P4, P5, P6
**Status:** planned

## Scope

- `src/types/shipmentInvoiceTypes.ts` — new.
- `src/utils/shipmentInvoiceLogic.ts` — new.
- `__tests__/shipmentInvoice/logic.test.ts` — new.

No other file may change. Independent of P3; build in either order. Do **not**
duplicate type definitions in P3 (P3 imports from here).

## Design

Reference `00-plan.md` §4.3 for call shapes and §4.4 for the poll rule. This
phase owns the **types and the decisions**, not the network.

Types (`shipmentInvoiceTypes.ts`):

- `AutomationStatus` = `CREATED | WAITING_FOR_FILES | FILES_READY |
  PROCESSING_IN_PROGRESS | AWAITING_REVIEW | COMPLETED | FAILED`.
- `AutomationStage` = the 13 task-file values (`DOCUMENT_UPLOAD` …
  `COMPLETED|FAILED`) plus the fixed stepper-order constant.
- `IssueFlag` = the full 18-value reviewer taxonomy (task §3.6).
- `MatchStatus`, `ResolutionState` (`UNRESOLVED | RESOLVED`).
- Request/response interfaces: `AutomationResponse`, `AutomationStatusResponse`,
  `PresignedUrlRequest` (**exact Q1 shape** below), `PresignedUrlResult`
  (`presignedUrl,fileUrl,objectKey,expiresIn`), `ReviewItem`, `ReviewPayload`
  (`items[],summary`), `Reconciliation`, `AuditEvent`, `ApproveResponse`,
  `DocumentDetail` (envelope-tolerant), `ShipmentDocumentTag` (`Rate List` |
  `Packing List`).
- `PollGuard` type.

`PresignedUrlRequest` (AC16) — exactly this, nothing else:

```ts
{
  documentType: 'SHIPMENT_INVOICE';
  requestId: string;
  fileName: string;
  contentType: string;
  fileSize: number;
  documentTags: ShipmentDocumentTag[]; // one element for one file
  metadata: { entityId: string; uploadedBy: string; uploaderRole: string };
}
```

Pure functions (`shipmentInvoiceLogic.ts`):

| Function | Rule |
|----------|------|
| `POLL_INTERVAL_MS` | constant `15000` (15 s) |
| `stageIndex(stage)` | index into the fixed stepper order; unknown → `-1` |
| `isProgressing(status)` | true for the four pre-review statuses |
| `nextStep(status)` | `AWAITING_REVIEW→'review'`, `COMPLETED→'done'`, `FAILED→'failed'`, else `'progress'` |
| `isRunReady(company, rateFile, packingFile)` | all three present |
| `buildPresignBody(input)` | returns `PresignedUrlRequest`; `documentTags:[tag]`, no `financialYear`/`month`/`aiDocumentType` |
| `buildPatchBody(field,value,reason)` / `(updates[],reason)` | single vs `updates[]`; values stringified; blank reason rejected; unknown field rejected; mixed valid+invalid rejected whole |
| `isBenign(row)` | `matchStatus==='MATCHED'` and every flag ∈ benign set |
| `canApprove(summary)` | false when `unresolvedCount>0` or `itemCount===0` |
| `createPollGuard()` | `next()` monotonic token + `isCurrent(token)`; drops stale responses |
| `canAccessShipmentInvoice(permissions)` | always `true` — entry open to all users for now (no `canSend`/`canView` check); the one seam the sidebar (P9) and home card (P10) both call, ready for the future `SHIPMENT_INVOICE` permission (FU6) |

`buildPresignBody` input (tag, requestId, entityId, file, uploadedBy,
uploaderRole) — `uploadedBy`/`uploaderRole` come from `AuthUser` (A2), not the
file.

## Tests

`__tests__/shipmentInvoice/logic.test.ts` (`describe` per unit):

- `stageIndex` for every stage, unknown → `-1`. (AC4)
- `nextStep` for `AWAITING_REVIEW`/`COMPLETED`/`FAILED` + a mid-flight status. (AC4, AC8)
- `isRunReady` matrix: missing company / missing either file / all present. (AC7)
- `buildPresignBody`: **deep-equals the exact Q1 body** (AC16) — key set,
  `documentTags:['Packing List']`, `metadata` triple, and asserts
  `financialYear`/`month`/`aiDocumentType` are **absent**; rate vs packing differ
  only in the tag. (AC4, AC16)
- `buildPatchBody` single **and** multi-field; string values; blank/whitespace
  reason rejected; illegal field rejected; mixed valid+invalid `updates[]`
  rejected whole. (AC4, AC10)
- `isBenign`: matched + benign-only → true; `RATE_NOT_FOUND`, `EXPIRED_RATE`,
  `MISSING_CODE`, `RATE_CODE_AUTO_CORRECTED` → false; unmatched → false. (AC4)
- `canApprove`: `unresolvedCount>0` → false; `itemCount===0` → false; clean → true. (AC4, AC11)
- `createPollGuard`: tokens monotonic; an older token is not current. (AC4)
- `canAccessShipmentInvoice`: returns `true` for any permissions, including
  `{canSend:false,canView:false}` — entry is open to all for now. (AC7)
- `POLL_INTERVAL_MS === 15000`. (AC4)

## Exit gate

`npx jest __tests__/shipmentInvoice/logic.test.ts` exits `0`.

## Escalation triggers

1. The task file's flag/status vocabulary is internally inconsistent (a flag in
   the benign set that the prose says blocks) — stop.
2. A type needs a field the task never defines (e.g. an error-code enum) — stop
   rather than invent one.
3. A pure helper cannot be expressed without a provider/DOM (not actually pure) —
   stop; the phase split assumed testable pure logic.
4. `buildPresignBody` cannot be satisfied by the Q1 body alone (a required field
   is missing) — stop; §4.3 is contradicted (escalation #1 in §8).
