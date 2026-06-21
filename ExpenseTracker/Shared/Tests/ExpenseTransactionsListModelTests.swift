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

    private func model(with transactions: [ExpenseDomain.Transaction]) -> ExpenseTransactionsListModel {
        let repo = ExpenseDomain.InMemoryRepository(transactions: transactions)
        return ExpenseTransactionsListModel(repository: repo, errorPresenter: ExpenseErrorPresenter())
    }

    @Test("load() builds rows sorted newest-first")
    func loadsRowsNewestFirst() {
        let old = transaction(merchant: "Old", date: Date(timeIntervalSince1970: 1000))
        let new = transaction(merchant: "New", date: Date(timeIntervalSince1970: 2000))
        let model = model(with: [old, new])

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
        let model = model(with: [txn])

        model.load()

        let row = model.rows[0]
        #expect(row.title == "Iberdrola")
        #expect(row.categoryPath == "Casa › bollette")
        #expect(row.tagNames == ["casa", "work"])
        #expect(row.amount == Decimal(string: "42.50")!)
    }

    @Test("Category path omits the subcategory when there isn't one")
    func categoryPathWithoutSubcategory() {
        let model = model(with: [transaction(subcategoryNamed: nil)])
        model.load()
        #expect(model.rows[0].categoryPath == "Casa")
    }

    @Test("Title falls back from merchant to description to a placeholder")
    func titleFallback() {
        let fromDescription = transaction(merchant: "  ", description: "Bonifico")
        let placeholder = transaction(merchant: nil, description: "")
        let model = model(with: [fromDescription])
        model.load()
        #expect(model.rows[0].title == "Bonifico")

        let model2 = model(with: [placeholder])
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
}

/// An `ExpenseRepository` whose every operation throws — for exercising error paths.
private struct FailingRepository: ExpenseRepository {
    struct Boom: Error {}
    func catalog() throws -> ExpenseDomain.Catalog { throw Boom() }
    func tags() throws -> [ExpenseDomain.Tag] { throw Boom() }
    func transactions() throws -> [ExpenseDomain.Transaction] { throw Boom() }
    func saveCatalog(_ catalog: ExpenseDomain.Catalog) throws { throw Boom() }
    func saveTag(_ tag: ExpenseDomain.Tag) throws { throw Boom() }
    func addTransaction(_ transaction: ExpenseDomain.Transaction) throws { throw Boom() }
    func updateTransaction(_ transaction: ExpenseDomain.Transaction) throws { throw Boom() }
    func deleteTransaction(id: UUID) throws { throw Boom() }
}
