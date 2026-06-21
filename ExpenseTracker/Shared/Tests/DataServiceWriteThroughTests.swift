import Testing
import Foundation
import SwiftData

/// The write-through bridge: every legacy `Transaction` mutation through
/// `DataService` keeps a matching `ExpenseTransactionRecord` (the SwiftData form
/// of the new domain) in sync, so repository-backed readers don't go stale
/// between launches. Mirrors share the legacy id, matching the launch
/// migration's idempotency.
@MainActor
struct DataServiceWriteThroughTests {

    private func makeService(_ build: (ModelContext) -> Void = { _ in }) throws -> DataService {
        let schema = Schema(
            [Transaction.self, Account.self, Budget.self, AppSettings.self, CategoryRule.self]
                + ExpenseSwiftDataSchema.models
        )
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        build(context)
        try context.save()
        return DataService(modelContext: context)
    }

    private func mirrors(_ service: DataService) throws -> [ExpenseTransactionRecord] {
        try service.modelContext.fetch(FetchDescriptor<ExpenseTransactionRecord>())
    }

    @Test("addTransaction mirrors a matching domain record (id, 2-dp Decimal, type)")
    func addMirrors() throws {
        let service = try makeService()
        let txn = Transaction(type: .expense, amount: 12.5, descriptionText: "Coffee")

        service.addTransaction(txn)

        let records = try mirrors(service)
        #expect(records.count == 1)
        #expect(records.first?.id == txn.id)
        #expect(records.first?.amount == Decimal(string: "12.5"))
        #expect(records.first?.typeRaw == TransactionType.expense.rawValue)
    }

    @Test("updateTransaction updates the existing mirror without duplicating it")
    func updateMirrors() throws {
        let service = try makeService()
        let txn = Transaction(type: .expense, amount: 10, descriptionText: "Before")
        service.addTransaction(txn)

        txn.descriptionText = "After"
        service.updateTransaction(txn)

        let records = try mirrors(service)
        #expect(records.count == 1)
        #expect(records.first?.descriptionText == "After")
    }

    @Test("deleteTransaction removes the mirror")
    func deleteRemovesMirror() throws {
        let service = try makeService()
        let txn = Transaction(type: .expense, amount: 5)
        service.addTransaction(txn)

        service.deleteTransaction(txn)

        #expect(try mirrors(service).isEmpty)
    }

    @Test("Mirroring an income transaction leaves it uncategorized")
    func incomeMirrorHasNoCategory() throws {
        let service = try makeService()
        let txn = Transaction(type: .income, amount: 100, descriptionText: "Salary", categoryId: "salary")

        service.addTransaction(txn)

        let record = try #require(try mirrors(service).first)
        #expect(record.categoryId == nil)
    }
}
