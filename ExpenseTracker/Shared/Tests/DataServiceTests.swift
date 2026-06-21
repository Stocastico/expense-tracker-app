import Testing
import Foundation
import SwiftData

/// Characterization tests for `DataService.fetchTransactions` filtering and
/// sorting. These pin the behaviour so the query can be pushed into the
/// `FetchDescriptor` (predicate + sort) without changing results.
@MainActor
struct DataServiceTests {

    private func makeService(_ build: (ModelContext) -> Void) throws -> DataService {
        let schema = Schema([Transaction.self, Account.self, Budget.self, AppSettings.self, CategoryRule.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        build(context)
        try context.save()
        return DataService(modelContext: context)
    }

    @Test("Without a filter, transactions come back newest-first")
    func newestFirstWithoutFilter() throws {
        let service = try makeService { context in
            context.insert(Transaction(amount: 1, date: Date(timeIntervalSince1970: 100)))
            context.insert(Transaction(amount: 2, date: Date(timeIntervalSince1970: 200)))
        }
        #expect(service.fetchTransactions().map(\.storedAmount) == [2, 1])
    }

    @Test("Filters by type")
    func filtersByType() throws {
        let service = try makeService { context in
            context.insert(Transaction(type: .income, amount: 10))
            context.insert(Transaction(type: .expense, amount: 20))
        }
        #expect(service.fetchTransactions(filter: .init(type: .income)).map(\.storedAmount) == [10])
    }

    @Test("Filters by category id")
    func filtersByCategory() throws {
        let service = try makeService { context in
            context.insert(Transaction(amount: 1, categoryId: "food"))
            context.insert(Transaction(amount: 2, categoryId: "rent"))
        }
        #expect(service.fetchTransactions(filter: .init(categoryId: "food")).map(\.storedAmount) == [1])
    }

    @Test("Filters by inclusive date range")
    func filtersByDateRange() throws {
        let d1 = Date(timeIntervalSince1970: 100)
        let d2 = Date(timeIntervalSince1970: 200)
        let d3 = Date(timeIntervalSince1970: 300)
        let service = try makeService { context in
            context.insert(Transaction(amount: 1, date: d1))
            context.insert(Transaction(amount: 2, date: d2))
            context.insert(Transaction(amount: 3, date: d3))
        }
        #expect(service.fetchTransactions(filter: .init(startDate: d2, endDate: d2)).map(\.storedAmount) == [2])
    }

    @Test("Filters by search text across description and merchant")
    func filtersBySearchText() throws {
        let service = try makeService { context in
            context.insert(Transaction(amount: 1, descriptionText: "Coffee at bar", merchant: "Cafe"))
            context.insert(Transaction(amount: 2, descriptionText: "Rent", merchant: "Landlord"))
        }
        #expect(service.fetchTransactions(filter: .init(searchText: "coffee")).map(\.storedAmount) == [1])
        #expect(service.fetchTransactions(filter: .init(searchText: "landlord")).map(\.storedAmount) == [2])
    }

    @Test("Filters by account")
    func filtersByAccount() throws {
        var accountId = UUID()
        let service = try makeService { context in
            let account = Account(name: "Personal")
            accountId = account.id
            context.insert(account)
            context.insert(Transaction(amount: 1, account: account))
            context.insert(Transaction(amount: 2))
        }
        #expect(service.fetchTransactions(filter: .init(accountId: accountId)).map(\.storedAmount) == [1])
    }

    @Test("Sorts by amount ascending and descending")
    func sortsByAmount() throws {
        let service = try makeService { context in
            context.insert(Transaction(amount: 30))
            context.insert(Transaction(amount: 10))
            context.insert(Transaction(amount: 20))
        }
        #expect(service.fetchTransactions(filter: .init(sortBy: .amount, sortAscending: true)).map(\.storedAmount) == [10, 20, 30])
        #expect(service.fetchTransactions(filter: .init(sortBy: .amount, sortAscending: false)).map(\.storedAmount) == [30, 20, 10])
    }

    @Test("Sorts by date ascending when requested")
    func sortsByDateAscending() throws {
        let service = try makeService { context in
            context.insert(Transaction(amount: 1, date: Date(timeIntervalSince1970: 100)))
            context.insert(Transaction(amount: 2, date: Date(timeIntervalSince1970: 200)))
        }
        #expect(service.fetchTransactions(filter: .init(sortAscending: true)).map(\.storedAmount) == [1, 2])
    }
}
