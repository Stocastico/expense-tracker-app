import Testing
import Foundation

/// Drives `BudgetSpending.spent`, which totals a legacy `Budget`'s spend from
/// domain `ExpenseDomain.Transaction`s — the budget's flat category id is mapped
/// into the two-level catalog via a resolver, and only expenses in that category
/// and the budget's current period are summed (as `Decimal`).
@MainActor
struct BudgetSpendingTests {

    private let food = ExpenseDomain.Category(displayName: "Cibo")

    private func resolver() -> LegacyExpenseMigration.CategoryResolver {
        { legacyId in legacyId == "food-dining" ? (category: food, subcategory: nil) : nil }
    }

    private func expense(_ amount: String, category: ExpenseDomain.Category?) -> ExpenseDomain.Transaction {
        ExpenseDomain.Transaction(amount: Decimal(string: amount)!, date: Date(), type: .expense, category: category)
    }

    @Test("spent sums expenses in the budget's resolved category for the period")
    func spentSumsResolvedCategory() {
        let budget = Budget(categoryId: "food-dining", amount: 200, period: .monthly)
        let other = ExpenseDomain.Category(displayName: "Casa")
        let txns = [
            expense("30", category: food),
            expense("70", category: food),
            expense("50", category: other),   // different category — excluded
            ExpenseDomain.Transaction(amount: 999, date: Date(), type: .income), // income — excluded
        ]
        let spent = BudgetSpending.spent(for: budget, in: txns, startOfMonth: 1, resolveCategory: resolver())
        #expect(spent == Decimal(string: "100"))
    }

    @Test("spent is zero when the budget's category can't be resolved")
    func spentZeroWhenUnresolved() {
        let budget = Budget(categoryId: "mystery", amount: 100, period: .monthly)
        let txns = [expense("40", category: food)]
        let spent = BudgetSpending.spent(for: budget, in: txns, startOfMonth: 1, resolveCategory: resolver())
        #expect(spent == 0)
    }
}
