import SwiftUI
import SwiftData
import Charts

struct MobileAnalyticsView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query private var settingsResults: [AppSettings]

    @State private var selectedMonths: Int = 6

    private var settings: AppSettings { settingsResults.first ?? AppSettings() }
    private var currency: String { settings.currency }

    private var monthlyData: [MonthlyTotal] {
        StatsService.monthlyTotals(transactions: allTransactions, months: selectedMonths)
    }

    private var categoryData: [CategoryBreakdown] {
        StatsService.categoryBreakdown(transactions: allTransactions, month: Date())
    }

    private var balanceData: [BalancePoint] {
        StatsService.netBalanceTrend(transactions: allTransactions, months: selectedMonths)
    }

    private var currentMonthIncome: Double {
        StatsService.totalForPeriod(
            transactions: allTransactions,
            type: .income,
            startDate: Date().startOfMonth,
            endDate: Date().endOfMonth
        )
    }

    private var currentMonthExpenses: Double {
        StatsService.totalForPeriod(
            transactions: allTransactions,
            type: .expense,
            startDate: Date().startOfMonth,
            endDate: Date().endOfMonth
        )
    }

    private var spendingTrend: Double {
        StatsService.spendingTrend(transactions: allTransactions)
    }

    private var prediction: Double {
        StatsService.spendingPrediction(transactions: allTransactions)
    }

    private var savingsRate: Double {
        StatsService.savingsRate(income: currentMonthIncome, expenses: currentMonthExpenses)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    periodPicker
                    summaryCards
                    monthlyBarChartSection
                    categoryBreakdownSection
                    balanceTrendSection
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $selectedMonths) {
            Text("3M").tag(3)
            Text("6M").tag(6)
            Text("12M").tag(12)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                summaryCard(
                    title: "Spending Trend",
                    value: String(format: "%+.1f%%", spendingTrend),
                    icon: spendingTrend <= 0 ? "arrow.down.right" : "arrow.up.right",
                    color: spendingTrend <= 0 ? .green : .red,
                    subtitle: "vs last month"
                )
                summaryCard(
                    title: "Savings Rate",
                    value: String(format: "%.1f%%", savingsRate),
                    icon: "banknote",
                    color: savingsRate >= 20 ? .green : savingsRate >= 0 ? .orange : .red,
                    subtitle: "this month"
                )
            }
            summaryCard(
                title: "Predicted Spending",
                value: prediction.currencyFormatted(code: currency),
                icon: "chart.line.uptrend.xyaxis",
                color: .blue,
                subtitle: "based on last 3 months"
            )
        }
    }

    private func summaryCard(title: String, value: String, icon: String, color: Color, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(color)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .frame(maxWidth: .infinity)
    }

    // MARK: - Monthly Bar Chart

    private var monthlyBarChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Income vs Expenses")
                .font(.headline)

            if monthlyData.isEmpty {
                emptyChartView(icon: "chart.bar", message: "Add transactions to see monthly trends.")
            } else {
                Chart {
                    ForEach(monthlyData) { item in
                        BarMark(
                            x: .value("Month", item.month.shortMonthString),
                            y: .value("Amount", item.income)
                        )
                        .foregroundStyle(by: .value("Type", "Income"))
                        .position(by: .value("Type", "Income"))

                        BarMark(
                            x: .value("Month", item.month.shortMonthString),
                            y: .value("Amount", item.expenses)
                        )
                        .foregroundStyle(by: .value("Type", "Expenses"))
                        .position(by: .value("Type", "Expenses"))
                    }
                }
                .chartForegroundStyleScale([
                    "Income": Color.green,
                    "Expenses": Color.red
                ])
                .chartLegend(position: .bottom, alignment: .center)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(compactCurrency(doubleValue))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 220)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Category Breakdown

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Spending by Category")
                    .font(.headline)
                Text("(this month)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if categoryData.isEmpty {
                emptyChartView(icon: "chart.pie", message: "No expense data for this month.")
            } else {
                VStack(spacing: 0) {
                    // Donut chart
                    Chart(categoryData) { item in
                        SectorMark(
                            angle: .value("Amount", item.total),
                            innerRadius: .ratio(0.55),
                            angularInset: 2
                        )
                        .foregroundStyle(Color(hex: item.categoryColor))
                        .cornerRadius(4)
                    }
                    .frame(height: 200)
                    .padding(.bottom, 12)

                    // Legend list
                    VStack(spacing: 0) {
                        ForEach(categoryData.prefix(8)) { item in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(hex: item.categoryColor))
                                    .frame(width: 10, height: 10)
                                Text(item.categoryIcon)
                                    .font(.caption)
                                Text(item.categoryName)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(item.total.currencyFormatted(code: currency))
                                        .font(.subheadline.monospacedDigit())
                                    Text(String(format: "%.0f%%", item.percentage))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 8)

                            if item.id != categoryData.prefix(8).last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Balance Trend

    private var balanceTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Net Balance Trend")
                .font(.headline)

            if balanceData.isEmpty {
                emptyChartView(icon: "chart.line.uptrend.xyaxis", message: "Not enough data yet.")
            } else {
                Chart(balanceData) { point in
                    LineMark(
                        x: .value("Date", point.date.shortMonthString),
                        y: .value("Balance", point.balance)
                    )
                    .foregroundStyle(Color.accentColor)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", point.date.shortMonthString),
                        y: .value("Balance", point.balance)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.25), Color.accentColor.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let d = value.as(Double.self) {
                                Text(compactCurrency(d))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Helpers

    private func emptyChartView(icon: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }

    private func compactCurrency(_ value: Double) -> String {
        if abs(value) >= 1000 {
            return String(format: "%.0fk", value / 1000)
        }
        return String(format: "%.0f", value)
    }
}

// MARK: - Date Extension for short month

private extension Date {
    var shortMonthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: self)
    }
}
