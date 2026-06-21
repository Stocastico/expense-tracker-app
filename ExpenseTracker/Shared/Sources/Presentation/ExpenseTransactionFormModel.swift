import Foundation
import Observation

/// View model behind a minimal "add transaction" form. Loads the catalog for
/// the category/subcategory pickers, parses a European-notation amount, and
/// writes a new `ExpenseDomain.Transaction` through the repository — surfacing
/// validation and persistence failures via the `ExpenseErrorPresenter`.
@MainActor
@Observable
public final class ExpenseTransactionFormModel {

    private let repository: any ExpenseRepository
    private let errorPresenter: ExpenseErrorPresenter
    private let onSaved: () -> Void

    // Editable fields.
    public var amountText: String = ""
    public var type: TransactionType = .expense
    public var selectedCategoryId: UUID?
    public var selectedSubcategoryId: UUID?

    public private(set) var categories: [ExpenseDomain.Category] = []
    private var catalog = ExpenseDomain.Catalog(categories: [], subcategories: [])

    public init(
        repository: any ExpenseRepository,
        errorPresenter: ExpenseErrorPresenter,
        onSaved: @escaping () -> Void = {}
    ) {
        self.repository = repository
        self.errorPresenter = errorPresenter
        self.onSaved = onSaved
    }

    /// Loads the catalog so the pickers have categories to show.
    public func load() {
        guard let catalog = errorPresenter.perform("Loading categories", {
            try repository.catalog()
        }) else {
            return
        }
        self.catalog = catalog
        self.categories = catalog.categories
    }

    /// Subcategories of the selected category — empty for income (which is not
    /// categorized) or when no category is selected.
    public var subcategories: [ExpenseDomain.Subcategory] {
        guard type == .expense,
              let id = selectedCategoryId,
              let category = categories.first(where: { $0.id == id })
        else {
            return []
        }
        return catalog.subcategories(of: category)
    }

    /// Builds and stores the transaction. Returns `true` on success. On failure
    /// (invalid amount, validation, persistence) an error is surfaced and
    /// nothing is stored.
    @discardableResult
    public func save() -> Bool {
        guard let amount = Self.parseAmount(amountText) else {
            errorPresenter.currentError = ExpensePresentableError(
                title: "Couldn’t save",
                message: "Enter a valid amount greater than zero."
            )
            return false
        }

        // Income is never categorized; for an expense, only take a subcategory
        // that belongs to the chosen category (stale selections are dropped).
        let category = type == .expense ? categories.first { $0.id == selectedCategoryId } : nil
        let subcategory = category == nil ? nil : subcategories.first { $0.id == selectedSubcategoryId }

        let transaction = ExpenseDomain.Transaction(
            amount: amount,
            type: type,
            category: category,
            subcategory: subcategory
        )

        guard errorPresenter.perform("Saving transaction", {
            try repository.addTransaction(transaction)
        }) != nil else {
            return false
        }
        onSaved()
        return true
    }

    /// Parses an amount in European or US notation into a positive magnitude.
    static func parseAmount(_ text: String) -> Decimal? {
        guard let value = MoneyParser.parse(text) else { return nil }
        let magnitude = abs(value)
        return magnitude > 0 ? magnitude : nil
    }
}
