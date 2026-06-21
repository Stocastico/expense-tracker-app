import SwiftUI
import SwiftData

struct BudgetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.expenseRepository) private var repository
    @Environment(ExpenseErrorPresenter.self) private var errorPresenter
    @Query(sort: \Budget.createdAt) private var budgets: [Budget]
    @Query private var settings: [AppSettings]

    /// Domain transactions read through the repository (kept current with legacy
    /// writes by `DataService`'s write-through). Loaded on appear.
    @State private var transactions: [ExpenseDomain.Transaction] = []
    @State private var showingAddBudget = false

    private var currentSettings: AppSettings? {
        settings.first
    }

    private var currency: String {
        currentSettings?.currency ?? "USD"
    }

    private var totalBudgeted: Double {
        budgets.filter { $0.period == .monthly }
            .reduce(0.0) { $0 + $1.storedAmount }
    }

    private var totalSpentThisMonth: Double {
        DomainStatsService.totalForPeriod(
            transactions: transactions,
            type: .expense,
            startDate: Date().startOfMonth,
            endDate: Date().endOfMonth
        ).doubleValue
    }

    private func load() {
        if let loaded = errorPresenter.perform("Loading budgets", { try repository.transactions() }) {
            transactions = loaded
        }
    }

    var body: some View {
        List {
            if budgets.isEmpty {
                ContentUnavailableView(
                    "No Budgets",
                    systemImage: "chart.bar.doc.horizontal",
                    description: Text("Create a budget to track your spending by category.")
                )
            } else {
                Section("Summary") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Budgeted (Monthly)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(totalBudgeted.currencyFormatted(code: currency))
                                .font(.title3)
                                .fontWeight(.bold)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Spent This Month")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(totalSpentThisMonth.currencyFormatted(code: currency))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(totalSpentThisMonth > totalBudgeted ? .red : .primary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Budgets") {
                    ForEach(budgets) { budget in
                        BudgetRowView(budget: budget, transactions: transactions, startOfMonth: currentSettings?.startOfMonth ?? 1)
                    }
                    .onDelete(perform: deleteBudgets)
                }
            }
        }
        .navigationTitle("Budgets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddBudget = true
                } label: {
                    Label("Add Budget", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddBudget) {
            BudgetFormView()
        }
        .task { load() }
    }

    private func deleteBudgets(at offsets: IndexSet) {
        for index in offsets {
            let budget = budgets[index]
            modelContext.delete(budget)
        }
        try? modelContext.save()
    }
}

private extension Decimal {
    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }
}
