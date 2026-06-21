import Foundation

/// The dashboard's derived figures, computed from domain
/// `ExpenseDomain.Transaction`s read through the `ExpenseRepository`, with money
/// kept as `Decimal` end-to-end. The domain-backed successor to
/// `DashboardSummary` (which works off legacy `Double` transactions); the view
/// switches to this as the dashboard adopts the repository.
///
/// Budgets are still the legacy `Budget` type with a flat-category id, so a
/// `CategoryResolver` maps each budget's category into the two-level domain
/// catalog before its spend is summed.
public struct DashboardFigures {

    /// A budget that has reached the alert threshold for its current period.
    public struct BudgetAlert: Identifiable {
        public let budgetId: UUID
        /// The legacy flat-category id, kept so the view can show its icon/name.
        public let categoryId: String
        public let spent: Decimal
        public let limit: Decimal
        public let percentage: Double
        public var id: UUID { budgetId }
    }

    public let monthExpenses: Decimal
    public let monthIncome: Decimal
    public let netBalance: Decimal
    public let spendingTrend: Double
    public let topCategory: (name: String, amount: Decimal)?
    public let budgetAlerts: [BudgetAlert]
    public let recentTransactions: [ExpenseDomain.Transaction]

    /// Alert when spending reaches this percentage of a budget's limit.
    private static let alertThreshold: Double = 80

    /// Derives the dashboard figures.
    ///
    /// - Parameters:
    ///   - transactions: account-filtered domain transactions, sorted newest-first.
    ///   - budgets: all legacy budgets to check for alerts.
    ///   - startOfMonthDay: the configured first day of the budget month.
    ///   - referenceDate: "now" (injectable for tests).
    ///   - resolveCategory: maps a legacy budget category id into the domain catalog.
    public static func make(
        transactions: [ExpenseDomain.Transaction],
        budgets: [Budget],
        startOfMonthDay: Int,
        referenceDate: Date = Date(),
        resolveCategory: LegacyExpenseMigration.CategoryResolver = DefaultLegacyCategoryMapping.resolver()
    ) -> DashboardFigures {
        let monthStart = referenceDate.startOfMonth
        let monthEnd = referenceDate.endOfMonth

        let expenses = total(transactions, type: .expense, from: monthStart, to: monthEnd)
        let income = total(transactions, type: .income, from: monthStart, to: monthEnd)

        return DashboardFigures(
            monthExpenses: expenses,
            monthIncome: income,
            netBalance: income - expenses,
            spendingTrend: spendingTrend(transactions, referenceDate: referenceDate),
            topCategory: topCategory(transactions, from: monthStart, to: monthEnd),
            budgetAlerts: budgetAlerts(transactions, budgets: budgets, startOfMonthDay: startOfMonthDay, resolveCategory: resolveCategory),
            recentTransactions: Array(transactions.prefix(10))
        )
    }

    // MARK: - Helpers

    private static func total(
        _ transactions: [ExpenseDomain.Transaction],
        type: TransactionType,
        from start: Date,
        to end: Date
    ) -> Decimal {
        transactions
            .filter { $0.type == type && $0.date >= start && $0.date <= end }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    /// Highest-spend top-level category for the reference month, by `Decimal` sum.
    /// Uncategorized expenses are ignored.
    private static func topCategory(
        _ transactions: [ExpenseDomain.Transaction],
        from start: Date,
        to end: Date
    ) -> (name: String, amount: Decimal)? {
        var totals: [ExpenseDomain.Category: Decimal] = [:]
        for transaction in transactions
        where transaction.type == .expense && transaction.date >= start && transaction.date <= end {
            guard let category = transaction.category else { continue }
            totals[category, default: 0] += transaction.amount
        }
        guard let top = totals.max(by: { $0.value < $1.value }) else { return nil }
        return (name: top.key.displayName, amount: top.value)
    }

    /// Percentage change in this month's expense vs the previous month's.
    private static func spendingTrend(
        _ transactions: [ExpenseDomain.Transaction],
        referenceDate: Date
    ) -> Double {
        let currentStart = referenceDate.startOfMonth
        let currentEnd = referenceDate.endOfMonth
        let previous = referenceDate.monthsAgo(1)
        let previousStart = previous.startOfMonth
        let previousEnd = previous.endOfMonth

        let current = total(transactions, type: .expense, from: currentStart, to: currentEnd).doubleValue
        let prior = total(transactions, type: .expense, from: previousStart, to: previousEnd).doubleValue

        guard prior > 0 else { return current > 0 ? 100 : 0 }
        return ((current - prior) / prior) * 100
    }

    private static func budgetAlerts(
        _ transactions: [ExpenseDomain.Transaction],
        budgets: [Budget],
        startOfMonthDay: Int,
        resolveCategory: LegacyExpenseMigration.CategoryResolver
    ) -> [BudgetAlert] {
        budgets.compactMap { budget -> BudgetAlert? in
            guard let categoryId = resolveCategory(budget.categoryId)?.category.id else { return nil }
            let range = budget.currentPeriodRange(startOfMonth: startOfMonthDay)
            let spent = transactions
                .filter {
                    $0.type == .expense
                        && $0.category?.id == categoryId
                        && $0.date >= range.start
                        && $0.date <= range.end
                }
                .reduce(Decimal(0)) { $0 + $1.amount }
            let limit = budget.amount
            let limitValue = limit.doubleValue
            let percentage = limitValue > 0 ? (spent.doubleValue / limitValue) * 100 : 0
            guard percentage >= alertThreshold else { return nil }
            return BudgetAlert(
                budgetId: budget.id,
                categoryId: budget.categoryId,
                spent: spent,
                limit: limit,
                percentage: percentage
            )
        }
        .sorted { $0.percentage > $1.percentage }
    }
}

private extension Decimal {
    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }
}
