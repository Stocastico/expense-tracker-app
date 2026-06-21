import Testing
import Foundation

/// Drives `DashboardSummary.make`, which derives all the dashboard's figures in
/// one pass so the view stops recomputing `filteredTransactions` and the stats
/// on every body evaluation.
@MainActor
struct DashboardSummaryTests {

    @Test("Month totals and net are computed for the reference month")
    func computesMonthTotalsAndNet() {
        let now = Date()
        let transactions = [
            Transaction(type: .expense, amount: 30, date: now),
            Transaction(type: .income, amount: 100, date: now),
            Transaction(type: .expense, amount: 999, date: now.monthsAgo(2)),
        ]
        let summary = DashboardSummary.make(
            transactions: transactions, budgets: [], startOfMonthDay: 1, referenceDate: now
        )
        #expect(summary.monthExpenses == 30)
        #expect(summary.monthIncome == 100)
        #expect(summary.netBalance == 70)
    }

    @Test("Recent transactions are the first ten of the (pre-sorted) input")
    func recentTransactionsAreFirstTen() {
        let now = Date()
        let transactions = (0..<15).map { Transaction(type: .expense, amount: Double($0), date: now) }
        let summary = DashboardSummary.make(
            transactions: transactions, budgets: [], startOfMonthDay: 1, referenceDate: now
        )
        #expect(summary.recentTransactions.count == 10)
    }

    @Test("Top category reflects the highest expense category")
    func topCategoryReflectsHighestSpend() {
        let now = Date()
        let transactions = [
            Transaction(type: .expense, amount: 10, date: now, categoryId: "food-dining"),
            Transaction(type: .expense, amount: 50, date: now, categoryId: "groceries"),
        ]
        let summary = DashboardSummary.make(
            transactions: transactions, budgets: [], startOfMonthDay: 1, referenceDate: now
        )
        #expect(summary.topCategory?.amount == 50)
        #expect(summary.topCategory?.name == DefaultCategories.category(withId: "groceries").displayName)
    }

    @Test("A budget at/above 80% of its limit raises an alert")
    func budgetAlertWhenNearingLimit() throws {
        let now = Date()
        let budget = Budget(categoryId: "food-dining", amount: 100, period: .monthly)
        let transactions = [Transaction(type: .expense, amount: 90, date: now, categoryId: "food-dining")]
        let summary = DashboardSummary.make(
            transactions: transactions, budgets: [budget], startOfMonthDay: 1, referenceDate: now
        )
        let alert = try #require(summary.budgetAlerts.first)
        #expect(alert.categoryId == "food-dining")
        #expect(alert.spent == 90)
        #expect(alert.limit == 100)
        #expect(alert.percentage == 90)
    }

    @Test("A budget below 80% raises no alert")
    func noBudgetAlertBelowThreshold() {
        let now = Date()
        let budget = Budget(categoryId: "food-dining", amount: 100, period: .monthly)
        let transactions = [Transaction(type: .expense, amount: 50, date: now, categoryId: "food-dining")]
        let summary = DashboardSummary.make(
            transactions: transactions, budgets: [budget], startOfMonthDay: 1, referenceDate: now
        )
        #expect(summary.budgetAlerts.isEmpty)
    }
}
