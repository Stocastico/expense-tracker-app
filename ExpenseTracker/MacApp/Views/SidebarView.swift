import SwiftUI
import SwiftData

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    @Environment(\.modelContext) private var modelContext
    @Query private var budgets: [Budget]
    @Query(filter: #Predicate<Transaction> { $0.typeRaw == "expense" })
    private var expenses: [Transaction]

    var body: some View {
        List(SidebarItem.allCases, selection: $selection) { item in
            NavigationLink(value: item) {
                Label(item.rawValue, systemImage: item.icon)
                    .badge(badgeCount(for: item))
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Expense Tracker")
        .frame(minWidth: 180)
    }

    private func badgeCount(for item: SidebarItem) -> Int {
        guard item == .budgets else { return 0 }
        return overBudgetCount
    }

    private var overBudgetCount: Int {
        budgets.filter { budget in
            let range = budget.currentPeriodRange()
            let spent = expenses.filter { t in
                t.categoryId == budget.categoryId
                    && t.date >= range.start
                    && t.date <= range.end
            }.reduce(0.0) { $0 + $1.storedAmount }
            return spent >= budget.storedAmount * 0.8
        }.count
    }
}
