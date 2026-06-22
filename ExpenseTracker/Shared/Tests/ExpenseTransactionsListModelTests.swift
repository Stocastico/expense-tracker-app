import Testing
import Foundation

/// Drives the view model behind a domain-backed transactions list: it reads
/// `ExpenseDomain.Transaction`s from the repository and turns them into
/// display-ready rows (title, category path, tags), routing failures to the
/// error presenter.
@MainActor
struct ExpenseTransactionsListModelTests {

    private let casa = ExpenseDomain.Category(displayName: "Casa")

    private func transaction(
        merchant: String? = "Iberdrola",
        description: String = "",
        amount: String = "42.50",
        date: Date = Date(),
        subcategoryNamed subcategory: String? = "bollette",
        tags: [String] = ["work"]
    ) -> ExpenseDomain.Transaction {
        let sub = subcategory.map {
            ExpenseDomain.Subcategory(displayName: $0, parentId: casa.id)
        }
        return ExpenseDomain.Transaction(
            amount: Decimal(string: amount)!,
            date: date,
            type: .expense,
            merchant: merchant,
            descriptionText: description,
            category: casa,
            subcategory: sub,
            tags: Set(tags.map { ExpenseDomain.Tag(displayName: $0) })
        )
    }

    private func makeModel(with transactions: [ExpenseDomain.Transaction]) -> ExpenseTransactionsListModel {
        let repo = ExpenseDomain.InMemoryRepository(transactions: transactions)
        return ExpenseTransactionsListModel(repository: repo, errorPresenter: ExpenseErrorPresenter())
    }

    @Test("load() builds rows sorted newest-first")
    func loadsRowsNewestFirst() {
        let old = transaction(merchant: "Old", date: Date(timeIntervalSince1970: 1000))
        let new = transaction(merchant: "New", date: Date(timeIntervalSince1970: 2000))
        let model = makeModel(with: [old, new])

        model.load()

        #expect(model.rows.map(\.title) == ["New", "Old"])
    }

    @Test("A row exposes title, category path and sorted tag names")
    func rowExposesDisplayFields() {
        let txn = transaction(
            merchant: "Iberdrola",
            subcategoryNamed: "bollette",
            tags: ["work", "casa"]
        )
        let model = makeModel(with: [txn])

        model.load()

        let row = model.rows[0]
        #expect(row.title == "Iberdrola")
        #expect(row.categoryPath == "Casa › bollette")
        #expect(row.tagNames == ["casa", "work"])
        #expect(row.amount == Decimal(string: "42.50")!)
    }

    @Test("Category path omits the subcategory when there isn't one")
    func categoryPathWithoutSubcategory() {
        let model = makeModel(with: [transaction(subcategoryNamed: nil)])
        model.load()
        #expect(model.rows[0].categoryPath == "Casa")
    }

    @Test("Title falls back from merchant to description to a placeholder")
    func titleFallback() {
        let fromDescription = transaction(merchant: "  ", description: "Bonifico")
        let placeholder = transaction(merchant: nil, description: "")
        let model = makeModel(with: [fromDescription])
        model.load()
        #expect(model.rows[0].title == "Bonifico")

        let model2 = makeModel(with: [placeholder])
        model2.load()
        #expect(model2.rows[0].title == "Untitled")
    }

    @Test("A load failure routes to the presenter and leaves rows empty")
    func loadFailureSurfaces() {
        let presenter = ExpenseErrorPresenter()
        let model = ExpenseTransactionsListModel(repository: FailingRepository(), errorPresenter: presenter)

        model.load()

        #expect(model.rows.isEmpty)
        #expect(presenter.currentError != nil)
    }

    @Test("delete() removes the transaction from the repository and the rows")
    func deleteRemovesTransaction() throws {
        let txn = transaction(merchant: "Eroski")
        let repo = ExpenseDomain.InMemoryRepository(transactions: [txn])
        let model = ExpenseTransactionsListModel(repository: repo, errorPresenter: ExpenseErrorPresenter())
        model.load()
        #expect(model.rows.count == 1)

        model.delete(id: txn.id)

        #expect(model.rows.isEmpty)
        #expect(try repo.transactions().isEmpty)
    }

    @Test("transaction(id:) returns the full domain transaction behind a row")
    func transactionLookup() {
        let txn = transaction(merchant: "X")
        let repo = ExpenseDomain.InMemoryRepository(transactions: [txn])
        let model = ExpenseTransactionsListModel(repository: repo, errorPresenter: ExpenseErrorPresenter())
        model.load()
        #expect(model.transaction(id: txn.id)?.id == txn.id)
        #expect(model.transaction(id: UUID()) == nil)
    }

    @Test("A delete failure routes to the presenter")
    func deleteFailureSurfaces() {
        let presenter = ExpenseErrorPresenter()
        let model = ExpenseTransactionsListModel(repository: FailingRepository(), errorPresenter: presenter)

        model.delete(id: UUID())

        #expect(presenter.currentError != nil)
    }

    // MARK: - Filtering, search & sort (parity with the legacy list)

    @Test("searchQuery filters across merchant/description/tags; blank clears it")
    func searchQueryFilters() {
        let iberdrola = transaction(merchant: "Iberdrola", description: "luce", tags: ["bolletta"])
        let eroski = transaction(merchant: "Eroski", description: "spesa", tags: ["food"])
        let model = makeModel(with: [iberdrola, eroski])
        model.load()

        model.searchQuery = "ibe"
        #expect(model.rows.map(\.title) == ["Iberdrola"])

        model.searchQuery = "FOOD" // matches a tag, case-insensitively
        #expect(model.rows.map(\.title) == ["Eroski"])

        model.searchQuery = "   " // whitespace-only is treated as no filter
        #expect(model.rows.count == 2)
    }

    @Test("typeFilter keeps only the chosen transaction type")
    func typeFilters() {
        let expense = ExpenseDomain.Transaction(amount: 10, type: .expense, merchant: "Shop")
        let income = ExpenseDomain.Transaction(amount: 99, type: .income, merchant: "Salary")
        let model = makeModel(with: [expense, income])
        model.load()

        model.typeFilter = .income
        #expect(model.rows.map(\.title) == ["Salary"])

        model.typeFilter = nil
        #expect(model.rows.count == 2)
    }

    @Test("categoryFilter keeps only transactions in the given category")
    func categoryFilters() {
        let cibo = ExpenseDomain.Category(displayName: "Cibo")
        let inCasa = ExpenseDomain.Transaction(amount: 1, type: .expense, merchant: "Casa", category: casa)
        let inCibo = ExpenseDomain.Transaction(amount: 2, type: .expense, merchant: "Cibo", category: cibo)
        let model = makeModel(with: [inCasa, inCibo])
        model.load()

        model.categoryFilter = cibo.id
        #expect(model.rows.map(\.title) == ["Cibo"])
    }

    @Test("accountFilter keeps only transactions for the given account")
    func accountFilters() {
        let account = UUID()
        let mine = ExpenseDomain.Transaction(amount: 1, type: .expense, merchant: "Mine", accountId: account)
        let other = ExpenseDomain.Transaction(amount: 2, type: .expense, merchant: "Other", accountId: UUID())
        let model = makeModel(with: [mine, other])
        model.load()

        model.accountFilter = account
        #expect(model.rows.map(\.title) == ["Mine"])
    }

    @Test("date range bounds are inclusive")
    func dateRangeFilters() {
        func day(_ n: Int) -> Date { Date(timeIntervalSince1970: Double(n) * 86_400) }
        let first = transaction(merchant: "First", date: day(1))
        let second = transaction(merchant: "Second", date: day(2))
        let third = transaction(merchant: "Third", date: day(3))
        let model = makeModel(with: [first, second, third])
        model.load()

        model.startDate = day(2)
        model.endDate = day(2)
        #expect(model.rows.map(\.title) == ["Second"])
    }

    @Test("load() surfaces the catalog's top-level categories for the filter picker")
    func loadsCategories() {
        let cibo = ExpenseDomain.Category(displayName: "Cibo")
        let repo = ExpenseDomain.InMemoryRepository(
            catalog: ExpenseDomain.Catalog(categories: [casa, cibo], subcategories: []),
            transactions: []
        )
        let model = ExpenseTransactionsListModel(repository: repo, errorPresenter: ExpenseErrorPresenter())

        model.load()

        #expect(model.categories.map(\.displayName) == ["Casa", "Cibo"])
    }

    @Test("sort switches between date and amount, ascending and descending")
    func sorts() {
        let cheapOld = transaction(merchant: "CheapOld", amount: "5.00", date: Date(timeIntervalSince1970: 1000))
        let dearNew = transaction(merchant: "DearNew", amount: "50.00", date: Date(timeIntervalSince1970: 2000))
        let model = makeModel(with: [cheapOld, dearNew])
        model.load()

        // Default: newest first.
        #expect(model.rows.map(\.title) == ["DearNew", "CheapOld"])

        model.sortField = .date
        model.sortAscending = true
        #expect(model.rows.map(\.title) == ["CheapOld", "DearNew"])

        model.sortField = .amount
        model.sortAscending = false
        #expect(model.rows.map(\.title) == ["DearNew", "CheapOld"])

        model.sortAscending = true
        #expect(model.rows.map(\.title) == ["CheapOld", "DearNew"])
    }
}

/// An `ExpenseRepository` whose every operation throws — for exercising error paths.
private struct FailingRepository: ExpenseRepository {
    struct Boom: Error {}
    func catalog() throws -> ExpenseDomain.Catalog { throw Boom() }
    func tags() throws -> [ExpenseDomain.Tag] { throw Boom() }
    func transactions() throws -> [ExpenseDomain.Transaction] { throw Boom() }
    func categoryRules() throws -> [ExpenseDomain.CategoryRule] { throw Boom() }
    func saveCatalog(_ catalog: ExpenseDomain.Catalog) throws { throw Boom() }
    func saveTag(_ tag: ExpenseDomain.Tag) throws { throw Boom() }
    func saveCategoryRule(_ rule: ExpenseDomain.CategoryRule) throws { throw Boom() }
    func addTransaction(_ transaction: ExpenseDomain.Transaction) throws { throw Boom() }
    func updateTransaction(_ transaction: ExpenseDomain.Transaction) throws { throw Boom() }
    func deleteTransaction(id: UUID) throws { throw Boom() }
}
