# ADR 001: Frontend stack and screen-integration approach (recorded, not re-debated)

- **Status:** accepted
- **Date:** 2026-10-09
- **Task:** shipment-invoice-automation (repo-wide stack record)

## Context

The repo had no live decision record for its stack. Every new feature dispatch
would otherwise re-derive why the web target is webpack + react-native-web rather
than a separate SPA, and why new screens are wired through
`AppNavigator.web.tsx`'s `Page` union rather than a router. Shipment Invoice is
the first whole-screen flow added since that question last arose, so the current
stack is written down **as found, assumed, not re-debated**. (This supersedes the
2026-10-08 ADR-001 that lived at repo-root `.swarm/` and was deleted in the
working tree.)

## Decision

The stack in `package.json` at `c50b572` (unchanged since `1a267e6`) stands as-is:

- **Runtime/language:** TypeScript 5 (`strict`), React 19.1, React Native 0.80.
- **Web target:** `react-native-web` through webpack 5 (`webpack.config.js`,
  entry `index.web.js`, `.web.tsx` resolution first, dev server 127.0.0.1:8080).
- **Mobile target:** Metro + React Navigation, unchanged and out of scope.
- **UI:** `react-native-paper` 5 + `react-native-vector-icons`, themed via
  `useAppTheme()` / `createGlobalStyles()`, web dialogs via `useWebAlert()`.
- **HTTP:** `axios` through the three instances in `src/services/apiClient.ts`
  (`authApi`/`userApi`/`agentApi`); bearer from the keychain shim
  (`src/web/keychain.ts`); base URLs from `.env*` via `react-native-config`
  (`.env` values are secrets, provided via environment configuration and never
  committed).
- **Web routing:** the `Page` union + lazy `.web.tsx` imports inside
  `src/navigator/AppNavigator.web.tsx`. No URL router exists.
- **State:** React context + local component state; no Redux/Zustand/react-query.
- **Tests/lint/format:** jest 29 (`react-native` preset), eslint
  (`@react-native`), prettier (singleQuote, trailingComma `all`).

New features follow the established seam: `*.web.tsx` screens under
`src/screens/<feature>/`, one service module per backend area under
`src/services/`, shared types under `src/types/`, wired into
`AppNavigator.web.tsx` only.

## Alternatives considered

| Option | Merits | Demerits | Why rejected |
|--------|--------|----------|--------------|
| A. Keep the stack above (chosen) | Zero migration; theming/auth already work; smallest diff | Two render targets; no deep-linkable URLs | This is the current, working state |
| B. Extract the web app onto a router (react-router / Next) | Deep links, shareable review URLs | Rewrites nav/auth guard/lazy loading; touches mobile-unrelated code | Turns a screen feature into a migration |
| C. Use react-navigation for web too | One nav model | `AppNavigator.web.tsx` deliberately uses a custom shell; `RoleBasedNavigator` is mobile-shaped | Rewrites a working shell with no requirement |
| D. Add react-query/SWR for polling | Cache/dedupe/retry for `GET …/review` | New dependency; a 15 s `setInterval` + explicit refetch is ~50 lines | Deferred — see ADR-002 |

## Consequences

- **Accepted cost:** web pages are not bookmarkable; a reload lands on `home`, so
  an in-progress run cannot resume (follow-up FU2).
- **Follow-on obligations:** web-only work must not modify
  `AppNavigator.tsx`,   `RoleBasedNavigator.tsx`, or `types/navigation.ts`. `dist/`
  is tracked; per Q3 the **rebuilt** `dist/` is committed **with** each feature
  phase that builds (P4/P6/P8/P9/P10), and builders must stage only their own
  build output, never the pre-existing stale `dist/` churn (AC17). `apiClient.ts`
  is no longer frozen: its `handleApiError` is in contract for this task (ADR-003).
- **Revisit if:** a task needs deep links/URL state, or polling grows beyond a
  single screen — then supersede with an ADR for routing/server-state.

## Verification

- Plan AC6: `git diff --name-only <base>...HEAD` contains no
  `src/navigator/AppNavigator.tsx`, `src/navigator/RoleBasedNavigator.tsx`, or
  `src/types/navigation.ts`.
- `git diff package.json` shows no added runtime dependency.
