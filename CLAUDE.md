# CLAUDE.md — working notes for this repo

A macOS-only SwiftUI/SwiftData expense tracker. This file is the standing brief
so context doesn't have to be re-derived each session. Keep it current when
structure or conventions change.

## How to build & test

- **No local builds in this environment.** Sessions run on Linux; the app is
  macOS-only (SwiftUI/SwiftData/Charts/Vision). There is no Xcode here, so
  **CI is the build/test gate** — push the branch and read the GitHub Actions
  result rather than trying to compile locally.
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
all computing in `Decimal`. **Writers still write legacy** (manual
`TransactionFormView`, menu-bar quick-add, Import/Scan) and reach the domain only
via the bridge. Manual entry now parses amounts with
`MoneyParser.parsePositiveAmount` (PRs #38, #39). **The domain now models
recurring schedules + receipts** — `ExpenseDomain.Transaction` carries a
`recurrence` (`ExpenseDomain.Recurrence`: required frequency + optional end
date), a `recurringParentId` for generated occurrences, and `receiptData`; the
SwiftData record stores and round-trips them and migration carries them across.
That clears the blocker, so the **next step is porting the writers
onto `ExpenseRepository`** (manual `TransactionFormView`, menu-bar quick-add,
Import/Scan). Until that lands, keep the legacy writer + write-through.

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
