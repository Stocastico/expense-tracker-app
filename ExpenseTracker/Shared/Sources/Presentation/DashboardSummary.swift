import Foundation

/// The dashboard's derived figures, computed once from a single (already
/// account-filtered, date-descending) transaction list. Previously the view
/// recomputed `filteredTransactions` and re-scanned it inside every computed
/// property on each `body` evaluation; building this once collapses that work.
public struct DashboardSummary {

    /// A budget that has reached the alert threshold for its current period.
    public struct BudgetAlert: Identifiable {
        public let budgetId: UUID
        public let categoryId: String
        public let spent: Double
        public let limit: Double
        public let percentage: Double
        public var id: UUID { budgetId }
    }

    public let monthExpenses: Double
    public let monthIncome: Double
    public let netBalance: Double
    public let spendingTrend: Double
    public let topCategory: (name: String, amount: Double)?
    public let budgetAlerts: [BudgetAlert]
    public let recentTransactions: [Transaction]

    /// Alert when spending reaches this percentage of a budget's limit.
    private static let alertThreshold: Double = 80

    /// Derives the dashboard figures.
    ///
    /// - Parameters:
    ///   - transactions: account-filtered transactions, sorted newest-first.
    ///   - budgets: all budgets to check for alerts.
    ///   - startOfMonthDay: the configured first day of the budget month.
    ///   - referenceDate: "now" (injectable for tests).
    public static func make(
        transactions: [Transaction],
        budgets: [Budget],
        startOfMonthDay: Int,
        referenceDate: Date = Date()
    ) -> DashboardSummary {
        let monthStart = referenceDate.startOfMonth
        let monthEnd = referenceDate.endOfMonth

        let expenses = StatsService.totalForPeriod(
            transactions: transactions, type: .expense, startDate: monthStart, endDate: monthEnd
        )
        let income = StatsService.totalForPeriod(
            transactions: transactions, type: .income, startDate: monthStart, endDate: monthEnd
        )

        let topCategory: (name: String, amount: Double)?
        if let top = StatsService.topCategory(transactions: transactions, month: referenceDate) {
            topCategory = (DefaultCategories.category(withId: top.categoryId).displayName, top.amount)
        } else {
            topCategory = nil
        }

        let alerts = budgets.compactMap { budget -> BudgetAlert? in
            let range = budget.currentPeriodRange(startOfMonth: startOfMonthDay)
            let spent = transactions
                .filter {
                    $0.type == .expense
                        && $0.categoryId == budget.categoryId
                        && $0.date >= range.start
                        && $0.date <= range.end
                }
                .reduce(0.0) { $0 + $1.storedAmount }
            let percentage = budget.storedAmount > 0 ? (spent / budget.storedAmount) * 100 : 0
            guard percentage >= alertThreshold else { return nil }
            return BudgetAlert(
                budgetId: budget.id,
                categoryId: budget.categoryId,
                spent: spent,
                limit: budget.storedAmount,
                percentage: percentage
            )
        }
        .sorted { $0.percentage > $1.percentage }

        return DashboardSummary(
            monthExpenses: expenses,
            monthIncome: income,
            netBalance: income - expenses,
            spendingTrend: StatsService.spendingTrend(transactions: transactions),
            topCategory: topCategory,
            budgetAlerts: alerts,
            recentTransactions: Array(transactions.prefix(10))
        )
    }
}
