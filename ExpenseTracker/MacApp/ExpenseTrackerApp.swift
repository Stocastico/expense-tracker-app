import SwiftUI
import SwiftData

@main
struct ExpenseTrackerApp: App {
    let modelContainer: ModelContainer
    /// SwiftData-backed repository for the pure two-level expense domain.
    let expenseRepository: SwiftDataExpenseRepository

    init() {
        do {
            let configuration = ModelConfiguration(
                "ExpenseTracker",
                schema: Schema([
                    Transaction.self,
                    Account.self,
                    Budget.self,
                    AppSettings.self,
                    CategoryRule.self,
                    ExpenseCategoryRecord.self,
                    ExpenseSubcategoryRecord.self,
                    ExpenseTagRecord.self,
                    ExpenseTransactionRecord.self
                ]),
                cloudKitDatabase: .none
            )
            modelContainer = try ModelContainer(
                for: Transaction.self, Account.self, Budget.self, AppSettings.self, CategoryRule.self,
                ExpenseCategoryRecord.self, ExpenseSubcategoryRecord.self,
                ExpenseTagRecord.self, ExpenseTransactionRecord.self,
                configurations: configuration
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        expenseRepository = SwiftDataExpenseRepository(context: modelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .environment(\.expenseRepository, expenseRepository)
                .onAppear {
                    createDefaultAccountsIfNeeded()
                    seedExpenseCatalogIfNeeded()
                    migrateLegacyTransactionsIfNeeded()
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 750)

        MenuBarExtra("Expense Tracker", systemImage: "dollarsign.circle.fill") {
            MenuBarQuickAdd()
                .modelContainer(modelContainer)
                .environment(\.expenseRepository, expenseRepository)
        }
        .menuBarExtraStyle(.window)
    }

    @MainActor
    private func createDefaultAccountsIfNeeded() {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<Account>()
        let accounts = (try? context.fetch(descriptor)) ?? []

        guard accounts.isEmpty else { return }

        let personal = Account(name: "Personal", icon: "person.fill", color: "#007AFF", isDefault: true)
        let family = Account(name: "Family", icon: "house.fill", color: "#34C759", isDefault: false)

        context.insert(personal)
        context.insert(family)
        try? context.save()
    }

    /// Installs the default Italian expense catalog and starter tags on first
    /// launch. Idempotent — a no-op once the store is populated.
    @MainActor
    private func seedExpenseCatalogIfNeeded() {
        try? expenseRepository.seedDefaultsIfEmpty()
    }

    /// Migrates any legacy `Transaction` rows into the new domain's records.
    /// Runs after the catalog is seeded so migrated transactions reference the
    /// seeded categories. Idempotent — already-migrated transactions are skipped,
    /// so it is safe to run on every launch.
    @MainActor
    private func migrateLegacyTransactionsIfNeeded() {
        try? LegacyExpenseMigrationRunner.run(in: modelContainer.mainContext)
    }
}
