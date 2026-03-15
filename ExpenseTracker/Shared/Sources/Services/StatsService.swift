import Foundation

// MARK: - Stats Data Types

public struct MonthlyTotal: Identifiable {
    public let id = UUID()
    public let month: Date
    public let income: Double
    public let expenses: Double
    public let net: Double

    public init(month: Date, income: Double, expenses: Double, net: Double) {
        self.month = month
        self.income = income
        self.expenses = expenses
        self.net = net
    }
}

public struct CategoryBreakdown: Identifiable {
    public let id = UUID()
    public let categoryId: String
    public let categoryName: String
    public let categoryIcon: String
    public let categoryColor: String
    public let total: Double
    public let percentage: Double

    public init(
        categoryId: String,
        categoryName: String,
        categoryIcon: String,
        categoryColor: String,
        total: Double,
        percentage: Double
    ) {
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.categoryIcon = categoryIcon
        self.categoryColor = categoryColor
        self.total = total
        self.percentage = percentage
    }
}

public struct BalancePoint: Identifiable {
    public let id = UUID()
    public let date: Date
    public let balance: Double

    public init(date: Date, balance: Double) {
        self.date = date
        self.balance = balance
    }
}

// MARK: - Stats Service

public struct StatsService {

    private static let calendar = Calendar.current

    // MARK: - Monthly Totals

    public static func monthlyTotals(transactions: [Transaction], months: Int) -> [MonthlyTotal] {
        let now = Date()
        var results: [MonthlyTotal] = []

        for i in 0..<months {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now),
                  let monthStart = startOfMonth(for: monthDate),
                  let monthEnd = endOfMonth(for: monthDate) else {
                continue
            }

            let monthTransactions = transactions.filter { t in
                t.date >= monthStart && t.date <= monthEnd
            }

            let income = monthTransactions
                .filter { $0.transactionType == .income }
                .reduce(0.0) { $0 + $1.storedAmount }

            let expenses = monthTransactions
                .filter { $0.transactionType == .expense }
                .reduce(0.0) { $0 + $1.storedAmount }

            results.append(MonthlyTotal(
                month: monthStart,
                income: income,
                expenses: expenses,
                net: income - expenses
            ))
        }

        return results.reversed()
    }

    // MARK: - Category Breakdown

    public static func categoryBreakdown(transactions: [Transaction], month: Date) -> [CategoryBreakdown] {
        guard let monthStart = startOfMonth(for: month),
              let monthEnd = endOfMonth(for: month) else {
            return []
        }

        let monthExpenses = transactions.filter { t in
            t.transactionType == .expense && t.date >= monthStart && t.date <= monthEnd
        }

        let totalExpenses = monthExpenses.reduce(0.0) { $0 + $1.storedAmount }
        guard totalExpenses > 0 else { return [] }

        // Group by categoryId
        var categoryTotals: [String: Double] = [:]
        for transaction in monthExpenses {
            categoryTotals[transaction.categoryId, default: 0] += transaction.storedAmount
        }

        var breakdowns: [CategoryBreakdown] = []
        for (categoryId, total) in categoryTotals {
            let category = DefaultCategories.all.category(withId: categoryId)
            breakdowns.append(CategoryBreakdown(
                categoryId: categoryId,
                categoryName: category?.name ?? "Unknown",
                categoryIcon: category?.icon ?? "questionmark.circle",
                categoryColor: category?.color ?? "#888888",
                total: total,
                percentage: (total / totalExpenses) * 100.0
            ))
        }

        return breakdowns.sorted { $0.total > $1.total }
    }

    // MARK: - Net Balance Trend

    public static func netBalanceTrend(transactions: [Transaction], months: Int) -> [BalancePoint] {
        let now = Date()
        var points: [BalancePoint] = []
        var runningBalance: Double = 0

        // Sort transactions by date ascending
        let sorted = transactions.sorted { $0.date < $1.date }

        for i in stride(from: months - 1, through: 0, by: -1) {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now),
                  let monthStart = startOfMonth(for: monthDate),
                  let monthEnd = endOfMonth(for: monthDate) else {
                continue
            }

            let monthTransactions = sorted.filter { t in
                t.date >= monthStart && t.date <= monthEnd
            }

            for transaction in monthTransactions {
                if transaction.transactionType == .income {
                    runningBalance += transaction.storedAmount
                } else {
                    runningBalance -= transaction.storedAmount
                }
            }

            points.append(BalancePoint(date: monthEnd, balance: runningBalance))
        }

        return points
    }

    // MARK: - Savings Rate

    public static func savingsRate(income: Double, expenses: Double) -> Double {
        guard income > 0 else { return 0 }
        let savings = income - expenses
        return (savings / income) * 100.0
    }

    // MARK: - Spending Prediction (Weighted Moving Average)

    public static func spendingPrediction(transactions: [Transaction]) -> Double {
        let now = Date()
        var monthlyExpenses: [Double] = []

        for i in 1...3 {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now),
                  let monthStart = startOfMonth(for: monthDate),
                  let monthEnd = endOfMonth(for: monthDate) else {
                continue
            }

            let total = transactions
                .filter { $0.transactionType == .expense && $0.date >= monthStart && $0.date <= monthEnd }
                .reduce(0.0) { $0 + $1.storedAmount }

            monthlyExpenses.append(total)
        }

        guard !monthlyExpenses.isEmpty else { return 0 }

        // Weighted moving average: most recent month gets highest weight
        // Weights: [3, 2, 1] for [1 month ago, 2 months ago, 3 months ago]
        let weights: [Double] = [3.0, 2.0, 1.0]
        var weightedSum: Double = 0
        var totalWeight: Double = 0

        for i in 0..<monthlyExpenses.count {
            let weight = weights[i]
            weightedSum += monthlyExpenses[i] * weight
            totalWeight += weight
        }

        return totalWeight > 0 ? weightedSum / totalWeight : 0
    }

    // MARK: - Spending Trend

    public static func spendingTrend(transactions: [Transaction]) -> Double {
        let now = Date()

        guard let currentMonthStart = startOfMonth(for: now),
              let currentMonthEnd = endOfMonth(for: now),
              let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: now),
              let previousMonthStart = startOfMonth(for: previousMonthDate),
              let previousMonthEnd = endOfMonth(for: previousMonthDate) else {
            return 0
        }

        let currentExpenses = transactions
            .filter { $0.transactionType == .expense && $0.date >= currentMonthStart && $0.date <= currentMonthEnd }
            .reduce(0.0) { $0 + $1.storedAmount }

        let previousExpenses = transactions
            .filter { $0.transactionType == .expense && $0.date >= previousMonthStart && $0.date <= previousMonthEnd }
            .reduce(0.0) { $0 + $1.storedAmount }

        guard previousExpenses > 0 else {
            return currentExpenses > 0 ? 100.0 : 0
        }

        return ((currentExpenses - previousExpenses) / previousExpenses) * 100.0
    }

    // MARK: - Top Category

    public static func topCategory(transactions: [Transaction], month: Date) -> (categoryId: String, amount: Double)? {
        guard let monthStart = startOfMonth(for: month),
              let monthEnd = endOfMonth(for: month) else {
            return nil
        }

        let monthExpenses = transactions.filter { t in
            t.transactionType == .expense && t.date >= monthStart && t.date <= monthEnd
        }

        var categoryTotals: [String: Double] = [:]
        for transaction in monthExpenses {
            categoryTotals[transaction.categoryId, default: 0] += transaction.storedAmount
        }

        guard let top = categoryTotals.max(by: { $0.value < $1.value }) else {
            return nil
        }

        return (categoryId: top.key, amount: top.value)
    }

    // MARK: - Total for Period

    public static func totalForPeriod(
        transactions: [Transaction],
        type: TransactionType,
        startDate: Date,
        endDate: Date
    ) -> Double {
        return transactions
            .filter { $0.transactionType == type && $0.date >= startDate && $0.date <= endDate }
            .reduce(0.0) { $0 + $1.storedAmount }
    }

    // MARK: - Date Helpers

    private static func startOfMonth(for date: Date) -> Date? {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components)
    }

    private static func endOfMonth(for date: Date) -> Date? {
        guard let start = startOfMonth(for: date),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: start) else {
            return nil
        }
        return calendar.date(byAdding: .second, value: -1, to: nextMonth)
    }
}
