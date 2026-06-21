import Testing
import Foundation

/// Drives the view model behind a minimal "add transaction" form: it loads the
/// catalog for category/subcategory pickers, parses a European-notation amount,
/// and writes through the repository, surfacing validation/persistence failures.
@MainActor
struct ExpenseTransactionFormModelTests {

    private func makeModel(
        onSaved: @escaping () -> Void = {}
    ) -> (model: ExpenseTransactionFormModel, repository: ExpenseDomain.InMemoryRepository, presenter: ExpenseErrorPresenter) {
        let repository = ExpenseDomain.InMemoryRepository.seeded()
        let presenter = ExpenseErrorPresenter()
        let model = ExpenseTransactionFormModel(
            repository: repository,
            errorPresenter: presenter,
            onSaved: onSaved
        )
        model.load()
        return (model, repository, presenter)
    }

    @Test("load() populates the category list from the catalog")
    func loadPopulatesCategories() {
        let (model, _, _) = makeModel()
        #expect(!model.categories.isEmpty)
        #expect(model.categories.contains { $0.displayName == "Casa" })
    }

    @Test("Subcategories follow the selected expense category")
    func subcategoriesFollowSelection() throws {
        let (model, _, _) = makeModel()
        let casa = try #require(model.categories.first { $0.displayName == "Casa" })
        model.selectedCategoryId = casa.id
        #expect(model.subcategories.contains { $0.displayName == "bollette" })
    }

    @Test("Income exposes no subcategories")
    func subcategoriesEmptyForIncome() {
        let (model, _, _) = makeModel()
        model.type = .income
        model.selectedCategoryId = model.categories.first?.id
        #expect(model.subcategories.isEmpty)
    }

    @Test("Saving a valid expense writes it through the repository")
    func savesExpense() throws {
        let (model, repository, presenter) = makeModel()
        let casa = try #require(model.categories.first { $0.displayName == "Casa" })
        model.type = .expense
        model.amountText = "12,50"
        model.selectedCategoryId = casa.id
        let bollette = try #require(model.subcategories.first { $0.displayName == "bollette" })
        model.selectedSubcategoryId = bollette.id

        #expect(model.save())
        #expect(presenter.currentError == nil)

        let stored = try repository.transactions()
        #expect(stored.count == 1)
        #expect(stored[0].amount == Decimal(string: "12.50")!)
        #expect(stored[0].category?.displayName == "Casa")
        #expect(stored[0].subcategory?.displayName == "bollette")
    }

    @Test("Saving income stores no category and validates")
    func savesIncome() throws {
        let (model, repository, presenter) = makeModel()
        model.type = .income
        model.amountText = "1000"
        model.selectedCategoryId = model.categories.first?.id // must be ignored

        #expect(model.save())
        let stored = try repository.transactions()
        #expect(stored.count == 1)
        #expect(stored[0].type == .income)
        #expect(stored[0].category == nil)
        #expect(presenter.currentError == nil)
    }

    @Test("An invalid amount surfaces an error and saves nothing")
    func invalidAmountSurfaces() throws {
        let (model, repository, presenter) = makeModel()
        model.amountText = "not a number"
        model.selectedCategoryId = model.categories.first?.id

        #expect(model.save() == false)
        #expect(presenter.currentError != nil)
        #expect(try repository.transactions().isEmpty)
    }

    @Test("onSaved fires on a successful save")
    func onSavedFires() {
        var saved = false
        let (model, _, _) = makeModel(onSaved: { saved = true })
        model.type = .income
        model.amountText = "5"
        _ = model.save()
        #expect(saved)
    }
}
