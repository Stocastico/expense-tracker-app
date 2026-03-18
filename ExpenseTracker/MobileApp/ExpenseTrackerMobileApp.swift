import SwiftUI
import SwiftData

@main
struct ExpenseTrackerMobileApp: App {
    let modelContainer: ModelContainer
    @StateObject private var syncService = SyncService(role: .browser)

    init() {
        do {
            let schema = Schema([
                Transaction.self,
                Account.self,
                Budget.self,
                AppSettings.self
            ])
            let configuration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .none
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MobileContentView()
                .modelContainer(modelContainer)
                .environmentObject(syncService)
                .onAppear {
                    syncService.setModelContext(modelContainer.mainContext)
                    syncService.start()
                }
        }
    }
}

// MARK: - Content View (Tab Bar)

struct MobileContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: MobileTab = .dashboard
    @State private var hasSeededAccounts = false

    enum MobileTab: Hashable {
        case dashboard
        case add
        case history
        case analytics
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            MobileDashboardView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(MobileTab.dashboard)

            AddExpenseView()
                .tabItem {
                    Label("Add", systemImage: "plus.circle.fill")
                }
                .tag(MobileTab.add)

            ExpenseHistoryView()
                .tabItem {
                    Label("History", systemImage: "list.bullet")
                }
                .tag(MobileTab.history)

            MobileAnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar.xaxis")
                }
                .tag(MobileTab.analytics)

            MobileSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(MobileTab.settings)
        }
        .onAppear {
            seedDefaultAccountsIfNeeded()
        }
    }

    private func seedDefaultAccountsIfNeeded() {
        guard !hasSeededAccounts else { return }
        hasSeededAccounts = true

        let descriptor = FetchDescriptor<Account>()
        let existingAccounts = (try? modelContext.fetch(descriptor)) ?? []

        guard existingAccounts.isEmpty else { return }

        let personal = Account(
            name: "Personal",
            icon: "💳",
            color: "#007AFF",
            isDefault: true
        )
        let family = Account(
            name: "Family",
            icon: "👨‍👩‍👧‍👦",
            color: "#34C759",
            isDefault: false
        )

        modelContext.insert(personal)
        modelContext.insert(family)

        do {
            try modelContext.save()
        } catch {
            print("Failed to seed default accounts: \(error.localizedDescription)")
        }
    }
}
