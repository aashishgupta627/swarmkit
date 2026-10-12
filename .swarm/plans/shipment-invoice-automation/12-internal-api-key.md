# P12 - Internal API key for local `documents/process`

**Depends on:** P3 (service + `service.test.ts` exist); independent of P4-P11.
**Unblocks:** manual E2E of the process step against the local backend (AC8, P11).
**Status:** planned
**Decision:** GATE2-APIKEY — local-only shim, not a product feature.

## Scope

The backend `InternalApiKeyFilter` rejects `POST /api/v1/documents/process`
without an `x-internal-api-key` header. P12 attaches that header **only** to the
process call and **only** when a key is configured, so native/production behavior
is unchanged. The key lives in a **gitignored** `.env.local`, read as a
dev-only override of `.env`.

No new dependency. No change to native code paths, `apiClient.ts`, router,
screens or any other service call.

## Files to change

| File | Change |
|------|--------|
| `src/services/shipmentInvoiceService.ts` | `processDocument` only (lines 90-92): attach header when key present |
| `src/config/environment.ts` | expose `internalApiKey: Config.INTERNAL_API_KEY ?? ''` |
| `src/web/config.ts` | expose `INTERNAL_API_KEY: process.env.INTERNAL_API_KEY` |
| `webpack.config.js` | dev-only `.env.local` override layer over `.env` |
| `__tests__/shipmentInvoice/service.test.ts` | 2 cases + config mock (below) |
| `.gitignore` | add `.env.local` |
| `dist/**` | rebuild/stage only if `build:web` output changes (AC17) |

`.env.local` is created by the developer, **not committed**; it holds the local
placeholder `INTERNAL_API_KEY=Dev-X-Internal-Api-Key`. The tracked `.env` must
**not** gain this key.

## Design

**Web env chain (existing):** `webpack.config.js:readEnvFile` parses `NODE_ENV==='production' ? '.env.production' : '.env'` and injects the values into
`process.env` via `DefinePlugin` (webpack.config.js:36-37,116-122). The
`react-native-config` import is aliased to `src/web/config.ts` (webpack.config.js:64),
which reads `process.env.*`; `src/config/environment.ts` re-exports them as a
typed object.

**`.env.local` layer (webpack.config.js):** keep `.env`/`.env.production` as the
base and merge `.env.local` **only in development** (NODE_ENV not `production`) so
`start:web` picks it up and `build:web` (which forces `NODE_ENV=production`) does
**not** bake the key into `dist/`:

```js
const isProd = process.env.NODE_ENV === 'production';
const envValues = {
  ...readEnvFile(isProd ? '.env.production' : '.env'),
  ...(isProd ? {} : readEnvFile('.env.local')), // dev-only override
};
```

**Config exposure:** add `INTERNAL_API_KEY` to the web `config.ts` object and
`internalApiKey: Config.INTERNAL_API_KEY ?? ''` to `environment.ts` (mirrors the
existing four fields). Native `react-native-config` reads `ENVFILE`
(`.env.development`/`.env.production`, package.json:6-9), never `.env.local`, so on
native `Config.INTERNAL_API_KEY` is `undefined` → `''` → no header.

**Header on the process call only** — branch so the unconfigured path keeps the
exact 2-arg call the existing test asserts (no trailing-`undefined` ambiguity):

```ts
processDocument: async (s3Key: string): Promise<void> => {
  const key = environment.internalApiKey;
  if (key) {
    await agentApi.post('/api/v1/documents/process', { s3Key },
      { headers: { 'x-internal-api-key': key } });
  } else {
    await agentApi.post('/api/v1/documents/process', { s3Key });
  }
},
```

Import `environment` from `../config/environment` (already the convention in
`apiClient.ts:4`, `notificationSocket.ts:3`). Header name is lowercase
`x-internal-api-key` as stated in GATE2-APIKEY.

## Tests

`__tests__/shipmentInvoice/service.test.ts` — the suite already mocks
`../../src/services/apiClient` (lines 10-17) and asserts the process call
(lines 80-88). Add a mock of the config source so the key is controllable without
loading `react-native-config` under the RN preset:

- `jest.mock('../../src/config/environment', () => ({ __esModule: true, default:
  { authApiBaseUrl: '', userApiBaseUrl: '', agentApiBaseUrl: '', wsBaseUrl: '',
  internalApiKey: '' } }))`, then a mutable holder toggled per test.

| Test | Assertion | AC |
|------|-----------|-----|
| header present when configured | key set → `post` called with `(path, {s3Key}, {headers:{'x-internal-api-key': <key>}})` | AC-AK1 |
| header absent when empty | key `''` → `post` called with exactly `(path, {s3Key})` (2 args, unchanged) | AC-AK1, AC-AK3 |
| other calls unaffected (negative) | `createAutomation`/`presign` receive no third-arg header config with the key set | AC-AK1 |

## Exit gate

1. `npx jest __tests__/shipmentInvoice/service.test.ts` exits 0, including the two
   key cases above.
2. `npm run build:web` exits 0; the production bundle contains **no**
   `Dev-X-Internal-Api-Key` (grep `dist/*.js`), rebuilt `dist/` staged per AC17.
3. `npx eslint src/services/shipmentInvoiceService.ts src/config/environment.ts
   src/web/config.ts __tests__/shipmentInvoice/service.test.ts` exits 0.
4. `npx tsc --noEmit` error count ≤ 136 (P0 baseline; no new errors in touched files).

## Acceptance criteria (phase-local)

- **AC-AK1** — `processDocument` sends `x-internal-api-key` with the configured
  value and only for this call; no header when the key is empty. (supports AC8)
- **AC-AK2** — `.env.local` overrides `.env` in development only; a production
  build (`build:web`) does not include the key. (supports R12)
- **AC-AK3** — native path unchanged: empty native config → no header. (R1)
- **AC-AK4** — gates green: `service.test.ts`, `build:web` 0, eslint 0 on touched,
  `tsc ≤ 136`. (AC1-AC3, R12)

These are phase-local ids; the orchestrator folds them into `00-plan.md` §6.

## Escalation triggers

1. `react-native-config` cannot be resolved/mocked under the RN jest preset
   without editing `jest.config.js` — stop; do not touch the harness (P1 owns it).
2. The header would need to be attached on native/production paths too, or sent on
   any call other than `documents/process` — stop; local web-only by decision.
3. `build:web` bakes the key into the committed `dist/` (the `.env.local` guard
   failed) — stop; that is a leak, do not stage `dist/`.
4. `.env.local` cannot be added to `.gitignore` without disturbing tracked `.env`
   — stop; never commit `.env.local`.
