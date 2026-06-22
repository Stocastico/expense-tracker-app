import Foundation
import Observation

/// View model behind a minimal "add transaction" form. Loads the catalog for
/// the category/subcategory pickers, parses a European-notation amount, and
/// writes a new `ExpenseDomain.Transaction` through the repository — surfacing
/// validation and persistence failures via the `ExpenseErrorPresenter`.
@MainActor
@Observable
public final class ExpenseTransactionFormModel {

    /// A selectable account, as a plain value so the form stays free of SwiftData.
    public struct AccountOption: Identifiable, Equatable, Sendable {
        public let id: UUID
        public let name: String
        public init(id: UUID, name: String) {
            self.id = id
            self.name = name
        }
    }

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
    public var selectedTagIds: Set<UUID> = []
    public var selectedAccountId: UUID?
    public var note: String = ""

    // Recurring schedule.
    public var isRecurring: Bool = false
    public var recurringFrequency: RecurringFrequency = .monthly
    public var hasEndDate: Bool = false
    public var recurringEndDate: Date = Date().monthsFromNow(12)

    public private(set) var categories: [ExpenseDomain.Category] = []
    public private(set) var availableTags: [ExpenseDomain.Tag] = []
    /// The accounts available to assign, provided by the caller.
    public let accounts: [AccountOption]
    private var catalog = ExpenseDomain.Catalog(categories: [], subcategories: [])

    /// Whether the form is editing an existing transaction (vs adding a new one).
    public var isEditing: Bool { editingTransaction != nil }

    public init(
        repository: any ExpenseRepository,
        errorPresenter: ExpenseErrorPresenter,
        editing: ExpenseDomain.Transaction? = nil,
        accounts: [AccountOption] = [],
        onSaved: @escaping () -> Void = {}
    ) {
        self.repository = repository
        self.errorPresenter = errorPresenter
        self.editingTransaction = editing
        self.accounts = accounts
        self.onSaved = onSaved

        if let editing {
            amountText = Self.displayAmount(editing.amount)
            type = editing.type
            selectedCategoryId = editing.category?.id
            selectedSubcategoryId = editing.subcategory?.id
            merchant = editing.merchant ?? ""
            descriptionText = editing.descriptionText
            date = editing.date
            selectedTagIds = Set(editing.tags.map(\.id))
            selectedAccountId = editing.accountId
            note = editing.note
            if let recurrence = editing.recurrence {
                isRecurring = true
                recurringFrequency = recurrence.frequency
                if let endDate = recurrence.endDate {
                    hasEndDate = true
                    recurringEndDate = endDate
                }
            }
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
        if let tags = errorPresenter.perform("Loading tags", { try repository.tags() }) {
            self.availableTags = tags
        }
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
        // Resolve selected ids against the available tags plus any already on the
        // edited transaction, so editing never drops a tag that isn't in the seed.
        var tagsById: [UUID: ExpenseDomain.Tag] = [:]
        for tag in availableTags + (editingTransaction?.tags.map { $0 } ?? []) {
            tagsById[tag.id] = tag
        }
        transaction.tags = Set(selectedTagIds.compactMap { tagsById[$0] })
        transaction.accountId = selectedAccountId
        transaction.note = note
        transaction.recurrence = isRecurring
            ? ExpenseDomain.Recurrence(
                frequency: recurringFrequency,
                endDate: hasEndDate ? recurringEndDate : nil
              )
            : nil

        // A new recurring template also writes its generated occurrences (an
        // open-ended schedule generates a year out, matching the legacy form);
        // editing updates the row in place and does not regenerate.
        let occurrences: [ExpenseDomain.Transaction]
        if !isEditing, transaction.recurrence != nil {
            let until = hasEndDate ? recurringEndDate : Date().monthsFromNow(12)
            occurrences = ExpenseDomain.recurringOccurrences(of: transaction, until: until)
        } else {
            occurrences = []
        }

        let title = isEditing ? "Updating transaction" : "Saving transaction"
        let outcome = errorPresenter.perform(title) { () throws -> Void in
            if isEditing {
                try repository.updateTransaction(transaction)
            } else {
                try repository.addTransaction(transaction)
                for occurrence in occurrences {
                    try repository.addTransaction(occurrence)
                }
            }
        }
        guard outcome != nil else { return false }
        // Best-effort: remember this merchant's category so future entries can be
        // pre-filled. Runs after the transaction is safely stored.
        learnCategory(merchant: transaction.merchant, category: category, subcategory: subcategory)
        onSaved()
        return true
    }

    /// Applies the category/subcategory learned for the current merchant (or
    /// description) to the pickers, if one was previously learned. Intended to be
    /// called by the view when the merchant field changes. No-op for income
    /// (which is never categorized) and for unknown merchants.
    public func suggestCategory() {
        guard type == .expense else { return }
        guard let rules = errorPresenter.perform("Loading learned categories", {
            try repository.categoryRules()
        }) else {
            return
        }
        let learner = ExpenseDomain.CategoryLearner(rules: rules)
        guard let suggestion = learner.suggestion(merchant: merchant, description: descriptionText) else {
            return
        }
        selectedCategoryId = suggestion.categoryId
        selectedSubcategoryId = suggestion.subcategoryId
    }

    /// Records (or reinforces) the merchant → category/subcategory association so
    /// `suggestCategory()` can offer it next time. Only expenses with a category
    /// are learned; income is never categorized.
    private func learnCategory(
        merchant: String?,
        category: ExpenseDomain.Category?,
        subcategory: ExpenseDomain.Subcategory?
    ) {
        guard type == .expense, let category else { return }
        _ = errorPresenter.perform("Learning category") {
            var learner = ExpenseDomain.CategoryLearner(rules: try repository.categoryRules())
            if let rule = learner.learn(
                merchant: merchant,
                description: descriptionText,
                categoryId: category.id,
                subcategoryId: subcategory?.id
            ) {
                try repository.saveCategoryRule(rule)
            }
        }
    }

    /// Clears the per-entry fields for a fresh add, preserving the context the
    /// user is likely to reuse (type, category/subcategory, account). Used by the
    /// menu-bar quick-add, which stays open for repeated entries.
    public func reset() {
        amountText = ""
        merchant = ""
        descriptionText = ""
        selectedTagIds = []
        date = Date()
        note = ""
        isRecurring = false
        hasEndDate = false
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
