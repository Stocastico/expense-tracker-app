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

    @Test("load() populates the available tags")
    func loadPopulatesTags() {
        let (model, _, _) = makeModel()
        #expect(!model.availableTags.isEmpty)
        #expect(model.availableTags.contains { $0.displayName == "work" })
    }

    @Test("Account options are exposed as provided")
    func accountsExposed() {
        let id = UUID()
        let model = ExpenseTransactionFormModel(
            repository: ExpenseDomain.InMemoryRepository.seeded(),
            errorPresenter: ExpenseErrorPresenter(),
            accounts: [.init(id: id, name: "Family")]
        )
        #expect(model.accounts.map(\.name) == ["Family"])
    }

    @Test("Saving stores the selected tags and account")
    func savesTagsAndAccount() throws {
        let account = UUID()
        let repository = ExpenseDomain.InMemoryRepository.seeded()
        let model = ExpenseTransactionFormModel(
            repository: repository,
            errorPresenter: ExpenseErrorPresenter(),
            accounts: [.init(id: account, name: "Personal")]
        )
        model.load()
        model.type = .income
        model.amountText = "50"
        let work = try #require(model.availableTags.first { $0.displayName == "work" })
        model.selectedTagIds = [work.id]
        model.selectedAccountId = account

        #expect(model.save())
        let stored = try repository.transactions()[0]
        #expect(stored.tags.map(\.displayName) == ["work"])
        #expect(stored.accountId == account)
    }

    @Test("Editing prefills the selected tags and account")
    func editingPrefillsTagsAndAccount() {
        let account = UUID()
        let tag = ExpenseDomain.Tag(displayName: "work")
        let original = ExpenseDomain.Transaction(
            amount: Decimal(string: "5.00")!,
            type: .expense,
            tags: [tag],
            accountId: account
        )
        let model = ExpenseTransactionFormModel(
            repository: ExpenseDomain.InMemoryRepository.seeded(),
            errorPresenter: ExpenseErrorPresenter(),
            editing: original
        )
        model.load()
        #expect(model.selectedTagIds == [tag.id])
        #expect(model.selectedAccountId == account)
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

    @Test("Saving a recurring expense stores the schedule and generates its occurrences")
    func savesRecurringWithOccurrences() throws {
        let (model, repository, presenter) = makeModel()
        let casa = try #require(model.categories.first { $0.displayName == "Casa" })
        let cal = Calendar.current
        model.type = .expense
        model.amountText = "30"
        model.selectedCategoryId = casa.id
        model.date = try #require(cal.date(from: DateComponents(year: 2026, month: 1, day: 10)))
        model.isRecurring = true
        model.recurringFrequency = .monthly
        model.hasEndDate = true
        model.recurringEndDate = try #require(cal.date(from: DateComponents(year: 2026, month: 4, day: 10)))

        #expect(model.save())
        #expect(presenter.currentError == nil)

        let stored = try repository.transactions()
        // The template plus three monthly occurrences (Feb, Mar, Apr).
        #expect(stored.count == 4)
        let parent = try #require(stored.first { $0.recurringParentId == nil })
        #expect(parent.recurrence == ExpenseDomain.Recurrence(frequency: .monthly, endDate: model.recurringEndDate))
        #expect(stored.filter { $0.recurringParentId == parent.id }.count == 3)
    }

    @Test("A non-recurring save stores a single transaction with no schedule")
    func savesNonRecurringSingle() throws {
        let (model, repository, _) = makeModel()
        model.type = .income
        model.amountText = "100"

        #expect(model.save())
        let stored = try repository.transactions()
        #expect(stored.count == 1)
        #expect(stored[0].recurrence == nil)
        #expect(stored[0].recurringParentId == nil)
    }

    @Test("Saving stores the entered note")
    func savesNote() throws {
        let (model, repository, _) = makeModel()
        model.type = .income
        model.amountText = "10"
        model.note = "rent for June"

        #expect(model.save())
        #expect(try repository.transactions()[0].note == "rent for June")
    }

    @Test("Editing prefills recurrence and note")
    func editingPrefillsRecurrenceAndNote() {
        let end = Date(timeIntervalSince1970: 2_000_000_000)
        let original = ExpenseDomain.Transaction(
            amount: Decimal(string: "5.00")!,
            type: .expense,
            note: "keep",
            recurrence: ExpenseDomain.Recurrence(frequency: .weekly, endDate: end)
        )
        let model = ExpenseTransactionFormModel(
            repository: ExpenseDomain.InMemoryRepository.seeded(),
            errorPresenter: ExpenseErrorPresenter(),
            editing: original
        )
        model.load()
        #expect(model.isRecurring)
        #expect(model.recurringFrequency == .weekly)
        #expect(model.hasEndDate)
        #expect(model.recurringEndDate == end)
        #expect(model.note == "keep")
    }

    @Test("Editing a recurring transaction updates in place, without generating occurrences")
    func editingRecurringDoesNotGenerate() throws {
        let repository = ExpenseDomain.InMemoryRepository.seeded()
        let original = ExpenseDomain.Transaction(
            amount: Decimal(string: "10.00")!,
            type: .expense,
            recurrence: ExpenseDomain.Recurrence(
                frequency: .monthly,
                endDate: Date(timeIntervalSince1970: 2_000_000_000)
            )
        )
        try repository.addTransaction(original)

        let model = ExpenseTransactionFormModel(
            repository: repository,
            errorPresenter: ExpenseErrorPresenter(),
            editing: original
        )
        model.load()
        model.amountText = "12"

        #expect(model.save())
        #expect(try repository.transactions().count == 1) // updated, not multiplied
    }

    @Test("reset() clears entry fields for a fresh quick add, keeping type, category and account")
    func resetClearsEntryFieldsKeepingContext() throws {
        let (model, _, _) = makeModel()
        let casa = try #require(model.categories.first { $0.displayName == "Casa" })
        let account = UUID()
        model.type = .expense
        model.amountText = "9,99"
        model.merchant = "Shop"
        model.descriptionText = "stuff"
        model.selectedCategoryId = casa.id
        let bollette = try #require(model.subcategories.first { $0.displayName == "bollette" })
        model.selectedSubcategoryId = bollette.id
        let tag = try #require(model.availableTags.first)
        model.selectedTagIds = [tag.id]
        model.selectedAccountId = account
        model.date = Date(timeIntervalSince1970: 1_000_000)

        model.reset()

        // Per-entry content is cleared.
        #expect(model.amountText == "")
        #expect(model.merchant == "")
        #expect(model.descriptionText == "")
        #expect(model.selectedTagIds.isEmpty)
        #expect(model.date.timeIntervalSinceNow > -5) // reset to ~now

        // Context likely reused for the next quick entry is preserved.
        #expect(model.type == .expense)
        #expect(model.selectedCategoryId == casa.id)
        #expect(model.selectedSubcategoryId == bollette.id)
        #expect(model.selectedAccountId == account)
    }

    @Test("Editing prefills the amount in a parseable form")
    func editingPrefillsAmount() throws {
        let repository = ExpenseDomain.InMemoryRepository.seeded()
        let original = ExpenseDomain.Transaction(amount: Decimal(string: "10.00")!, type: .expense)
        let model = ExpenseTransactionFormModel(
            repository: repository,
            errorPresenter: ExpenseErrorPresenter(),
            editing: original
        )
        model.load()
        #expect(model.type == .expense)
        #expect(ExpenseTransactionFormModel.parseAmount(model.amountText) == Decimal(string: "10.00")!)
    }

    @Test("Saving stores merchant, description and date")
    func savesOptionalDetails() throws {
        let (model, repository, _) = makeModel()
        model.type = .income
        model.amountText = "100"
        model.merchant = "Acme"
        model.descriptionText = "March invoice"
        let date = Date(timeIntervalSince1970: 1_000_000)
        model.date = date

        #expect(model.save())
        let stored = try repository.transactions()[0]
        #expect(stored.merchant == "Acme")
        #expect(stored.descriptionText == "March invoice")
        #expect(stored.date == date)
    }

    @Test("A blank merchant is stored as nil")
    func blankMerchantIsNil() throws {
        let (model, repository, _) = makeModel()
        model.type = .income
        model.amountText = "10"
        model.merchant = "   "

        #expect(model.save())
        #expect(try repository.transactions()[0].merchant == nil)
    }

    // MARK: - Category learning

    @Test("Saving a categorized expense learns the merchant's category")
    func savingExpenseLearnsCategory() throws {
        let (model, repository, _) = makeModel()
        let casa = try #require(model.categories.first { $0.displayName == "Casa" })
        model.type = .expense
        model.amountText = "20"
        model.merchant = "Mercadona"
        model.selectedCategoryId = casa.id
        let bollette = try #require(model.subcategories.first { $0.displayName == "bollette" })
        model.selectedSubcategoryId = bollette.id

        #expect(model.save())

        let rule = try #require(repository.categoryRules().first { $0.key == "mercadona" })
        #expect(rule.categoryId == casa.id)
        #expect(rule.subcategoryId == bollette.id)
    }

    @Test("Saving income learns nothing (income is never categorized)")
    func savingIncomeLearnsNothing() throws {
        let (model, repository, _) = makeModel()
        model.type = .income
        model.amountText = "1000"
        model.merchant = "Employer"

        #expect(model.save())
        #expect(try repository.categoryRules().isEmpty)
    }

    @Test("Saving an uncategorized expense learns nothing")
    func savingUncategorizedExpenseLearnsNothing() throws {
        let (model, repository, _) = makeModel()
        model.type = .expense
        model.amountText = "20"
        model.merchant = "Mystery"

        #expect(model.save())
        #expect(try repository.categoryRules().isEmpty)
    }

    @Test("suggestCategory fills the pickers from a previously learned merchant")
    func suggestCategoryAppliesLearnedAssignment() throws {
        let repository = ExpenseDomain.InMemoryRepository.seeded()
        let presenter = ExpenseErrorPresenter()

        // First entry teaches "Mercadona → Casa / bollette".
        let teacher = ExpenseTransactionFormModel(repository: repository, errorPresenter: presenter)
        teacher.load()
        let casa = try #require(teacher.categories.first { $0.displayName == "Casa" })
        teacher.type = .expense
        teacher.amountText = "20"
        teacher.merchant = "Mercadona"
        teacher.selectedCategoryId = casa.id
        let bollette = try #require(teacher.subcategories.first { $0.displayName == "bollette" })
        teacher.selectedSubcategoryId = bollette.id
        #expect(teacher.save())

        // A fresh entry for the same merchant (different branch number) gets it
        // applied — the branch digits are dropped, so the key still matches.
        let model = ExpenseTransactionFormModel(repository: repository, errorPresenter: presenter)
        model.load()
        model.type = .expense
        model.merchant = "MERCADONA 1234"
        model.suggestCategory()

        #expect(model.selectedCategoryId == casa.id)
        #expect(model.selectedSubcategoryId == bollette.id)
    }

    @Test("suggestCategory leaves the selection untouched for an unknown merchant")
    func suggestCategoryUnknownMerchant() {
        let (model, _, _) = makeModel()
        model.type = .expense
        model.merchant = "Totally Unknown Shop"
        model.suggestCategory()
        #expect(model.selectedCategoryId == nil)
        #expect(model.selectedSubcategoryId == nil)
    }

    @Test("suggestCategory does nothing for income")
    func suggestCategoryIgnoredForIncome() throws {
        let repository = ExpenseDomain.InMemoryRepository.seeded()
        let presenter = ExpenseErrorPresenter()
        let teacher = ExpenseTransactionFormModel(repository: repository, errorPresenter: presenter)
        teacher.load()
        let casa = try #require(teacher.categories.first { $0.displayName == "Casa" })
        teacher.type = .expense
        teacher.amountText = "20"
        teacher.merchant = "Mercadona"
        teacher.selectedCategoryId = casa.id
        #expect(teacher.save())

        let model = ExpenseTransactionFormModel(repository: repository, errorPresenter: presenter)
        model.load()
        model.type = .income
        model.merchant = "Mercadona"
        model.suggestCategory()
        #expect(model.selectedCategoryId == nil)
    }

    @Test("Editing prefills merchant, description and date")
    func editingPrefillsDetails() {
        let repository = ExpenseDomain.InMemoryRepository.seeded()
        let date = Date(timeIntervalSince1970: 2_000_000)
        let original = ExpenseDomain.Transaction(
            amount: Decimal(string: "5.00")!,
            date: date,
            type: .expense,
            merchant: "Shop",
            descriptionText: "stuff"
        )
        let model = ExpenseTransactionFormModel(
            repository: repository,
            errorPresenter: ExpenseErrorPresenter(),
            editing: original
        )
        model.load()
        #expect(model.merchant == "Shop")
        #expect(model.descriptionText == "stuff")
        #expect(model.date == date)
    }

    @Test("Editing updates in place and preserves untouched fields")
    func editingPreservesUntouchedFields() throws {
        let repository = ExpenseDomain.InMemoryRepository.seeded()
        let presenter = ExpenseErrorPresenter()
        let casa = try #require(try repository.catalog().categories.first { $0.displayName == "Casa" })
        let original = ExpenseDomain.Transaction(
            amount: Decimal(string: "10.00")!,
            type: .expense,
            merchant: "Iberdrola",
            descriptionText: "luce",
            category: casa,
            tags: [ExpenseDomain.Tag(displayName: "casa")],
            note: "keep me"
        )
        try repository.addTransaction(original)

        let model = ExpenseTransactionFormModel(repository: repository, errorPresenter: presenter, editing: original)
        model.load()
        #expect(model.selectedCategoryId == casa.id)
        model.amountText = "25,00"

        #expect(model.save())

        let stored = try repository.transactions()
        #expect(stored.count == 1) // updated, not added
        let updated = stored[0]
        #expect(updated.id == original.id)
        #expect(updated.amount == Decimal(string: "25.00")!)
        #expect(updated.merchant == "Iberdrola")
        #expect(updated.descriptionText == "luce")
        #expect(updated.note == "keep me")
        #expect(updated.tags.map(\.displayName) == ["casa"])
        #expect(presenter.currentError == nil)
    }
}
