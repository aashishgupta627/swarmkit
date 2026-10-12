# P1 - Harness restored + ApiError contract

Date: 2026-10-09
Commit: this phase's feature commit (P1)

## What changed

- `jest.setup.js` (new) — wires the pre-existing `__tests__/mocks/axios.js`
  default mock (`jest.mock('axios', ...)`), plus the native-module mocks the
  axios import chain needs under jest: `react-native-config` (reads
  `RNCConfigModule`) and `@react-native-async-storage/async-storage` (ships its
  own jest mock). Without these the module graph cannot be imported at all.
- `__mocks__/fileMock.js` (new) — `module.exports = 'file-stub';`
- `__mocks__/styleMock.js` (new) — `module.exports = {};`
- `src/services/apiClient.ts` — `handleApiError` now throws `ApiError`
  (message, HTTP `status`, response `data`) instead of a plain `Error`;
  new exported `readErrorCode(error)` reads `data.code ?? data.errorCode`
  (A7). Messages are unchanged.
- `__tests__/shipmentInvoice/apiError.test.ts` (new) — 5 tests (AC15).

Not edited: `jest.config.js`, `__tests__/App.test.tsx`,
`__tests__/services/auth.test.ts`, `__tests__/mocks/axios.js`.

## Exit gate

1. `npx jest --listTests` → **exit 0** (4 paths listed).
2. `npx jest __tests__/shipmentInvoice/apiError.test.ts` → **exit 0**,
   `Test Suites: 1 passed`, `Tests: 5 passed, 5 total`.
3. `npx jest` → ran to completion. Summary (AC5 baseline):

```
Test Suites: 3 failed, 1 passed, 4 total
Tests:       5 failed, 5 passed, 10 total
Snapshots:   0 total
Time:        10.216 s
Ran all test suites.
```

## Full-run failure breakdown (pre-existing, recorded as the AC5 baseline)

- `__tests__/services/auth.test.ts` — suite resolves and runs; all 5 tests fail
  on assertions. The tests stub `(axios.create as jest.Mock)().get` and expect
  GET `/users`, but the current `src/services/auth.ts` calls
  `authApi.post('/api/users/isValidUsername', ...)`; `sendOTP`/`verifyOTP` stub
  `.post` on a freshly created (different) instance, so the calls land on the
  un-stubbed shared `authApi`. Test-vs-source drift, not a harness fault.
- `__tests__/App.test.tsx` — suite fails to run:
  `TurboModuleRegistry.getEnforcing(...): 'RNGestureHandlerModule' could not be
  found` (App → `@react-navigation/stack` → `react-native-gesture-handler`; no
  gesture-handler jest setup registered).
- `__tests__/mocks/axios.js` — jest `testMatch` collects any file under
  `__tests__/`, so the mock is reported as a suite: "Your test suite must
  contain at least one test." `jest.config.js` is read-only in P1.

Resulting baseline for AC5 (P9): **1 passing suite / 5 passing tests /
3 failing suites / 5 failing tests**, full-run exit 1.
