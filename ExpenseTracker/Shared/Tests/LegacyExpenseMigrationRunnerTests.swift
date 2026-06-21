import Testing
import Foundation
import SwiftData

/// Drives the runner that reads legacy `Transaction` rows from a `ModelContext`
/// and writes `ExpenseTransactionRecord`s, idempotently.
@MainActor
struct LegacyExpenseMigrationRunnerTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(
            ExpenseSwiftDataSchema.models
                + [Transaction.self, Account.self, Budget.self, AppSettings.self, CategoryRule.self]
        )
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test("Legacy transactions migrate into domain records via the default mapping")
    func migratesLegacyTransactions() throws {
        let context = try makeContext()
        context.insert(Transaction(type: .expense, amount: 12.5, merchant: "Bar", categoryId: "gifts"))
        context.insert(Transaction(type: .income, amount: 1000, categoryId: "salary"))
        try context.save()

        let summary = try LegacyExpenseMigrationRunner.run(in: context)

        #expect(summary.migrated == 2)
        #expect(summary.skipped == 0)

        let records = try context.fetch(FetchDescriptor<ExpenseTransactionRecord>())
        #expect(records.count == 2)

        let gift = try #require(records.first { $0.merchant == "Bar" })
        #expect(gift.amount == Decimal(string: "12.50")!) // Double -> Decimal at the boundary
        #expect(gift.categoryName == "Shopping")
        #expect(gift.subcategoryName == "regali")

        let income = try #require(records.first { $0.typeRaw == TransactionType.income.rawValue })
        #expect(income.categoryName == nil) // income is never categorized
    }

    @Test("After seed + migrate, a migrated record's category lines up with the seeded catalog")
    func migratedRecordsLineUpWithSeededCatalog() throws {
        let schema = Schema(
            ExpenseSwiftDataSchema.models
                + [Transaction.self, Account.self, Budget.self, AppSettings.self, CategoryRule.self]
        )
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let repository = SwiftDataExpenseRepository(context: context)

        context.insert(Transaction(type: .expense, amount: 9.99, merchant: "Gift Shop", categoryId: "gifts"))
        try context.save()

        try repository.seedDefaultsIfEmpty()
        try LegacyExpenseMigrationRunner.run(in: context)

        let record = try #require(
            try context.fetch(FetchDescriptor<ExpenseTransactionRecord>()).first { $0.merchant == "Gift Shop" }
        )
        let shopping = try #require(repository.catalog().categories.first { $0.displayName == "Shopping" })
        // The resolver's category id must equal the persisted seeded category id.
        #expect(record.categoryId == shopping.id)
        #expect(record.subcategoryName == "regali")
    }

    @Test("Running twice does not duplicate records")
    func isIdempotentAcrossRuns() throws {
        let context = try makeContext()
        context.insert(Transaction(type: .expense, amount: 5, categoryId: "transport"))
        try context.save()

        let first = try LegacyExpenseMigrationRunner.run(in: context)
        let second = try LegacyExpenseMigrationRunner.run(in: context)

        #expect(first.migrated == 1)
        #expect(second.migrated == 0)
        #expect(second.skipped == 1)
        #expect(try context.fetch(FetchDescriptor<ExpenseTransactionRecord>()).count == 1)
    }
}
