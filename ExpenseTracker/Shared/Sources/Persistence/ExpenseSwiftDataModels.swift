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
    public var categoryId: UUID?
    public var categoryName: String?
    public var subcategoryId: UUID?
    public var subcategoryName: String?
    public var subcategoryParentId: UUID?
    public var note: String
    public var tags: [StoredExpenseTag]

    public init(
        id: UUID,
        amount: Decimal,
        date: Date,
        typeRaw: String,
        categoryId: UUID?,
        categoryName: String?,
        subcategoryId: UUID?,
        subcategoryName: String?,
        subcategoryParentId: UUID?,
        note: String,
        tags: [StoredExpenseTag]
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.typeRaw = typeRaw
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.subcategoryId = subcategoryId
        self.subcategoryName = subcategoryName
        self.subcategoryParentId = subcategoryParentId
        self.note = note
        self.tags = tags
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
