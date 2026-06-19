# Expense Tracker

A native **macOS** expense tracker built with SwiftUI and SwiftData. The focus
is **document intelligence**: drop in a credit-card statement (PDF) or a photo
of a receipt/invoice, and the app reads it, extracts the transactions, and
auto-categorises your spending — on top of the usual filtering, search and
monthly/global charts.

> **Project direction (June 2026):** the app is pivoting to a macOS-only,
> document-first tool. The previous iOS companion app and local-network
> (MultipeerConnectivity) sync have been archived on the
> [`archive/mobile-app`](../../tree/archive/mobile-app) branch and may return
> later. No paid Apple Developer account is required to build and run on your
> own Mac.

---

## What it does

| Area | Description |
|---|---|
| **Document import (focus)** | Upload PDF credit-card/bank statements and image receipts/invoices; the app extracts date, amount and merchant and clusters spending into categories. |
| **Auto-categorisation** | Understands and classifies transactions automatically. Heuristics today; on-device Apple Foundation Models planned (see roadmap). |
| **Manual entry** | Full add/edit form and a **menu-bar quick-add** for fast entries without importing anything. |
| **Categories** | Add, edit and remove your own categories alongside the built-in ones. |
| **Transactions** | Search, filters (date range, category, type, amount), sorting and grouping. |
| **Analytics** | Monthly bar chart, balance trend, category breakdown, savings rate, spending prediction. |
| **Budgets** | Per-category limits with progress tracking and over-budget alerts. |
| **Import/Export** | JSON and CSV. |

### Documents are mostly Spanish

The statements and receipts this app ingests are predominantly **Spanish**,
with a minority in Italian, Basque (Euskera) and English. Parsing therefore
defaults to **European notation** — comma decimal separator, dot thousands
separator (`1.234,56`), `€`, day-first dates (`dd/mm/yyyy`) — while still
understanding US notation.

---

## Roadmap

1. ✅ Archive iOS app + sync; macOS-only project; CI on a macOS runner.
2. ✅ Locale-aware parsing layer (`MoneyParser`, `DocumentDateParser`).
3. ✅ Structured extraction from statements (`StatementParser`, Spanish-first).
4. ✅ Categorisation engine abstraction: heuristic engine + learned rules
   (`CategoryRule`), with an on-device **Apple Foundation Models** engine
   behind `#if canImport(FoundationModels)` + `@available(macOS 26, *)` so the
   app still builds on Xcode 16 / older macOS and in CI.
5. ⬜ Image pipeline (receipts/invoices) reusing the same engine.
6. ✅ PDF import review: editable category per row; corrections are learned.

### Learned categorisation

When you assign a category to a transaction (manual form, menu-bar quick-add,
or the import review), the app remembers `merchant/description → category`
(normalised by `MerchantKey`, ignoring card/branch numbers) and auto-applies
it to future transactions with the same name. Learned rules take precedence
over keyword heuristics and the on-device model.

---

## Requirements

| Requirement | Minimum |
|---|---|
| Xcode | 16.0 |
| macOS (build & run) | 15.0 (Sequoia) |
| Swift | 5.9 |
| XcodeGen | 2.40+ |

> Foundation Models features (roadmap step 4) will require macOS 26 + Apple
> Silicon at runtime, and Xcode 17 to build — introduced behind availability
> checks so the rest of the app keeps building on Xcode 16.

---

## Project Structure

```
ExpenseTracker/
├── project.yml                  # XcodeGen project definition
├── Shared/
│   ├── Sources/
│   │   ├── Models/              # SwiftData @Model classes
│   │   ├── Services/            # Stats, Data, Recurring, Export, PDFImport,
│   │   │                        # OCR, SmartCategory, CategoryRule(+Service),
│   │   │                        # CategorizationEngine, CategoryResolver,
│   │   │                        # FoundationModelsCategorizationEngine (gated)
│   │   ├── Parsing/             # MoneyParser, DocumentDateParser,
│   │   │                        # StatementParser, MerchantKey
│   │   ├── Extensions/          # Date, Currency, Color helpers
│   │   └── Defaults/            # Default categories
│   └── Tests/                   # XCTest unit tests
└── MacApp/                      # macOS app
    ├── Views/                   # Dashboard, Transactions, Analytics,
    │                            # Budgets, Settings, MenuBar
    └── ExpenseTrackerApp.swift
```

---

## Building & Running

```bash
brew install xcodegen           # once
cd ExpenseTracker
xcodegen generate               # regenerates ExpenseTracker.xcodeproj
open ExpenseTracker.xcodeproj
```

Select the **ExpenseTrackerMac** scheme, then **⌘R** to run or **⌘U** to test.
Re-run `xcodegen generate` whenever you add/remove files or edit `project.yml`.

---

## Running Tests

```bash
cd ExpenseTracker
xcodegen generate
xcodebuild test -scheme ExpenseTrackerMac -destination "platform=macOS"
```

CI runs the same on a macOS runner for every push
(`.github/workflows/ci.yml`), so build/test status is visible on each commit.

### Current test suites (`Shared/Tests/`)

| Suite | Covers |
|---|---|
| `ModelTests` | Model creation, computed properties, enum roundtrips, Category Codable |
| `MoneyParserTests` | European/US amount parsing, separators, signs, currency symbols |
| `DocumentDateParserTests` | Day-first/ISO dates, ES/IT/EU/EN month names, invalid dates |
| `StatementParserTests` | Statement lines → transactions, header/balance skipping, income keywords |
| `MerchantKeyTests` | Merchant normalisation (diacritics, digits, whitespace) |
| `CategoryRuleServiceTests` | Learn/lookup/upsert of learned category rules |
| `CategorizationEngineTests` | Heuristic engine + resolver precedence (learned → engine) |
| `RecurringServiceTests` | Recurrence generation, end dates, parent linking |
| `StatsServiceTests` | Monthly totals, category breakdown, savings rate, predictions |
| `ExportServiceTests` | CSV/JSON export & import roundtrip |
| `PDFImportTests` | Bank statement text parsing |
| `SmartCategoryTests` | Keyword matching, merchant priority, fallback |

---

## Architecture

```
┌──────────────────────────────────────────┐
│              SwiftUI Views (macOS)        │
│   NavigationSplitView + Sidebar           │
│   MenuBarExtra quick-add                   │
└──────────────┬───────────────────────────┘
               │ @Query / @Environment
┌──────────────▼───────────────────────────┐
│          SwiftData Layer                  │
│  Transaction · Account · Budget · Settings│
└──────────────┬───────────────────────────┘
               │ ModelContext operations
┌──────────────▼───────────────────────────┐
│          Services & Parsing               │
│  Stats · Data · Recurring · Export        │
│  PDFImport · OCR · MoneyParser            │
│  SmartCategory (→ Foundation Models)      │
└───────────────────────────────────────────┘
```

**Key decisions:**
- **macOS-only**, no external dependencies — only Apple system frameworks
  (SwiftUI, SwiftData, Charts, Vision, PDFKit, and Foundation Models later).
- **Decimal for money** — precise parsing via `MoneyParser`.
- **XcodeGen** — `project.yml` is the source of truth; `.xcodeproj` is
  git-ignored and regenerated locally.
- **Testable AI boundary** — the categorisation engine is abstracted so the
  on-device LLM path can be swapped for a deterministic heuristic in tests/CI.

---

## License

MIT License — see [LICENSE](LICENSE).
