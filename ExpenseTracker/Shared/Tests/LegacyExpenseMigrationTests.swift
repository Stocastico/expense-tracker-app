import Testing
import Foundation
import SwiftData

/// Drives the migration from legacy `Transaction` records (Double money, flat
/// String category, comma-separated tags) into `ExpenseDomain.Transaction`,
/// rounding money to a 2-dp `Decimal` at the boundary (the precision fix).
struct LegacyExpenseMigrationTests {

    @Test("Legacy Double amounts round to a 2-dp Decimal without float noise")
    func moneyRoundsToTwoDecimals() {
        #expect(LegacyExpenseMigration.money(from: 0.1 + 0.2) == Decimal(string: "0.30")!)
        #expect(LegacyExpenseMigration.money(from: 42.5) == Decimal(string: "42.50")!)
        #expect(LegacyExpenseMigration.money(from: 19.99) == Decimal(string: "19.99")!)
    }

    @Test("Core fields map across, money becomes Decimal, and the result validates")
    func migratesCoreFields() throws {
        let legacy = Transaction(
            type: .expense,
            amount: 12.5,
            descriptionText: "Coffee",
            merchant: "Bar Pepe",
            categoryId: "fuori-casa",
            tags: ["work", "reimbursable"],
            notes: "team lunch"
        )

        let migrated = LegacyExpenseMigration.migrate(legacy)

        #expect(migrated.id == legacy.id)
        #expect(migrated.amount == Decimal(string: "12.50")!)
        #expect(migrated.type == .expense)
        #expect(migrated.merchant == "Bar Pepe")
        #expect(migrated.descriptionText == "Coffee")
        #expect(migrated.note == "team lunch")
        #expect(migrated.accountId == nil)
        #expect(migrated.category == nil) // default resolver leaves it uncategorized
        #expect(Set(migrated.tags.map(\.displayName)) == ["work", "reimbursable"])
        try migrated.validate()
    }

    @Test("Income never receives an expense category, even if the resolver would")
    func incomeNeverGetsCategory() throws {
        let casa = ExpenseDomain.Category(displayName: "Casa")
        let legacy = Transaction(type: .income, amount: 2500, categoryId: "salary")

        let migrated = LegacyExpenseMigration.migrate(legacy) { _ in (casa, nil) }

        #expect(migrated.type == .income)
        #expect(migrated.category == nil)
        try migrated.validate()
    }

    @Test("The category resolver maps a legacy id to a category and subcategory")
    func appliesCategoryResolverForExpenses() throws {
        let casa = ExpenseDomain.Category(displayName: "Casa")
        let bollette = ExpenseDomain.Subcategory(displayName: "bollette", parentId: casa.id)
        let legacy = Transaction(type: .expense, amount: 80, categoryId: "utilities")

        let migrated = LegacyExpenseMigration.migrate(legacy) { id in
            id == "utilities" ? (casa, bollette) : nil
        }

        #expect(migrated.category == casa)
        #expect(migrated.subcategory == bollette)
        try migrated.validate()
    }

    @Test("Migrating a list preserves every transaction and they all validate")
    func migratesList() throws {
        let legacy = [
            Transaction(type: .expense, amount: 0.1, categoryId: "x"),
            Transaction(type: .expense, amount: 0.2, categoryId: "x"),
            Transaction(type: .income, amount: 1000, categoryId: "salary"),
        ]

        let migrated = LegacyExpenseMigration.migrate(legacy)

        #expect(migrated.count == 3)
        for txn in migrated { try txn.validate() }
        let expenseSum = migrated.filter { $0.type == .expense }.reduce(Decimal(0)) { $0 + $1.amount }
        #expect(expenseSum == Decimal(string: "0.30")!)
    }

    @Test("The owning account id carries across")
    @MainActor
    func migratesAccountId() throws {
        let container = try ModelContainer(
            for: Transaction.self, Account.self, Budget.self, AppSettings.self, CategoryRule.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let account = Account(name: "Personal")
        context.insert(account)
        let legacy = Transaction(type: .expense, amount: 5, categoryId: "x", account: account)
        context.insert(legacy)

        let migrated = LegacyExpenseMigration.migrate(legacy)

        #expect(migrated.accountId == account.id)
    }
}
