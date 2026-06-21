import SwiftUI
import SwiftData

struct DashboardView: View {
    let selectedAccount: Account?

    @Environment(\.expenseRepository) private var repository
    @Environment(ExpenseErrorPresenter.self) private var errorPresenter
    @Query private var budgets: [Budget]
    @Query private var settingsResults: [AppSettings]

    /// Domain transactions read through the repository (kept current with legacy
    /// writes by `DataService`'s write-through). Loaded on appear and when the
    /// account changes.
    @State private var transactions: [ExpenseDomain.Transaction] = []

    private var settings: AppSettings {
        settingsResults.first ?? AppSettings()
    }

    private var currency: String {
        settings.currency
    }

    /// Account-filtered, newest-first — the shape `DashboardFigures` expects.
    private var scopedTransactions: [ExpenseDomain.Transaction] {
        let scoped = selectedAccount.map { account in
            transactions.filter { $0.accountId == account.id }
        } ?? transactions
        return scoped.sorted { $0.date > $1.date }
    }

    var body: some View {
        // Derive every figure once per render from the domain transactions.
        let figures = DashboardFigures.make(
            transactions: scopedTransactions,
            budgets: budgets,
            startOfMonthDay: settings.startOfMonth
        )

        ScrollView {
            VStack(spacing: 20) {
                BalanceCardView(
                    netBalance: figures.netBalance.doubleValue,
                    trend: figures.spendingTrend,
                    currency: currency
                )

                statsGrid(figures)

                if !figures.budgetAlerts.isEmpty {
                    budgetAlertsSection(figures.budgetAlerts)
                }

                recentTransactionsSection(figures.recentTransactions)
            }
            .padding(24)
        }
        .navigationTitle("Dashboard")
        .background(Color(nsColor: .windowBackgroundColor))
        .task { load() }
        .onChange(of: selectedAccount?.id) { _, _ in load() }
    }

    private func load() {
        if let loaded = errorPresenter.perform("Loading dashboard", { try repository.transactions() }) {
            transactions = loaded
        }
    }

    // MARK: - Stats Grid

    private func statsGrid(_ figures: DashboardFigures) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            StatCardView(
                title: "Expenses",
                value: figures.monthExpenses.currencyFormatted(code: currency),
                icon: "arrow.down.circle.fill",
                color: .red
            )
            StatCardView(
                title: "Income",
                value: figures.monthIncome.currencyFormatted(code: currency),
                icon: "arrow.up.circle.fill",
                color: .green
            )
            StatCardView(
                title: "Net",
                value: figures.netBalance.currencyFormatted(code: currency),
                icon: "plusminus.circle.fill",
                color: figures.netBalance >= 0 ? .green : .red
            )
            StatCardView(
                title: "Top Category",
                value: figures.topCategory?.name ?? "N/A",
                icon: "star.circle.fill",
                color: .orange
            )
        }
    }

    // MARK: - Budget Alerts

    private func budgetAlertsSection(_ alerts: [DashboardFigures.BudgetAlert]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Budget Alerts", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            ForEach(alerts) { alert in
                let cat = DefaultCategories.category(withId: alert.categoryId)
                HStack {
                    Text(cat.icon)
                    Text(cat.name)
                        .font(.subheadline)
                    Spacer()
                    Text("\(alert.spent.currencyFormatted(code: currency)) / \(alert.limit.currencyFormatted(code: currency))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f%%", alert.percentage))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(alert.percentage >= 100 ? .red : .orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(alert.percentage >= 100 ? Color.red.opacity(0.15) : Color.orange.opacity(0.15))
                        )
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
    }

    // MARK: - Recent Transactions

    private func recentTransactionsSection(_ recent: [ExpenseDomain.Transaction]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                Spacer()
            }

            if recent.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No transactions yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(recent) { transaction in
                    dashboardTransactionRow(transaction)
                    if transaction.id != recent.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
    }

    private func dashboardTransactionRow(_ transaction: ExpenseDomain.Transaction) -> some View {
        let isExpense = transaction.type == .expense
        return HStack(spacing: 12) {
            Image(systemName: isExpense ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .font(.title3)
                .foregroundStyle(isExpense ? Color.red : Color.green)
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill((isExpense ? Color.red : Color.green).opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title(for: transaction))
                    .font(.subheadline)
                    .lineLimit(1)
                if let categoryName = transaction.category?.displayName {
                    Text(categoryName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text((isExpense ? "-" : "+") + transaction.amount.currencyFormatted(code: currency))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isExpense ? .red : .green)

                Text(transaction.date.shortDateString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    /// Display title: merchant, then description, then a placeholder.
    private func title(for transaction: ExpenseDomain.Transaction) -> String {
        if let merchant = transaction.merchant, !merchant.trimmingCharacters(in: .whitespaces).isEmpty {
            return merchant
        }
        if !transaction.descriptionText.trimmingCharacters(in: .whitespaces).isEmpty {
            return transaction.descriptionText
        }
        return "Untitled"
    }
}

private extension Decimal {
    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }
}
