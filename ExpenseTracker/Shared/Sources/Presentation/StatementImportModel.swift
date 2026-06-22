import Foundation
import Observation

/// View model behind the "Import Statement" review step. It takes the parsed
/// `StatementEntry`s, exposes them as editable drafts (date, description,
/// amount, type, category) with a learned-category suggestion, and writes the
/// selected rows through `ExpenseRepository` as domain `Transaction`s —
/// Decimal amounts, two-level category, learning each description → category
/// as it imports. The SwiftUI review table is a thin shell over this model.
///
/// This is the domain-repository port of the legacy `PDFImportView` writer
/// (which built `Double` `Transaction`s via `DataService` and learned through
/// the flat-catalog `CategoryRuleService`).
@MainActor
@Observable
public final class StatementImportModel {

    /// Reuses the form model's account value type so the two import surfaces
    /// share one representation.
    public typealias AccountOption = ExpenseTransactionFormModel.AccountOption

    /// One editable import row, mirroring a parsed `StatementEntry`.
    public struct Draft: Identifiable {
        public let id: UUID
        public var date: Date
        public var descriptionText: String
        public var amountText: String
        public var type: TransactionType
        public var selectedCategoryId: UUID?
        public var selectedSubcategoryId: UUID?
        /// Settlements/transfers/zero lines (`.ignored`) start unticked.
        public var isSelected: Bool

        public init(
            id: UUID = UUID(),
            date: Date,
            descriptionText: String,
            amountText: String,
            type: TransactionType,
            selectedCategoryId: UUID? = nil,
            selectedSubcategoryId: UUID? = nil,
            isSelected: Bool
        ) {
            self.id = id
            self.date = date
            self.descriptionText = descriptionText
            self.amountText = amountText
            self.type = type
            self.selectedCategoryId = selectedCategoryId
            self.selectedSubcategoryId = selectedSubcategoryId
            self.isSelected = isSelected
        }
    }

    private let entries: [StatementEntry]
    private let repository: any ExpenseRepository
    private let errorPresenter: ExpenseErrorPresenter

    public let accounts: [AccountOption]
    public var selectedAccountId: UUID?

    public private(set) var drafts: [Draft] = []
    public private(set) var categories: [ExpenseDomain.Category] = []
    public private(set) var importedCount = 0

    private var catalog = ExpenseDomain.Catalog(categories: [], subcategories: [])
    /// Learned rules loaded at `load()` and reinforced as rows import.
    private var learner = ExpenseDomain.CategoryLearner()

    public init(
        entries: [StatementEntry],
        repository: any ExpenseRepository,
        errorPresenter: ExpenseErrorPresenter,
        accounts: [AccountOption] = []
    ) {
        self.entries = entries
        self.repository = repository
        self.errorPresenter = errorPresenter
        self.accounts = accounts
    }

    /// Loads the catalog and learned rules, then builds an editable draft per
    /// parsed entry — suggesting a category for known expense merchants.
    public func load() {
        if let catalog = errorPresenter.perform("Loading categories", { try repository.catalog() }) {
            self.catalog = catalog
            self.categories = catalog.categories
        }
        if let rules = errorPresenter.perform("Loading learned categories", { try repository.categoryRules() }) {
            self.learner = ExpenseDomain.CategoryLearner(rules: rules)
        }

        drafts = entries.map { entry in
            let type: TransactionType = entry.isExpense ? .expense : .income
            let suggestion = type == .expense
                ? learner.suggestion(merchant: nil, description: entry.description)
                : nil
            return Draft(
                date: entry.date ?? Date(),
                descriptionText: entry.description,
                amountText: ExpenseTransactionFormModel.displayAmount(entry.amount),
                type: type,
                selectedCategoryId: suggestion?.categoryId,
                selectedSubcategoryId: suggestion?.subcategoryId,
                isSelected: entry.kind != .ignored
            )
        }
    }

    /// Subcategories available for a draft — empty for income or when its
    /// category isn't an expense category in the catalog.
    public func subcategories(for draft: Draft) -> [ExpenseDomain.Subcategory] {
        guard draft.type == .expense,
              let id = draft.selectedCategoryId,
              let category = categories.first(where: { $0.id == id })
        else {
            return []
        }
        return catalog.subcategories(of: category)
    }

    /// Imports every selected draft with a valid positive amount, writing it
    /// through the repository and learning its category. Returns the count
    /// imported and records it in `importedCount`.
    @discardableResult
    public func importSelected() -> Int {
        var count = 0
        for draft in drafts where draft.isSelected {
            guard let amount = ExpenseTransactionFormModel.parseAmount(draft.amountText) else { continue }

            // Income is never categorized; for an expense, only take a subcategory
            // that belongs to the chosen category.
            let category = draft.type == .expense
                ? categories.first { $0.id == draft.selectedCategoryId }
                : nil
            let subcategory = category == nil
                ? nil
                : subcategories(for: draft).first { $0.id == draft.selectedSubcategoryId }

            let transaction = ExpenseDomain.Transaction(
                amount: amount,
                date: draft.date,
                type: draft.type,
                descriptionText: draft.descriptionText,
                category: category,
                subcategory: subcategory,
                accountId: selectedAccountId
            )

            let stored = errorPresenter.perform("Importing transactions") { () throws -> Bool in
                try repository.addTransaction(transaction)
                return true
            }
            guard stored == true else { continue }
            count += 1

            learnCategory(description: draft.descriptionText, category: category, subcategory: subcategory)
        }
        importedCount = count
        return count
    }

    /// Records (or reinforces) the imported expense's description → category so
    /// later imports and the manual form can suggest it.
    private func learnCategory(
        description: String,
        category: ExpenseDomain.Category?,
        subcategory: ExpenseDomain.Subcategory?
    ) {
        guard let category else { return }
        guard let rule = learner.learn(
            merchant: nil,
            description: description,
            categoryId: category.id,
            subcategoryId: subcategory?.id
        ) else {
            return
        }
        _ = errorPresenter.perform("Importing transactions") { () throws -> Bool in
            try repository.saveCategoryRule(rule)
            return true
        }
    }
}
