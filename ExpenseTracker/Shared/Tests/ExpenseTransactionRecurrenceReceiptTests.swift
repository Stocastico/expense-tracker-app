import Testing
import Foundation
import SwiftData

/// Drives modelling the last two fields a faithful writer port needs so it does
/// not drop data: a **recurring schedule** (`recurrence` + `recurringParentId`)
/// and a **receipt image** (`receiptData`). Covers the domain value type, the
/// SwiftData round-trip, and the legacy → domain migration.
@MainActor
struct ExpenseTransactionRecurrenceReceiptTests {

    // MARK: - Domain value type

    @Test("Recurrence and receipt fields default to nil")
    func newFieldsDefaultToNil() {
        let txn = ExpenseDomain.Transaction(amount: Decimal(string: "1.00")!, type: .expense)
        #expect(txn.recurrence == nil)
        #expect(txn.recurringParentId == nil)
        #expect(txn.receiptData == nil)
    }

    @Test("A transaction carries its recurrence, parent id and receipt")
    func transactionCarriesNewFields() {
        let parent = UUID()
        let receipt = Data([0x01, 0x02, 0x03])
        let end = Date(timeIntervalSince1970: 1_800_000_000)
        let txn = ExpenseDomain.Transaction(
            amount: Decimal(string: "9.99")!,
            type: .expense,
            recurrence: ExpenseDomain.Recurrence(frequency: .monthly, endDate: end),
            recurringParentId: parent,
            receiptData: receipt
        )
        #expect(txn.recurrence == ExpenseDomain.Recurrence(frequency: .monthly, endDate: end))
        #expect(txn.recurrence?.frequency == .monthly)
        #expect(txn.recurrence?.endDate == end)
        #expect(txn.recurringParentId == parent)
        #expect(txn.receiptData == receipt)
    }

    @Test("A recurrence with no end date is open-ended")
    func openEndedRecurrence() {
        let recurrence = ExpenseDomain.Recurrence(frequency: .weekly)
        #expect(recurrence.frequency == .weekly)
        #expect(recurrence.endDate == nil)
    }

    // MARK: - SwiftData round-trip

    @Test("Recurrence, parent id and receipt round-trip through SwiftData")
    func newFieldsRoundTripThroughSwiftData() throws {
        let schema = Schema(ExpenseSwiftDataSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repo = SwiftDataExpenseRepository(context: ModelContext(container))

        let parent = UUID()
        let receipt = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let end = Date(timeIntervalSince1970: 1_900_000_000)
        let txn = ExpenseDomain.Transaction(
            amount: Decimal(string: "20.00")!,
            type: .expense,
            recurrence: ExpenseDomain.Recurrence(frequency: .yearly, endDate: end),
            recurringParentId: parent,
            receiptData: receipt
        )
        try repo.addTransaction(txn)

        let loaded = try #require(try repo.transactions().first)
        #expect(loaded.recurrence == ExpenseDomain.Recurrence(frequency: .yearly, endDate: end))
        #expect(loaded.recurringParentId == parent)
        #expect(loaded.receiptData == receipt)
    }

    @Test("A non-recurring transaction with no receipt round-trips as nil")
    func absentFieldsRoundTripAsNil() throws {
        let schema = Schema(ExpenseSwiftDataSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repo = SwiftDataExpenseRepository(context: ModelContext(container))

        try repo.addTransaction(
            ExpenseDomain.Transaction(amount: Decimal(string: "3.50")!, type: .expense)
        )

        let loaded = try #require(try repo.transactions().first)
        #expect(loaded.recurrence == nil)
        #expect(loaded.recurringParentId == nil)
        #expect(loaded.receiptData == nil)
    }

    // MARK: - Migration

    @Test("A recurring legacy transaction migrates its schedule")
    func migratesRecurringSchedule() throws {
        let end = Date(timeIntervalSince1970: 2_000_000_000)
        let legacy = Transaction(
            type: .expense,
            amount: 50,
            categoryId: "x",
            isRecurring: true,
            recurringFrequency: .monthly,
            recurringEndDate: end
        )

        let migrated = LegacyExpenseMigration.migrate(legacy)

        #expect(migrated.recurrence == ExpenseDomain.Recurrence(frequency: .monthly, endDate: end))
        try migrated.validate()
    }

    @Test("A generated occurrence migrates its parent id without a schedule")
    func migratesRecurringParentId() throws {
        let parent = UUID()
        let legacy = Transaction(
            type: .expense,
            amount: 50,
            categoryId: "x",
            isRecurring: false,
            recurringParentId: parent
        )

        let migrated = LegacyExpenseMigration.migrate(legacy)

        #expect(migrated.recurrence == nil)
        #expect(migrated.recurringParentId == parent)
    }

    @Test("A non-recurring legacy transaction migrates without a schedule")
    func nonRecurringMigratesWithoutSchedule() {
        let legacy = Transaction(type: .expense, amount: 5, categoryId: "x")
        let migrated = LegacyExpenseMigration.migrate(legacy)
        #expect(migrated.recurrence == nil)
        #expect(migrated.recurringParentId == nil)
    }

    @Test("A legacy receipt image migrates across")
    func migratesReceiptData() {
        let receipt = Data([0x11, 0x22, 0x33])
        let legacy = Transaction(type: .expense, amount: 5, categoryId: "x", receiptData: receipt)
        let migrated = LegacyExpenseMigration.migrate(legacy)
        #expect(migrated.receiptData == receipt)
    }
}
