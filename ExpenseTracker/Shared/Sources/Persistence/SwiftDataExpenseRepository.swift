import Foundation
import SwiftData

/// A SwiftData-backed `ExpenseRepository`. This is the persistence adapter: it
/// owns a `ModelContext`, maps the domain value types to/from `@Model` records,
/// and is the seam where SwiftData (and, via mirroring, CloudKit) plugs in
/// without the domain layer knowing about either.
public final class SwiftDataExpenseRepository: ExpenseRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: Reads

    public func catalog() throws -> ExpenseDomain.Catalog {
        let categoryRecords = try context.fetch(
            FetchDescriptor<ExpenseCategoryRecord>(sortBy: [SortDescriptor(\.sortIndex)])
        )
        let subcategoryRecords = try context.fetch(
            FetchDescriptor<ExpenseSubcategoryRecord>(sortBy: [SortDescriptor(\.sortIndex)])
        )
        return ExpenseDomain.Catalog(
            categories: categoryRecords.map {
                ExpenseDomain.Category(id: $0.id, displayName: $0.displayName)
            },
            subcategories: subcategoryRecords.map {
                ExpenseDomain.Subcategory(id: $0.id, displayName: $0.displayName, parentId: $0.parentId)
            }
        )
    }

    public func tags() throws -> [ExpenseDomain.Tag] {
        let records = try context.fetch(
            FetchDescriptor<ExpenseTagRecord>(sortBy: [SortDescriptor(\.displayName)])
        )
        return records.map { ExpenseDomain.Tag(id: $0.id, displayName: $0.displayName) }
    }

    public func transactions() throws -> [ExpenseDomain.Transaction] {
        let records = try context.fetch(
            FetchDescriptor<ExpenseTransactionRecord>(sortBy: [SortDescriptor(\.date)])
        )
        return records.map { $0.toDomain() }
    }

    // MARK: Catalog & tags

    public func saveCatalog(_ catalog: ExpenseDomain.Catalog) throws {
        for record in try context.fetch(FetchDescriptor<ExpenseCategoryRecord>()) {
            context.delete(record)
        }
        for record in try context.fetch(FetchDescriptor<ExpenseSubcategoryRecord>()) {
            context.delete(record)
        }
        for (index, category) in catalog.categories.enumerated() {
            context.insert(ExpenseCategoryRecord(
                id: category.id, displayName: category.displayName, sortIndex: index
            ))
        }
        for (index, subcategory) in catalog.subcategories.enumerated() {
            context.insert(ExpenseSubcategoryRecord(
                id: subcategory.id,
                displayName: subcategory.displayName,
                parentId: subcategory.parentId,
                sortIndex: index
            ))
        }
        try context.save()
    }

    public func saveTag(_ tag: ExpenseDomain.Tag) throws {
        if let existing = try fetchTagRecord(id: tag.id) {
            existing.displayName = tag.displayName
        } else {
            context.insert(ExpenseTagRecord(id: tag.id, displayName: tag.displayName))
        }
        try context.save()
    }

    // MARK: Transactions

    public func addTransaction(_ transaction: ExpenseDomain.Transaction) throws {
        try transaction.validate()
        context.insert(ExpenseTransactionRecord(from: transaction))
        try context.save()
    }

    public func updateTransaction(_ transaction: ExpenseDomain.Transaction) throws {
        try transaction.validate()
        guard let record = try fetchTransactionRecord(id: transaction.id) else {
            throw ExpenseDomain.RepositoryError.transactionNotFound
        }
        record.update(from: transaction)
        try context.save()
    }

    public func deleteTransaction(id: UUID) throws {
        if let record = try fetchTransactionRecord(id: id) {
            context.delete(record)
            try context.save()
        }
    }

    // MARK: Helpers

    private func fetchTagRecord(id: UUID) throws -> ExpenseTagRecord? {
        var descriptor = FetchDescriptor<ExpenseTagRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchTransactionRecord(id: UUID) throws -> ExpenseTransactionRecord? {
        var descriptor = FetchDescriptor<ExpenseTransactionRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
