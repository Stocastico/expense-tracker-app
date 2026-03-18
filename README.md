# Expense Tracker

A native Swift expense tracker for macOS and iOS, built with SwiftUI and SwiftData. Transactions sync between your Mac and iPhone/iPad over the local network using MultipeerConnectivity — no paid Apple Developer account required.

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
| **Settings** | Currency, accounts, local network sync status |

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
- **Local network sync** between macOS and iOS via MultipeerConnectivity
- No paid Apple Developer account needed — works with a free Apple ID
- Mac advertises on the network, iPhone discovers and connects automatically
- Bidirectional merge with last-write-wins conflict resolution

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
│   │   │   ├── OCRService.swift
│   │   │   └── SyncService.swift
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

> **Note:** MultipeerConnectivity sync is **not available** in the Simulator. The app uses local-only SwiftData storage. All other features work fully.

---

## Running on a Physical iPhone or iPad

### Free Apple ID (no paid account)

A free Apple ID lets you sideload the app for **7-day** test periods. **No paid Apple Developer account is needed** — sync uses MultipeerConnectivity over the local network.

1. In Xcode → **Settings → Accounts**, add your Apple ID
2. Select your iPhone as the run destination
3. In the project target settings → **Signing & Capabilities**, set:
   - Team: your personal team (shown as "Your Name (Personal Team)")
   - Bundle Identifier: change `com.expensetracker.mobile` to something unique like `com.yourname.expensetracker`
4. Connect your device, trust it, press **⌘R**
5. On your iPhone: **Settings → General → VPN & Device Management** → trust your developer certificate
6. When prompted, allow "Expense Tracker" to use the local network

> **Limitation:** Apps signed with a free account expire after 7 days and must be re-signed.

### Syncing between devices

Both devices must be on the **same Wi-Fi network**:

1. Open the macOS app — it automatically advertises on the local network
2. Open the iOS app — it discovers the Mac and connects automatically
3. Data syncs bidirectionally on connect (and via "Sync Now" in Settings)

The sync uses last-write-wins conflict resolution based on the `updatedAt` timestamp.

---

## Running the macOS App

```bash
# From the project root
cd ExpenseTracker
xcodegen generate
open ExpenseTracker.xcodeproj
```

Select the **ExpenseTrackerMac** scheme, then press **⌘R**. The app opens as a standard macOS window with a sidebar.

**macOS sync:** The Mac app automatically advertises on the local network when launched. The iOS app discovers and connects to it for bidirectional sync.

---

## Running Tests

### From the command line

```bash
cd ExpenseTracker
xcodegen generate

# Run tests for macOS
xcodebuild test \
  -scheme ExpenseTrackerMac \
  -destination "platform=macOS"

# Run tests for iOS (Simulator)
xcodebuild test \
  -scheme ExpenseTrackerMobile \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro"
```

### From Xcode

1. Open the project: `open ExpenseTracker.xcodeproj`
2. Select the scheme you want to test:
   - **ExpenseTrackerMac** — runs tests against macOS
   - **ExpenseTrackerMobile** — runs tests against an iOS Simulator
3. Press **⌘U** to run all tests
4. View results in the **Test Navigator** (⌘6) or the **Report Navigator** (⌘9)

> **Tip:** To run a single test class or method, click the diamond icon next to it in the Test Navigator, or right-click and choose "Run".

### Test suite

All tests are in `Shared/Tests/` and run on both platforms:

| Test class | Tests | What it covers |
|---|---|---|
| `ModelTests` | 18 | Transaction, Account, Budget, AppSettings model creation, computed properties, enum roundtrips, Category Codable |
| `SyncServiceTests` | 42 | Payload encoding/decoding, merge logic (insert, update, conflict resolution, account linking, idempotency), service state machine |
| `RecurringServiceTests` | 18 | Daily/weekly/monthly/quarterly/yearly recurrence generation, end date handling, parent ID linking, field copying |
| `StatsServiceTests` | 10 | Monthly totals, category breakdown, savings rate, spending predictions, balance trends |
| `ExportServiceTests` | 8 | CSV/JSON export formatting, import roundtrip, data persistence |
| `PDFImportTests` | 8 | Bank statement text parsing, date/amount extraction, garbage line filtering |
| `SmartCategoryTests` | 16 | Keyword matching, case insensitivity, merchant priority, fallback logic, edge cases |

#### SyncService tests in detail

The `SyncServiceTests.swift` file contains three test classes:

- **`SyncPayloadCodableTests`** — verifies that `SyncPayload`, `SyncTransaction`, and `SyncAccount` encode and decode correctly through JSON, including nil optionals, large receipt data, and multi-item payloads.

- **`SyncMergeTests`** — tests the core merge logic (`SyncService.mergePayload`) against an in-memory SwiftData store:
  - Inserting new accounts and transactions
  - Last-write-wins conflict resolution (newer remote wins, newer local wins, same timestamp keeps local)
  - All transaction fields updated on conflict
  - Account-to-transaction linking (new accounts, existing accounts, nil/non-existent account IDs)
  - Mixed payloads (some new, some existing records)
  - Empty payload handling
  - Idempotency (merging same payload twice produces same result)
  - Large payloads (100 transactions, 10 accounts)
  - Recurring transaction field preservation

- **`SyncServiceStateTests`** — tests the service lifecycle state machine:
  - Initial idle state
  - Advertiser starts in `.advertising`, browser starts in `.browsing`
  - Stop resets to `.idle`
  - Start while active is a no-op
  - Start/stop cycling
  - `SyncStatus` equatable conformance

---

## Debugging Tips

### Sync not working
1. Ensure both devices are on the **same Wi-Fi network**
2. On iOS, check that the app has **Local Network** permission: **Settings → Privacy & Security → Local Network** → enable Expense Tracker
3. On macOS, ensure the firewall allows incoming connections for Expense Tracker
4. Try toggling "Stop Sync" / "Start Sync" in the iOS Settings tab
5. If using a corporate/guest network, peer-to-peer discovery may be blocked — try a home network

### "No such module 'ExpenseTrackerShared'" build error
Re-run `xcodegen generate` from the `ExpenseTracker/` directory. The shared framework target must be built before the app targets.

### SwiftData migration errors
If you change a `@Model` class (add/remove properties), SwiftData needs a migration. For development, the easiest fix is to **delete the app** from the simulator to wipe the store, then rebuild. For production, implement a `VersionedSchema` migration.

### Entitlements errors (CODE_SIGN_ENTITLEMENTS)
The project references entitlement files that are auto-generated by XcodeGen. If you see missing entitlements errors, run `xcodegen generate` again.

### App crashes on launch (ModelContainer failure)
Check the console for the `fatalError` message from `ModelContainer` initialisation. Common causes:
- Schema mismatch after a model change → delete the app and reinstall
- Local network permission denied → re-enable in iOS Settings → Privacy & Security → Local Network

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
               │ MultipeerConnectivity
┌──────────────▼───────────────────────────┐
│          SyncService                     │
│  macOS: Advertiser (receives data)       │
│  iOS:   Browser (sends data)             │
└──────────────────────────────────────────┘
```

**Key design decisions:**
- **MultipeerConnectivity** — local network sync between devices; no paid Apple Developer account needed
- **Shared framework** — all models and services are in `ExpenseTrackerShared`, compiled for both macOS and iOS
- **XcodeGen** — `project.yml` is the source of truth; `.xcodeproj` is git-ignored and regenerated locally
- **No external dependencies** — only Apple system frameworks (SwiftUI, SwiftData, Charts, Vision, MultipeerConnectivity, PDFKit)
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
