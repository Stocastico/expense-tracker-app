import Testing
import Foundation
import SwiftData

/// Tests driving out the SwiftData adapter that maps `ExpenseDomain` value
/// types to `@Model` records and conforms to `ExpenseRepository`. Each test
/// uses a fresh in-memory store. Marked `@MainActor` so the non-Sendable
/// `ModelContext` stays on one actor under Swift Testing's parallelism.
@MainActor
struct SwiftDataExpenseRepositoryTests {

    private func makeRepository() throws -> SwiftDataExpenseRepository {
        let schema = Schema(ExpenseSwiftDataSchema.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return SwiftDataExpenseRepository(context: ModelContext(container))
    }

    // MARK: - Catalog

    @Test("The default seed catalog round-trips through SwiftData unchanged")
    func seedCatalogRoundTrips() throws {
        let repo = try makeRepository()
        let seed = DefaultExpenseCategories.catalog

        try repo.saveCatalog(seed)
        let loaded = try repo.catalog()

        #expect(loaded.categories == seed.categories)
        #expect(loaded.subcategories == seed.subcategories)
        #expect(loaded.isValid)
    }

    @Test("Saving a catalog replaces the previous one")
    func saveCatalogReplaces() throws {
        let repo = try makeRepository()
        try repo.saveCatalog(DefaultExpenseCategories.catalog)

        let casa = ExpenseDomain.Category(displayName: "Casa")
        try repo.saveCatalog(ExpenseDomain.Catalog(categories: [casa], subcategories: []))

        #expect(try repo.catalog().categories == [casa])
    }

    // MARK: - Tags

    @Test("Saving a tag inserts then updates in place, and round-trips")
    func saveTagUpsertRoundTrips() throws {
        let repo = try makeRepository()
        var work = ExpenseDomain.Tag(displayName: "work")
        try repo.saveTag(work)
        #expect(try repo.tags() == [work])

        work.displayName = "business"
        try repo.saveTag(work)
        #expect(try repo.tags() == [work])
    }

    // MARK: - Transactions

    @Test("A transaction round-trips with category, subcategory, tags and Decimal amount")
    func transactionRoundTrips() throws {
        let repo = try makeRepository()
        let casa = ExpenseDomain.Category(displayName: "Casa")
        let bollette = ExpenseDomain.Subcategory(displayName: "bollette", parentId: casa.id)
        let work = ExpenseDomain.Tag(displayName: "work")
        let date = Date(timeIntervalSinceReferenceDate: 1000)

        let txn = ExpenseDomain.Transaction(
            amount: Decimal(string: "84.50")!,
            date: date,
            type: .expense,
            category: casa,
            subcategory: bollette,
            tags: [work],
            note: "utilities"
        )
        try repo.addTransaction(txn)

        let loaded = try #require(try repo.transactions().first)
        #expect(loaded.id == txn.id)
        #expect(loaded.amount == Decimal(string: "84.50")!)
        #expect(loaded.type == .expense)
        #expect(loaded.category == casa)
        #expect(loaded.subcategory == bollette)
        #expect(loaded.tags == [work])
        #expect(loaded.note == "utilities")
        #expect(abs(loaded.date.timeIntervalSince(date)) < 0.001)
    }

    @Test("Adding an invalid transaction throws and stores nothing")
    func addRejectsInvalidTransaction() throws {
        let repo = try makeRepository()
        let casa = ExpenseDomain.Category(displayName: "Casa")
        let bad = ExpenseDomain.Transaction(amount: Decimal(string: "5.00")!, type: .income, category: casa)

        #expect(throws: ExpenseDomain.ValidationError.incomeHasCategory) {
            try repo.addTransaction(bad)
        }
        #expect(try repo.transactions().isEmpty)
    }

    @Test("Updating a transaction replaces the one with the same id")
    func updateTransactionReplacesById() throws {
        let repo = try makeRepository()
        var txn = ExpenseDomain.Transaction(amount: Decimal(string: "10.00")!, type: .expense, note: "old")
        try repo.addTransaction(txn)

        txn.note = "new"
        try repo.updateTransaction(txn)

        let stored = try repo.transactions()
        #expect(stored.count == 1)
        #expect(stored.first?.note == "new")
    }

    @Test("Updating an unknown transaction throws notFound")
    func updateUnknownThrows() throws {
        let repo = try makeRepository()
        let txn = ExpenseDomain.Transaction(amount: Decimal(string: "1.00")!, type: .expense)

        #expect(throws: ExpenseDomain.RepositoryError.transactionNotFound) {
            try repo.updateTransaction(txn)
        }
    }

    @Test("Deleting a transaction removes it by id")
    func deleteTransactionRemovesById() throws {
        let repo = try makeRepository()
        let txn = ExpenseDomain.Transaction(amount: Decimal(string: "10.00")!, type: .expense)
        try repo.addTransaction(txn)

        try repo.deleteTransaction(id: txn.id)

        #expect(try repo.transactions().isEmpty)
    }

    // MARK: - Money & protocol conformance

    @Test("Decimal amounts persist without floating-point rounding error")
    func decimalAmountsArePrecise() throws {
        let repo = try makeRepository()
        let casa = ExpenseDomain.Category(displayName: "Casa")
        try repo.addTransaction(.init(amount: Decimal(string: "0.10")!, type: .expense, category: casa))
        try repo.addTransaction(.init(amount: Decimal(string: "0.20")!, type: .expense, category: casa))

        let totals = try repo.totalSpendByCategory()
        #expect(totals[casa] == Decimal(string: "0.30")!)
    }

    @Test("Works through the ExpenseRepository protocol")
    func usableThroughProtocol() throws {
        let repo: ExpenseRepository = try makeRepository()
        let casa = ExpenseDomain.Category(displayName: "Casa")

        try repo.addTransaction(.init(amount: Decimal(string: "800.00")!, type: .expense, category: casa))
        try repo.addTransaction(.init(amount: Decimal(string: "2500.00")!, type: .income))

        let totals = try repo.totalSpendByCategory()
        #expect(totals[casa] == Decimal(string: "800.00")!)
        #expect(totals.count == 1)
    }
}
