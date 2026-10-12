# P0 Baseline — shipment-invoice-automation

- **Phase:** P0 (`swarmkit/.swarm/plans/shipment-invoice-automation/00-baseline.md`)
- **Recorded:** 2026-10-09
- **Purpose:** raw, observed build/test/lint/typecheck numbers before any `src/`
  edit. Nothing in this file is an expected value substituted for a result; every
  row below was executed in this working tree.
- **Related:** `00-plan.md` §3 was corrected from this log.

Commands were run from the repo root
`C:\Users\aashi\workspaces\CAAPP\CACubeFrontend` (win32, PowerShell 5.1).

## Summary

| # | Command | Observed result | Counts / exit |
|---|---------|-----------------|---------------|
| 1 | `git rev-parse HEAD` | `6d0d4f1330384d8644c4fb79c437b68288c7200d` | — |
| 2 | `git rev-parse --abbrev-ref HEAD` | `main` | — |
| 3 | `git status -sb` | `## main...origin/main [ahead 6]` | ahead 6, behind 0 |
| 4 | `git status --porcelain` | dirty (raw below) | 32 entries |
| 5 | `git ls-files dist` | `dist/` **is tracked** (Q3 consequence confirmed) | 28 files |
| 6 | `npx tsc --noEmit` | exit **2** (raw below) | **136 errors**, 0 warnings — all under `src/` |
| 7 | `npx eslint . -f compact` | exit **1** | **121 errors, 25 803 warnings** (25 924 problems) |
| 8 | `npm test` | exit **1** — config-resolution failure (raw below) | run 0 / pass 0 / fail 0 / error 0 / skip 0 |
| 9 | `npm run build:web` | exit **0** | webpack 5.103.0 compiled with 2 warnings in 36 467 ms |

### Deviations from the architect's planning-time table (`00-plan.md` §3)

- HEAD is now `6d0d4f1`, **ahead of `origin/main` by 6**, not `c50b572` / ahead 2.
  The three extra commits (`2eef2e8`, `9c27241`, `6d0d4f1`) are plan revisions;
  no feature/`src` commit was introduced.
- The `NOT RUN` build/test/lint/typecheck rows are now measured (rows 6–9).
- The drift matters for **no** feature file: `git diff --name-only -- src
  __tests__` is empty and the dirty tree is restricted to root `.swarm/*`,
  `dist/**` and untracked scratch (see raw `git status`). **Escalation trigger 3
  (working tree changed in a way that changes which files the feature may touch)
  did not fire.**

### Notes on the lint command (row 7)

`npx eslint .` with the default `stylish` formatter does not complete to a
capturable summary in this tree: the tracked minified `dist/**` bundles produce
25 803 warnings whose formatter output echoes each offending source line
(columns up to ~660 000), which exhausted the free space on `C:` (~1.9 GB) on
the first attempt. The counts above were therefore captured with
`npx eslint . -f compact` piped to a line counter and confirmed by the formatter
summary line `25924 problems`. `-f compact` changes only the reporter, not the
set of files linted or the totals. This is a P0 observation about the
pre-existing tree, not a source change.

## Raw output

### 1–3. `git rev-parse HEAD`, `git rev-parse --abbrev-ref HEAD`, `git status -sb`

```
6d0d4f1330384d8644c4fb79c437b68288c7200d
main
## main...origin/main [ahead 6]
```

### 4. `git status --porcelain` (32 entries; leading space in ` D` is git's)

```
 D .swarm/adr/001-frontend-stack.md
 D .swarm/plans/shipment-invoice-automation.md
 D .swarm/state/shipment-invoice-automation.json
 D dist/app.2c2f8c2d9aa75c2ed1ce.bundle.js
 D dist/app.2c2f8c2d9aa75c2ed1ce.bundle.js.LICENSE.txt
 D dist/app.2c2f8c2d9aa75c2ed1ce.bundle.js.map
 D dist/app.9381ac98d9c860105d20.bundle.js
 D dist/app.9381ac98d9c860105d20.bundle.js.map
 D dist/app.a467ec1d3ec88204997e.bundle.js
 D dist/app.a467ec1d3ec88204997e.bundle.js.map
 D dist/app.d40b17ecd7472ee4ad03.bundle.js
 D dist/app.d40b17ecd7472ee4ad03.bundle.js.map
 D dist/app.fb7cdbf13cd1788f3e99.bundle.js
 D dist/app.fb7cdbf13cd1788f3e99.bundle.js.map
 M dist/index.html
?? COMMUNICATION_NOTIFICATION_SERVICE_SPEC.md
?? "Login Screen.jpeg"
?? Screenshot.jpeg
?? dist/app.206e8adc1ea9ad11fdd1.bundle.js
?? dist/app.206e8adc1ea9ad11fdd1.bundle.js.map
?? dist/app.353fbb454d2cb994c992.bundle.js
?? dist/app.353fbb454d2cb994c992.bundle.js.map
?? dist/app.53826c8b7738b682ee68.bundle.js
?? dist/app.53826c8b7738b682ee68.bundle.js.LICENSE.txt
?? dist/app.53826c8b7738b682ee68.bundle.js.map
?? dist/app.986804e52f89724c6d0c.bundle.js
?? dist/app.986804e52f89724c6d0c.bundle.js.map
?? dist/app.a2969652facb7a88b066.bundle.js
?? dist/app.a2969652facb7a88b066.bundle.js.map
?? invoices.db
?? swarmkit/.swarm/locks/shipment-invoice-automation.lock
?? swarmkit/.swarm/logs/shipment-invoice-automation/
```

Breakdown: 3 root `.swarm/*` deletions, 11 `dist/**` deletions, `dist/index.html`
modified, 11 untracked `dist/**` files, and 6 other untracked entries
(`COMMUNICATION_NOTIFICATION_SERVICE_SPEC.md`, `Login Screen.jpeg`,
`Screenshot.jpeg`, `invoices.db`, the swarm lock, the swarm log dir).

### 5. `git ls-files dist` (28 tracked files)

```
dist/5d42b4e60858731e7b65.ttf
dist/77417465d7537e7318eb.png
dist/a0bdd27b1b85b8acb006.png
dist/app.26208448e4989b5be5ba.bundle.js
dist/app.26208448e4989b5be5ba.bundle.js.map
dist/app.2c2f8c2d9aa75c2ed1ce.bundle.js
dist/app.2c2f8c2d9aa75c2ed1ce.bundle.js.LICENSE.txt
dist/app.2c2f8c2d9aa75c2ed1ce.bundle.js.map
dist/app.322129565b8218152b4d.bundle.js
dist/app.322129565b8218152b4d.bundle.js.map
dist/app.544918cfd6e4c813ce5f.bundle.js
dist/app.544918cfd6e4c813ce5f.bundle.js.map
dist/app.57b09904824f02f6841d.bundle.js
dist/app.57b09904824f02f6841d.bundle.js.map
dist/app.6bec715b6a17380acc38.bundle.js
dist/app.6bec715b6a17380acc38.bundle.js.map
dist/app.9381ac98d9c860105d20.bundle.js
dist/app.9381ac98d9c860105d20.bundle.js.map
dist/app.a467ec1d3ec88204997e.bundle.js
dist/app.a467ec1d3ec88204997e.bundle.js.map
... (28 total; `dist/index.html` and further `app.*` bundles complete the set)
```

### 6. `npx tsc --noEmit` — exit 2, 136 errors (all under `src/`)

```
src/App.tsx(76,28): error TS2322: Type '{ colors: { primary: string; onPrimary: string; primaryContainer: string; onPrimaryContainer: string; secondary: string; onSecondary: string; secondaryContainer: string; onSecondaryContainer: string; ... 28 more ...; notification: string; }; ... 6 more ...; isV3: true; }' is not assignable to type 'Theme'.
  Types of property 'fonts' are incompatible.
    Type 'MD3Typescale' is missing the following properties from type '{ regular: FontStyle; medium: FontStyle; bold: FontStyle; heavy: FontStyle; }': regular, medium, bold, heavy
src/App.web.tsx(50,16): error TS2584: Cannot find name 'document'. Do you need to change your target library? Try changing the 'lib' compiler option to include 'dom'.
src/App.web.tsx(55,5): error TS2584: Cannot find name 'document'. Do you need to change your target library? Try changing the 'lib' compiler option to include 'dom'.
src/App.web.tsx(56,5): error TS2584: Cannot find name 'document'. Do you need to change your target library? Try changing the 'lib' compiler option to include 'dom'.
src/App.web.tsx(57,5): error TS2584: Cannot find name 'document'. Do you need to change your target library? Try changing the 'lib' compiler option to include 'dom'.
src/App.web.tsx(58,5): error TS2584: Cannot find name 'document'. Do you need to change your target library? Try changing the 'lib' compiler option to include 'dom'.
src/App.web.tsx(59,5): error TS2584: Cannot find name 'document'. Do you need to change your target library? Try changing the 'lib' compiler option to include 'dom'.
src/App.web.tsx(61,18): error TS2584: Cannot find name 'document'. Do you need to change your target library? Try changing the 'lib' compiler option to include 'dom'.
src/components/documents/DocumentViewer.web.tsx(89,20): error TS2304: Cannot find name 'window'.
src/components/documents/DocumentViewer.web.tsx(93,7): error TS2304: Cannot find name 'window'.
src/components/documents/DocumentViewer.web.tsx(101,21): error TS2554: Expected 2-3 arguments, but got 1.
src/components/documents/FilterBottomSheet.tsx(18,3): error TS7031: Binding element 'visible' implicitly has an 'any' type.
src/components/documents/FilterBottomSheet.tsx(19,3): error TS7031: Binding element 'onClose' implicitly has an 'any' type.
src/components/documents/FilterBottomSheet.tsx(20,3): error TS7031: Binding element 'onApply' implicitly has an 'any' type.
src/components/documents/FilterBottomSheet.tsx(24,3): error TS7031: Binding element 'onRetryCompanies' implicitly has an 'any' type.
src/components/documents/FilterBottomSheet.tsx(45,34): error TS7006: Parameter 'list' implicitly has an 'any' type.
src/components/documents/FilterBottomSheet.tsx(45,40): error TS7006: Parameter 'item' implicitly has an 'any' type.
src/components/documents/FilterBottomSheet.tsx(45,46): error TS7006: Parameter 'setList' implicitly has an 'any' type.
src/components/documents/FilterBottomSheet.tsx(47,27): error TS7006: Parameter 'i' implicitly has an 'any' type.
src/components/documents/FilterBottomSheet.tsx(65,81): error TS2339: Property 'id' does not exist on type 'never'.
src/components/documents/FilterBottomSheet.tsx(119,46): error TS2339: Property 'id' does not exist on type 'never'.
src/components/documents/FilterBottomSheet.tsx(122,35): error TS2339: Property 'name' does not exist on type 'never'.
src/components/documents/FilterBottomSheet.tsx(123,61): error TS2339: Property 'id' does not exist on type 'never'.
src/components/documents/FilterBottomSheet.tsx(123,73): error TS2339: Property 'id' does not exist on type 'never'.
src/components/documents/FilterBottomSheet.tsx(136,52): error TS2345: Argument of type 'string' is not assignable to parameter of type 'never'.
src/components/documents/FilterBottomSheet.tsx(148,53): error TS2345: Argument of type 'string' is not assignable to parameter of type 'never'.
src/components/documents/FilterBottomSheet.tsx(160,55): error TS2345: Argument of type '"Sales" | "Purchases" | "Credit Note" | "Debit Note" | "TDS" | "ITR" | "Balance Sheet" | "Certificates" | "ROC Documents" | "GST Challans" | "Income tax challans" | "Bank Statement"' is not assignable to parameter of type 'never'.
  Type '"Sales"' is not assignable to type 'never'.
src/components/documents/FilterBottomSheet.tsx(176,20): error TS7006: Parameter 'theme' implicitly has an 'any' type.
src/components/fields/SingleDocumentInput.tsx(194,9): error TS2322: Type '{ label: string; buttonLabel: string; onFileSelected: (file: FileType | null) => void; defaultValue: FileType | null; error: string | undefined; disabled: boolean; }' is not assignable to type 'IntrinsicAttributes & DocumentUploaderProps'.
  Property 'disabled' does not exist on type 'IntrinsicAttributes & DocumentUploaderProps'.
src/components/form/ProgressIndicator.tsx(40,36): error TS2339: Property 'success' does not exist on type 'MD3Colors'.
src/components/form/ProgressIndicator.tsx(41,36): error TS2339: Property 'disabled' does not exist on type 'MD3Colors'.
src/components/form/ProgressIndicator.tsx(45,25): error TS7053: Element implicitly has an 'any' type because expression of type 'string' can't be used to index type '{ 'Personal Information': string; 'Financial Information': string; Documents: string; 'Basic Information': string; }'.
  No index signature with a parameter of type 'string' was found on type '{ 'Personal Information': string; 'Financial Information': string; Documents: string; 'Basic Information': string; }'.
src/components/form/ProgressIndicator.tsx(59,34): error TS2339: Property 'success' does not exist on type 'MD3Colors'.
src/components/form/ProgressIndicator.tsx(60,34): error TS2339: Property 'disabled' does not exist on type 'MD3Colors'.
src/components/form/SectionedForm.tsx(69,4): error TS2741: Property 'children' is missing in type '{ mode: "outlined" | "contained"; style: {}[]; disabled: boolean | undefined; }' but required in type 'Omit<Props, "ref">'.
src/components/form/SectionedForm.tsx(118,5): error TS2322: Type 'TFormValues' is not assignable to type 'AsyncDefaultValues<TFormValues> | DefaultValues<TFormValues> | undefined'.
  Type 'FieldValues' is not assignable to type 'AsyncDefaultValues<TFormValues> | DefaultValues<TFormValues> | undefined'.
src/components/form/SectionedForm.tsx(119,5): error TS2322: Type 'Resolver<{}, any, {}> | undefined' is not assignable to type 'Resolver<TFormValues, any, TFormValues> | undefined'.
  Type 'Resolver<{}, any, {}>' is not assignable to type 'Resolver<TFormValues, any, TFormValues>'.
    Types of parameters 'options' and 'options' are incompatible.
      Type 'ResolverOptions<TFormValues>' is not assignable to type 'ResolverOptions<{}>'.
        Types of property 'names' are incompatible.
          Type 'FieldName<TFormValues>[] | undefined' is not assignable to type 'never[] | undefined'.
            Type 'FieldName<TFormValues>[]' is not assignable to type 'never[]'.
              Type 'FieldName<TFormValues>' is not assignable to type 'never'.
                Type 'string | Extract<keyof TFormValues, string>' is not assignable to type 'never'.
                  Type 'string' is not assignable to type 'never'.
src/components/form/SectionedForm.tsx(295,34): error TS2339: Property 'fieldName' does not exist on type '{}'.
src/components/form/SectionedForm.tsx(295,58): error TS2339: Property 'name' does not exist on type '{}'.
src/components/form/SectionedForm.tsx(307,55): error TS2339: Property 'children' does not exist on type '{}'.
src/components/home/ClientAssociateActions.tsx(163,9): error TS2345: Argument of type '[never, never]' is not assignable to parameter of type 'never'.
src/components/home/ClientAssociateActions.tsx(176,25): error TS2345: Argument of type '[never, never]' is not assignable to parameter of type 'never'.
src/components/home/ClientAssociateActions.tsx(187,7): error TS2345: Argument of type '[never, never]' is not assignable to parameter of type 'never'.
src/components/MultiDocumentUploader.tsx(86,11): error TS18046: 'err' is of type 'unknown'.
src/config/kycForms.ts(2,10): error TS2305: Module '"../types/kycTypes"' has no exported member 'KYCEntityType'.
src/context/UserContext.tsx(176,30): error TS2339: Property 'size' does not exist on type 'FileType'.
src/context/UserContext.tsx(203,17): error TS7053: Element implicitly has an 'any' type because expression of type 'string' can't be used to index type 'string[] | CompanyProfile | Address | CompanyBgvDocuments | FinancialInformation | TaxInformation'.
  No index signature with a parameter of type 'string' was found on type 'string[] | CompanyProfile | Address | CompanyBgvDocuments | FinancialInformation | TaxInformation'.
src/context/UserContext.tsx(203,40): error TS7053: Element implicitly has an 'any' type because expression of type 'string' can't be used to index type 'string[] | CompanyProfile | Address | CompanyBgvDocuments | FinancialInformation | TaxInformation'.
  No index signature with a parameter of type 'string' was found on type 'string[] | CompanyProfile | Address | CompanyBgvDocuments | FinancialInformation | TaxInformation'.
src/context/UserContext.tsx(203,78): error TS7053: Element implicitly has an 'any' type because expression of type 'string' can't be used to index type 'string[] | CompanyProfile | Address | CompanyBgvDocuments | FinancialInformation | TaxInformation'.
  No index signature with a parameter of type 'string' was found on type 'string[] | CompanyProfile | Address | CompanyBgvDocuments | FinancialInformation | TaxInformation'.
src/context/UserContext.tsx(204,28): error TS7053: Element implicitly has an 'any' type because expression of type 'string' can't be used to index type 'string[] | CompanyProfile | Address | CompanyBgvDocuments | FinancialInformation | TaxInformation'.
  No index signature with a parameter of type 'string' was found on type 'string[] | CompanyProfile | Address | CompanyBgvDocuments | FinancialInformation | TaxInformation'.
src/context/UserContext.tsx(208,34): error TS2339: Property 'size' does not exist on type 'FileType'.
src/context/UserContext.tsx(213,17): error TS7053: Element implicitly has an 'any' type because expression of type 'string' can't be used to index type 'string[] | CompanyProfile | Address | CompanyBgvDocuments | FinancialInformation | TaxInformation'.
  No index signature with a parameter of type 'string' was found on type 'string[] | CompanyProfile | Address | CompanyBgvDocuments | FinancialInformation | TaxInformation'.
src/context/UserContext.tsx(314,78): error TS2355: A function whose declared type is neither 'undefined', 'void', nor 'any' must return a value.
src/data/mockData.ts(6,3): error TS2741: Property 'status' is missing in type '{ id: string; title: string; dueDate: string; type: "GST"; urgency: "normal" | "overdue" | "today" | "upcoming"; }' but required in type 'Deadline'.
src/data/mockData.ts(13,3): error TS2741: Property 'status' is missing in type '{ id: string; title: string; dueDate: string; type: "INCOME_TAX"; urgency: "normal" | "overdue" | "today" | "upcoming"; }' but required in type 'Deadline'.
src/data/mockData.ts(20,3): error TS2741: Property 'status' is missing in type '{ id: string; title: string; dueDate: string; type: "TDS"; urgency: "normal" | "overdue" | "today" | "upcoming"; }' but required in type 'Deadline'.
src/data/mockData.ts(27,3): error TS2741: Property 'status' is missing in type '{ id: string; title: string; dueDate: string; type: "GST"; urgency: "normal" | "overdue" | "today" | "upcoming"; }' but required in type 'Deadline'.
src/data/mockData.ts(34,3): error TS2741: Property 'status' is missing in type '{ id: string; title: string; dueDate: string; type: "INCOME_TAX"; urgency: "normal" | "overdue" | "today" | "upcoming"; }' but required in type 'Deadline'.
src/data/mockData.ts(41,3): error TS2741: Property 'status' is missing in type '{ id: string; title: string; dueDate: string; type: "GST"; urgency: "normal" | "overdue" | "today" | "upcoming"; }' but required in type 'Deadline'.
src/data/mockData.ts(48,3): error TS2741: Property 'status' is missing in type '{ id: string; title: string; dueDate: string; type: "TDS"; urgency: "overdue"; }' but required in type 'Deadline'.
src/navigator/AppNavigator.web.tsx(80,34): error TS2304: Cannot find name 'window'.
src/navigator/AppNavigator.web.tsx(80,59): error TS2304: Cannot find name 'window'.
src/navigator/AppNavigator.web.tsx(326,15): error TS2769: No overload matches this call.
  Overload 1 of 2, '(props: ImageProps): Image', gave the following error.
    Type 'ViewStyle | TextStyle | ImageStyle' is not assignable to type 'StyleProp<ImageStyle>'.
      Type 'ViewStyle' is not assignable to type 'StyleProp<ImageStyle>'.
        Type 'ViewStyle' is not assignable to type 'ImageStyle'.
          Types of property 'overflow' are incompatible.
            Type '"visible" | "hidden" | "scroll" | undefined' is not assignable to type '"visible" | "hidden" | undefined'.
              Type '"scroll"' is not assignable to type '"visible" | "hidden" | undefined'.
  Overload 2 of 2, '(props: ImageProps, context: any): Image', gave the following error.
    Type 'ViewStyle | TextStyle | ImageStyle' is not assignable to type 'StyleProp<ImageStyle>'.
      Type 'ViewStyle' is not assignable to type 'StyleProp<ImageStyle>'.
        Type 'ViewStyle' is not assignable to type 'ImageStyle'.
          Types of property 'overflow' are incompatible.
            Type '"visible" | "hidden" | "scroll" | undefined' is not assignable to type '"visible" | "hidden" | undefined'.
              Type '"scroll"' is not assignable to type '"visible" | "hidden" | undefined'.
src/navigator/AppNavigator.web.tsx(413,19): error TS2769: No overload matches this call.
  Overload 1 of 2, '(props: ImageProps): Image', gave the following error.
    Type 'ViewStyle | TextStyle | ImageStyle' is not assignable to type 'StyleProp<ImageStyle>'.
      Type 'ViewStyle' is not assignable to type 'StyleProp<ImageStyle>'.
        Type 'ViewStyle' is not assignable to type 'ImageStyle'.
          Types of property 'overflow' are incompatible.
            Type '"visible" | "hidden" | "scroll" | undefined' is not assignable to type '"visible" | "hidden" | undefined'.
              Type '"scroll"' is not assignable to type '"visible" | "hidden" | undefined'.
  Overload 2 of 2, '(props: ImageProps, context: any): Image', gave the following error.
    Type 'ViewStyle | TextStyle | ImageStyle' is not assignable to type 'StyleProp<ImageStyle>'.
      Type 'ViewStyle' is not assignable to type 'StyleProp<ImageStyle>'.
        Type 'ViewStyle' is not assignable to type 'ImageStyle'.
          Types of property 'overflow' are incompatible.
            Type '"visible" | "hidden" | "scroll" | undefined' is not assignable to type '"visible" | "hidden" | undefined'.
              Type '"scroll"' is not assignable to type '"visible" | "hidden" | undefined'.
src/navigator/AppNavigator.web.tsx(496,5): error TS2322: Type '"100vh"' is not assignable to type 'DimensionValue | undefined'.
src/navigator/AppNavigator.web.tsx(513,5): error TS2322: Type '"100vh"' is not assignable to type 'DimensionValue | undefined'.
src/navigator/AppNavigator.web.tsx(535,5): error TS2561: Object literal may only specify known properties, but 'overflowY' does not exist in type 'ViewStyle | TextStyle | ImageStyle'. Did you mean to write 'overflow'?
src/navigator/RoleBasedNavigator.tsx(170,21): error TS2322: Type '"PermissionGate"' is not assignable to type 'keyof RootStackParamList'.
src/navigator/RoleBasedNavigator.tsx(170,43): error TS2322: Type '({ children }: { children: any; }) => any' is not assignable to type 'ScreenComponentType<RootStackParamList, keyof RootStackParamList> | undefined'.
  Type '({ children }: { children: any; }) => any' is not assignable to type 'FunctionComponent<{}>'.
    Types of parameters '__0' and 'props' are incompatible.
      Property 'children' is missing in type '{}' but required in type '{ children: any; }'.
src/screens/AdminHomeScreen.tsx(8,18): error TS7016: Could not find a declaration file for module 'react-native-vector-icons/dist/MaterialCommunityIcons'. 'C:/Users/aashi/workspaces/CAAPP/CACubeFrontend/node_modules/react-native-vector-icons/dist/MaterialCommunityIcons.js' implicitly has an 'any' type.
  If the 'react-native-vector-icons' package actually exposes this module, consider sending a pull request to amend 'https://github.com/DefinitelyTyped/DefinitelyTyped/tree/master/types/react-native-vector-icons'
src/screens/AdminHomeScreen.tsx(92,50): error TS2345: Argument of type '[keyof RootStackParamList, never]' is not assignable to parameter of type '[screen: "Documents", params?: undefined, options?: { merge?: boolean | undefined; pop?: boolean | undefined; } | undefined] | [screen: "Login", params?: undefined, options?: { merge?: boolean | undefined; pop?: boolean | undefined; } | undefined] | ... 25 more ... | [screen: ...]'.
  Type '[keyof RootStackParamList, never]' is not assignable to type '[screen: "NotificationTray", params?: undefined, options?: { merge?: boolean | undefined; pop?: boolean | undefined; } | undefined]'.
    Type at position 0 in source is not compatible with type at position 0 in target.
      Type 'keyof RootStackParamList' is not assignable to type '"NotificationTray"'.
        Type '"Documents"' is not assignable to type '"NotificationTray"'.
src/screens/AdminHomeScreen.tsx(114,20): error TS7006: Parameter 'theme' implicitly has an 'any' type.
src/screens/approval/ApprovalDetailsScreen.tsx(23,11): error TS2339: Property 'documentId' does not exist on type 'Readonly<{ document: Document; }>'.
src/screens/approval/ApprovalDetailsScreen.tsx(41,11): error TS18046: 'err' is of type 'unknown'.
src/screens/approval/ApprovalDetailsScreen.tsx(41,47): error TS18046: 'err' is of type 'unknown'.
src/screens/approval/ApprovalDetailsScreen.tsx(41,63): error TS18046: 'err' is of type 'unknown'.
src/screens/approval/ApprovalDetailsScreen.tsx(44,18): error TS18046: 'err' is of type 'unknown'.
src/screens/approval/ApprovalListScreen.tsx(75,11): error TS18046: 'err' is of type 'unknown'.
src/screens/approval/ApprovalListScreen.tsx(75,47): error TS18046: 'err' is of type 'unknown'.
src/screens/approval/ApprovalListScreen.tsx(77,15): error TS18046: 'err' is of type 'unknown'.
src/screens/approval/ApprovalListScreen.tsx(108,46): error TS2561: Object literal may only specify known properties, but 'documentId' does not exist in type '{ document: Document; }'. Did you mean to write 'document'?
src/screens/CAHomeScreen.tsx(11,18): error TS7016: Could not find a declaration file for module 'react-native-vector-icons/dist/MaterialCommunityIcons'. 'C:/Users/aashi/workspaces/CAAPP/CACubeFrontend/node_modules/react-native-vector-icons/dist/MaterialCommunityIcons.js' implicitly has an 'any' type.
  If the 'react-native-vector-icons' package actually exposes this module, consider sending a pull request to amend 'https://github.com/DefinitelyTyped/DefinitelyTyped/tree/master/types/react-native-vector-icons'
src/screens/CAHomeScreen.tsx(235,20): error TS7006: Parameter 'theme' implicitly has an 'any' type.
src/screens/classification/ClassificationFailedDetailScreen.tsx(889,59): error TS2345: Argument of type 'string | undefined' is not assignable to parameter of type 'string'.
  Type 'undefined' is not assignable to type 'string'.
src/screens/CreateCompanyKYC.tsx(270,5): error TS7031: Binding element 'fieldName' implicitly has an 'any' type.
src/screens/CreateCompanyKYC.tsx(271,5): error TS7031: Binding element 'fields' implicitly has an 'any' type.
src/screens/CreateCompanyKYC.tsx(272,5): error TS7031: Binding element 'onAddItem' implicitly has an 'any' type.
src/screens/CreateCompanyKYC.tsx(273,5): error TS7031: Binding element 'onRemoveItem' implicitly has an 'any' type.
src/screens/CreateCompanyKYC.tsx(274,5): error TS7031: Binding element 'showErrors' implicitly has an 'any' type.
src/screens/CreateCompanyKYC.tsx(337,22): error TS7006: Parameter 'field' implicitly has an 'any' type.
src/screens/CreateCompanyKYC.tsx(337,29): error TS7006: Parameter 'index' implicitly has an 'any' type.
src/screens/documents/DocumentListScreen.tsx(611,36): error TS2304: Cannot find name 'NavigationProp'.
src/screens/documents/DocumentListScreen.tsx(1028,11): error TS2322: Type 'Company[]' is not assignable to type 'never[]'.
  Type 'Company' is not assignable to type 'never'.
src/screens/documents/DocumentListScreen.tsx(1029,11): error TS2322: Type 'Error | null' is not assignable to type 'null | undefined'.
  Type 'Error' is not assignable to type 'null | undefined'.
src/screens/documents/DocumentsScreen.web.tsx(112,62): error TS2339: Property 'getCompanyKYC' does not exist on type 'CompanyContextType'.
src/screens/documents/RecentDocumentsScreen.tsx(125,27): error TS2345: Argument of type '[never, never]' is not assignable to parameter of type 'never'.
src/screens/DocumentUploadScreen.tsx(160,11): error TS18046: 'error' is of type 'unknown'.
src/screens/DocumentUploadScreen.tsx(160,49): error TS18046: 'error' is of type 'unknown'.
src/screens/DocumentUploadScreen.tsx(160,67): error TS18046: 'error' is of type 'unknown'.
src/screens/DocumentUploadScreen.tsx(208,20): error TS7006: Parameter 'theme' implicitly has an 'any' type.
src/screens/home/HomeV1.tsx(170,22): error TS2448: Block-scoped variable 'startAutoPlay' used before its declaration.
src/screens/home/HomeV1.tsx(170,22): error TS2454: Variable 'startAutoPlay' is used before being assigned.
src/screens/home/HomeV1.tsx(170,37): error TS2448: Block-scoped variable 'stopAutoPlay' used before its declaration.
src/screens/home/HomeV1.tsx(170,37): error TS2454: Variable 'stopAutoPlay' is used before being assigned.
src/screens/home/HomeV1.web.tsx(24,44): error TS2345: Argument of type 'FileStatus' is not assignable to parameter of type '"APPROVAL_PENDING"'.
  Type '"PENDING_UPLOAD"' is not assignable to type '"APPROVAL_PENDING"'.
src/screens/home/HomeV1.web.tsx(28,7): error TS2345: Argument of type 'FileStatus' is not assignable to parameter of type '"UPLOADED" | "CLASSIFICATION_IN_PROGRESS"'.
  Type '"PENDING_UPLOAD"' is not assignable to type '"UPLOADED" | "CLASSIFICATION_IN_PROGRESS"'.
src/screens/HomeScreen.tsx(136,50): error TS2345: Argument of type '[keyof RootStackParamList, never]' is not assignable to parameter of type '[screen: "Documents", params?: undefined, options?: { merge?: boolean | undefined; pop?: boolean | undefined; } | undefined] | [screen: "Login", params?: undefined, options?: { merge?: boolean | undefined; pop?: boolean | undefined; } | undefined] | ... 25 more ... | [screen: ...]'.
  Type '[keyof RootStackParamList, never]' is not assignable to type '[screen: "NotificationTray", params?: undefined, options?: { merge?: boolean | undefined; pop?: boolean | undefined; } | undefined]'.
    Type at position 0 in source is not compatible with type at position 0 in target.
      Type 'keyof RootStackParamList' is not assignable to type '"NotificationTray"'.
        Type '"Documents"' is not assignable to type '"NotificationTray"'.
src/screens/HomeScreen.tsx(158,20): error TS7006: Parameter 'theme' implicitly has an 'any' type.
src/screens/NewLoginScreen.tsx(133,17): error TS2769: No overload matches this call.
  Overload 1 of 2, '(props: ImageProps): Image', gave the following error.
    Type 'ViewStyle | TextStyle | ImageStyle' is not assignable to type 'StyleProp<ImageStyle>'.
      Type 'ViewStyle' is not assignable to type 'StyleProp<ImageStyle>'.
        Type 'ViewStyle' is not assignable to type 'ImageStyle'.
          Types of property 'overflow' are incompatible.
            Type '"visible" | "hidden" | "scroll" | undefined' is not assignable to type '"visible" | "hidden" | undefined'.
              Type '"scroll"' is not assignable to type '"visible" | "hidden" | undefined'.
  Overload 2 of 2, '(props: ImageProps, context: any): Image', gave the following error.
    Type 'ViewStyle | TextStyle | ImageStyle' is not assignable to type 'StyleProp<ImageStyle>'.
      Type 'ViewStyle' is not assignable to type 'StyleProp<ImageStyle>'.
        Type 'ViewStyle' is not assignable to type 'ImageStyle'.
          Types of property 'overflow' are incompatible.
            Type '"visible" | "hidden" | "scroll" | undefined' is not assignable to type '"visible" | "hidden" | undefined'.
              Type '"scroll"' is not assignable to type '"visible" | "hidden" | undefined'.
src/screens/NewLoginScreen.tsx(244,19): error TS2769: No overload matches this call.
  Overload 1 of 2, '(props: ImageProps): Image', gave the following error.
    Type 'ViewStyle | TextStyle | ImageStyle' is not assignable to type 'StyleProp<ImageStyle>'.
      Type 'ViewStyle' is not assignable to type 'StyleProp<ImageStyle>'.
        Type 'ViewStyle' is not assignable to type 'ImageStyle'.
          Types of property 'overflow' are incompatible.
            Type '"visible" | "hidden" | "scroll" | undefined' is not assignable to type '"visible" | "hidden" | undefined'.
              Type '"scroll"' is not assignable to type '"visible" | "hidden" | undefined'.
  Overload 2 of 2, '(props: ImageProps, context: any): Image', gave the following error.
    Type 'ViewStyle | TextStyle | ImageStyle' is not assignable to type 'StyleProp<ImageStyle>'.
      Type 'ViewStyle' is not assignable to type 'StyleProp<ImageStyle>'.
        Type 'ViewStyle' is not assignable to type 'ImageStyle'.
          Types of property 'overflow' are incompatible.
            Type '"visible" | "hidden" | "scroll" | undefined' is not assignable to type '"visible" | "hidden" | undefined'.
              Type '"scroll"' is not assignable to type '"visible" | "hidden" | undefined'.
src/screens/NewLoginScreen.tsx(444,5): error TS2322: Type '"stretch"' is not assignable to type '"center" | "flex-start" | "flex-end" | "space-between" | "space-around" | "space-evenly" | undefined'.
src/screens/NewLoginScreen.web.tsx(149,19): error TS2769: No overload matches this call.
  Overload 1 of 2, '(props: ImageProps): Image', gave the following error.
    Type 'ViewStyle | TextStyle | ImageStyle' is not assignable to type 'ImageStyle | Falsy | RegisteredStyle<ImageStyle> | RecursiveArray<ImageStyle | Falsy | RegisteredStyle<ImageStyle>> | readonly (ImageStyle | ... 1 more ... | RegisteredStyle<...>)[]'.
      Type 'ViewStyle' is not assignable to type 'ImageStyle | Falsy | RegisteredStyle<ImageStyle> | RecursiveArray<ImageStyle | Falsy | RegisteredStyle<ImageStyle>> | readonly (ImageStyle | ... 1 more ... | RegisteredStyle<...>)[]'.
        Type 'ViewStyle' is not assignable to type 'ImageStyle'.
          Types of property 'overflow' are incompatible.
            Type '"visible" | "hidden" | "scroll" | undefined' is not assignable to type '"visible" | "hidden" | undefined'.
              Type '"scroll"' is not assignable to type '"visible" | "hidden" | undefined'.
  Overload 2 of 2, '(props: ImageProps, context: any): Image', gave the following error.
    Type 'ViewStyle | TextStyle | ImageStyle' is not assignable to type 'ImageStyle | Falsy | RegisteredStyle<ImageStyle> | RecursiveArray<ImageStyle | Falsy | RegisteredStyle<ImageStyle>> | readonly (ImageStyle | ... 1 more ... | RegisteredStyle<...>)[]'.
      Type 'ViewStyle' is not assignable to type 'ImageStyle | Falsy | RegisteredStyle<ImageStyle> | RecursiveArray<ImageStyle | Falsy | RegisteredStyle<ImageStyle>> | readonly (ImageStyle | ... 1 more ... | RegisteredStyle<...>)[]'.
        Type 'ViewStyle' is not assignable to type 'ImageStyle'.
          Types of property 'overflow' are incompatible.
            Type '"visible" | "hidden" | "scroll" | undefined' is not assignable to type '"visible" | "hidden" | undefined'.
              Type '"scroll"' is not assignable to type '"visible" | "hidden" | undefined'.
src/screens/NewLoginScreen.web.tsx(301,5): error TS2322: Type '"100vh"' is not assignable to type 'DimensionValue | undefined'.
src/screens/notifications/NotificationTrayScreen.tsx(198,48): error TS2339: Property 'footerSpinner' does not exist on type '{ markAllRow: { alignItems: "flex-end"; paddingHorizontal: number; paddingVertical: number; }; itemTouchable: { paddingHorizontal: number; paddingVertical: number; }; itemRow: { flexDirection: "row"; alignItems: "flex-start"; }; ... 4 more ...; centerState: { ...; }; }'.
src/screens/PermissionGate.tsx(14,27): error TS7031: Binding element 'children' implicitly has an 'any' type.
src/screens/PermissionGate.tsx(126,20): error TS7006: Parameter 'theme' implicitly has an 'any' type.
src/services/apiClient.ts(77,7): error TS7053: Element implicitly has an 'any' type because expression of type 'number' can't be used to index type '{ 400: string; 401: string; 403: string; 404: string; 429: string; 500: string; 502: string; 503: string; }'.
  No index signature with a parameter of type 'number' was found on type '{ 400: string; 401: string; 403: string; 404: string; 429: string; 500: string; 502: string; 503: string; }'.
src/services/apiClient.ts(121,29): error TS7006: Parameter 'config' implicitly has an 'any' type.
src/services/apiClient.ts(158,40): error TS7006: Parameter 'config' implicitly has an 'any' type.
src/services/apiClient.ts(189,36): error TS7006: Parameter 'requestConfig' implicitly has an 'any' type.
src/services/apiClient.ts(189,51): error TS7006: Parameter 'newRefreshToken' implicitly has an 'any' type.
src/services/apiClient.ts(206,5): error TS7034: Variable 'failedQueue' implicitly has type 'any[]' in some locations where its type cannot be determined.
src/services/apiClient.ts(208,23): error TS7006: Parameter 'error' implicitly has an 'any' type.
src/services/apiClient.ts(209,3): error TS7005: Variable 'failedQueue' implicitly has an 'any[]' type.
src/services/apiClient.ts(220,36): error TS7006: Parameter 'error' implicitly has an 'any' type.
src/services/apiClient.ts(237,15): error TS2345: Argument of type '({ token, refreshToken: rotatedRefreshToken }: { token: any; refreshToken: any; }) => Promise<AxiosResponse<any, any, {}>>' is not assignable to parameter of type '(value: unknown) => AxiosResponse<any, any, {}> | PromiseLike<AxiosResponse<any, any, {}>>'.
  Types of parameters '__0' and 'value' are incompatible.
    Type 'unknown' is not assignable to type '{ token: any; refreshToken: any; }'.
src/services/apiClient.ts(269,28): error TS2345: Argument of type '{ token: any; refreshToken: any; }' is not assignable to parameter of type 'null | undefined'.
src/services/auth.ts(78,5): error TS2322: Type 'AxiosResponse<AuthTokenResponse, any, {}>' is not assignable to type 'AxiosResponse<VerifyOTPResponse, any, {}>'.
  Type 'AuthTokenResponse' is not assignable to type 'VerifyOTPResponse'.
    Types of property 'status' are incompatible.
      Type 'string | undefined' is not assignable to type 'string'.
        Type 'undefined' is not assignable to type 'string'.
src/services/auth.ts(99,7): error TS2322: Type 'AxiosResponse<AuthTokenResponse, any, {}>' is not assignable to type 'AxiosResponse<RefreshTokenResponse, any, {}>'.
  Type 'AuthTokenResponse' is not assignable to type 'RefreshTokenResponse'.
    Types of property 'accessToken' are incompatible.
      Type 'string | undefined' is not assignable to type 'string'.
        Type 'undefined' is not assignable to type 'string'.
src/theme/index.ts(1,10): error TS2305: Module '"./theme"' has no exported member 'default'.
src/utils/permissions.ts(84,11): error TS2304: Cannot find name 'AppState'.
src/utils/permissions.ts(89,48): error TS2304: Cannot find name 'BackHandler'.
src/utils/permissions.ts(133,36): error TS2345: Argument of type '"android.permission.CAMERA" | "ios.permission.CAMERA" | undefined' is not assignable to parameter of type 'Permission'.
  Type 'undefined' is not assignable to type 'Permission'.
src/utils/scanToPdf.ts(3,41): error TS2614: Module '"react-native-document-scanner-plugin"' has no exported member 'DocumentScannerOptions'. Did you mean to use 'import DocumentScannerOptions from "react-native-document-scanner-plugin"' instead?
src/utils/scanToPdf.ts(4,26): error TS7016: Could not find a declaration file for module 'react-native-image-to-pdf'. 'C:/Users/aashi/workspaces/CAAPP/CACubeFrontend/node_modules/react-native-image-to-pdf/index.js' implicitly has an 'any' type.
  Try `npm i --save-dev @types/react-native-image-to-pdf` if it exists or add a new declaration (.d.ts) file containing `declare module 'react-native-image-to-pdf';`
src/utils/scanToPdf.ts(20,5): error TS2353: Object literal may only specify known properties, and 'colorMode' does not exist in type 'ScanDocumentOptions'.
```

`npx tsc --noEmit` exit code: **2**.

### 7. `npx eslint . -f compact` — exit 1

Formatter summary line:

```
25924 problems
```

Line-counter totals (piped to a Node line counter; one line per problem):

```
LINES=25974 ERRORS=121 WARNINGS=25803
```

(`25974 - 25924 = 50` formatter/header lines.)

### 8. `npm test` — exit 1, config-resolution failure

```
> CAKube@1.3.3 test
> jest

● Validation Error:

  Module ./jest.setup.js in the setupFiles option was not found.
         <rootDir> is: C:\Users\aashi\workspaces\CAAPP\CACubeFrontend

  Configuration Documentation:
  https://jestjs.io/docs/configuration
```

Confirms the plan's pre-P1 harness failure mode. `jest.config.js` declares
`setupFiles: ['./jest.setup.js']` and maps images/styles to
`__mocks__/{fileMock,styleMock}.js`; all three are absent from the tree
(`jest.setup.js` = not found, `__mocks__/` = not found). **Escalation trigger 1
(a `npm test` failure other than the missing harness files) did not fire.**

### 9. `npm run build:web` — exit 0

```
> CAKube@1.3.3 build:web
> cross-env NODE_ENV=production webpack --config webpack.config.js --mode production

assets by status 2.41 MiB [cached] 15 assets
asset index.html 514 bytes [compared for emit]
runtime modules 6.36 KiB 10 modules
javascript modules 2.45 MiB
  ./index.web.js 926 bytes [built] [code generated]

WARNING in asset size limit: The following asset(s) exceed the recommended size limit (244 KiB).
This can impact web performance.
Assets:
  5d42b4e60858731e7b65.ttf (1.09 MiB)
  app.53826c8b7738b682ee68.bundle.js (1.09 MiB)

WARNING in entrypoint size limit: The following entrypoint(s) combined asset size exceeds the recommended limit (244 KiB).
This can impact web performance.
Entrypoints:
  main (1.09 MiB)
      app.53826c8b7738b682ee68.bundle.js

webpack 5.103.0 compiled with 2 warnings in 36467 ms
```

(ANSI colour codes present in the captured stdout were stripped for this
transcript; the text is otherwise verbatim.)

Exit code: **0**. **Escalation trigger 2 (build already failing) did not fire.**
`output.clean:true` did not manufacture a new bundle hash: webpack reused the
cached asset set (15 cached + `index.html` compared for emit), and the emitted
`app.53826c8b7738b682ee68.*` files were already the untracked `dist/` churn
listed above (the build added the matching `.LICENSE.txt`). No pre-existing
`dist/` churn is staged by P0.

## Exit gate

1. This file exists and has a row for each of the six commands in the phase
   table, each with an observed result (none `NOT RUN`). ✅
2. `git diff --name-only -- src __tests__` → **empty**. ✅ (see below)

```
$ git diff --name-only -- src __tests__
<no output>
```

## Notes / artifacts created during this phase

- `swarmkit/.swarm/logs/shipment-invoice-automation/000-baseline.md` (this file).
- `npx eslint .` run left no committed artifact; intermediate capture temp files
  were removed. Running `npm run build:web` touched the already-dirty `dist/`
  tree only (not staged).
