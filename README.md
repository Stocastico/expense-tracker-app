# Expense Tracker

A native Swift expense tracker for macOS and iOS, built with SwiftUI and SwiftData. Transactions sync automatically between your Mac and iPhone/iPad via CloudKit.

---

## Features

### iOS App
| Feature | Description |
|---|---|
| **Dashboard** | Monthly net balance, income/expense stats, budget alerts, recent transactions |
| **Add Transaction** | Quick-add form with smart category detection, recurring transactions, haptic feedback |
| **History** | Searchable transaction list with All/Income/Expense filter chips, grouped by date |
| **Analytics** | Monthly income vs expenses bar chart, category breakdown donut chart, balance trend line, savings rate & spending prediction |
| **Budgets** | Per-category spending limits with progress bars and over-budget alerts |
| **Settings** | Currency, accounts, iCloud sync status |

### macOS App
| Feature | Description |
|---|---|
| **Dashboard** | Balance card, stats grid, budget alerts, recent transactions |
| **Transactions** | Full CRUD with search, filters (date range, category, type, amount), sorting & grouping |
| **Analytics** | Monthly bar chart, balance trend, category pie chart, savings rate, spending prediction |
| **Budgets** | Create/edit/delete budgets with progress tracking |
| **Menu Bar** | Quick-add floating panel accessible from the menu bar |
| **PDF Import** | Parse bank statements via OCR (Vision framework) |
| **Import/Export** | JSON, CSV export and legacy Electron data import |
| **Settings** | Currency, accounts, custom categories, import/export |

### Sync
- Automatic **iCloud CloudKit** sync between macOS and iOS
- Shared data model — transactions added on iPhone appear instantly on Mac

---

## Requirements

| Requirement | Minimum Version |
|---|---|
| Xcode | 15.0 |
| macOS (for building) | 14.0 (Sonoma) |
| macOS app deployment target | 14.0 |
| iOS app deployment target | 17.0 |
| Swift | 5.9 |
| XcodeGen | 2.40+ |

---

## Project Structure

```
ExpenseTracker/
├── project.yml                  # XcodeGen project definition
├── Shared/
│   ├── Sources/
│   │   ├── Models/              # SwiftData @Model classes
│   │   │   ├── Transaction.swift
│   │   │   ├── Account.swift
│   │   │   ├── Budget.swift
│   │   │   ├── AppSettings.swift
│   │   │   ├── Category.swift
│   │   │   └── Enums.swift
│   │   ├── Services/            # Business logic
│   │   │   ├── StatsService.swift
│   │   │   ├── DataService.swift
│   │   │   ├── SmartCategoryService.swift
│   │   │   ├── RecurringService.swift
│   │   │   ├── ExportService.swift
│   │   │   ├── PDFImportService.swift
│   │   │   └── OCRService.swift
│   │   ├── Extensions/          # Date, Currency, Color helpers
│   │   └── Defaults/            # Default categories
│   └── Tests/                   # Unit tests
├── MacApp/                      # macOS-specific views
│   ├── Views/
│   │   ├── Dashboard/
│   │   ├── Transactions/
│   │   ├── Analytics/
│   │   ├── Budgets/
│   │   └── Settings/
│   └── ExpenseTrackerApp.swift
└── MobileApp/                   # iOS-specific views
    ├── Views/
    │   ├── MobileDashboardView.swift
    │   ├── AddExpenseView.swift
    │   ├── ExpenseHistoryView.swift
    │   ├── MobileAnalyticsView.swift
    │   ├── MobileBudgetsView.swift
    │   └── MobileSettingsView.swift
    └── ExpenseTrackerMobileApp.swift
```

---

## Building the App

### Step 1 — Install XcodeGen

XcodeGen generates the `.xcodeproj` from `project.yml`. Install it once:

```bash
# Using Homebrew (recommended)
brew install xcodegen

# Or using Mint
mint install yonaskolb/XcodeGen
```

### Step 2 — Generate the Xcode project

```bash
cd ExpenseTracker
xcodegen generate
```

This creates `ExpenseTracker.xcodeproj`. Re-run this command any time you add or remove files, or modify `project.yml`.

### Step 3 — Open in Xcode

```bash
open ExpenseTracker.xcodeproj
```

### Step 4 — Select a scheme and build

In Xcode, select the scheme from the toolbar:
- **ExpenseTrackerMac** → builds the macOS app
- **ExpenseTrackerMobile** → builds the iOS app

Press **⌘B** to build, **⌘R** to run.

---

## Running on iOS Simulator

**No Apple Developer account is required** to run on the iOS Simulator.

1. In Xcode, select the **ExpenseTrackerMobile** scheme
2. Choose any iPhone or iPad simulator from the device picker (e.g. iPhone 16 Pro)
3. Press **⌘R**

> **Note:** CloudKit sync is **not available** in the Simulator. The app falls back to local-only SwiftData storage. All other features work fully.

---

## Running on a Physical iPhone or iPad

### Free Apple ID (no paid account)

A free Apple ID lets you sideload the app for **7-day** test periods.

1. In Xcode → **Settings → Accounts**, add your Apple ID
2. Select your iPhone as the run destination
3. In the project target settings → **Signing & Capabilities**, set:
   - Team: your personal team (shown as "Your Name (Personal Team)")
   - Bundle Identifier: change `com.expensetracker.mobile` to something unique like `com.yourname.expensetracker`
4. **Disable CloudKit** for free accounts (CloudKit requires a paid account):
   - Remove the CloudKit capability from the target
   - In `ExpenseTrackerMobileApp.swift`, change `.automatic` to `.none`:
     ```swift
     let configuration = ModelConfiguration(
         schema: schema,
         cloudKitDatabase: .none   // ← change from .automatic
     )
     ```
5. Connect your device, trust it, press **⌘R**
6. On your iPhone: **Settings → General → VPN & Device Management** → trust your developer certificate

> **Limitation:** Apps signed with a free account expire after 7 days and must be re-signed.

### Paid Apple Developer Account ($99/year)

With a paid account you get:
- ✅ CloudKit sync between macOS and iOS
- ✅ 1-year code signing (no re-signing every 7 days)
- ✅ TestFlight distribution
- ✅ App Store submission

**CloudKit setup for paid account:**
1. Sign in to [developer.apple.com](https://developer.apple.com) and create an App ID with CloudKit enabled
2. In Xcode → **Signing & Capabilities**, ensure CloudKit is listed and your container is `iCloud.com.expensetracker.shared`
3. In the [CloudKit Console](https://icloud.developer.apple.com), create the schema (or let the app create it on first run in Development environment)

---

## Running the macOS App

```bash
# From the project root
cd ExpenseTracker
xcodegen generate
open ExpenseTracker.xcodeproj
```

Select the **ExpenseTrackerMac** scheme, then press **⌘R**. The app opens as a standard macOS window with a sidebar.

**macOS CloudKit:** The entitlements file at `MacApp/ExpenseTrackerMac.entitlements` already includes CloudKit. With a paid developer account and proper provisioning, sync is automatic.

---

## Running Tests

```bash
# From inside the ExpenseTracker directory
xcodegen generate
xcodebuild test -scheme ExpenseTrackerMac -destination "platform=macOS"
```

Or in Xcode: **⌘U** runs all tests for the selected scheme.

Tests cover:
- `StatsServiceTests` — monthly totals, category breakdown, savings rate, trend calculations
- `ModelTests` — Transaction, Account, Budget model creation and computed properties
- `SmartCategoryTests` — keyword-based auto-categorisation
- `RecurringServiceTests` — recurring transaction generation
- `PDFImportTests` — bank statement regex parsing
- `ExportServiceTests` — JSON/CSV export formatting

---

## Debugging Tips

### CloudKit sync not working
1. Ensure both devices are signed into the **same iCloud account**
2. Check **Settings → Apple ID → iCloud** and confirm iCloud Drive is enabled
3. On macOS: **System Settings → Apple ID → iCloud → iCloud Drive** must be on
4. CloudKit containers can take a few minutes to propagate on first sync
5. Use the [CloudKit Console](https://icloud.developer.apple.com) to inspect records
6. In Xcode, enable **CloudKit logging**: Edit Scheme → Run → Arguments → add `-com.apple.CoreData.CloudKitDebug 1`

### "No such module 'ExpenseTrackerShared'" build error
Re-run `xcodegen generate` from the `ExpenseTracker/` directory. The shared framework target must be built before the app targets.

### SwiftData migration errors
If you change a `@Model` class (add/remove properties), SwiftData needs a migration. For development, the easiest fix is to **delete the app** from the simulator to wipe the store, then rebuild. For production, implement a `VersionedSchema` migration.

### Entitlements errors (CODE_SIGN_ENTITLEMENTS)
The project references entitlement files that are auto-generated by XcodeGen. If you see missing entitlements errors, run `xcodegen generate` again.

### App crashes on launch (ModelContainer failure)
Check the console for the `fatalError` message from `ModelContainer` initialisation. Common causes:
- Schema mismatch after a model change → delete the app and reinstall
- CloudKit container not provisioned → switch to `.none` during development

### Xcode 15 vs Xcode 16
The project targets Swift 5.9 and is compatible with both Xcode 15 and 16. If you're on Xcode 16, you may see deprecation warnings for `@retroactive` conformance — these are warnings only and don't affect functionality.

---

## Architecture

```
┌──────────────────────────────────────────┐
│              SwiftUI Views               │
│  macOS: NavigationSplitView + Sidebar    │
│  iOS:   TabView (5 tabs)                 │
└──────────────┬───────────────────────────┘
               │ @Query / @Environment
┌──────────────▼───────────────────────────┐
│          SwiftData Layer                 │
│  @Model classes: Transaction, Account,   │
│  Budget, AppSettings                     │
└──────────────┬───────────────────────────┘
               │ ModelContext operations
┌──────────────▼───────────────────────────┐
│          Business Logic Services         │
│  StatsService · DataService              │
│  SmartCategoryService · RecurringService │
│  PDFImportService · OCRService           │
│  ExportService                           │
└──────────────┬───────────────────────────┘
               │ ModelConfiguration(.automatic)
┌──────────────▼───────────────────────────┐
│          CloudKit (NSPersistentCloudKit) │
│  Container: iCloud.com.expensetracker.shared │
└──────────────────────────────────────────┘
```

**Key design decisions:**
- **SwiftData + CloudKit** — zero-boilerplate sync; no custom sync logic needed
- **Shared framework** — all models and services are in `ExpenseTrackerShared`, compiled for both macOS and iOS
- **XcodeGen** — `project.yml` is the source of truth; `.xcodeproj` is git-ignored and regenerated locally
- **No external dependencies** — only Apple system frameworks (SwiftUI, SwiftData, Charts, Vision, CloudKit, PDFKit)
- **Decimal for money** — `Transaction.amount` exposed as `Decimal` (stored as `Double` for SwiftData compatibility), with `Double` extension for display

---

## Data Model

```
Transaction
  id: UUID
  type: expense | income
  amount: Double (stored) / Decimal (computed)
  currency: String (ISO 4217)
  descriptionText: String
  merchant: String?
  date: Date
  categoryId: String           → references Category.id
  account: Account?            → SwiftData relationship
  tags: [String]               → stored as comma-separated String
  notes: String?
  isRecurring: Bool
  recurringFrequency: daily | weekly | biweekly | monthly | quarterly | yearly
  recurringEndDate: Date?
  recurringParentId: UUID?
  receiptData: Data?           → @Attribute(.externalStorage)

Account
  id: UUID
  name: String
  icon: String (emoji)
  color: String (hex)
  isDefault: Bool

Budget
  id: UUID
  categoryId: String
  amount: Double
  currency: String
  period: monthly | yearly

AppSettings
  id: UUID
  currency: String
  darkMode: Bool
  startOfMonth: Int
  defaultAccountId: UUID?
  customCategoriesData: Data?  → [Category] encoded as JSON
```

---

## Adding New Categories

Custom categories can be added in **Settings → Categories** (macOS) or via `AppSettings.addCustomCategory(_:)`. Each category has:

```swift
Category(
    id: "custom.gym",       // unique, stable identifier
    name: "Gym",
    icon: "🏋️",
    color: "#FF6B35",       // hex color
    type: .expense,         // .expense | .income | .both
    keywords: ["gym", "fitness", "workout"]  // for smart auto-detection
)
```

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-improvement`
3. Run `xcodegen generate` to set up the project
4. Make your changes
5. Run tests: `⌘U` in Xcode
6. Submit a pull request

**Code style:** Standard Swift conventions, no external formatters required. Keep services platform-agnostic (no UIKit/AppKit in `Shared/`).

---

## License

MIT License — see [LICENSE](LICENSE).
