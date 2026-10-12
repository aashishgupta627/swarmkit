# P1 - Foundation: jest harness + ApiError contract

**Depends on:** P0
**Unblocks:** P2, P3
**Status:** planned

## Scope

This phase lands two independent foundation pieces, because every later gate
depends on both:

**A. Restore the jest harness** (declared baseline debt this task now owns, Q5).
`jest.config.js` (unchanged, read-only) declares `setupFiles:
['./jest.setup.js']` and maps images/styles to `__mocks__/{fileMock,styleMock}.js`.
All three are verified absent, so jest cannot resolve and **no** test runs.

Create:

- `jest.setup.js` — register the pre-existing axios mock so the axios-based tests
  resolve. `__tests__/mocks/axios.js` exists and is used by
  `__tests__/services/auth.test.ts` (which calls `(axios.create as jest.Mock)()`),
  so the setup file wires `jest.mock('axios', …)` to that mock (match its
  default-export shape).
- `__mocks__/fileMock.js` — `module.exports = 'file-stub';`
- `__mocks__/styleMock.js` — `module.exports = {};`

Do **not** edit `jest.config.js` or the two existing test files.

**B. Fix `handleApiError` to throw `ApiError`** (user-authorized, now in
contract — ADR-003). In `src/services/apiClient.ts`, `handleApiError` currently
throws a plain `Error(message)`, discarding `status` and the backend body, so
codes (`REASON_REQUIRED`, `INVALID_BUSINESS_DATA`, `INVALID_STATE_TRANSITION`, …)
cannot reach callers. The `ApiError` class (`message`, `status?`, `data?`,
`name='ApiError'`) already exists in this file. Change `handleApiError` to throw
that class, carrying the HTTP status and the full response body.

Files:

- `jest.setup.js`, `__mocks__/fileMock.js`, `__mocks__/styleMock.js` — new.
- `src/services/apiClient.ts` — `handleApiError` only.
- `__tests__/shipmentInvoice/apiError.test.ts` — new.

## Design

`ApiError extends Error`, so `instanceof Error` and existing `.message` strings
are preserved — the change is backward compatible (ADR-003). The error-code field
name is tolerated: `data.code ?? data.errorCode` (A7) is read by a small
`readErrorCode(error)` helper, not hard-coded at every call site.

## Tests

`__tests__/shipmentInvoice/apiError.test.ts`:

- A 400 response with body `{code:'REASON_REQUIRED'}` → thrown error is
  `instanceof ApiError`, `status===400`, `data` deep-equals the body, and
  `readErrorCode` returns `'REASON_REQUIRED'`. (AC15)
- The same with `{errorCode:'INVALID_STATE_TRANSITION'}` → `readErrorCode`
  returns it (tolerant field). (AC15)
- A network error with no response → still an `Error` with a message; `status`
  is `undefined` and `readErrorCode` returns `undefined` (no throw). (AC15)
- Backward compatibility: `instanceof Error` and the message text are unchanged
  from the old behaviour. (AC15)

## Exit gate

1. `npx jest --listTests` exits `0`.
2. `npx jest __tests__/shipmentInvoice/apiError.test.ts` exits `0`. (AC15)
3. `npx jest` runs to completion; the run/pass/fail/error/skip summary is
   recorded to `swarmkit/.swarm/logs/shipment-invoice-automation/001-harness.md`
   — this count is the AC5 baseline.

## Escalation triggers

1. The suite cannot run without rewriting the two existing tests (as opposed to
   adding the missing setup/mocks) — stop; rewriting existing tests is outside
   this contract.
2. The `react-native` preset needs more transform/setup than the three declared
   files — stop; widening `jest.config.js` is beyond the authorised fix.
3. Throwing `ApiError` from `handleApiError` breaks another screen or an existing
   test expectation (beyond `apiError.test.ts`) — stop (escalation #5 in
   `00-plan.md` §8); this change must stay backward compatible.
4. The backend error code is not reachable at `data.code`/`data.errorCode` (A7) —
   stop and supply the payload shape; do not guess.
