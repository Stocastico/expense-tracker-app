import SwiftUI
import SwiftData

@main
struct ExpenseTrackerApp: App {
    let modelContainer: ModelContainer
    @StateObject private var syncService = SyncService(role: .advertiser)

    init() {
        do {
            let configuration = ModelConfiguration(
                "ExpenseTracker",
                schema: Schema([
                    Transaction.self,
                    Account.self,
                    Budget.self,
                    AppSettings.self
                ]),
                cloudKitDatabase: .none
            )
            modelContainer = try ModelContainer(
                for: Transaction.self, Account.self, Budget.self, AppSettings.self,
                configurations: configuration
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .environmentObject(syncService)
                .onAppear {
                    createDefaultAccountsIfNeeded()
                    syncService.setModelContext(modelContainer.mainContext)
                    syncService.start()
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 750)

        MenuBarExtra("Expense Tracker", systemImage: "dollarsign.circle.fill") {
            MenuBarQuickAdd()
                .modelContainer(modelContainer)
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
}
