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

2. **Locale-aware parsing** ✅
   - `MoneyParser` (European/US amounts) ✅
   - `DocumentDateParser` (day-first European + Spanish/Italian/Basque/English
     month names + ISO) ✅

3. **Statement extraction** ✅
   - `StatementParser`: statement text → structured `StatementEntry`s (date,
     amount, expense/income/**ignored**, description), skipping headers/balances,
     with Spanish income-keyword detection. Tuned against a real Kutxabank
     *Movimientos de tarjeta* (PDF).
   - `StatementCSVParser`: bank-account CSV export (*Movimientos de cuenta*,
     `fecha;concepto;fecha valor;importe;saldo`) → `StatementEntry`s, taking the
     sign from the `importe` column rather than the `saldo` balance.
   - `StatementClassifier`: shared rules flagging the card-bill settlement,
     own-account transfers, pension contributions and zero-amount lines as
     `.ignored` so they are excluded from totals (and pre-unticked on import).

4. **Auto-categorisation engine** ✅
   - Learned rules: `CategoryRule` + `CategoryRuleService` (normalised by
     `MerchantKey`), wired into manual form, quick-add and import review.
   - `CategorizationEngine` protocol + `HeuristicCategorizationEngine` +
     `CategoryResolver` (learned → engine).
   - `FoundationModelsCategorizationEngine` (`@available(macOS 26, *)`,
     `#if canImport(FoundationModels)`) — needs validation on a macOS 26
     toolchain.

5. **Image pipeline** ⬜
   - Receipts/invoices via Vision OCR → `StatementParser`/resolver reuse.

6. **Review UI & polish** ✅ (import) / ⬜ (broader polish)
   - Import review: editable category per row + learning on import. ✅
   - Wire the resolver/FM engine into the manual form suggestion; refresh
     analytics/filters as needed. ⬜

## Data model (unchanged core)

`Transaction`, `Account`, `Budget`, `AppSettings`, `Category` — SwiftData
`@Model` classes in `Shared/Sources/Models`. Money stored as `Double`,
handled as `Decimal` where precision matters (parsing).
