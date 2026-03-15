import XCTest
import Foundation
import SwiftData
@testable import ExpenseTracker

final class RecurringServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private let calendar = Calendar.current

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([Transaction.self, Account.self, Budget.self, AppSettings.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeRecurringTransaction(
        frequency: RecurringFrequency,
        startDate: Date = Date(),
        endDate: Date? = nil,
        amount: Double = 50.0,
        categoryId: String = "subscriptions",
        currency: String = "EUR",
        type: TransactionType = .expense
    ) -> Transaction {
        let transaction = Transaction(
            type: type,
            amount: amount,
            currency: currency,
            descriptionText: "Recurring \(frequency.displayName)",
            date: startDate,
            categoryId: categoryId,
            isRecurring: true,
            recurringFrequency: frequency,
            recurringEndDate: endDate
        )
        context.insert(transaction)
        return transaction
    }

    private func fixedDate(year: Int, month: Int, day: Int) -> Date {
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - Daily Recurrence

    func testDailyRecurrence() {
        let startDate = fixedDate(year: 2026, month: 3, day: 1)
        let endDate = fixedDate(year: 2026, month: 3, day: 8)

        let transaction = makeRecurringTransaction(
            frequency: .daily,
            startDate: startDate
        )

        let instances = RecurringService.generateInstances(for: transaction, until: endDate)

        // From March 1, daily until March 8: generates March 2, 3, 4, 5, 6, 7, 8 = 7 instances
        // But endDate is March 8 and nextDate must be <= endDate, so March 2..8 = 7
        // Actually the code checks nextDate > effectiveEndDate to break, so March 8 is included
        XCTAssertEqual(instances.count, 7)

        // Verify dates are sequential
        for (index, instance) in instances.enumerated() {
            let expectedDate = calendar.date(byAdding: .day, value: index + 1, to: startDate)!
            let expectedComponents = calendar.dateComponents([.year, .month, .day], from: expectedDate)
            let actualComponents = calendar.dateComponents([.year, .month, .day], from: instance.date)
            XCTAssertEqual(actualComponents.year, expectedComponents.year)
            XCTAssertEqual(actualComponents.month, expectedComponents.month)
            XCTAssertEqual(actualComponents.day, expectedComponents.day)
        }
    }

    // MARK: - Weekly Recurrence

    func testWeeklyRecurrence() {
        let startDate = fixedDate(year: 2026, month: 3, day: 1)
        let endDate = fixedDate(year: 2026, month: 3, day: 29)

        let transaction = makeRecurringTransaction(
            frequency: .weekly,
            startDate: startDate
        )

        let instances = RecurringService.generateInstances(for: transaction, until: endDate)

        // From March 1, weekly: March 8, March 15, March 22, March 29 = 4 instances
        XCTAssertEqual(instances.count, 4)

        // Verify first instance is 1 week after start
        let firstComponents = calendar.dateComponents([.year, .month, .day], from: instances[0].date)
        XCTAssertEqual(firstComponents.day, 8)
        XCTAssertEqual(firstComponents.month, 3)
    }

    // MARK: - Monthly Recurrence

    func testMonthlyRecurrence() {
        let startDate = fixedDate(year: 2026, month: 1, day: 15)
        let endDate = fixedDate(year: 2026, month: 7, day: 1)

        let transaction = makeRecurringTransaction(
            frequency: .monthly,
            startDate: startDate
        )

        let instances = RecurringService.generateInstances(for: transaction, until: endDate)

        // From Jan 15, monthly: Feb 15, Mar 15, Apr 15, May 15, Jun 15 = 5 instances
        // Jul 15 would be after Jul 1 end date
        XCTAssertEqual(instances.count, 5)

        // Verify months
        let months = instances.map { calendar.component(.month, from: $0.date) }
        XCTAssertEqual(months, [2, 3, 4, 5, 6])
    }

    // MARK: - Yearly Recurrence

    func testYearlyRecurrence() {
        let startDate = fixedDate(year: 2026, month: 3, day: 14)
        let endDate = fixedDate(year: 2028, month: 6, day: 1)

        let transaction = makeRecurringTransaction(
            frequency: .yearly,
            startDate: startDate
        )

        let instances = RecurringService.generateInstances(for: transaction, until: endDate)

        // From Mar 14 2026, yearly: Mar 14 2027, Mar 14 2028 = 2 instances
        XCTAssertEqual(instances.count, 2)

        let years = instances.map { calendar.component(.year, from: $0.date) }
        XCTAssertEqual(years, [2027, 2028])
    }

    func testYearlyRecurrenceSingleInstance() {
        let startDate = fixedDate(year: 2026, month: 3, day: 14)
        let endDate = fixedDate(year: 2027, month: 6, day: 1)

        let transaction = makeRecurringTransaction(
            frequency: .yearly,
            startDate: startDate
        )

        let instances = RecurringService.generateInstances(for: transaction, until: endDate)

        // From Mar 14 2026, yearly until Jun 1 2027: only Mar 14 2027 = 1 instance
        XCTAssertEqual(instances.count, 1)
        XCTAssertEqual(calendar.component(.year, from: instances[0].date), 2027)
    }

    // MARK: - End Date Respect

    func testRespectsEndDate() {
        let startDate = fixedDate(year: 2026, month: 3, day: 1)
        let recurringEndDate = fixedDate(year: 2026, month: 3, day: 15)
        let generationEndDate = fixedDate(year: 2026, month: 12, day: 31)

        let transaction = makeRecurringTransaction(
            frequency: .daily,
            startDate: startDate,
            endDate: recurringEndDate
        )

        let instances = RecurringService.generateInstances(for: transaction, until: generationEndDate)

        // Should respect recurringEndDate (March 15), not generationEndDate (Dec 31)
        // Daily from March 1: March 2..15 = 14 instances
        XCTAssertEqual(instances.count, 14)

        // All instances should be on or before March 15
        for instance in instances {
            XCTAssertTrue(instance.date <= recurringEndDate,
                         "Instance date \(instance.date) exceeds end date \(recurringEndDate)")
        }
    }

    func testRespectsGenerationEndDateWhenEarlierThanRecurringEnd() {
        let startDate = fixedDate(year: 2026, month: 3, day: 1)
        let recurringEndDate = fixedDate(year: 2026, month: 12, day: 31)
        let generationEndDate = fixedDate(year: 2026, month: 3, day: 5)

        let transaction = makeRecurringTransaction(
            frequency: .daily,
            startDate: startDate,
            endDate: recurringEndDate
        )

        let instances = RecurringService.generateInstances(for: transaction, until: generationEndDate)

        // Should respect generationEndDate (March 5) since it's earlier
        // Daily from March 1: March 2, 3, 4, 5 = 4 instances
        XCTAssertEqual(instances.count, 4)
    }

    // MARK: - Parent ID

    func testInstancesHaveCorrectParentId() {
        let startDate = fixedDate(year: 2026, month: 3, day: 1)
        let endDate = fixedDate(year: 2026, month: 3, day: 8)

        let transaction = makeRecurringTransaction(
            frequency: .daily,
            startDate: startDate
        )

        let instances = RecurringService.generateInstances(for: transaction, until: endDate)

        XCTAssertFalse(instances.isEmpty)

        for instance in instances {
            XCTAssertEqual(instance.recurringParentId, transaction.id,
                          "Instance should have parent's ID as recurringParentId")
        }
    }

    // MARK: - Field Copying

    func testInstancesCopyFields() {
        let startDate = fixedDate(year: 2026, month: 3, day: 1)
        let endDate = fixedDate(year: 2026, month: 3, day: 4)

        let transaction = makeRecurringTransaction(
            frequency: .daily,
            startDate: startDate,
            amount: 99.99,
            categoryId: "subscriptions",
            currency: "USD",
            type: .expense
        )

        let instances = RecurringService.generateInstances(for: transaction, until: endDate)

        XCTAssertFalse(instances.isEmpty)

        for instance in instances {
            XCTAssertEqual(instance.storedAmount, 99.99, accuracy: 0.001)
            XCTAssertEqual(instance.categoryId, "subscriptions")
            XCTAssertEqual(instance.currency, "USD")
            XCTAssertEqual(instance.typeRaw, "expense")
            XCTAssertEqual(instance.descriptionText, transaction.descriptionText)
        }
    }

    // MARK: - Non-Recurring Transaction

    func testNonRecurringReturnsEmpty() {
        let transaction = Transaction(
            type: .expense,
            amount: 25.0,
            currency: "EUR",
            descriptionText: "One-time purchase",
            date: Date(),
            categoryId: "shopping",
            isRecurring: false
        )
        context.insert(transaction)

        let instances = RecurringService.generateInstances(for: transaction)

        XCTAssertTrue(instances.isEmpty)
    }

    func testRecurringWithNoFrequencyReturnsEmpty() {
        let transaction = Transaction(
            type: .expense,
            amount: 25.0,
            currency: "EUR",
            descriptionText: "Weird transaction",
            date: Date(),
            categoryId: "other",
            isRecurring: true,
            recurringFrequency: nil
        )
        context.insert(transaction)

        let instances = RecurringService.generateInstances(for: transaction)

        XCTAssertTrue(instances.isEmpty)
    }

    // MARK: - Next Occurrence

    func testGetNextOccurrenceDaily() {
        let startDate = fixedDate(year: 2026, month: 3, day: 14)
        let transaction = makeRecurringTransaction(frequency: .daily, startDate: startDate)

        let next = RecurringService.getNextOccurrence(for: transaction)

        XCTAssertNotNil(next)
        let components = calendar.dateComponents([.year, .month, .day], from: next!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 15)
    }

    func testGetNextOccurrenceWeekly() {
        let startDate = fixedDate(year: 2026, month: 3, day: 14)
        let transaction = makeRecurringTransaction(frequency: .weekly, startDate: startDate)

        let next = RecurringService.getNextOccurrence(for: transaction)

        XCTAssertNotNil(next)
        let components = calendar.dateComponents([.year, .month, .day], from: next!)
        XCTAssertEqual(components.day, 21)
    }

    func testGetNextOccurrenceMonthly() {
        let startDate = fixedDate(year: 2026, month: 3, day: 14)
        let transaction = makeRecurringTransaction(frequency: .monthly, startDate: startDate)

        let next = RecurringService.getNextOccurrence(for: transaction)

        XCTAssertNotNil(next)
        let components = calendar.dateComponents([.year, .month, .day], from: next!)
        XCTAssertEqual(components.month, 4)
        XCTAssertEqual(components.day, 14)
    }

    func testGetNextOccurrenceYearly() {
        let startDate = fixedDate(year: 2026, month: 3, day: 14)
        let transaction = makeRecurringTransaction(frequency: .yearly, startDate: startDate)

        let next = RecurringService.getNextOccurrence(for: transaction)

        XCTAssertNotNil(next)
        let components = calendar.dateComponents([.year, .month, .day], from: next!)
        XCTAssertEqual(components.year, 2027)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 14)
    }

    func testGetNextOccurrenceNonRecurringReturnsNil() {
        let transaction = Transaction(
            type: .expense,
            amount: 10,
            currency: "EUR",
            descriptionText: "One-time",
            date: Date(),
            categoryId: "other",
            isRecurring: false
        )
        context.insert(transaction)

        let next = RecurringService.getNextOccurrence(for: transaction)
        XCTAssertNil(next)
    }

    func testGetNextOccurrenceRespectsEndDate() {
        let startDate = fixedDate(year: 2026, month: 3, day: 14)
        let endDate = fixedDate(year: 2026, month: 3, day: 14)

        let transaction = makeRecurringTransaction(
            frequency: .daily,
            startDate: startDate,
            endDate: endDate
        )

        let next = RecurringService.getNextOccurrence(for: transaction)

        // Next date would be March 15, which is after endDate March 14
        XCTAssertNil(next)
    }

    // MARK: - Biweekly Recurrence

    func testBiweeklyRecurrence() {
        let startDate = fixedDate(year: 2026, month: 3, day: 1)
        let endDate = fixedDate(year: 2026, month: 4, day: 30)

        let transaction = makeRecurringTransaction(
            frequency: .biweekly,
            startDate: startDate
        )

        let instances = RecurringService.generateInstances(for: transaction, until: endDate)

        // From March 1, biweekly: March 15, March 29, April 12, April 26 = 4 instances
        XCTAssertEqual(instances.count, 4)

        // Verify first instance is 2 weeks after start
        let daysBetween = calendar.dateComponents([.day], from: startDate, to: instances[0].date).day!
        XCTAssertEqual(daysBetween, 14)
    }

    // MARK: - Quarterly Recurrence

    func testQuarterlyRecurrence() {
        let startDate = fixedDate(year: 2026, month: 1, day: 1)
        let endDate = fixedDate(year: 2027, month: 1, day: 1)

        let transaction = makeRecurringTransaction(
            frequency: .quarterly,
            startDate: startDate
        )

        let instances = RecurringService.generateInstances(for: transaction, until: endDate)

        // From Jan 1, quarterly: Apr 1, Jul 1, Oct 1, Jan 1 2027 = 4 instances
        XCTAssertEqual(instances.count, 4)

        let months = instances.map { calendar.component(.month, from: $0.date) }
        XCTAssertEqual(months, [4, 7, 10, 1])
    }

    // MARK: - Instance Properties

    func testInstancesAreNotRecurring() {
        let startDate = fixedDate(year: 2026, month: 3, day: 1)
        let endDate = fixedDate(year: 2026, month: 3, day: 8)

        let transaction = makeRecurringTransaction(
            frequency: .daily,
            startDate: startDate
        )

        let instances = RecurringService.generateInstances(for: transaction, until: endDate)

        for instance in instances {
            XCTAssertFalse(instance.isRecurring, "Generated instances should not be marked as recurring")
            XCTAssertNil(instance.recurringFrequency, "Generated instances should have no recurring frequency")
        }
    }

    func testInstancesHaveUniqueIds() {
        let startDate = fixedDate(year: 2026, month: 3, day: 1)
        let endDate = fixedDate(year: 2026, month: 3, day: 8)

        let transaction = makeRecurringTransaction(
            frequency: .daily,
            startDate: startDate
        )

        let instances = RecurringService.generateInstances(for: transaction, until: endDate)

        let ids = instances.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "All instances should have unique IDs")

        // Also ensure no instance has the parent's ID
        for instance in instances {
            XCTAssertNotEqual(instance.id, transaction.id)
        }
    }
}
