import SwiftUI
import SwiftData

struct DashboardView: View {
    let selectedAccount: Account?

    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query private var budgets: [Budget]
    @Query private var settingsResults: [AppSettings]

    private var settings: AppSettings {
        settingsResults.first ?? AppSettings()
    }

    private var currency: String {
        settings.currency
    }

    private var filteredTransactions: [Transaction] {
        guard let account = selectedAccount else { return allTransactions }
        return allTransactions.filter { $0.account?.id == account.id }
    }

    var body: some View {
        // Derive every figure once per render instead of re-scanning the
        // transactions inside each computed property.
        let summary = DashboardSummary.make(
            transactions: filteredTransactions,
            budgets: budgets,
            startOfMonthDay: settings.startOfMonth
        )

        ScrollView {
            VStack(spacing: 20) {
                BalanceCardView(
                    netBalance: summary.netBalance,
                    trend: summary.spendingTrend,
                    currency: currency
                )

                statsGrid(summary)

                if !summary.budgetAlerts.isEmpty {
                    budgetAlertsSection(summary.budgetAlerts)
                }

                recentTransactionsSection(summary.recentTransactions)
            }
            .padding(24)
        }
        .navigationTitle("Dashboard")
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Stats Grid

    private func statsGrid(_ summary: DashboardSummary) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            StatCardView(
                title: "Expenses",
                value: summary.monthExpenses.currencyFormatted(code: currency),
                icon: "arrow.down.circle.fill",
                color: .red
            )
            StatCardView(
                title: "Income",
                value: summary.monthIncome.currencyFormatted(code: currency),
                icon: "arrow.up.circle.fill",
                color: .green
            )
            StatCardView(
                title: "Net",
                value: summary.netBalance.currencyFormatted(code: currency),
                icon: "plusminus.circle.fill",
                color: summary.netBalance >= 0 ? .green : .red
            )
            StatCardView(
                title: "Top Category",
                value: summary.topCategory?.name ?? "N/A",
                icon: "star.circle.fill",
                color: .orange
            )
        }
    }

    // MARK: - Budget Alerts

    private func budgetAlertsSection(_ alerts: [DashboardSummary.BudgetAlert]) -> some View {
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

    private func recentTransactionsSection(_ recent: [Transaction]) -> some View {
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
