import Testing
import Foundation

/// Drives the testable core of the statement import writer: it turns parsed
/// `StatementEntry`s into editable drafts (with a learned-category suggestion)
/// and writes the selected ones through `ExpenseRepository` as domain
/// `Transaction`s (Decimal amounts, two-level category), learning each
/// description → category as it goes. The SwiftUI review table is a thin shell
/// over this model.
@MainActor
struct StatementImportModelTests {

    private func entry(
        _ description: String,
        _ amount: String,
        kind: StatementEntryKind,
        date: Date = Date(timeIntervalSinceReferenceDate: 1000)
    ) -> StatementEntry {
        StatementEntry(date: date, amount: Decimal(string: amount)!, kind: kind, description: description)
    }

    private func makeModel(
        _ entries: [StatementEntry],
        accounts: [ExpenseTransactionFormModel.AccountOption] = []
    ) -> (model: StatementImportModel, repository: ExpenseDomain.InMemoryRepository, presenter: ExpenseErrorPresenter) {
        let repository = ExpenseDomain.InMemoryRepository.seeded()
        let presenter = ExpenseErrorPresenter()
        let model = StatementImportModel(
            entries: entries,
            repository: repository,
            errorPresenter: presenter,
            accounts: accounts
        )
        model.load()
        return (model, repository, presenter)
    }

    @Test("load() builds one draft per entry with type and a parseable amount")
    func loadBuildsDrafts() {
        let (model, _, _) = makeModel([
            entry("Mercadona", "12.50", kind: .expense),
            entry("Stipendio", "1500.00", kind: .income),
        ])
        #expect(model.drafts.count == 2)
        #expect(model.drafts[0].type == .expense)
        #expect(model.drafts[0].descriptionText == "Mercadona")
        #expect(ExpenseTransactionFormModel.parseAmount(model.drafts[0].amountText) == Decimal(string: "12.50")!)
        #expect(model.drafts[1].type == .income)
    }

    @Test("Ignored entries are pre-deselected; expenses/income are pre-selected")
    func ignoredEntriesDeselected() {
        let (model, _, _) = makeModel([
            entry("Pago TARJETA", "100.00", kind: .ignored),
            entry("Mercadona", "12.50", kind: .expense),
        ])
        #expect(model.drafts[0].isSelected == false)
        #expect(model.drafts[1].isSelected == true)
    }

    @Test("Importing selected drafts writes domain transactions through the repository")
    func importsSelectedDrafts() throws {
        let account = UUID()
        let (model, repository, presenter) = makeModel(
            [entry("Mercadona", "12.50", kind: .expense)],
            accounts: [.init(id: account, name: "Bank")]
        )
        model.selectedAccountId = account
        let casa = try #require(model.categories.first { $0.displayName == "Casa" })
        model.drafts[0].selectedCategoryId = casa.id

        #expect(model.importSelected() == 1)
        #expect(presenter.currentError == nil)

        let stored = try repository.transactions()
        #expect(stored.count == 1)
        #expect(stored[0].amount == Decimal(string: "12.50")!)
        #expect(stored[0].type == .expense)
        #expect(stored[0].category?.displayName == "Casa")
        #expect(stored[0].accountId == account)
        #expect(stored[0].descriptionText == "Mercadona")
    }

    @Test("Unselected and zero/invalid-amount drafts are skipped")
    func skipsUnselectedAndInvalid() throws {
        let (model, repository, _) = makeModel([
            entry("Mercadona", "12.50", kind: .expense),
            entry("Bar", "5.00", kind: .expense),
        ])
        model.drafts[0].isSelected = false
        model.drafts[1].amountText = "0"

        #expect(model.importSelected() == 0)
        #expect(try repository.transactions().isEmpty)
    }

    @Test("Income imports with no category")
    func incomeImportsWithoutCategory() throws {
        let (model, repository, _) = makeModel([entry("Stipendio", "1500.00", kind: .income)])
        #expect(model.importSelected() == 1)
        #expect(try repository.transactions()[0].category == nil)
    }

    @Test("Importing a categorized expense learns its description → category")
    func importLearnsCategory() throws {
        let (model, repository, _) = makeModel([entry("Mercadona", "12.50", kind: .expense)])
        let casa = try #require(model.categories.first { $0.displayName == "Casa" })
        model.drafts[0].selectedCategoryId = casa.id

        #expect(model.importSelected() == 1)
        let rule = try #require(repository.categoryRules().first { $0.key == "mercadona" })
        #expect(rule.categoryId == casa.id)
    }

    @Test("A keyword seeds a category for an unlearned expense at load")
    func keywordSeedsCategoryAtLoad() throws {
        let (model, _, _) = makeModel([entry("Compra en Mercadona", "12.50", kind: .expense)])
        let spesa = try #require(model.categories.first { $0.displayName == "Spesa" })
        #expect(model.drafts[0].selectedCategoryId == spesa.id)
    }

    @Test("A learned rule takes precedence over the keyword seed")
    func learnedBeatsKeyword() throws {
        let repository = ExpenseDomain.InMemoryRepository.seeded()
        let presenter = ExpenseErrorPresenter()
        let casa = try #require(try repository.catalog().categories.first { $0.displayName == "Casa" })
        try repository.saveCategoryRule(ExpenseDomain.CategoryRule(key: "mercadona", categoryId: casa.id))

        let model = StatementImportModel(
            entries: [entry("Mercadona", "12.50", kind: .expense)],
            repository: repository,
            errorPresenter: presenter
        )
        model.load()
        // Learned "Casa" wins over the keyword seed's "Spesa".
        #expect(model.drafts[0].selectedCategoryId == casa.id)
    }

    @Test("Income gets no keyword suggestion")
    func incomeNoKeywordSuggestion() {
        let (model, _, _) = makeModel([entry("Mercadona", "12.50", kind: .income)])
        #expect(model.drafts[0].selectedCategoryId == nil)
    }

    @Test("A previously learned category pre-fills the draft at load")
    func loadAppliesLearnedCategory() throws {
        let repository = ExpenseDomain.InMemoryRepository.seeded()
        let presenter = ExpenseErrorPresenter()
        let casa = try #require(try repository.catalog().categories.first { $0.displayName == "Casa" })
        try repository.saveCategoryRule(ExpenseDomain.CategoryRule(key: "mercadona", categoryId: casa.id))

        let model = StatementImportModel(
            entries: [entry("MERCADONA 1234 BILBAO", "12.50", kind: .expense)],
            repository: repository,
            errorPresenter: presenter
        )
        model.load()
        // "MERCADONA 1234 BILBAO" normalises to "mercadona bilbao" — no match —
        // while a plain "Mercadona" would. Use the exact learned key here.
        #expect(model.drafts[0].selectedCategoryId == nil)

        let model2 = StatementImportModel(
            entries: [entry("Mercadona", "12.50", kind: .expense)],
            repository: repository,
            errorPresenter: presenter
        )
        model2.load()
        #expect(model2.drafts[0].selectedCategoryId == casa.id)
    }
}
