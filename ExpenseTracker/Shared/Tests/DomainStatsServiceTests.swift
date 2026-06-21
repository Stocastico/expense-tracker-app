import Testing
import Foundation

/// Drives `DomainStatsService`, the domain-backed (`Decimal`-summed) analytics
/// over `ExpenseDomain.Transaction`s — the successor to `StatsService` (legacy
/// `Double`/`Transaction`). Produces the same plot DTOs the charts consume.
@MainActor
struct DomainStatsServiceTests {

    private let now = Calendar.current.date(from: DateComponents(year: 2025, month: 6, day: 15))!

    private var thisMonth: Date { now }
    private func monthsAgo(_ n: Int) -> Date { now.monthsAgo(n) }

    private func expense(_ amount: String, _ date: Date, category: ExpenseDomain.Category? = nil) -> ExpenseDomain.Transaction {
        ExpenseDomain.Transaction(amount: Decimal(string: amount)!, date: date, type: .expense, category: category)
    }

    private func income(_ amount: String, _ date: Date) -> ExpenseDomain.Transaction {
        ExpenseDomain.Transaction(amount: Decimal(string: amount)!, date: date, type: .income)
    }

    @Test("monthlyTotals sums income/expenses/net per month, oldest first")
    func monthlyTotals() {
        let txns = [income("100", thisMonth), expense("30", thisMonth), expense("50", monthsAgo(1))]
        let totals = DomainStatsService.monthlyTotals(transactions: txns, months: 2, now: now)
        #expect(totals.count == 2)
        // index 0 is the older month, last is the current month.
        #expect(totals[0].expenses == 50)
        #expect(totals[1].income == 100)
        #expect(totals[1].expenses == 30)
        #expect(totals[1].net == 70)
    }

    @Test("categoryBreakdown groups expenses by category with share percentages, largest first")
    func categoryBreakdown() {
        let food = ExpenseDomain.Category(displayName: "Cibo")
        let home = ExpenseDomain.Category(displayName: "Casa")
        let txns = [
            expense("30", thisMonth, category: food),
            expense("10", thisMonth, category: food),
            expense("60", thisMonth, category: home),
        ]
        let breakdown = DomainStatsService.categoryBreakdown(transactions: txns, month: now)
        #expect(breakdown.map(\.categoryName) == ["Casa", "Cibo"])
        #expect(breakdown[0].total == 60)
        #expect(breakdown[0].percentage == 60)
        #expect(breakdown[1].total == 40)
        // Every slice gets a non-empty colour for the chart.
        #expect(breakdown.allSatisfy { !$0.categoryColor.isEmpty })
    }

    @Test("categoryBreakdown labels uncategorized expenses")
    func categoryBreakdownUncategorized() {
        let txns = [expense("50", thisMonth)]
        let breakdown = DomainStatsService.categoryBreakdown(transactions: txns, month: now)
        #expect(breakdown.map(\.categoryName) == ["Uncategorized"])
    }

    @Test("netBalanceTrend accumulates a running balance per month")
    func netBalanceTrend() {
        let txns = [income("100", monthsAgo(1)), expense("40", thisMonth)]
        let points = DomainStatsService.netBalanceTrend(transactions: txns, months: 2, now: now)
        #expect(points.map(\.balance) == [100, 60])
    }

    @Test("spendingTrend is the month-over-month percentage change in expenses")
    func spendingTrend() {
        let txns = [expense("120", thisMonth), expense("100", monthsAgo(1))]
        #expect(DomainStatsService.spendingTrend(transactions: txns, now: now) == 20)
    }

    @Test("spendingPrediction is a 3/2/1-weighted average of the last three months")
    func spendingPrediction() {
        let txns = [expense("30", monthsAgo(1)), expense("60", monthsAgo(2)), expense("90", monthsAgo(3))]
        // (30*3 + 60*2 + 90*1) / 6 = 50
        #expect(DomainStatsService.spendingPrediction(transactions: txns, now: now) == 50)
    }

    @Test("totalForPeriod sums a type within an inclusive date range, as Decimal")
    func totalForPeriod() {
        let txns = [expense("30", thisMonth), expense("70", thisMonth), income("999", thisMonth)]
        let total = DomainStatsService.totalForPeriod(
            transactions: txns, type: .expense, startDate: now.startOfMonth, endDate: now.endOfMonth
        )
        #expect(total == Decimal(string: "100"))
    }
}
