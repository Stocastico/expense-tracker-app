# CLAUDE.md — working notes for this repo

A macOS-only SwiftUI/SwiftData expense tracker. This file is the standing brief
so context doesn't have to be re-derived each session. Keep it current when
structure or conventions change.

## How to build & test

- **No local builds — CI is the build/test gate.** The app is macOS-only and
  targets macOS 15 / Xcode 16, so it can't be built here: sessions run either on
  Linux (no Xcode) or on a Mac too old for the macOS-15 SDK (e.g. Ventura /
  Xcode 15, which lacks it and can't run the target). Push the branch and read
  the GitHub Actions result instead of compiling locally. Work that genuinely
  needs a build-capable Mac (Vision/OCR, Foundation Models, the import review UI,
  distribution) is collected in `BUILD-MACHINE-TODO.md`.
- CI (`.github/workflows/ci.yml`, runs on every push) does:
  `xcodegen generate` → `xcodebuild test -scheme ExpenseTrackerMac -destination "platform=macOS"`.
  A run takes ~1–1.5 min. A green "Build & Test (macOS)" job = compiles + all tests pass.
- **`project.yml` is the source of truth** for the Xcode project (XcodeGen);
  `.xcodeproj` is git-ignored and regenerated. Edit `project.yml`, never the
  generated project. New source files are picked up automatically (targets
  reference whole directories), so no project edits are needed to add a file.
- Locally (on a Mac) the same flow works: `cd ExpenseTracker && xcodegen generate && xcodebuild test -scheme ExpenseTrackerMac -destination "platform=macOS"`.
- Deployment target macOS 15, Swift 5.9, Xcode 16.

## Project structure

```
ExpenseTracker/
  project.yml                  # XcodeGen config (source of truth)
  MacApp/                      # the macOS app target
    ExpenseTrackerApp.swift    # @main: ModelContainer, env injection, launch setup
    ExpenseRepositoryEnvironment.swift
    Views/                     # all SwiftUI screens
  Shared/
    Sources/                   # compiled into BOTH app and test targets
      Domain/                  # pure ExpenseDomain (no SwiftData) + ExpenseRepository
      Persistence/             # SwiftData adapter: records, mapping, migration
      Presentation/            # ExpenseErrorPresenter (error surfacing)
      Models/                  # legacy @Model types (Transaction, Account, Budget, …)
      Services/                # Stats, Data, Recurring, Export, OCR, categorization
      Parsing/                 # statement/CSV/money/date parsers
      Defaults/                # DefaultCategories (legacy flat catalog)
      Extensions/
    Tests/                     # Swift Testing suites (one module with Sources)
```

Shared sources compile **directly into the app/test module** (not a separate
framework), so local types like `Transaction` shadow same-named system types
(e.g. `SwiftUI.Transaction`). Don't introduce a framework boundary without
reason.

## Architecture: two coexisting data models

1. **Legacy (currently live in the UI):** `@Model` classes in `Shared/Sources/Models`
   — flat `Category` (String ids in `DefaultCategories`), money stored as `Double`.
   Used by all current Views via `@Query` / `DataService`.
2. **New (pure, the target):** `ExpenseDomain` — a namespace enum holding value
   types `Category`/`Subcategory`/`Tag`/`Transaction`/`Catalog`, two-level
   categories, tags, money as **`Decimal`**. Persistence-agnostic, behind the
   `ExpenseRepository` protocol (module-scope). Adapters:
   - `SwiftDataExpenseRepository` (+ `ExpenseTransactionRecord` etc. in
     `Persistence/`) — records mirror the domain; mapping in `ExpenseSwiftDataMapping`.
   - `ExpenseDomain.InMemoryRepository` — for tests/previews.
   - Seed: `DefaultExpenseCategories` (Italian two-level catalog); ids are
     deterministic via `ExpenseDomain.StableID.make("category:Name")` etc.

**Convergence plan (decided):** adopt `ExpenseRepository` in the UI incrementally
and retire the legacy `Double` math. Legacy data migrates into the new domain on
launch via `LegacyExpenseMigrationRunner` (idempotent; `Double`→2-dp `Decimal`
at the boundary; legacy String category → Italian catalog via
`DefaultLegacyCategoryMapping`). See `TODO.md` for live status (P0 done; P1 =
UI adoption).

**UI adoption status (P1):** a **write-through bridge** keeps the domain store
current — `DataService` mirrors every legacy add/update/delete into
`ExpenseTransactionRecord` (PR #34). On top of it, **all transaction readers now
go through `ExpenseRepository`**: Dashboard (`DashboardFigures`, PR #35),
Analytics (`DomainStatsService`, PR #36) and Budgets (`BudgetSpending`, PR #37),
all computing in `Decimal`. The **domain models recurring schedules + receipts**
— `ExpenseDomain.Transaction` carries a `recurrence` (`ExpenseDomain.Recurrence`:
required frequency + optional end date), a `recurringParentId` for generated
occurrences, and `receiptData`; the SwiftData record stores and round-trips them
and migration carries them across.

**Writers are being ported onto `ExpenseRepository` incrementally — one writer
per PR, using the two-level domain catalog:**
- **Menu-bar quick-add: ported.** `MenuBarQuickAdd` is a thin shell over
  `ExpenseTransactionFormModel`, writing through `@Environment(\.expenseRepository)`
  (`reset()` keeps the popover open for repeated entries). It no longer touches
  `DataService` or the flat-category `CategoryRuleService`. It learns on save and
  **suggests** on the two-level catalog: the Description field calls
  `suggestCategory()` (keyed on the description, as there's no merchant field).
- **Manual form: in progress.** The domain form
  (`ExpenseTransactionFormModel` / `AddDomainTransactionView`) now supports
  **recurring schedules** (pure `ExpenseDomain.recurringOccurrences(of:until:)`
  generates the occurrences), an editable **note**, and **category learning** —
  a pure two-level `ExpenseDomain.CategoryLearner` (keyed via
  `MerchantKey.normalize`) persisted through the repository
  (`categoryRules()` / `saveCategoryRule(_:)`, backed by `ExpenseCategoryRuleRecord`).
  The form learns a categorized expense's merchant → category/subcategory on
  save and `suggestCategory()` pre-fills the pickers for a known merchant (only
  when no category is chosen, so it never overwrites a manual pick). All
  additive; the legacy `CategoryRuleService` (flat catalog) stays for the legacy
  screen. Still to port: **receipt image + OCR** (`receiptData` round-trips
  already; needs the file-pick/OCR UI) — tracked in `BUILD-MACHINE-TODO.md`
  because it can only be built and verified on a macOS-15 + Xcode-16 Mac. The
  legacy `TransactionFormView` itself stays (writes legacy, mirrored to the
  domain) until the whole legacy Transactions screen is retired.
- **Import Statement: writer core ported, UI swap pending.** The testable core
  is `StatementImportModel` — it turns parsed `StatementEntry`s into editable
  drafts and writes the selected ones through `ExpenseRepository` (Decimal,
  two-level category, account), learning each description → category. Unlearned
  expenses get a starter category from a two-level keyword heuristic
  (`ExpenseDomain.CategoryKeywordMatcher` + the `DefaultExpenseKeywordRules`
  Italian/Spanish seed; learned rules win). The live `PDFImportView` still uses
  the legacy `DataService` writer until its review table is rebound onto this
  model — a build-machine task (see `BUILD-MACHINE-TODO.md`).
- **Still legacy (write to `DataService`, reach the domain via the bridge):**
  Scan Receipts (OCR) and the legacy `TransactionFormView`. All parse amounts
  with `MoneyParser.parsePositiveAmount` (PRs #38, #39). Keep the legacy writer +
  write-through until each is ported.

## Dev principles (please follow without being asked)

- **TDD, strictly.** Write a failing test first, push, confirm it's **RED on
  CI**, then implement and confirm **GREEN on CI**. One small increment per
  red→green cycle. Commit the test and the implementation separately.
- **Swift Testing**, not XCTest: `import Testing`, `@Test`, `#expect(...)`,
  `try #require(...)`. Tests live in `Shared/Tests`. Mark suites/tests
  `@MainActor` when they touch SwiftData `ModelContext`/containers. Use an
  in-memory `ModelConfiguration(isStoredInMemoryOnly: true)` for SwiftData tests.
- **Money is `Decimal`** in the domain — never reintroduce `Double` math there.
  Round `Double`→`Decimal` only at the legacy boundary (`NSDecimalRound`, 2 dp).
- **Keep the domain pure** — no SwiftData/SwiftUI imports under `Domain/`. The
  SwiftData seam lives in `Persistence/`.
- **Surface errors, don't swallow them.** Route fallible work through
  `ExpenseErrorPresenter.perform(_:)` so failures reach the user; avoid `try?`
  and never `fatalError` on a recoverable path.
- **Match surrounding style** — value types, `public` API with doc comments in
  the domain, small focused files, comments explaining *why*.
- **Don't over-spawn / over-ask.** Handle multi-part tasks inline; only ask when
  a decision is genuinely the user's (e.g. ambiguous category mappings).

## Git / PR conventions

- Branch from latest `main`, named `claude/<short-topic>`.
- **Squash-merge** PRs into `main` (the repo's convention). One P0/feature
  "chunk" per PR; TDD red/green commits within it are fine.
- Don't open a PR unless asked, but when finishing a chunk the established
  rhythm here is: PR → confirm CI green → squash-merge.
- Commit message + PR body trailers are configured in the harness; PR bodies end
  with the Claude Code generation line.

## Gotchas

- The same `TransactionType` enum is shared by legacy and domain `Transaction`.
- `ExpenseDomain.StableID` is module-internal — reuse its key scheme
  (`"tag:<name>"`, `"category:<Name>"`, `"subcategory:<Cat>/<name>"`) so seeded
  and migrated ids line up.
- Income is never categorized (migration + validation enforce this).
- New domain records are forward-prep: the UI still reads legacy `DataService`,
  so migrated `ExpenseTransactionRecord`s aren't shown (no double-counting) until
  UI adoption lands.
