import Testing
import Foundation

/// Drives `DashboardFigures.make`, the domain-backed (`Decimal`) replacement for
/// `DashboardSummary`: it derives the dashboard's figures from
/// `ExpenseDomain.Transaction`s read through the repository, with money kept as
/// `Decimal` end-to-end. Budgets are still the legacy type, so their flat
/// category id is mapped into the domain catalog via a resolver.
@MainActor
struct DashboardFiguresTests {

    private let food = ExpenseDomain.Category(displayName: "Cibo")

    private func expense(_ amount: String, date: Date, category: ExpenseDomain.Category? = nil) -> ExpenseDomain.Transaction {
        ExpenseDomain.Transaction(amount: Decimal(string: amount)!, date: date, type: .expense, category: category)
    }

    private func income(_ amount: String, date: Date) -> ExpenseDomain.Transaction {
        ExpenseDomain.Transaction(amount: Decimal(string: amount)!, date: date, type: .income)
    }

    /// Maps the one legacy budget category used in these tests onto `food`.
    private func resolver() -> LegacyExpenseMigration.CategoryResolver {
        { legacyId in legacyId == "food-dining" ? (category: food, subcategory: nil) : nil }
    }

    @Test("Month totals and net are computed in Decimal for the reference month")
    func computesMonthTotalsAndNet() {
        let now = Date()
        let transactions = [
            expense("30.00", date: now),
            income("100.00", date: now),
            expense("999.00", date: now.monthsAgo(2)),
        ]
        let figures = DashboardFigures.make(
            transactions: transactions, budgets: [], startOfMonthDay: 1, referenceDate: now, resolveCategory: resolver()
        )
        #expect(figures.monthExpenses == Decimal(string: "30.00"))
        #expect(figures.monthIncome == Decimal(string: "100.00"))
        #expect(figures.netBalance == Decimal(string: "70.00"))
    }

    @Test("Recent transactions are the first ten of the (pre-sorted) input")
    func recentTransactionsAreFirstTen() {
        let now = Date()
        let transactions = (0..<15).map { expense("\($0).00", date: now) }
        let figures = DashboardFigures.make(
            transactions: transactions, budgets: [], startOfMonthDay: 1, referenceDate: now, resolveCategory: resolver()
        )
        #expect(figures.recentTransactions.count == 10)
    }

    @Test("Top category reflects the highest expense category this month")
    func topCategoryReflectsHighestSpend() {
        let now = Date()
        let drink = ExpenseDomain.Category(displayName: "Bevande")
        let transactions = [
            expense("10.00", date: now, category: drink),
            expense("50.00", date: now, category: food),
        ]
        let figures = DashboardFigures.make(
            transactions: transactions, budgets: [], startOfMonthDay: 1, referenceDate: now, resolveCategory: resolver()
        )
        #expect(figures.topCategory?.amount == Decimal(string: "50.00"))
        #expect(figures.topCategory?.name == "Cibo")
    }

    @Test("A budget at/above 80% of its limit raises an alert, mapped via the resolver")
    func budgetAlertWhenNearingLimit() throws {
        let now = Date()
        let budget = Budget(categoryId: "food-dining", amount: 100, period: .monthly)
        let transactions = [expense("90.00", date: now, category: food)]
        let figures = DashboardFigures.make(
            transactions: transactions, budgets: [budget], startOfMonthDay: 1, referenceDate: now, resolveCategory: resolver()
        )
        let alert = try #require(figures.budgetAlerts.first)
        #expect(alert.categoryId == "food-dining")
        #expect(alert.spent == Decimal(string: "90.00"))
        #expect(alert.limit == Decimal(string: "100"))
        #expect(alert.percentage == 90)
    }

    @Test("A budget below the threshold raises no alert")
    func noAlertBelowThreshold() {
        let now = Date()
        let budget = Budget(categoryId: "food-dining", amount: 100, period: .monthly)
        let transactions = [expense("10.00", date: now, category: food)]
        let figures = DashboardFigures.make(
            transactions: transactions, budgets: [budget], startOfMonthDay: 1, referenceDate: now, resolveCategory: resolver()
        )
        #expect(figures.budgetAlerts.isEmpty)
    }
}
