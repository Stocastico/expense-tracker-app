import Foundation

/// Converts legacy `Transaction` records into the pure `ExpenseDomain.Transaction`
/// value type. Money is rounded to a 2-dp `Decimal` at the boundary so the
/// binary floating-point noise carried by the legacy `Double` storage does not
/// leak into the new model (the P0 precision fix).
///
/// The legacy flat category id has no clean 1:1 mapping to the new two-level
/// catalog, so callers supply a `CategoryResolver`; unresolved expenses are left
/// uncategorized, and income is never categorized.
public enum LegacyExpenseMigration {

    /// Resolves a legacy flat category id to a domain category (and optional
    /// subcategory). Return `nil` to leave the transaction uncategorized.
    public typealias CategoryResolver =
        (_ legacyCategoryId: String) -> (category: ExpenseDomain.Category, subcategory: ExpenseDomain.Subcategory?)?

    /// Migrates a single legacy transaction.
    public static func migrate(
        _ legacy: Transaction,
        resolveCategory: CategoryResolver = { _ in nil }
    ) -> ExpenseDomain.Transaction {
        // Income lives off the category axis, so only resolve for expenses.
        let resolved = legacy.type == .expense ? resolveCategory(legacy.categoryId) : nil

        return ExpenseDomain.Transaction(
            id: legacy.id,
            amount: money(from: legacy.storedAmount),
            date: legacy.date,
            type: legacy.type,
            merchant: legacy.merchant,
            descriptionText: legacy.descriptionText,
            category: resolved?.category,
            subcategory: resolved?.subcategory,
            tags: Set(
                legacy.tags
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .map { ExpenseDomain.Tag(id: ExpenseDomain.StableID.make("tag:\($0)"), displayName: $0) }
            ),
            accountId: legacy.account?.id,
            note: legacy.notes ?? ""
        )
    }

    /// Migrates a list of legacy transactions.
    public static func migrate(
        _ legacy: [Transaction],
        resolveCategory: CategoryResolver = { _ in nil }
    ) -> [ExpenseDomain.Transaction] {
        legacy.map { migrate($0, resolveCategory: resolveCategory) }
    }

    /// Rounds a legacy `Double` amount to a 2-dp `Decimal` without carrying the
    /// `Double`'s binary representation error.
    static func money(from double: Double) -> Decimal {
        var source = Decimal(double)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 2, .plain)
        return rounded
    }
}
