import Testing
import Foundation
import SwiftData

/// Drives extending `ExpenseDomain.Transaction` with the fields the UI needs to
/// adopt the domain without losing data: a merchant, a human description
/// (distinct from `note`), and the owning account's id. Includes a SwiftData
/// round-trip so the persistence adapter carries them too.
@MainActor
struct ExpenseTransactionFieldsTests {

    @Test("New transaction fields default to empty")
    func newFieldsDefaultToEmpty() {
        let txn = ExpenseDomain.Transaction(amount: Decimal(string: "1.00")!, type: .expense)
        #expect(txn.merchant == nil)
        #expect(txn.descriptionText == "")
        #expect(txn.accountId == nil)
    }

    @Test("A transaction carries merchant, description and account id")
    func transactionCarriesNewFields() {
        let account = UUID()
        let txn = ExpenseDomain.Transaction(
            amount: Decimal(string: "10.00")!,
            type: .expense,
            merchant: "Mercadona",
            descriptionText: "weekly shop",
            accountId: account
        )
        #expect(txn.merchant == "Mercadona")
        #expect(txn.descriptionText == "weekly shop")
        #expect(txn.accountId == account)
    }

    @Test("Merchant, description and account id round-trip through SwiftData")
    func newFieldsRoundTripThroughSwiftData() throws {
        let schema = Schema(ExpenseSwiftDataSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repo = SwiftDataExpenseRepository(context: ModelContext(container))

        let account = UUID()
        let txn = ExpenseDomain.Transaction(
            amount: Decimal(string: "12.34")!,
            type: .expense,
            merchant: "Eroski",
            descriptionText: "groceries",
            accountId: account
        )
        try repo.addTransaction(txn)

        let loaded = try #require(try repo.transactions().first)
        #expect(loaded.merchant == "Eroski")
        #expect(loaded.descriptionText == "groceries")
        #expect(loaded.accountId == account)
    }
}
