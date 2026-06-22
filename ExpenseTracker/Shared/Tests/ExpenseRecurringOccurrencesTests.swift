import Testing
import Foundation

/// Drives expanding a recurring `ExpenseDomain.Transaction` template into the
/// concrete occurrences it generates — the domain equivalent of the legacy
/// `TransactionFormView.generateRecurringInstances`, but pure and in `Decimal`.
struct ExpenseRecurringOccurrencesTests {

    private func template(
        frequency: RecurringFrequency,
        endDate: Date?,
        date: Date
    ) -> ExpenseDomain.Transaction {
        ExpenseDomain.Transaction(
            amount: Decimal(string: "10.00")!,
            date: date,
            type: .expense,
            recurrence: ExpenseDomain.Recurrence(frequency: frequency, endDate: endDate)
        )
    }

    @Test("A non-recurring template produces no occurrences")
    func nonRecurringProducesNone() {
        let txn = ExpenseDomain.Transaction(amount: 5, type: .expense)
        let occurrences = ExpenseDomain.recurringOccurrences(
            of: txn,
            until: Date().addingTimeInterval(10_000_000)
        )
        #expect(occurrences.isEmpty)
    }

    @Test("Monthly occurrences step by one month, up to and including the end date")
    func monthlyOccurrences() throws {
        let cal = Calendar.current
        let start = try #require(cal.date(from: DateComponents(year: 2026, month: 1, day: 15)))
        let end = try #require(cal.date(from: DateComponents(year: 2026, month: 4, day: 15)))

        let occurrences = ExpenseDomain.recurringOccurrences(
            of: template(frequency: .monthly, endDate: end, date: start),
            until: end
        )

        // Feb 15, Mar 15, Apr 15 — the template's own date is excluded.
        #expect(occurrences.count == 3)
        #expect(occurrences.map { cal.component(.month, from: $0.date) } == [2, 3, 4])
    }

    @Test("Each occurrence copies the template, gets a fresh id, points at the parent, and drops the receipt")
    func occurrenceCopiesFields() throws {
        let cal = Calendar.current
        let start = try #require(cal.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        let end = try #require(cal.date(from: DateComponents(year: 2026, month: 3, day: 1)))
        let parent = ExpenseDomain.Transaction(
            amount: Decimal(string: "42.00")!,
            date: start,
            type: .expense,
            merchant: "Gym",
            descriptionText: "membership",
            tags: [ExpenseDomain.Tag(displayName: "health")],
            note: "monthly",
            recurrence: ExpenseDomain.Recurrence(frequency: .monthly, endDate: end),
            receiptData: Data([0x01])
        )

        let occurrences = ExpenseDomain.recurringOccurrences(of: parent, until: end)

        #expect(!occurrences.isEmpty)
        for occurrence in occurrences {
            #expect(occurrence.id != parent.id)
            #expect(occurrence.amount == parent.amount)
            #expect(occurrence.merchant == "Gym")
            #expect(occurrence.descriptionText == "membership")
            #expect(occurrence.note == "monthly")
            #expect(occurrence.tags == parent.tags)
            #expect(occurrence.recurrence == parent.recurrence)
            #expect(occurrence.recurringParentId == parent.id)
            #expect(occurrence.receiptData == nil) // the receipt stays on the parent only
            try occurrence.validate()
        }
    }

    @Test("Occurrences stop at the end date")
    func stopsAtEndDate() throws {
        let cal = Calendar.current
        let start = try #require(cal.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        let end = try #require(cal.date(from: DateComponents(year: 2026, month: 1, day: 20)))

        let occurrences = ExpenseDomain.recurringOccurrences(
            of: template(frequency: .weekly, endDate: end, date: start),
            until: end
        )

        // Jan 8, Jan 15 — Jan 22 is past the end.
        #expect(occurrences.count == 2)
        #expect(occurrences.allSatisfy { $0.date <= end })
    }
}
