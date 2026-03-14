# Native Swift Expense Tracker — Implementation Plan

## Architecture Overview

```
ExpenseTracker/
├── ExpenseTrackerShared/          # Swift Package (shared between macOS + iOS)
│   ├── Models/                    # SwiftData models
│   ├── Services/                  # Sync, PDF parsing, OCR, stats
│   └── Extensions/                # Date, Currency helpers
├── ExpenseTrackerMac/             # macOS app (full-featured)
│   ├── App/                       # App entry, menu bar
│   ├── Views/                     # All screens
│   │   ├── Dashboard/
│   │   ├── Transactions/
│   │   ├── Analytics/
│   │   ├── Budgets/
│   │   └── Settings/
│   ├── MenuBar/                   # Menu bar quick-add
│   └── Resources/
├── ExpenseTrackerMobile/          # iOS app (simple entry + sync)
│   ├── App/
│   ├── Views/
│   │   ├── AddExpense/
│   │   ├── ExpenseList/
│   │   └── Settings/
│   └── Resources/
└── ExpenseTrackerTests/           # Shared + per-platform tests
```

## Data Models (SwiftData + CloudKit)

### Account
- id: UUID
- name: String (e.g., "Personal", "Joint", "Business")
- icon: String (emoji)
- color: String (hex)
- isDefault: Bool
- createdAt: Date

### Transaction
- id: UUID
- type: TransactionType (expense/income)
- amount: Decimal
- currency: String (ISO 4217)
- description: String
- merchant: String?
- date: Date
- categoryId: String
- accountId: UUID (→ Account)
- tags: [String]
- notes: String?
- isRecurring: Bool
- recurringFrequency: RecurringFrequency?
- recurringEndDate: Date?
- recurringParentId: UUID?
- receiptData: Data? (image blob)
- createdAt: Date
- updatedAt: Date

### Budget
- id: UUID
- categoryId: String
- amount: Decimal
- currency: String
- period: BudgetPeriod (monthly/yearly)
- createdAt: Date
- updatedAt: Date

### Category
- id: String
- name: String
- icon: String (emoji)
- color: String (hex)
- type: CategoryType (expense/income/both)
- keywords: [String] (for auto-categorization)
- isCustom: Bool

### AppSettings
- id: UUID (singleton)
- currency: String
- darkMode: Bool (follows system or manual)
- startOfMonth: Int (1-28)
- defaultAccountId: UUID?

## Phase 1: Shared Package + Data Layer
1. Create Xcode project structure (workspace, targets, shared package)
2. Define all SwiftData @Model classes
3. Configure CloudKit container + SwiftData ModelContainer with cloud sync
4. Implement DataService (CRUD operations, queries, filters)
5. Implement default categories + seed data
6. Write unit tests for models and DataService

## Phase 2: macOS App — Core UI
7. App entry point with SwiftData container injection
8. Main window with NavigationSplitView (sidebar + detail)
   - Sidebar: Dashboard, Transactions, Analytics, Budgets, Settings
9. Dashboard view: net balance, budget alerts, recent transactions, mini stats
10. Transaction list view with search, filters (type, category, account, date range, sort)
11. Transaction form (add/edit) as sheet modal
12. Transaction detail view
13. Write view tests

## Phase 3: macOS App — Analytics
14. Monthly income vs expenses bar chart (Swift Charts)
15. Net balance trend line chart
16. Category breakdown pie/donut chart
17. Savings rate display
18. Spending prediction (weighted average)
19. Time period selector (3/6/12 months, custom range)
20. Stats utility functions (port from TypeScript)
21. Write tests for stats calculations

## Phase 4: macOS App — Budgets & Settings
22. Budget list view with progress bars
23. Add/edit budget sheet
24. Over-budget warnings (badge in sidebar)
25. Settings view: currency, accounts management (CRUD), categories management (CRUD)
26. Import/Export (CSV + JSON)
27. Write tests

## Phase 5: macOS App — Advanced Features
28. Menu bar quick-add (MenuBarExtra with floating panel)
29. PDF bank statement import (PDFKit text extraction + parser)
30. Receipt OCR scanning (Vision framework VNRecognizeTextRequest)
31. Smart categorization (merchant keyword matching)
32. Recurring transaction generation
33. Write tests for PDF parser and OCR

## Phase 6: iOS App
34. Simple app shell with TabView (Add, History, Settings)
35. Quick-add expense form (amount, description, category, account, date)
36. Local expense list (basic, recent entries only)
37. CloudKit sync happens automatically via SwiftData
38. Settings: accounts, categories, currency
39. Write tests

## Phase 7: Integration & Polish
40. End-to-end CloudKit sync testing (macOS ↔ iOS)
41. Data migration tool (import JSON from old Electron app)
42. macOS native look: vibrancy, proper spacing, toolbar
43. Error handling, empty states, loading states
44. Accessibility (VoiceOver labels, Dynamic Type on iOS)

## Key Design Decisions

- **NavigationSplitView** for macOS (sidebar pattern like Finder/Mail)
- **SwiftData + CloudKit** for automatic sync (no manual sync logic needed)
- **Decimal** for money (not Double — avoids floating point errors)
- **Vision framework** for OCR (runs on-device, no external dependency)
- **PDFKit** for PDF parsing (Apple native)
- **Swift Charts** for all visualizations
- **MenuBarExtra** for menu bar quick-add

## What's Removed from Electron Version
- Express server backend (CloudKit replaces)
- PWA/service worker (native apps)
- File-based cloud sync (CloudKit)
- Tesseract.js (→ Vision framework)
- pdf.js (→ PDFKit)
- React/Tailwind/Recharts (→ SwiftUI/Swift Charts)
- localStorage (→ SwiftData/SQLite)

## Testing Strategy
- Unit tests for all model logic, stats calculations, PDF parsing
- View tests for key UI flows
- Integration tests for CloudKit sync
- All tests written alongside implementation (red/green)
