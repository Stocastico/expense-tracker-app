import SwiftUI
import SwiftData
import Charts

struct AnalyticsView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query private var settings: [AppSettings]

    @State private var selectedMonths: Int = 6

    var selectedAccount: Account?

    private var currentSettings: AppSettings? {
        settings.first
    }

    private var currency: String {
        currentSettings?.currency ?? "USD"
    }

    private var filteredTransactions: [Transaction] {
        if let account = selectedAccount {
            return allTransactions.filter { $0.account?.id == account.id }
        }
        return allTransactions
    }

    private var monthlyData: [MonthlyTotal] {
        StatsService.monthlyTotals(transactions: filteredTransactions, months: selectedMonths)
    }

    private var balanceData: [BalancePoint] {
        StatsService.netBalanceTrend(transactions: filteredTransactions, months: selectedMonths)
    }

    private var categoryData: [CategoryBreakdown] {
        StatsService.categoryBreakdown(transactions: filteredTransactions, month: Date())
    }

    private var currentMonthIncome: Double {
        StatsService.totalForPeriod(
            transactions: filteredTransactions,
            type: .income,
            startDate: Date().startOfMonth,
            endDate: Date().endOfMonth
        )
    }

    private var currentMonthExpenses: Double {
        StatsService.totalForPeriod(
            transactions: filteredTransactions,
            type: .expense,
            startDate: Date().startOfMonth,
            endDate: Date().endOfMonth
        )
    }

    private var trend: Double {
        StatsService.spendingTrend(transactions: filteredTransactions)
    }

    private var prediction: Double {
        StatsService.spendingPrediction(transactions: filteredTransactions)
    }

    private var savingsRateValue: Double {
        StatsService.savingsRate(income: currentMonthIncome, expenses: currentMonthExpenses)
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
