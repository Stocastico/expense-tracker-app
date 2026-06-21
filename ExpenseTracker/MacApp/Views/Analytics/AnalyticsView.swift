import SwiftUI
import SwiftData
import Charts

struct AnalyticsView: View {
    @Environment(\.expenseRepository) private var repository
    @Environment(ExpenseErrorPresenter.self) private var errorPresenter
    @Query private var settings: [AppSettings]

    /// Domain transactions read through the repository (kept current with legacy
    /// writes by `DataService`'s write-through). Loaded on appear / account change.
    @State private var transactions: [ExpenseDomain.Transaction] = []
    @State private var selectedMonths: Int = 6

    var selectedAccount: Account?

    private var currentSettings: AppSettings? {
        settings.first
    }

    private var currency: String {
        currentSettings?.currency ?? "USD"
    }

    private var filteredTransactions: [ExpenseDomain.Transaction] {
        if let account = selectedAccount {
            return transactions.filter { $0.accountId == account.id }
        }
        return transactions
    }

    private var monthlyData: [MonthlyTotal] {
        DomainStatsService.monthlyTotals(transactions: filteredTransactions, months: selectedMonths)
    }

    private var balanceData: [BalancePoint] {
        DomainStatsService.netBalanceTrend(transactions: filteredTransactions, months: selectedMonths)
    }

    private var categoryData: [CategoryBreakdown] {
        DomainStatsService.categoryBreakdown(transactions: filteredTransactions, month: Date())
    }

    private var currentMonthIncome: Double {
        DomainStatsService.totalForPeriod(
            transactions: filteredTransactions,
            type: .income,
            startDate: Date().startOfMonth,
            endDate: Date().endOfMonth
        ).doubleValue
    }

    private var currentMonthExpenses: Double {
        DomainStatsService.totalForPeriod(
            transactions: filteredTransactions,
            type: .expense,
            startDate: Date().startOfMonth,
            endDate: Date().endOfMonth
        ).doubleValue
    }

    private var trend: Double {
        DomainStatsService.spendingTrend(transactions: filteredTransactions)
    }

    private var prediction: Double {
        DomainStatsService.spendingPrediction(transactions: filteredTransactions)
    }

    private var savingsRateValue: Double {
        StatsService.savingsRate(income: currentMonthIncome, expenses: currentMonthExpenses)
    }

    private func load() {
        if let loaded = errorPresenter.perform("Loading analytics", { try repository.transactions() }) {
            transactions = loaded
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                summaryCards
                MonthlyBarChart(data: monthlyData)
                BalanceTrendChart(data: balanceData)

                HStack(alignment: .top, spacing: 16) {
                    CategoryPieChart(data: categoryData)
                    SavingsRateView(
                        rate: savingsRateValue,
                        income: currentMonthIncome,
                        expenses: currentMonthExpenses,
                        currency: currency
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Analytics")
        .task { load() }
        .onChange(of: selectedAccount?.id) { _, _ in load() }
    }

    private var headerSection: some View {
        HStack {
            if let account = selectedAccount {
                Label("Filtered: \(account.displayName)", systemImage: "line.3.horizontal.decrease.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Period", selection: $selectedMonths) {
                Text("3 Months").tag(3)
                Text("6 Months").tag(6)
                Text("12 Months").tag(12)
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
        }
    }

    private var summaryCards: some View {
        HStack(spacing: 16) {
            summaryCard(
                title: "Spending Trend",
                value: String(format: "%+.1f%%", trend),
                icon: trend >= 0 ? "arrow.up.right" : "arrow.down.right",
                color: trend <= 0 ? .green : .red
            )

            summaryCard(
                title: "Predicted Spending",
                value: prediction.currencyFormatted(code: currency),
                icon: "chart.line.uptrend.xyaxis",
                color: .blue
            )

            summaryCard(
                title: "Savings Rate",
                value: String(format: "%.1f%%", savingsRateValue),
                icon: "banknote",
                color: savingsRateValue >= 0 ? .green : .red
            )
        }
    }

    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }
}

private extension Decimal {
    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }
}
