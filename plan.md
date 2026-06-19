# Implementation Plan — Document-Intelligence Pivot (macOS)

The app is being refocused into a **macOS-only, document-first** expense
tracker. The headline capability is reading uploaded documents — credit-card
/ bank statements (PDF) and receipts/invoices (images) — understanding them,
extracting transactions, and auto-categorising spending. The existing logic
(filtering, search, monthly/global charts, budgets, manual entry, category
management) is kept.

The iOS companion app and MultipeerConnectivity sync are archived on
`archive/mobile-app` and removed from the development branch.

## Constraints & workflow

- **Documents are ~90% Spanish** (rest: Italian, Basque/Euskera, English) →
  European number/date notation by default, multilingual aware.
- **On-device intelligence**: Apple **Foundation Models** (private, free,
  offline). Requires macOS 26 + Apple Silicon at runtime; gated behind
  `@available(macOS 26, *)` with a deterministic heuristic fallback so the
  app builds on Xcode 16 and tests run in CI.
- **TDD, small commits.** The Linux dev environment has no Swift toolchain,
  so red/green is provided by **GitHub Actions on a macOS runner**.

## Phases

1. **Cleanup / foundation** ✅
   - Archive mobile app + sync to a branch; remove from dev branch.
   - macOS-only `project.yml`; add macOS CI.
   - Fix the missing `MenuBarQuickAdd` (Mac target did not compile).

2. **Locale-aware parsing** 🚧
   - `MoneyParser` (European/US amounts) ✅
   - `DocumentDateParser` (day-first European + Spanish/Italian/English month
     names + ISO).

3. **Statement extraction**
   - Cluster OCR/PDF text into structured `ParsedTransaction`s (date, amount,
     merchant/description, sign) for real Spanish statement layouts.
   - Anonymised statement fixtures as test data.

4. **Auto-categorisation engine**
   - `CategorizationEngine` protocol.
   - `HeuristicCategorizationEngine` (testable, keyword/merchant based).
   - `FoundationModelsCategorizationEngine` (`@available(macOS 26, *)`),
     guided generation into a category enum.

5. **Image pipeline**
   - Receipts/invoices via Vision OCR → same extraction + categorisation.

6. **Review UI & polish**
   - Unified import-review screen; wire engine into the manual form's
     suggestion; refresh analytics/filters as needed.

## Data model (unchanged core)

`Transaction`, `Account`, `Budget`, `AppSettings`, `Category` — SwiftData
`@Model` classes in `Shared/Sources/Models`. Money stored as `Double`,
handled as `Decimal` where precision matters (parsing).
