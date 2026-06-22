import Testing
import Foundation

/// Drives `Budget.currentPeriodRange` deterministically by injecting `now`,
/// covering the custom start-of-month day and the "before the start day →
/// previous month" branch that the existing regression tests don't reach.
struct BudgetPeriodRangeTests {

    private let calendar = Calendar.current

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test("Monthly period starts on the 1st by default and is inclusive to the last second")
    func monthlyDefaultStart() {
        let budget = Budget(categoryId: "food", period: .monthly)
        let now = date(2026, 3, 14)

        let (start, end) = budget.currentPeriodRange(now: now)

        #expect(calendar.component(.day, from: start) == 1)
        #expect(calendar.component(.month, from: start) == 3)
        #expect(calendar.component(.hour, from: start) == 0)
        let nextStart = calendar.date(byAdding: .month, value: 1, to: start)!
        #expect(end == calendar.date(byAdding: .second, value: -1, to: nextStart)!)
        #expect(start <= now && now <= end)
    }

    @Test("A custom start-of-month day is used once it has been reached this month")
    func monthlyCustomStartAfter() {
        let budget = Budget(categoryId: "food", period: .monthly)
        let now = date(2026, 3, 20)

        let (start, end) = budget.currentPeriodRange(startOfMonth: 15, now: now)

        #expect(calendar.component(.day, from: start) == 15)
        #expect(calendar.component(.month, from: start) == 3)
        #expect(start <= now && now <= end)
    }

    @Test("Before the start-of-month day, the period belongs to the previous month")
    func monthlyCustomStartBefore() {
        let budget = Budget(categoryId: "food", period: .monthly)
        let now = date(2026, 3, 10)

        let (start, end) = budget.currentPeriodRange(startOfMonth: 15, now: now)

        #expect(calendar.component(.day, from: start) == 15)
        #expect(calendar.component(.month, from: start) == 2) // February
        #expect(start <= now && now <= end)
    }

    @Test("Yearly period spans Jan 1 to the last second of Dec 31")
    func yearly() {
        let budget = Budget(categoryId: "other", period: .yearly)
        let now = date(2026, 7, 4)

        let (start, end) = budget.currentPeriodRange(now: now)

        #expect(calendar.component(.year, from: start) == 2026)
        #expect(calendar.component(.month, from: start) == 1)
        #expect(calendar.component(.day, from: start) == 1)
        let nextStart = calendar.date(byAdding: .year, value: 1, to: start)!
        #expect(end == calendar.date(byAdding: .second, value: -1, to: nextStart)!)
        #expect(start <= now && now <= end)
    }
}
