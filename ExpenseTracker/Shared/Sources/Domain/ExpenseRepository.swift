import Foundation

/// A persistence boundary for the expense domain, expressed purely in terms of
/// the domain value types. The domain never depends on a concrete store: tests
/// (and SwiftUI previews) use the in-memory fake, while a future SwiftData /
/// CloudKit adapter would conform to this same protocol.
///
/// Defined at module scope because Swift protocols cannot be nested in a type;
/// the value types it traffics in live under `ExpenseDomain`.
public protocol ExpenseRepository {
    /// The current category/subcategory catalog.
    func catalog() throws -> ExpenseDomain.Catalog
    /// All known tags.
    func tags() throws -> [ExpenseDomain.Tag]
    /// All stored transactions.
    func transactions() throws -> [ExpenseDomain.Transaction]
    /// All learned category rules, most-reinforced first.
    func categoryRules() throws -> [ExpenseDomain.CategoryRule]

    /// Replaces the stored catalog wholesale.
    func saveCatalog(_ catalog: ExpenseDomain.Catalog) throws
    /// Inserts a tag, or updates the existing one with the same id.
    func saveTag(_ tag: ExpenseDomain.Tag) throws
    /// Stores a learned category rule, replacing any existing rule with the same
    /// normalised key (so relearning a merchant updates, never duplicates).
    func saveCategoryRule(_ rule: ExpenseDomain.CategoryRule) throws

    /// Validates and stores a new transaction.
    func addTransaction(_ transaction: ExpenseDomain.Transaction) throws
    /// Validates and replaces the transaction with the same id.
    func updateTransaction(_ transaction: ExpenseDomain.Transaction) throws
    /// Removes the transaction with the given id, if present.
    func deleteTransaction(id: UUID) throws
}

extension ExpenseRepository {
    /// Totals expense spend per top-level category over all stored transactions.
    public func totalSpendByCategory() throws -> [ExpenseDomain.Category: Decimal] {
        ExpenseDomain.totalSpendByCategory(try transactions())
    }
}
