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
    /// The transaction being edited, or `nil` when adding. Editing preserves the
    /// fields the minimal form doesn't expose (merchant, description, tags, …).
    private let editingTransaction: ExpenseDomain.Transaction?

    // Editable fields.
    public var amountText: String = ""
    public var type: TransactionType = .expense
    public var selectedCategoryId: UUID?
    public var selectedSubcategoryId: UUID?
    public var merchant: String = ""
    public var descriptionText: String = ""
    public var date: Date = Date()

    public private(set) var categories: [ExpenseDomain.Category] = []
    private var catalog = ExpenseDomain.Catalog(categories: [], subcategories: [])

    /// Whether the form is editing an existing transaction (vs adding a new one).
    public var isEditing: Bool { editingTransaction != nil }

    public init(
        repository: any ExpenseRepository,
        errorPresenter: ExpenseErrorPresenter,
        editing: ExpenseDomain.Transaction? = nil,
        onSaved: @escaping () -> Void = {}
    ) {
        self.repository = repository
        self.errorPresenter = errorPresenter
        self.editingTransaction = editing
        self.onSaved = onSaved

        if let editing {
            amountText = Self.displayAmount(editing.amount)
            type = editing.type
            selectedCategoryId = editing.category?.id
            selectedSubcategoryId = editing.subcategory?.id
            merchant = editing.merchant ?? ""
            descriptionText = editing.descriptionText
            date = editing.date
        }
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

        // When editing, start from the original so untouched fields (merchant,
        // description, tags, account, note, date) are preserved.
        var transaction = editingTransaction ?? ExpenseDomain.Transaction(amount: amount, type: type)
        transaction.amount = amount
        transaction.type = type
        transaction.category = category
        transaction.subcategory = subcategory
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespaces)
        transaction.merchant = trimmedMerchant.isEmpty ? nil : trimmedMerchant
        transaction.descriptionText = descriptionText
        transaction.date = date

        let title = isEditing ? "Updating transaction" : "Saving transaction"
        guard errorPresenter.perform(title, {
            if isEditing {
                try repository.updateTransaction(transaction)
            } else {
                try repository.addTransaction(transaction)
            }
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

    /// Formats a magnitude as a 2-dp European string (comma decimal, no grouping)
    /// that round-trips through `parseAmount` — used to prefill the field when editing.
    static func displayAmount(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "it_IT")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}
