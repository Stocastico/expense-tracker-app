import Foundation
import Observation

/// View model behind a domain-backed transactions list. Reads
/// `ExpenseDomain.Transaction`s through an `ExpenseRepository` and exposes
/// display-ready rows, routing any failure to the `ExpenseErrorPresenter` rather
/// than swallowing it. The SwiftUI view stays a thin shell over this.
@MainActor
@Observable
public final class ExpenseTransactionsListModel {

    /// A display-ready transaction, decoupled from the domain value type.
    public struct Row: Identifiable, Equatable, Sendable {
        public let id: UUID
        public let title: String
        /// "Category › subcategory", just the category, or `nil` when uncategorized.
        public let categoryPath: String?
        public let tagNames: [String]
        public let amount: Decimal
        public let date: Date
        public let type: TransactionType
    }

    /// What the list is sorted by.
    public enum SortField: Sendable {
        case date
        case amount
    }

    private let repository: any ExpenseRepository
    private let errorPresenter: ExpenseErrorPresenter

    /// Free-text search; matched case-insensitively against merchant,
    /// description, note, category/subcategory names and tag names. Blank
    /// (or whitespace-only) means no search filter.
    public var searchQuery: String = ""
    /// Restrict to a single transaction type, or `nil` for both.
    public var typeFilter: TransactionType?
    /// Restrict to a single top-level category by id, or `nil` for all.
    public var categoryFilter: ExpenseDomain.Category.ID?
    /// Restrict to a single account by id, or `nil` for all.
    public var accountFilter: UUID?
    /// Inclusive lower bound on the transaction date, if set.
    public var startDate: Date?
    /// Inclusive upper bound on the transaction date, if set.
    public var endDate: Date?
    /// Field the list is sorted by (default: date).
    public var sortField: SortField = .date
    /// Sort direction (default: descending — newest / largest first).
    public var sortAscending: Bool = false

    /// Top-level categories from the catalog, for the category filter picker.
    public private(set) var categories: [ExpenseDomain.Category] = []

    /// The domain transactions behind the rows, kept so a row can be opened for editing.
    private var loadedTransactions: [ExpenseDomain.Transaction] = []

    /// Display-ready rows after applying the active filters, search and sort.
    public var rows: [Row] {
        filteredAndSorted(loadedTransactions).map(Self.row(from:))
    }

    public init(repository: any ExpenseRepository, errorPresenter: ExpenseErrorPresenter) {
        self.repository = repository
        self.errorPresenter = errorPresenter
    }

    /// The full domain transaction behind a row, by id.
    public func transaction(id: UUID) -> ExpenseDomain.Transaction? {
        loadedTransactions.first { $0.id == id }
    }

    /// Loads transactions. On failure the error is surfaced and the existing
    /// rows are left untouched. Ordering and filtering are applied lazily by
    /// `rows`, so changing a filter doesn't require a reload.
    public func load() {
        guard let transactions = errorPresenter.perform("Loading transactions", {
            try repository.transactions()
        }) else {
            return
        }
        loadedTransactions = transactions

        if let catalog = errorPresenter.perform("Loading categories", {
            try repository.catalog()
        }) {
            categories = catalog.categories
        }
    }

    /// Deletes a transaction and reloads. Failures are surfaced.
    public func delete(id: UUID) {
        guard errorPresenter.perform("Deleting transaction", {
            try repository.deleteTransaction(id: id)
        }) != nil else {
            return
        }
        load()
    }

    // MARK: - Filtering & sorting

    /// Applies the active filters and search to `transactions`, then sorts.
    private func filteredAndSorted(_ transactions: [ExpenseDomain.Transaction]) -> [ExpenseDomain.Transaction] {
        var result = transactions

        if let accountFilter {
            result = result.filter { $0.accountId == accountFilter }
        }
        if let typeFilter {
            result = result.filter { $0.type == typeFilter }
        }
        if let categoryFilter {
            result = result.filter { $0.category?.id == categoryFilter }
        }
        if let startDate {
            result = result.filter { $0.date >= startDate }
        }
        if let endDate {
            result = result.filter { $0.date <= endDate }
        }

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter { Self.searchableText(for: $0).contains(query) }
        }

        result.sort { lhs, rhs in
            switch sortField {
            case .date:
                return sortAscending ? lhs.date < rhs.date : lhs.date > rhs.date
            case .amount:
                return sortAscending ? lhs.amount < rhs.amount : lhs.amount > rhs.amount
            }
        }
        return result
    }

    /// The lower-cased haystack a search query is matched against.
    private static func searchableText(for transaction: ExpenseDomain.Transaction) -> String {
        var parts: [String] = [transaction.descriptionText, transaction.note]
        if let merchant = transaction.merchant { parts.append(merchant) }
        if let category = transaction.category { parts.append(category.displayName) }
        if let subcategory = transaction.subcategory { parts.append(subcategory.displayName) }
        parts.append(contentsOf: transaction.tags.map(\.displayName))
        return parts.joined(separator: "\n").lowercased()
    }

    static func row(from transaction: ExpenseDomain.Transaction) -> Row {
        Row(
            id: transaction.id,
            title: title(for: transaction),
            categoryPath: categoryPath(for: transaction),
            tagNames: transaction.tags.map(\.displayName).sorted(),
            amount: transaction.amount,
            date: transaction.date,
            type: transaction.type
        )
    }

    private static func title(for transaction: ExpenseDomain.Transaction) -> String {
        if let merchant = transaction.merchant,
           !merchant.trimmingCharacters(in: .whitespaces).isEmpty {
            return merchant
        }
        if !transaction.descriptionText.trimmingCharacters(in: .whitespaces).isEmpty {
            return transaction.descriptionText
        }
        return "Untitled"
    }

    private static func categoryPath(for transaction: ExpenseDomain.Transaction) -> String? {
        guard let category = transaction.category else { return nil }
        if let subcategory = transaction.subcategory {
            return "\(category.displayName) › \(subcategory.displayName)"
        }
        return category.displayName
    }
}
