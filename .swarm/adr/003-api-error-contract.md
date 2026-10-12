# ADR 003: `handleApiError` preserves status and body via `ApiError`

- **Status:** accepted
- **Date:** 2026-10-09
- **Task:** shipment-invoice-automation

## Context

`src/services/apiClient.ts` centralises error handling for every axios instance
(`authApi`/`userApi`/`agentApi`). Its `handleApiError` collapsed every failure
into a plain `Error(message)`, discarding the HTTP `status` and the entire backend
response body. The Shipment Invoice backend signals outcomes by **code** in the
body — `400 REASON_REQUIRED` / `INVALID_BUSINESS_DATA`,
`409 INVALID_STATE_TRANSITION`, `404` existence-masking, `403` permission — none
of which reached callers. The previous plan worked around this by string-matching
error messages (FU3).

The `ApiError` class (`message`, `status?`, `data?`, `name = 'ApiError'`) already
existed in the same file and is already re-exported by `src/services/auth.ts`.
Gate-1 feedback put fixing `handleApiError` **in contract** for this task. The
risk is that `apiClient.ts` is app-wide, so the change must be backward
compatible.

## Decision

`handleApiError` throws an `ApiError` carrying the HTTP `status` and the full
response body (`data`), instead of a plain `Error`. Because `ApiError extends
Error`, existing `instanceof Error` checks and `.message` strings are preserved.
Callers read a code through a tolerant helper `readErrorCode(error)` returning
`data.code ?? data.errorCode` (the exact field is unverified — A7). Errors with
no response (network failure) still surface as an `Error` with `status`
`undefined` and no code.

## Alternatives considered

| Option | Merits | Demerits | Why rejected |
|--------|--------|----------|--------------|
| A. Throw `ApiError{message,status,data}` (chosen) | Codes/status reach callers; class already exists; backward compatible | One app-wide behaviour change | Smallest change that removes message sniffing |
| B. Leave `handleApiError` and map message strings in the feature (previous plan) | Zero blast radius | Brittle; cannot tell 404 from 403 reliably; FU3 forever | Gate-1 feedback; codes are required by AC14 |
| C. Add a second error class just for this feature | Localised | Two error contracts in one client; callers must know which | Duplicates an existing class for no gain |
| D. Catch in each service and re-wrap | Per-call control | Repeats logic in 17 functions; interceptor still discards first | Same data loss, more code |

## Consequences

- **Accepted cost:** every service now receives `ApiError`; any consumer relying
  on exact `Error` constructor identity (none verified) could notice. Message text
  is unchanged, so UI that only shows `error.message` is unaffected.
- **Follow-on obligations:** P1 lands the change with `apiError.test.ts`; P9's
  `errorMessageFor` reads `status`/`readErrorCode`; the exact code field name (A7)
  stays isolated in `readErrorCode`, not spread across call sites.
- **Revisit if:** the backend standardises a different code location, or a
  consumer needs the full axios error object (then extend `ApiError`).

## Verification

- `__tests__/shipmentInvoice/apiError.test.ts`: `ApiError` is thrown with the
  right `status`+`data`, `readErrorCode` reads both `code` and `errorCode`, a
  no-response error stays a plain `Error`, and `instanceof Error`/message are
  preserved (AC15).
- Full `npx jest` (AC5) shows no new failures versus the P1 baseline — the change
  is app-wide and must not break existing screens.
- Grep gate: `rg "handleApiError" src/services/apiClient.ts` shows the throw of
  `ApiError`, not `new Error`.
