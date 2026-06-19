import SwiftUI
import SwiftData

struct DashboardView: View {
    let selectedAccount: Account?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query private var budgets: [Budget]
    @Query private var settingsResults: [AppSettings]

    private var settings: AppSettings {
        settingsResults.first ?? AppSettings()
    }

    private var currency: String {
        settings.currency
    }

    private var dataService: DataService {
        DataService(modelContext: modelContext)
    }

    private var filteredTransactions: [Transaction] {
        guard let account = selectedAccount else { return allTransactions }
        return allTransactions.filter { $0.account?.id == account.id }
    }

    private var currentMonthStart: Date { Date().startOfMonth }
    private var currentMonthEnd: Date { Date().endOfMonth }

    private var monthExpenses: Double {
        StatsService.totalForPeriod(
            transactions: filteredTransactions,
            type: .expense,
            startDate: currentMonthStart,
            endDate: currentMonthEnd
        )
    }

    private var monthIncome: Double {
        StatsService.totalForPeriod(
            transactions: filteredTransactions,
            type: .income,
            startDate: currentMonthStart,
            endDate: currentMonthEnd
        )
    }

    private var netBalance: Double {
        monthIncome - monthExpenses
    }

    private var spendingTrend: Double {
        StatsService.spendingTrend(transactions: filteredTransactions)
    }

    private var topCategoryInfo: (name: String, amount: Double)? {
        guard let top = StatsService.topCategory(transactions: filteredTransactions, month: Date()) else {
            return nil
        }
        let cat = DefaultCategories.category(withId: top.categoryId)
        return (name: cat.displayName, amount: top.amount)
    }

    private var budgetAlerts: [(budget: Budget, spent: Double, percentage: Double)] {
        budgets.compactMap { budget in
            let range = budget.currentPeriodRange(startOfMonth: settings.startOfMonth)
            let spent = filteredTransactions
                .filter {
                    $0.type == .expense
                        && $0.categoryId == budget.categoryId
                        && $0.date >= range.start
                        && $0.date <= range.end
                }
                .reduce(0.0) { $0 + $1.storedAmount }

            let pct = budget.storedAmount > 0 ? (spent / budget.storedAmount) * 100 : 0
            guard pct >= 80 else { return nil }
            return (budget: budget, spent: spent, percentage: pct)
        }
        .sorted { $0.percentage > $1.percentage }
    }

    private var recentTransactions: [Transaction] {
        Array(filteredTransactions.prefix(10))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                BalanceCardView(
                    netBalance: netBalance,
                    trend: spendingTrend,
                    currency: currency
                )

                statsGrid

                if !budgetAlerts.isEmpty {
                    budgetAlertsSection
                }

                recentTransactionsSection
            }
            .padding(24)
        }
        .navigationTitle("Dashboard")
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            StatCardView(
                title: "Expenses",
                value: monthExpenses.currencyFormatted(code: currency),
                icon: "arrow.down.circle.fill",
                color: .red
            )
            StatCardView(
                title: "Income",
                value: monthIncome.currencyFormatted(code: currency),
                icon: "arrow.up.circle.fill",
                color: .green
            )
            StatCardView(
                title: "Net",
                value: netBalance.currencyFormatted(code: currency),
                icon: "plusminus.circle.fill",
                color: netBalance >= 0 ? .green : .red
            )
            StatCardView(
                title: "Top Category",
                value: topCategoryInfo?.name ?? "N/A",
                icon: "star.circle.fill",
                color: .orange
            )
        }
    }

    // MARK: - Budget Alerts

    private var budgetAlertsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Budget Alerts", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            ForEach(budgetAlerts, id: \.budget.id) { alert in
                let cat = DefaultCategories.category(withId: alert.budget.categoryId)
                HStack {
                    Text(cat.icon)
                    Text(cat.name)
                        .font(.subheadline)
                    Spacer()
                    Text("\(alert.spent.currencyFormatted(code: currency)) / \(alert.budget.storedAmount.currencyFormatted(code: currency))")
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

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                Spacer()
            }

            if recentTransactions.isEmpty {
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
                ForEach(recentTransactions) { transaction in
                    dashboardTransactionRow(transaction)
                    if transaction.id != recentTransactions.last?.id {
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

    private func dashboardTransactionRow(_ transaction: Transaction) -> some View {
        let cat = DefaultCategories.category(withId: transaction.categoryId)
        return HStack(spacing: 12) {
            Text(cat.icon)
                .font(.title3)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color(hex: cat.color).opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.descriptionText)
                    .font(.subheadline)
                    .lineLimit(1)
                if let merchant = transaction.merchant, !merchant.isEmpty {
                    Text(merchant)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(transaction.type == .expense
                    ? "-\(transaction.storedAmount.currencyFormatted(code: currency))"
                    : "+\(transaction.storedAmount.currencyFormatted(code: currency))")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(transaction.type == .expense ? .red : .green)

                Text(transaction.date.shortDateString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
