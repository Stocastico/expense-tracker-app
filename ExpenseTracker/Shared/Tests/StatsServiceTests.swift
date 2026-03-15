import XCTest
import Foundation
import SwiftData
@testable import ExpenseTracker

final class StatsServiceTests: XCTestCase {

    private let calendar = Calendar.current

    // MARK: - Helpers

    private func makeTransaction(
        type: TransactionType,
        amount: Double,
        categoryId: String = "food-dining",
        date: Date = Date()
    ) -> Transaction {
        return Transaction(
            type: type,
            amount: amount,
            currency: "EUR",
            descriptionText: "Test \(type.rawValue)",
            date: date,
            categoryId: categoryId
        )
    }

    private func dateFor(year: Int, month: Int, day: Int = 15) -> Date {
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - monthlyTotals Tests

    func testMonthlyTotalsWithKnownTransactionsAcrossThreeMonths() {
        let now = Date()
        let currentMonth = now
        let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
        let twoMonthsAgo = calendar.date(byAdding: .month, value: -2, to: now)!

        let transactions = [
            makeTransaction(type: .income, amount: 3000, date: currentMonth),
            makeTransaction(type: .expense, amount: 500, date: currentMonth),
            makeTransaction(type: .income, amount: 2500, date: oneMonthAgo),
            makeTransaction(type: .expense, amount: 800, date: oneMonthAgo),
            makeTransaction(type: .income, amount: 2000, date: twoMonthsAgo),
            makeTransaction(type: .expense, amount: 600, date: twoMonthsAgo),
        ]

        let totals = StatsService.monthlyTotals(transactions: transactions, months: 3)

        XCTAssertEqual(totals.count, 3)

        // Results are returned in chronological order (oldest first)
        // Oldest month (2 months ago)
        XCTAssertEqual(totals[0].income, 2000, accuracy: 0.01)
        XCTAssertEqual(totals[0].expenses, 600, accuracy: 0.01)
        XCTAssertEqual(totals[0].net, 1400, accuracy: 0.01)

        // Middle month (1 month ago)
        XCTAssertEqual(totals[1].income, 2500, accuracy: 0.01)
        XCTAssertEqual(totals[1].expenses, 800, accuracy: 0.01)

        // Current month
        XCTAssertEqual(totals[2].income, 3000, accuracy: 0.01)
        XCTAssertEqual(totals[2].expenses, 500, accuracy: 0.01)
    }

    func testMonthlyTotalsEmptyTransactions() {
        let totals = StatsService.monthlyTotals(transactions: [], months: 3)
        XCTAssertEqual(totals.count, 3)
        for total in totals {
            XCTAssertEqual(total.income, 0, accuracy: 0.01)
            XCTAssertEqual(total.expenses, 0, accuracy: 0.01)
            XCTAssertEqual(total.net, 0, accuracy: 0.01)
        }
    }

    // MARK: - categoryBreakdown Tests

    func testCategoryBreakdownPercentagesSumToHundred() {
        let now = Date()
        let transactions = [
            makeTransaction(type: .expense, amount: 200, categoryId: "food-dining", date: now),
            makeTransaction(type: .expense, amount: 300, categoryId: "transport", date: now),
            makeTransaction(type: .expense, amount: 500, categoryId: "shopping", date: now),
        ]

        let breakdown = StatsService.categoryBreakdown(transactions: transactions, month: now)

        XCTAssertFalse(breakdown.isEmpty)
        let totalPercentage = breakdown.reduce(0.0) { $0 + $1.percentage }
        XCTAssertEqual(totalPercentage, 100.0, accuracy: 0.01)
    }

    func testCategoryBreakdownCorrectPercentages() {
        let now = Date()
        let transactions = [
            makeTransaction(type: .expense, amount: 250, categoryId: "food-dining", date: now),
            makeTransaction(type: .expense, amount: 750, categoryId: "transport", date: now),
        ]

        let breakdown = StatsService.categoryBreakdown(transactions: transactions, month: now)

        XCTAssertEqual(breakdown.count, 2)

        let food = breakdown.first(where: { $0.categoryId == "food-dining" })
        let transport = breakdown.first(where: { $0.categoryId == "transport" })

        XCTAssertNotNil(food)
        XCTAssertNotNil(transport)
        XCTAssertEqual(food!.percentage, 25.0, accuracy: 0.01)
        XCTAssertEqual(transport!.percentage, 75.0, accuracy: 0.01)
    }

    func testCategoryBreakdownEmptyTransactions() {
        let breakdown = StatsService.categoryBreakdown(transactions: [], month: Date())
        XCTAssertTrue(breakdown.isEmpty)
    }

    func testCategoryBreakdownIgnoresIncome() {
        let now = Date()
        let transactions = [
            makeTransaction(type: .income, amount: 5000, categoryId: "salary", date: now),
            makeTransaction(type: .expense, amount: 100, categoryId: "food-dining", date: now),
        ]

        let breakdown = StatsService.categoryBreakdown(transactions: transactions, month: now)
        XCTAssertEqual(breakdown.count, 1)
        XCTAssertEqual(breakdown[0].categoryId, "food-dining")
        XCTAssertEqual(breakdown[0].percentage, 100.0, accuracy: 0.01)
    }

    // MARK: - savingsRate Tests

    func testSavingsRateCalculation() {
        let rate = StatsService.savingsRate(income: 1000, expenses: 700)
        XCTAssertEqual(rate, 30.0, accuracy: 0.01)
    }

    func testSavingsRateZeroIncome() {
        let rate = StatsService.savingsRate(income: 0, expenses: 500)
        XCTAssertEqual(rate, 0.0)
    }

    func testSavingsRateNoExpenses() {
        let rate = StatsService.savingsRate(income: 2000, expenses: 0)
        XCTAssertEqual(rate, 100.0, accuracy: 0.01)
    }

    func testSavingsRateNegative() {
        // Spending more than income
        let rate = StatsService.savingsRate(income: 500, expenses: 800)
        XCTAssertEqual(rate, -60.0, accuracy: 0.01)
    }

    // MARK: - spendingPrediction Tests

    func testSpendingPredictionWithKnownData() {
        let now = Date()
        let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
        let twoMonthsAgo = calendar.date(byAdding: .month, value: -2, to: now)!
        let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now)!

        let transactions = [
            makeTransaction(type: .expense, amount: 600, date: oneMonthAgo),
            makeTransaction(type: .expense, amount: 400, date: twoMonthsAgo),
            makeTransaction(type: .expense, amount: 200, date: threeMonthsAgo),
        ]

        let prediction = StatsService.spendingPrediction(transactions: transactions)

        // Weighted average: (600*3 + 400*2 + 200*1) / (3+2+1) = (1800+800+200)/6 = 2800/6 ~= 466.67
        XCTAssertEqual(prediction, 2800.0 / 6.0, accuracy: 1.0)
    }

    func testSpendingPredictionEmptyTransactions() {
        let prediction = StatsService.spendingPrediction(transactions: [])
        XCTAssertEqual(prediction, 0.0)
    }

    // MARK: - spendingTrend Tests

    func testSpendingTrendPercentageChange() {
        let now = Date()
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!

        let transactions = [
            makeTransaction(type: .expense, amount: 600, date: now),
            makeTransaction(type: .expense, amount: 400, date: lastMonth),
        ]

        let trend = StatsService.spendingTrend(transactions: transactions)
        // (600 - 400) / 400 * 100 = 50%
        XCTAssertEqual(trend, 50.0, accuracy: 0.01)
    }

    func testSpendingTrendDecrease() {
        let now = Date()
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!

        let transactions = [
            makeTransaction(type: .expense, amount: 300, date: now),
            makeTransaction(type: .expense, amount: 600, date: lastMonth),
        ]

        let trend = StatsService.spendingTrend(transactions: transactions)
        // (300 - 600) / 600 * 100 = -50%
        XCTAssertEqual(trend, -50.0, accuracy: 0.01)
    }

    func testSpendingTrendNoPreviousMonth() {
        let now = Date()
        let transactions = [
            makeTransaction(type: .expense, amount: 500, date: now),
        ]

        let trend = StatsService.spendingTrend(transactions: transactions)
        // No previous month spending -> returns 100.0 if current > 0
        XCTAssertEqual(trend, 100.0, accuracy: 0.01)
    }

    func testSpendingTrendEmptyTransactions() {
        let trend = StatsService.spendingTrend(transactions: [])
        XCTAssertEqual(trend, 0.0)
    }

    // MARK: - topCategory Tests

    func testTopCategoryReturnsHighestSpending() {
        let now = Date()
        let transactions = [
            makeTransaction(type: .expense, amount: 100, categoryId: "food-dining", date: now),
            makeTransaction(type: .expense, amount: 300, categoryId: "transport", date: now),
            makeTransaction(type: .expense, amount: 50, categoryId: "shopping", date: now),
            makeTransaction(type: .expense, amount: 200, categoryId: "transport", date: now),
        ]

        let top = StatsService.topCategory(transactions: transactions, month: now)

        XCTAssertNotNil(top)
        XCTAssertEqual(top?.categoryId, "transport")
        XCTAssertEqual(top?.amount, 500.0, accuracy: 0.01)
    }

    func testTopCategoryEmptyTransactions() {
        let top = StatsService.topCategory(transactions: [], month: Date())
        XCTAssertNil(top)
    }

    func testTopCategoryIgnoresIncome() {
        let now = Date()
        let transactions = [
            makeTransaction(type: .income, amount: 5000, categoryId: "salary", date: now),
            makeTransaction(type: .expense, amount: 100, categoryId: "food-dining", date: now),
        ]

        let top = StatsService.topCategory(transactions: transactions, month: now)
        XCTAssertNotNil(top)
        XCTAssertEqual(top?.categoryId, "food-dining")
    }

    // MARK: - totalForPeriod Tests

    func testTotalForPeriodFiltersByDateRangeAndType() {
        let startDate = dateFor(year: 2026, month: 1, day: 1)
        let endDate = dateFor(year: 2026, month: 1, day: 31)

        let transactions = [
            // Inside range, correct type
            makeTransaction(type: .expense, amount: 100, date: dateFor(year: 2026, month: 1, day: 10)),
            makeTransaction(type: .expense, amount: 200, date: dateFor(year: 2026, month: 1, day: 20)),
            // Inside range, wrong type
            makeTransaction(type: .income, amount: 999, date: dateFor(year: 2026, month: 1, day: 15)),
            // Outside range
            makeTransaction(type: .expense, amount: 500, date: dateFor(year: 2026, month: 2, day: 5)),
            makeTransaction(type: .expense, amount: 300, date: dateFor(year: 2025, month: 12, day: 25)),
        ]

        let total = StatsService.totalForPeriod(
            transactions: transactions,
            type: .expense,
            startDate: startDate,
            endDate: endDate
        )

        XCTAssertEqual(total, 300.0, accuracy: 0.01)
    }

    func testTotalForPeriodIncomeType() {
        let startDate = dateFor(year: 2026, month: 3, day: 1)
        let endDate = dateFor(year: 2026, month: 3, day: 31)

        let transactions = [
            makeTransaction(type: .income, amount: 3000, date: dateFor(year: 2026, month: 3, day: 1)),
            makeTransaction(type: .income, amount: 500, date: dateFor(year: 2026, month: 3, day: 15)),
            makeTransaction(type: .expense, amount: 200, date: dateFor(year: 2026, month: 3, day: 10)),
        ]

        let total = StatsService.totalForPeriod(
            transactions: transactions,
            type: .income,
            startDate: startDate,
            endDate: endDate
        )

        XCTAssertEqual(total, 3500.0, accuracy: 0.01)
    }

    func testTotalForPeriodEmptyTransactions() {
        let total = StatsService.totalForPeriod(
            transactions: [],
            type: .expense,
            startDate: Date(),
            endDate: Date()
        )
        XCTAssertEqual(total, 0.0)
    }

    // MARK: - netBalanceTrend Tests

    func testNetBalanceTrendReturnsCorrectPoints() {
        let now = Date()
        let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: now)!

        let transactions = [
            makeTransaction(type: .income, amount: 2000, date: oneMonthAgo),
            makeTransaction(type: .expense, amount: 500, date: oneMonthAgo),
            makeTransaction(type: .income, amount: 1500, date: now),
            makeTransaction(type: .expense, amount: 800, date: now),
        ]

        let trend = StatsService.netBalanceTrend(transactions: transactions, months: 2)

        XCTAssertEqual(trend.count, 2)
        // First point: 2000 - 500 = 1500
        XCTAssertEqual(trend[0].balance, 1500.0, accuracy: 0.01)
        // Second point: 1500 + 1500 - 800 = 2200
        XCTAssertEqual(trend[1].balance, 2200.0, accuracy: 0.01)
    }
}
