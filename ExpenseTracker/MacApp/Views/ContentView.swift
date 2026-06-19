import SwiftUI
import SwiftData

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case transactions = "Transactions"
    case analytics = "Analytics"
    case budgets = "Budgets"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .transactions: return "list.bullet"
        case .analytics: return "chart.bar.fill"
        case .budgets: return "target"
        case .settings: return "gear"
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedItem: SidebarItem? = .dashboard
    @State private var selectedAccount: Account?
    @Query(sort: \Account.createdAt) private var accounts: [Account]

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedItem)
        } detail: {
            detailView
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        accountPicker
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 600)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedItem {
        case .dashboard:
            DashboardView(selectedAccount: selectedAccount)
        case .transactions:
            TransactionListView(selectedAccount: selectedAccount)
        case .analytics:
            AnalyticsView(selectedAccount: selectedAccount)
        case .budgets:
            BudgetsView(selectedAccount: selectedAccount)
        case .settings:
            SettingsView()
        case nil:
            Text("Select an item from the sidebar")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }

    private var accountPicker: some View {
        Picker("Account", selection: $selectedAccount) {
            Text("All Accounts").tag(Account?.none)
            ForEach(accounts) { account in
                Text("\(account.icon) \(account.name)").tag(Account?.some(account))
            }
        }
        .pickerStyle(.menu)
        .frame(width: 180)
    }
}
