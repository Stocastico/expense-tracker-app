# TODO — road to a fully working app

Status of the app as of this document: a working macOS SwiftUI/SwiftData expense
tracker (dashboard, transactions, analytics, budgets, settings, menu-bar
quick-add, PDF/CSV import, receipt OCR, learned categorisation) **plus** a new,
pure, fully-tested `ExpenseDomain` model + `ExpenseRepository` + SwiftData
adapter that is wired into the app but **not yet consumed by any view**.

Two parallel data models currently coexist:

- **Legacy (live in the UI):** `Transaction`/`Account`/`Budget`/`Category` —
  flat categories, money stored as `Double`.
- **New (tested, unused by UI):** `ExpenseDomain.{Category,Subcategory,Tag,
  Transaction}` — two-level categories, tags, money as `Decimal`, behind
  `ExpenseRepository`.

The single biggest decision for "fully working" was **whether/how to converge
these two**. **That path is now chosen:** adopt `ExpenseRepository` in the UI
incrementally and retire the legacy `Double` math over time. As of 2026-06 the
supporting correctness work is done (PRs #15–#18) — legacy data migrates into
the new domain on launch — and what remains is consuming the new layer in the
views. Everything below is grouped by priority.

---

## P0 — correctness & convergence — ✅ done (PRs #15–#18)

The remaining open work here is consuming the new layer in the UI, tracked
under P1 → "Adopt `ExpenseRepository` end-to-end".

- [x] **Money precision (new path).** The `ExpenseDomain` model and its
  SwiftData records store and aggregate money as `Decimal` end-to-end, and the
  legacy→domain migration rounds the old `Double` amounts to a 2-dp `Decimal`
  at the boundary, so float error doesn't leak into the new model. *(PR #15.)*
  The legacy live models still store `Double`; that storage retires together
  with the UI adoption above rather than as a separate fix.
- [x] **Convergence path chosen.** Adopt `ExpenseRepository` in the UI
  incrementally (option 1). The new domain is no longer dead weight now that
  data migrates into it on launch.
- [x] **Data migration.** `LegacyExpenseMigration` maps legacy `Transaction` →
  `ExpenseDomain.Transaction` (Double→Decimal, merchant/description/account,
  tags, category via `DefaultLegacyCategoryMapping`); `LegacyExpenseMigrationRunner`
  writes `ExpenseTransactionRecord`s idempotently and runs on launch after
  seeding. Fully tested, including a seed/migrate drift guard. *(PRs #15–#17.)*
- [x] **Surface errors to the user (new path).** `ExpenseErrorPresenter` +
  `ExpensePresentableError` route setup/persistence failures into a SwiftUI
  alert; the `ModelContainer`-creation `fatalError` is replaced with a graceful
  in-memory fallback that tells the user changes won't be saved. *(PR #18.)*
  The legacy `DataService` still uses `print(...)` on its own save/fetch path —
  fold those into the presenter as the UI adopts the repository.

## P1 — performance — ✅ done (PRs #26–#28)

- [x] **Cache formatters.** `FormatterCache` reuses `NumberFormatter`/
  `DateFormatter` instances (keyed by currency code / pattern) instead of
  allocating per call; `Decimal`/`Double.currencyFormatted`,
  `Transaction.formattedAmount` and the `Date` string helpers route through it.
  *(PR #26.)*
- [x] **Filter/sort in the query, not in memory.** `DataService.fetchTransactions`
  now builds a `FetchDescriptor` with a `#Predicate` (type/category/date) and a
  `SortDescriptor` (date/amount); only the relationship (account) and substring
  (search) filters run in memory, on the reduced set. Characterized by
  `DataServiceTests`. *(PR #27.)* The `DashboardView` rescans are addressed
  below.
- [x] **Avoid recomputing derived values per render.** `DashboardSummary.make`
  derives all dashboard figures in one pass; `DashboardView` builds it once per
  render instead of recomputing `filteredTransactions` + stats in every computed
  property. *(PR #28.)*

## P1 — feature completeness (per README/roadmap)

- [x] **Adopt `ExpenseRepository` end-to-end** — the **"Expenses (beta)"**
  screen reads and writes transactions through `@Environment(\.expenseRepository)`
  (list, add, edit, delete) via `@Observable` view models. *(PRs #21–#25.)*
- [~] **Two-level categories + tags in the UI.** Exposed on the new Expenses
  screen (category/subcategory pickers, tag toggles, account; category-path +
  tags shown in the list). *(PRs #21–#25.)* The list now also reaches the legacy
  screen's browse parity — type/category/account/date-range filters, search,
  date/amount sort, date-grouped sections and settings-driven currency, all in
  the tested `ExpenseTransactionsListModel`. *(PR #33.)*

  Convergence toward retiring the legacy screen is now underway:
  - **Write-through bridge** — `DataService` mirrors every legacy add/update/
    delete into the domain store (`ExpenseTransactionRecord`), so the new model
    stays current with legacy writes and readers can migrate without going stale
    between launches. *(PR #34.)*
  - **Dashboard migrated** — reads `ExpenseDomain.Transaction`s through the
    repository and derives its figures via `DashboardFigures` (money as
    `Decimal`); legacy `DashboardSummary` retired. *(PR #35.)*
  - **Analytics migrated** — charts/summary read through the repository and are
    computed by `DomainStatsService` (sums in `Decimal`, category slices get a
    palette colour). *(PR #36.)*
  - **Budgets migrated** — per-budget spend and the month total read through the
    repository via `BudgetSpending`/`DomainStatsService` (`Decimal`); budgets
    themselves stay legacy, so their category icon/name still come from the flat
    catalog. *(PR #37.)*
  - **Manual & menu-bar entry hardened** — both the manual `TransactionFormView`
    and the menu-bar quick-add now parse amounts via
    `MoneyParser.parsePositiveAmount` (European/US notation, currency symbols,
    thousands separators) instead of a hand-rolled `Double` cast that couldn't
    even read a comma decimal. Writes still go through `DataService` and so are
    mirrored into the domain by the write-through. *(PRs #38, #39.)*

  **All transaction *readers* now go through the repository.** What remains
  before the legacy Transactions screen can be deleted:

  - **Port the *writers* to the domain** — manual `TransactionFormView`, menu-bar
    quick-add, and **Import Statement / Scan Receipts** currently write legacy
    `Transaction` (reaching the domain only via the write-through). **Blocked
    first on a domain-model gap:** `ExpenseDomain.Transaction` has no
    `recurring*`/`receiptData` fields, so a faithful writer port would drop
    recurring schedules and receipt images. **Next step is to model recurring +
    receipts in the domain** (with migration), *then* swap the writers onto
    `ExpenseRepository`.
  - **Then** delete the legacy Transactions screen + "(beta)" label and retire
    the `Double` `@Model` types + `DataService`.
  - **Analytics grouping** by the two-level catalog (deferred).
- [x] **Image pipeline (roadmap step 5).** `ReceiptImportPipeline` turns the OCR
  text of one or more receipt/invoice images into categorized `ReceiptDraft`s
  (reusing `ReceiptParser` + a `CategorizationEngine`), unit-tested with sample
  text *(PR #30)*. Surfaced as a batch **"Scan Receipts"** flow
  (`ReceiptScanImportView`): multi-image pick → on-device OCR → editable draft
  review → save *(PR #31)*. The OCR/UI layer is verified manually (Vision can't
  run in CI).
- [ ] **Foundation Models engine validation.** `FoundationModelsCategorizationEngine`
  is gated behind `@available(macOS 26, *)`/`#if canImport(FoundationModels)`
  and unvalidated on a real macOS 26 toolchain. Validate, and add a runtime
  fallback path test.

## P2 — UX / UI

- [ ] **Localization.** Docs say documents are mostly Spanish/Italian, but UI
  strings are English-only and dates use a fixed `"d MMM"` format ignoring
  locale (`Date+Extensions.swift:45`). Add `String(localized:)` + locale-aware
  formatting; consider ES/IT localizations.
- [ ] **Consistent money input.** `MenuBarQuickAdd` parses amounts with a
  hand-rolled `Double(amount.replacing(",", "."))` (`MenuBarQuickAdd.swift:36,123`)
  instead of the locale-aware `MoneyParser` used elsewhere — inconsistent with
  the European-notation goal.
- [ ] **Empty/loading/error states** across views; **undo** for delete;
  confirm-before-destruct on account/budget deletion.
- [ ] **Accessibility:** VoiceOver labels on icon-only controls, Dynamic Type,
  colour-contrast for the red/green amount semantics (add a non-colour cue).
- [ ] **Keyboard & focus:** default field focus in forms, `⌘N` new transaction,
  escape-to-dismiss sheets, tab order.

## P2 — quality / infra

- [ ] **Tests for the UI-facing layers.** Strong unit coverage on parsing/stats;
  add tests for `DataService` filtering/sorting, budget period math, and (via
  `ViewInspector` or model-level view models) the view logic.
- [ ] **CI hardening:** treat warnings as errors for the new code; add SwiftLint;
  upload/inspect `.xcresult` on failure.
- [ ] **Concurrency:** audit for Swift 6 mode (the new `EnvironmentKey`
  default and `ModelContext`-holding types will need `@MainActor`/`Sendable`
  review before enabling complete checking).
- [ ] **Distribution:** app icon, `Info.plist` polish, hardened runtime,
  notarization/signing story for sharing builds.

## P3 — optional / future

- [ ] **CloudKit sync.** `cloudKitDatabase: .none` today
  (`ExpenseTrackerApp.swift:25`). Enable SwiftData CloudKit mirroring on the
  `ExpenseDomain` `@Model` records — deterministic seed UUIDs keep default
  categories consistent across devices.
- [ ] Recurring-transaction UI surfacing; budget roll-over; multi-currency with
  FX; export presets; spotlight/quick-actions.

---

## Code-review findings (details)

See the companion review in the PR/notes. Highest-impact items, in order:

1. ✅ **Money is `Double` end-to-end** — fixed on the new domain/migration path
   (Decimal end-to-end + Double→Decimal at migration, PR #15); legacy `Double`
   storage retires with UI adoption.
2. ✅ **`DataService.fetchTransactions` is O(all) in memory** — predicate + sort
   pushed into the `FetchDescriptor` (PR #27).
3. ✅ **Formatters allocated per call in row rendering** — `FormatterCache`
   reuses them (PR #26).
4. ✅ **Errors swallowed via `print` / `fatalError` on launch** — fixed on the
   new path (PR #18): presenter + alert, `fatalError` replaced; legacy
   `DataService` `print(...)` remains until UI adoption.
5. ✅ **New `ExpenseDomain` injected but unused** — convergence decided and data
   now migrates into it on launch (PRs #15–#18); UI consumption pending (P1).
6. **`MenuBarQuickAdd` money parsing diverges from `MoneyParser`** (P2).
