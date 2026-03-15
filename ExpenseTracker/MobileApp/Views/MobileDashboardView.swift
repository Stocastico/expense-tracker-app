import SwiftUI
import SwiftData

struct MobileDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \Budget.createdAt) private var budgets: [Budget]
    @Query private var settingsResults: [AppSettings]

    @State private var showBudgets = false

    private var settings: AppSettings {
        settingsResults.first ?? AppSettings()
    }

    private var currency: String { settings.currency }

    private var now: Date { Date() }
    private var monthStart: Date { now.startOfMonth }
    private var monthEnd: Date { now.endOfMonth }

    private var monthExpenses: Double {
        StatsService.totalForPeriod(
            transactions: allTransactions,
            type: .expense,
            startDate: monthStart,
            endDate: monthEnd
        )
    }

    private var monthIncome: Double {
        StatsService.totalForPeriod(
            transactions: allTransactions,
            type: .income,
            startDate: monthStart,
            endDate: monthEnd
        )
    }

    private var netBalance: Double { monthIncome - monthExpenses }

    private var spendingTrend: Double {
        StatsService.spendingTrend(transactions: allTransactions)
    }

    private var savingsRate: Double {
        StatsService.savingsRate(income: monthIncome, expenses: monthExpenses)
    }

    private var budgetAlerts: [(budget: Budget, spent: Double, percentage: Double)] {
        budgets.compactMap { budget in
            let range = budget.currentPeriodRange()
            let spent = allTransactions
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
        Array(allTransactions.prefix(5))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    balanceCard
                    statsRow
                    if !budgetAlerts.isEmpty {
                        budgetAlertsSection
                    }
                    recentSection
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle(now.monthYearString)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showBudgets = true
                    } label: {
                        Image(systemName: "chart.bar.doc.horizontal")
                    }
                }
            }
            .sheet(isPresented: $showBudgets) {
                MobileBudgetsView()
            }
        }
    }

    // MARK: - Balance Card

    private var balanceCard: some View {
        VStack(spacing: 8) {
            Text("Net Balance")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))

            Text(netBalance.currencyFormatted(code: currency))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            HStack(spacing: 16) {
                trendBadge
                savingsBadge
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(
            LinearGradient(
                colors: netBalance >= 0
                    ? [Color(hex: "#34C759"), Color(hex: "#30D158")]
                    : [Color(hex: "#FF3B30"), Color(hex: "#FF6961")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: (netBalance >= 0 ? Color.green : Color.red).opacity(0.35), radius: 12, y: 6)
    }

    private var trendBadge: some View {
        let isUp = spendingTrend > 0
        return HStack(spacing: 4) {
            Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2)
            Text(String(format: "%+.1f%%", spendingTrend))
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.white.opacity(0.2))
        .clipShape(Capsule())
    }

    private var savingsBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "banknote")
                .font(.caption2)
            Text(String(format: "%.0f%% saved", max(savingsRate, 0)))
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.white.opacity(0.2))
        .clipShape(Capsule())
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(
                title: "Income",
                value: monthIncome.currencyFormatted(code: currency),
                icon: "arrow.down.circle.fill",
                color: .green
            )
            statCard(
                title: "Expenses",
                value: monthExpenses.currencyFormatted(code: currency),
                icon: "arrow.up.circle.fill",
                color: .red
            )
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(color.opacity(0.15), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
    }

    // MARK: - Budget Alerts

    private var budgetAlertsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Budget Alerts", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Spacer()
                Button("View All") {
                    showBudgets = true
                }
                .font(.subheadline)
                .foregroundStyle(.accentColor)
            }

            ForEach(budgetAlerts.prefix(3), id: \.budget.id) { alert in
                let cat = DefaultCategories.category(withId: alert.budget.categoryId)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(cat.icon)
                        Text(cat.name)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(String(format: "%.0f%%", alert.percentage))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(alert.percentage >= 100 ? .red : .orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(alert.percentage >= 100
                                          ? Color.red.opacity(0.12)
                                          : Color.orange.opacity(0.12))
                            )
                    }
                    ProgressView(value: min(alert.percentage / 100, 1.0))
                        .tint(alert.percentage >= 100 ? .red : .orange)
                    HStack {
                        Text("\(alert.spent.currencyFormatted(code: currency)) of \(alert.budget.storedAmount.currencyFormatted(code: currency))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        let remaining = alert.budget.storedAmount - alert.spent
                        if remaining < 0 {
                            Text("\(abs(remaining).currencyFormatted(code: currency)) over")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemGroupedBackground))
        )
    }

    // MARK: - Recent Transactions

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Transactions")
                .font(.headline)

            if recentTransactions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No transactions yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Tap the + tab to add your first transaction")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentTransactions.enumerated()), id: \.element.id) { index, transaction in
                        dashboardRow(transaction)
                        if index < recentTransactions.count - 1 {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
        }
    }

    private func dashboardRow(_ transaction: Transaction) -> some View {
        let cat = DefaultCategories.category(withId: transaction.categoryId)
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: cat.color).opacity(0.15))
                    .frame(width: 40, height: 40)
                Text(cat.icon)
                    .font(.body)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.descriptionText)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(transaction.date.relativeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(transaction.type == .expense
                 ? "-\(transaction.storedAmount.currencyFormatted(code: currency))"
                 : "+\(transaction.storedAmount.currencyFormatted(code: currency))")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(transaction.type == .expense ? .red : .green)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
