# BUILD-MACHINE-TODO — work that needs a real macOS 15 + Xcode 16 Mac

Some work on this app **cannot be done in the usual CI-only flow**. CI compiles
and runs the Swift Testing suites on a macOS runner, but it cannot exercise
anything that depends on **Vision (on-device OCR)** or the **Foundation Models**
framework, and the current development Mac (Intel, macOS 13.7.8 Ventura, Xcode
15.2) can neither build the macOS-15 target nor launch the app. This file lists
what to pick up once you're on a machine that **can build and run** the app:

- macOS **15 (Sequoia)** or newer to run it,
- Xcode **16** (macOS 15 SDK) to build it,
- for the Foundation Models item, macOS **26** with that framework available.

Local build/run from such a machine:

```sh
cd ExpenseTracker
xcodegen generate
xcodebuild test -scheme ExpenseTrackerMac -destination "platform=macOS"
open ...   # or run from Xcode to click through the UI
```

---

## 1. Finish the manual-form writer port: receipt image + OCR

This is the **last remaining piece** of porting the manual form onto the
repository (see `TODO.md` → "Manual `TransactionFormView`"). Everything else
(recurring schedules, note, category learning) is done and merged.

The domain and persistence are already in place — only the UI + OCR glue is left:

- `ExpenseDomain.Transaction.receiptData: Data?` exists and **round-trips**
  through `ExpenseTransactionRecord` (`@Attribute(.externalStorage)`) and
  migration. Tests: `ExpenseTransactionRecurrenceReceiptTests`.
- `ExpenseTransactionFormModel` does **not** yet expose `receiptData`, and
  `AddDomainTransactionView` has no image picker.

To do:

1. Add a `receiptData` field (+ image pick / drag-drop, and a "scan" affordance)
   to `ExpenseTransactionFormModel` and surface it in `AddDomainTransactionView`.
2. Run picked images through `OCRService` (Vision) and the existing
   `ReceiptImportPipeline` / `ReceiptParser` to pre-fill amount / merchant /
   date, reusing the same logic the batch "Scan Receipts" flow uses.
3. Persist `receiptData` on save (the model already builds the `Transaction`; it
   just needs to set `receiptData`).

**Why a build machine:** `OCRService` is `import Vision` and produces no useful
output in CI; the picker + OCR pre-fill can only be verified by running the app.
Keep the pure parsing (`ReceiptParser`, `ReceiptImportPipeline`) under unit
tests as today — only the Vision/UI seam needs manual verification.

## 2. Manually verify the existing OCR surfaces

`ReceiptScanImportView` (batch "Scan Receipts": multi-image pick → on-device OCR
→ editable draft review → save) and, once built, the new single-receipt form
flow above are **verified by hand** — Vision can't run in CI. On a build machine,
click through:

- multi-image scan → drafts populated → edits → save lands as transactions;
- the single-form receipt attach + OCR pre-fill;
- a non-receipt / unreadable image degrades gracefully (no crash, surfaced
  error via `ExpenseErrorPresenter`).

## 3. Validate the Foundation Models categorization engine (needs macOS 26)

`FoundationModelsCategorizationEngine` is gated behind
`@available(macOS 26, *)` / `#if canImport(FoundationModels)` and has **never run
on a real toolchain** (`TODO.md` P1). On a macOS 26 machine with the framework:

- validate it produces sensible categories on sample receipt text;
- add a runtime **fallback path test** for when the model is unavailable or
  declines, so categorization always falls back to the heuristic engine.

## 4. Distribution (when ready to ship)

App icon, `Info.plist` polish, hardened runtime, and a notarization / signing
story for sharing builds (`TODO.md` P2 → "Distribution"). All require Xcode +
signing on a Mac.

---

### What does NOT need a build machine

Pure domain / parsing / view-model work stays on the CI-only TDD flow: the
`ExpenseDomain`, `ExpenseRepository` adapters, parsers (`MoneyParser`,
`ReceiptParser`, statement/CSV), stats, and the `@Observable` view models are all
unit-testable on the macOS CI runner. Prefer landing logic there (red→green on
CI) and leaving only the Vision/Foundation-Models/UI seams for a build machine.
