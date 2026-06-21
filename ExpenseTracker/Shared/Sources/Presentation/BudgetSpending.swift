import Foundation

/// Totals a legacy `Budget`'s spend from the new domain transactions. Budgets
/// keep their flat-category id, so the id is mapped into the two-level catalog
/// via a `CategoryResolver` (the same one the migration/write-through use) before
/// matching expenses; money is summed as `Decimal`.
///
/// Lets the Budgets screen read spend through the repository while budgets
/// themselves remain on the legacy model.
public enum BudgetSpending {

    /// Sum of expenses in the budget's resolved category over its current period.
    /// Returns zero if the budget's category can't be mapped into the catalog.
    public static func spent(
        for budget: Budget,
        in transactions: [ExpenseDomain.Transaction],
        startOfMonth: Int,
        resolveCategory: LegacyExpenseMigration.CategoryResolver = DefaultLegacyCategoryMapping.resolver()
    ) -> Decimal {
        guard let categoryId = resolveCategory(budget.categoryId)?.category.id else { return 0 }
        let range = budget.currentPeriodRange(startOfMonth: startOfMonth)
        return transactions
            .filter {
                $0.type == .expense
                    && $0.category?.id == categoryId
                    && $0.date >= range.start
                    && $0.date <= range.end
            }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }
}
