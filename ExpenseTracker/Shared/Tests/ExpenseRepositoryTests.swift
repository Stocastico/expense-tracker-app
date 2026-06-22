import Testing
import Foundation

/// Tests driving out the `ExpenseRepository` protocol and its in-memory fake,
/// keeping the domain testable without any persistence backend.
struct ExpenseRepositoryTests {

    // MARK: - Seeding

    @Test("A seeded repository exposes the default Italian catalog and tags")
    func seededRepositoryExposesDefaults() throws {
        let repo = ExpenseDomain.InMemoryRepository.seeded()

        let catalog = try repo.catalog()
        #expect(catalog.categories.count == 9)
        #expect(catalog.isValid)
        #expect(try repo.tags().isEmpty == false)
    }

    @Test("A fresh repository starts empty")
    func freshRepositoryIsEmpty() throws {
        let repo = ExpenseDomain.InMemoryRepository()
        #expect(try repo.catalog().categories.isEmpty)
        #expect(try repo.transactions().isEmpty)
    }

    // MARK: - Catalog & tags

    @Test("Saving a catalog replaces the stored catalog")
    func saveCatalogReplacesStoredCatalog() throws {
        let repo = ExpenseDomain.InMemoryRepository()
        let casa = ExpenseDomain.Category(displayName: "Casa")
        let bollette = ExpenseDomain.Subcategory(displayName: "bollette", parentId: casa.id)

        try repo.saveCatalog(ExpenseDomain.Catalog(categories: [casa], subcategories: [bollette]))

        #expect(try repo.catalog().categories == [casa])
        #expect(try repo.catalog().subcategories(of: casa) == [bollette])
    }

    @Test("Saving a tag inserts it, saving the same id updates in place")
    func saveTagInsertsThenUpdates() throws {
        let repo = ExpenseDomain.InMemoryRepository()
        var work = ExpenseDomain.Tag(displayName: "work")
        try repo.saveTag(work)
        #expect(try repo.tags() == [work])

        work.displayName = "business"
        try repo.saveTag(work)
        #expect(try repo.tags() == [work])
    }

    // MARK: - Transactions

    @Test("Adding a transaction stores it")
    func addTransactionStoresIt() throws {
        let repo = ExpenseDomain.InMemoryRepository()
        let txn = ExpenseDomain.Transaction(amount: Decimal(string: "10.00")!, type: .expense)

        try repo.addTransaction(txn)

        #expect(try repo.transactions().map(\.id) == [txn.id])
    }

    @Test("Adding an invalid transaction throws and stores nothing")
    func addRejectsInvalidTransaction() throws {
        let repo = ExpenseDomain.InMemoryRepository()
        let casa = ExpenseDomain.Category(displayName: "Casa")
        let bad = ExpenseDomain.Transaction(
            amount: Decimal(string: "5.00")!,
            type: .income,
            category: casa
        )

        #expect(throws: ExpenseDomain.ValidationError.incomeHasCategory) {
            try repo.addTransaction(bad)
        }
        let remaining = try repo.transactions()
        #expect(remaining.isEmpty)
    }

    @Test("Updating a transaction replaces the one with the same id")
    func updateTransactionReplacesById() throws {
        let repo = ExpenseDomain.InMemoryRepository()
        var txn = ExpenseDomain.Transaction(amount: Decimal(string: "10.00")!, type: .expense, note: "old")
        try repo.addTransaction(txn)

        txn.note = "new"
        try repo.updateTransaction(txn)

        let stored = try repo.transactions()
        #expect(stored.count == 1)
        #expect(stored.first?.note == "new")
    }

    @Test("Updating an unknown transaction throws notFound")
    func updateUnknownTransactionThrows() {
        let repo = ExpenseDomain.InMemoryRepository()
        let txn = ExpenseDomain.Transaction(amount: Decimal(string: "1.00")!, type: .expense)

        #expect(throws: ExpenseDomain.RepositoryError.transactionNotFound) {
            try repo.updateTransaction(txn)
        }
    }

    @Test("Deleting a transaction removes it by id")
    func deleteTransactionRemovesById() throws {
        let repo = ExpenseDomain.InMemoryRepository()
        let txn = ExpenseDomain.Transaction(amount: Decimal(string: "10.00")!, type: .expense)
        try repo.addTransaction(txn)

        try repo.deleteTransaction(id: txn.id)

        #expect(try repo.transactions().isEmpty)
    }

    // MARK: - Protocol default helper

    @Test("Repository computes total spend per category through the protocol")
    func repositoryComputesTotalSpendByCategory() throws {
        let casa = ExpenseDomain.Category(displayName: "Casa")
        let spesa = ExpenseDomain.Category(displayName: "Spesa")
        let repo: ExpenseRepository = ExpenseDomain.InMemoryRepository()

        try repo.addTransaction(.init(amount: Decimal(string: "800.00")!, type: .expense, category: casa))
        try repo.addTransaction(.init(amount: Decimal(string: "50.00")!, type: .expense, category: casa))
        try repo.addTransaction(.init(amount: Decimal(string: "120.00")!, type: .expense, category: spesa))
        try repo.addTransaction(.init(amount: Decimal(string: "2500.00")!, type: .income))

        let totals = try repo.totalSpendByCategory()
        #expect(totals[casa] == Decimal(string: "850.00")!)
        #expect(totals[spesa] == Decimal(string: "120.00")!)
        #expect(totals.count == 2)
    }

    // MARK: - Category rules

    @Test("A learned category rule round-trips through the in-memory store")
    func categoryRuleRoundTrips() throws {
        let repo = ExpenseDomain.InMemoryRepository()
        let category = UUID()
        let subcategory = UUID()
        try repo.saveCategoryRule(ExpenseDomain.CategoryRule(
            key: "mercadona", categoryId: category, subcategoryId: subcategory, hitCount: 2
        ))

        let loaded = try repo.categoryRules()
        #expect(loaded.count == 1)
        #expect(loaded.first?.key == "mercadona")
        #expect(loaded.first?.categoryId == category)
        #expect(loaded.first?.subcategoryId == subcategory)
        #expect(loaded.first?.hitCount == 2)
    }

    @Test("Saving a rule for an existing key updates it in place, not duplicated")
    func saveCategoryRuleUpsertsByKey() throws {
        let repo = ExpenseDomain.InMemoryRepository()
        try repo.saveCategoryRule(ExpenseDomain.CategoryRule(key: "amazon", categoryId: UUID(), hitCount: 1))
        let newCategory = UUID()
        try repo.saveCategoryRule(ExpenseDomain.CategoryRule(key: "amazon", categoryId: newCategory, hitCount: 2))

        let loaded = try repo.categoryRules()
        #expect(loaded.count == 1)
        #expect(loaded.first?.categoryId == newCategory)
        #expect(loaded.first?.hitCount == 2)
    }

    @Test("Category rules are returned most-reinforced first")
    func categoryRulesSortedByHitCount() throws {
        let repo = ExpenseDomain.InMemoryRepository()
        try repo.saveCategoryRule(ExpenseDomain.CategoryRule(key: "mercadona", categoryId: UUID(), hitCount: 1))
        try repo.saveCategoryRule(ExpenseDomain.CategoryRule(key: "spotify", categoryId: UUID(), hitCount: 2))

        #expect(try repo.categoryRules().map(\.key) == ["spotify", "mercadona"])
    }
}
