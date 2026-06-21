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

    private let repository: any ExpenseRepository
    private let errorPresenter: ExpenseErrorPresenter

    public private(set) var rows: [Row] = []

    public init(repository: any ExpenseRepository, errorPresenter: ExpenseErrorPresenter) {
        self.repository = repository
        self.errorPresenter = errorPresenter
    }

    /// Loads transactions (newest first). On failure the error is surfaced and
    /// the existing rows are left untouched.
    public func load() {
        guard let transactions = errorPresenter.perform("Loading transactions", {
            try repository.transactions()
        }) else {
            return
        }
        rows = transactions
            .sorted { $0.date > $1.date }
            .map(Self.row(from:))
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
