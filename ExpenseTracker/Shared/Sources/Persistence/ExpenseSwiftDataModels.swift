import Foundation
import SwiftData

// MARK: - Persistence layer for the ExpenseDomain
//
// These `@Model` record types are the SwiftData representation of the pure
// `ExpenseDomain` value types. The domain layer stays free of SwiftData; this
// layer is the adapter that maps between the two. The records mirror the value
// semantics of the domain (a transaction embeds its category/subcategory/tag
// values) so a transaction round-trips exactly without depending on the catalog.

/// A tag value embedded inside a transaction record.
public struct StoredExpenseTag: Codable, Hashable, Sendable {
    public var id: UUID
    public var displayName: String

    public init(id: UUID, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

@Model
public final class ExpenseCategoryRecord {
    @Attribute(.unique) public var id: UUID
    public var displayName: String
    /// Preserves the catalog's declared order across fetches.
    public var sortIndex: Int

    public init(id: UUID, displayName: String, sortIndex: Int) {
        self.id = id
        self.displayName = displayName
        self.sortIndex = sortIndex
    }
}

@Model
public final class ExpenseSubcategoryRecord {
    @Attribute(.unique) public var id: UUID
    public var displayName: String
    public var parentId: UUID
    public var sortIndex: Int

    public init(id: UUID, displayName: String, parentId: UUID, sortIndex: Int) {
        self.id = id
        self.displayName = displayName
        self.parentId = parentId
        self.sortIndex = sortIndex
    }
}

@Model
public final class ExpenseTagRecord {
    @Attribute(.unique) public var id: UUID
    public var displayName: String

    public init(id: UUID, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

@Model
public final class ExpenseTransactionRecord {
    @Attribute(.unique) public var id: UUID
    /// Stored as `Decimal` (never `Double`) to preserve money precision.
    public var amount: Decimal
    public var date: Date
    public var typeRaw: String
    public var merchant: String?
    public var descriptionText: String
    public var categoryId: UUID?
    public var categoryName: String?
    public var subcategoryId: UUID?
    public var subcategoryName: String?
    public var subcategoryParentId: UUID?
    public var accountId: UUID?
    public var note: String
    public var tags: [StoredExpenseTag]
    /// Recurring schedule: a non-nil frequency marks a recurring template.
    public var recurringFrequencyRaw: String?
    public var recurringEndDate: Date?
    /// Set on a generated occurrence, pointing back to its template.
    public var recurringParentId: UUID?
    /// Attached receipt/invoice image, stored outside the main store.
    @Attribute(.externalStorage) public var receiptData: Data?

    public init(
        id: UUID,
        amount: Decimal,
        date: Date,
        typeRaw: String,
        merchant: String?,
        descriptionText: String,
        categoryId: UUID?,
        categoryName: String?,
        subcategoryId: UUID?,
        subcategoryName: String?,
        subcategoryParentId: UUID?,
        accountId: UUID?,
        note: String,
        tags: [StoredExpenseTag],
        recurringFrequencyRaw: String? = nil,
        recurringEndDate: Date? = nil,
        recurringParentId: UUID? = nil,
        receiptData: Data? = nil
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.typeRaw = typeRaw
        self.merchant = merchant
        self.descriptionText = descriptionText
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.subcategoryId = subcategoryId
        self.subcategoryName = subcategoryName
        self.subcategoryParentId = subcategoryParentId
        self.accountId = accountId
        self.note = note
        self.tags = tags
        self.recurringFrequencyRaw = recurringFrequencyRaw
        self.recurringEndDate = recurringEndDate
        self.recurringParentId = recurringParentId
        self.receiptData = receiptData
    }
}

/// The model types making up the expense persistence schema. Use this to build
/// a `ModelContainer` (and to keep these records separate from the app's
/// existing `Transaction`/`Account`/… schema).
public enum ExpenseSwiftDataSchema {
    public static let models: [any PersistentModel.Type] = [
        ExpenseCategoryRecord.self,
        ExpenseSubcategoryRecord.self,
        ExpenseTagRecord.self,
        ExpenseTransactionRecord.self,
    ]
}
