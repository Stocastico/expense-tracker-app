import Foundation

extension ExpenseRepository {
    /// Installs the default Italian catalog and starter tags, but only when the
    /// store has no categories yet. Safe to call on every launch.
    ///
    /// - Returns: `true` if seeding occurred, `false` if the store was already
    ///   populated.
    @discardableResult
    public func seedDefaultsIfEmpty() throws -> Bool {
        guard try catalog().categories.isEmpty else { return false }

        try saveCatalog(DefaultExpenseCategories.catalog)
        for tag in DefaultExpenseCategories.tags {
            try saveTag(tag)
        }
        return true
    }
}
