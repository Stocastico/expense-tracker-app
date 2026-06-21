import Foundation

extension ExpenseDomain {

    // MARK: - Validation

    /// Reasons a `Transaction`'s category assignment is inconsistent.
    public enum ValidationError: Error, Equatable, Sendable {
        /// An income transaction must not carry an expense category/subcategory.
        case incomeHasCategory
        /// A subcategory was set without a parent category.
        case subcategoryWithoutCategory
        /// The subcategory does not belong to the assigned category.
        case subcategoryParentMismatch
    }

    // MARK: - Transaction

    /// A single money movement. Money is held as `Decimal` (never `Double`) so
    /// sums are exact. `category`/`subcategory` are optional because income is a
    /// separate axis and an expense may be left uncategorized.
    public struct Transaction: Identifiable, Hashable, Sendable {
        public let id: UUID
        public var amount: Decimal
        public var date: Date
        public var type: TransactionType
        /// Payee / merchant, if known.
        public var merchant: String?
        /// Human-readable description, distinct from the free-text `note`.
        public var descriptionText: String
        public var category: Category?
        public var subcategory: Subcategory?
        public var tags: Set<Tag>
        /// The owning account, referenced by id (the domain does not depend on
        /// the SwiftData `Account` type).
        public var accountId: UUID?
        public var note: String

        public init(
            id: UUID = UUID(),
            amount: Decimal,
            date: Date = Date(),
            type: TransactionType,
            merchant: String? = nil,
            descriptionText: String = "",
            category: Category? = nil,
            subcategory: Subcategory? = nil,
            tags: Set<Tag> = [],
            accountId: UUID? = nil,
            note: String = ""
        ) {
            self.id = id
            self.amount = amount
            self.date = date
            self.type = type
            self.merchant = merchant
            self.descriptionText = descriptionText
            self.category = category
            self.subcategory = subcategory
            self.tags = tags
            self.accountId = accountId
            self.note = note
        }

        /// Validates that the category assignment is internally consistent.
        ///
        /// Income lives on a separate axis from the expense category tree, so an
        /// income transaction must carry no category. For expenses, any
        /// subcategory must belong to the assigned category.
        public func validate() throws {
            if type == .income {
                guard category == nil, subcategory == nil else {
                    throw ValidationError.incomeHasCategory
                }
                return
            }

            if let subcategory {
                guard let category else {
                    throw ValidationError.subcategoryWithoutCategory
                }
                guard subcategory.isChild(of: category) else {
                    throw ValidationError.subcategoryParentMismatch
                }
            }
        }
    }

    // MARK: - Queries

    /// Totals expense spend grouped by top-level category. Income and
    /// uncategorized expenses are ignored. Amounts are summed as `Decimal`.
    public static func totalSpendByCategory(
        _ transactions: [Transaction]
    ) -> [Category: Decimal] {
        var totals: [Category: Decimal] = [:]
        for transaction in transactions where transaction.type == .expense {
            guard let category = transaction.category else { continue }
            totals[category, default: 0] += transaction.amount
        }
        return totals
    }
}
