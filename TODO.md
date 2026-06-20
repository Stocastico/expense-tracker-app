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

The single biggest decision for "fully working" is **whether/how to converge
these two**. Everything below is grouped by priority.

---

## P0 — correctness & convergence (do first)

- [ ] **Money precision.** Storage and all aggregation use `Double`
  (`Transaction.storedAmount`, `Budget.storedAmount`, every `StatsService`
  `reduce(0.0)`). The `amount: Decimal` accessors are derived *from* the
  `Double`, so they don't actually buy precision — float error accumulates in
  the sums before conversion. Fix by storing money as integer **minor units**
  (`Int`, cents) or `Decimal`, and doing all math in `Decimal`.
  Refs: `Shared/Sources/Models/Transaction.swift`,
  `Shared/Sources/Models/Budget.swift:46`,
  `Shared/Sources/Services/StatsService.swift` (throughout).
- [ ] **Pick a convergence path for the two models.** Options:
  1. Adopt `ExpenseRepository` in the UI incrementally (recommended) and retire
     the legacy `Double` math over time; or
  2. Backport the domain's `Decimal` + two-level categories onto the existing
     `Transaction`/`Category` and drop the new layer.
  Until this is decided the new domain is dead weight in the running app.
- [ ] **Data migration.** Whatever path is chosen, write a one-time migration:
  legacy `Transaction` → `ExpenseTransactionRecord` (or legacy money `Double` →
  minor units). Add a migration test.
- [ ] **Surface errors to the user.** Data/save failures are swallowed with
  `print(...)` (`DataService.swift` `saveContext`, all `fetch*`). At minimum
  show a non-fatal alert; never `fatalError` on container creation in a shipped
  app (`ExpenseTrackerApp.swift:34`) — present a recovery UI instead.

## P1 — performance

- [ ] **Cache formatters.** `NumberFormatter`/`DateFormatter` are allocated on
  every call inside list/row rendering — expensive at scale.
  Refs: `Extensions/Decimal+Extensions.swift:9,30`,
  `Extensions/Date+Extensions.swift:38,45,92,96`,
  `Models/Transaction.swift:120`. Use cached statics keyed by currency/locale.
- [ ] **Filter/sort in the query, not in memory.** `DataService.fetchTransactions`
  fetches *all* transactions and filters/sorts in Swift
  (`DataService.swift:54–112`). Push predicates + sort into `FetchDescriptor`
  (`#Predicate`, `sortBy:`) and paginate. Same pattern in `DashboardView`
  (`@Query` all, then repeated in-memory passes).
- [ ] **Avoid recomputing derived values per render.** Dashboard computes
  `filteredTransactions` repeatedly and recomputes stats on every body eval;
  memoize or move into an `@Observable` view model.

## P1 — feature completeness (per README/roadmap)

- [ ] **Two-level categories + tags in the UI.** The new model supports
  subcategories and tags; no screen exposes them yet (category pickers, forms,
  filters, analytics grouping).
- [ ] **Image pipeline (roadmap step 5).** Receipt OCR is wired in the manual
  form (`TransactionFormView` → `OCRService`/`ReceiptParser`); finish the
  broader pipeline (batch/invoice images reusing the statement parser + the
  categorisation engine), and add tests with sample images/text.
- [ ] **Foundation Models engine validation.** `FoundationModelsCategorizationEngine`
  is gated behind `@available(macOS 26, *)`/`#if canImport(FoundationModels)`
  and unvalidated on a real macOS 26 toolchain. Validate, and add a runtime
  fallback path test.
- [ ] **Adopt `ExpenseRepository` end-to-end** in at least one feature
  (e.g. a category picker or a new-transaction flow) reading/writing via
  `@Environment(\.expenseRepository)` to prove the integration in UI.

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

1. **Money is `Double` end-to-end** (P0 above) — precision risk on sums/budgets.
2. **`DataService.fetchTransactions` is O(all) in memory** (P1) — no predicates.
3. **Formatters allocated per call in row rendering** (P1).
4. **Errors swallowed via `print` / `fatalError` on launch** (P0).
5. **New `ExpenseDomain` injected but unused** — decide convergence (P0).
6. **`MenuBarQuickAdd` money parsing diverges from `MoneyParser`** (P2).
