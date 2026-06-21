import Foundation

/// Analytics over the new `ExpenseDomain.Transaction`s, summed as `Decimal` and
/// projected into the same plot DTOs (`MonthlyTotal`/`CategoryBreakdown`/
/// `BalancePoint`) the charts already consume. The domain-backed successor to
/// `StatsService` (which works off legacy `Double`/`Transaction`); the Analytics
/// screen switches to this as it adopts the repository.
///
/// Money is summed in `Decimal` and converted to `Double` only at the plotting
/// boundary, where Swift Charts needs it.
public enum DomainStatsService {

    private static let calendar = Calendar.current

    /// Distinct, stable colours for category slices (domain categories don't
    /// carry the legacy flat catalog's icon/colour). Assigned by rank.
    static let categoryColorPalette: [String] = [
        "#FF6B6B", "#4ECDC4", "#FFD93D", "#6C5CE7", "#00B894",
        "#E17055", "#0984E3", "#E84393", "#FDCB6E", "#00CEC9",
    ]

    // MARK: - Monthly totals

    public static func monthlyTotals(
        transactions: [ExpenseDomain.Transaction],
        months: Int,
        now: Date = Date()
    ) -> [MonthlyTotal] {
        var results: [MonthlyTotal] = []
        for i in 0..<months {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
            let start = monthDate.startOfMonth
            let end = monthDate.endOfMonth
            let income = sum(transactions, type: .income, from: start, to: end)
            let expenses = sum(transactions, type: .expense, from: start, to: end)
            results.append(MonthlyTotal(
                month: start,
                income: income.doubleValue,
                expenses: expenses.doubleValue,
                net: (income - expenses).doubleValue
            ))
        }
        return results.reversed()
    }

    // MARK: - Category breakdown

    public static func categoryBreakdown(
        transactions: [ExpenseDomain.Transaction],
        month: Date
    ) -> [CategoryBreakdown] {
        let start = month.startOfMonth
        let end = month.endOfMonth
        let monthExpenses = transactions.filter {
            $0.type == .expense && $0.date >= start && $0.date <= end
        }
        let total = monthExpenses.reduce(Decimal(0)) { $0 + $1.amount }
        guard total > 0 else { return [] }

        // Group by category, keeping uncategorized as its own bucket.
        var totals: [ExpenseDomain.Category?: Decimal] = [:]
        for transaction in monthExpenses {
            totals[transaction.category, default: 0] += transaction.amount
        }

        let totalValue = total.doubleValue
        let ranked = totals.sorted { $0.value > $1.value }
        return ranked.enumerated().map { index, entry in
            CategoryBreakdown(
                categoryId: entry.key?.id.uuidString ?? "uncategorized",
                categoryName: entry.key?.displayName ?? "Uncategorized",
                categoryIcon: "",
                categoryColor: categoryColorPalette[index % categoryColorPalette.count],
                total: entry.value.doubleValue,
                percentage: totalValue > 0 ? (entry.value.doubleValue / totalValue) * 100 : 0
            )
        }
    }

    // MARK: - Net balance trend

    public static func netBalanceTrend(
        transactions: [ExpenseDomain.Transaction],
        months: Int,
        now: Date = Date()
    ) -> [BalancePoint] {
        let sorted = transactions.sorted { $0.date < $1.date }
        var runningBalance = Decimal(0)
        var points: [BalancePoint] = []
        for i in stride(from: months - 1, through: 0, by: -1) {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
            let start = monthDate.startOfMonth
            let end = monthDate.endOfMonth
            for transaction in sorted where transaction.date >= start && transaction.date <= end {
                runningBalance += transaction.type == .income ? transaction.amount : -transaction.amount
            }
            points.append(BalancePoint(date: end, balance: runningBalance.doubleValue))
        }
        return points
    }

    // MARK: - Spending trend

    public static func spendingTrend(
        transactions: [ExpenseDomain.Transaction],
        now: Date = Date()
    ) -> Double {
        let current = sum(transactions, type: .expense, from: now.startOfMonth, to: now.endOfMonth).doubleValue
        let previousMonth = now.monthsAgo(1)
        let prior = sum(transactions, type: .expense, from: previousMonth.startOfMonth, to: previousMonth.endOfMonth).doubleValue
        guard prior > 0 else { return current > 0 ? 100 : 0 }
        return ((current - prior) / prior) * 100
    }

    // MARK: - Spending prediction (3/2/1-weighted moving average)

    public static func spendingPrediction(
        transactions: [ExpenseDomain.Transaction],
        now: Date = Date()
    ) -> Double {
        var monthlyExpenses: [Double] = []
        for i in 1...3 {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
            monthlyExpenses.append(
                sum(transactions, type: .expense, from: monthDate.startOfMonth, to: monthDate.endOfMonth).doubleValue
            )
        }
        guard !monthlyExpenses.isEmpty else { return 0 }
        let weights: [Double] = [3, 2, 1]
        var weightedSum: Double = 0
        var totalWeight: Double = 0
        for (i, value) in monthlyExpenses.enumerated() {
            weightedSum += value * weights[i]
            totalWeight += weights[i]
        }
        return totalWeight > 0 ? weightedSum / totalWeight : 0
    }

    // MARK: - Total for period

    public static func totalForPeriod(
        transactions: [ExpenseDomain.Transaction],
        type: TransactionType,
        startDate: Date,
        endDate: Date
    ) -> Decimal {
        sum(transactions, type: type, from: startDate, to: endDate)
    }

    // MARK: - Helpers

    private static func sum(
        _ transactions: [ExpenseDomain.Transaction],
        type: TransactionType,
        from start: Date,
        to end: Date
    ) -> Decimal {
        transactions
            .filter { $0.type == type && $0.date >= start && $0.date <= end }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }
}

private extension Decimal {
    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }
}
