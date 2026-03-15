import Foundation
import SwiftData

// MARK: - Transaction Filter

public struct TransactionFilter {
    public enum SortField {
        case date
        case amount
    }

    public var searchText: String?
    public var type: TransactionType?
    public var categoryId: String?
    public var accountId: UUID?
    public var startDate: Date?
    public var endDate: Date?
    public var sortBy: SortField
    public var sortAscending: Bool

    public init(
        searchText: String? = nil,
        type: TransactionType? = nil,
        categoryId: String? = nil,
        accountId: UUID? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        sortBy: SortField = .date,
        sortAscending: Bool = false
    ) {
        self.searchText = searchText
        self.type = type
        self.categoryId = categoryId
        self.accountId = accountId
        self.startDate = startDate
        self.endDate = endDate
        self.sortBy = sortBy
        self.sortAscending = sortAscending
    }
}

// MARK: - Data Service

@Observable
public class DataService {
    public var modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Fetch Operations

    public func fetchTransactions(filter: TransactionFilter? = nil) -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>()
        var results: [Transaction]

        do {
            results = try modelContext.fetch(descriptor)
        } catch {
            print("DataService: Failed to fetch transactions: \(error.localizedDescription)")
            return []
        }

        guard let filter = filter else {
            return results.sorted { $0.date > $1.date }
        }

        // Apply filters
        if let searchText = filter.searchText, !searchText.isEmpty {
            let lowered = searchText.lowercased()
            results = results.filter { transaction in
                transaction.descriptionText.lowercased().contains(lowered)
                    || (transaction.merchant?.lowercased().contains(lowered) ?? false)
                    || (transaction.notes?.lowercased().contains(lowered) ?? false)
            }
        }

        if let type = filter.type {
            results = results.filter { $0.transactionType == type }
        }

        if let categoryId = filter.categoryId {
            results = results.filter { $0.categoryId == categoryId }
        }

        if let accountId = filter.accountId {
            results = results.filter { $0.account?.id == accountId }
        }

        if let startDate = filter.startDate {
            results = results.filter { $0.date >= startDate }
        }

        if let endDate = filter.endDate {
            results = results.filter { $0.date <= endDate }
        }

        // Apply sorting
        switch filter.sortBy {
        case .date:
            results.sort { a, b in
                filter.sortAscending ? a.date < b.date : a.date > b.date
            }
        case .amount:
            results.sort { a, b in
                filter.sortAscending ? a.amount < b.amount : a.amount > b.amount
            }
        }

        return results
    }

    public func fetchAccounts() -> [Account] {
        let descriptor = FetchDescriptor<Account>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("DataService: Failed to fetch accounts: \(error.localizedDescription)")
            return []
        }
    }

    public func fetchBudgets() -> [Budget] {
        let descriptor = FetchDescriptor<Budget>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("DataService: Failed to fetch budgets: \(error.localizedDescription)")
            return []
        }
    }

    public func fetchSettings() -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        do {
            let allSettings = try modelContext.fetch(descriptor)
            if let existing = allSettings.first {
                return existing
            }
        } catch {
            print("DataService: Failed to fetch settings: \(error.localizedDescription)")
        }

        // Create default settings singleton
        let defaults = AppSettings(
            id: UUID(),
            currency: "USD",
            darkMode: false,
            startOfMonth: 1,
            defaultAccountId: nil,
            customCategoriesData: nil
        )
        modelContext.insert(defaults)
        saveContext()
        return defaults
    }

    // MARK: - Transaction Operations

    public func addTransaction(_ transaction: Transaction) {
        modelContext.insert(transaction)
        saveContext()
    }

    public func updateTransaction(_ transaction: Transaction) {
        transaction.updatedAt = Date()
        saveContext()
    }

    public func deleteTransaction(_ transaction: Transaction) {
        modelContext.delete(transaction)
        saveContext()
    }

    public func deleteTransactionAndRecurrences(_ transaction: Transaction) {
        let parentId = transaction.recurringParentId ?? transaction.id

        let descriptor = FetchDescriptor<Transaction>()
        do {
            let allTransactions = try modelContext.fetch(descriptor)
            let relatedTransactions = allTransactions.filter { t in
                t.id == parentId
                    || t.recurringParentId == parentId
            }
            for t in relatedTransactions {
                modelContext.delete(t)
            }
        } catch {
            print("DataService: Failed to fetch transactions for recurring deletion: \(error.localizedDescription)")
            // Fall back to deleting just this one
            modelContext.delete(transaction)
        }
        saveContext()
    }

    // MARK: - Account Operations

    public func addAccount(_ account: Account) {
        modelContext.insert(account)
        saveContext()
    }

    public func updateAccount(_ account: Account) {
        saveContext()
    }

    public func deleteAccount(_ account: Account) {
        let accounts = fetchAccounts()
        guard accounts.count > 1 else {
            print("DataService: Cannot delete the last account.")
            return
        }
        modelContext.delete(account)
        saveContext()
    }

    // MARK: - Budget Operations

    public func addBudget(_ budget: Budget) {
        modelContext.insert(budget)
        saveContext()
    }

    public func deleteBudget(_ budget: Budget) {
        modelContext.delete(budget)
        saveContext()
    }

    // MARK: - Settings Operations

    public func updateSettings(_ settings: AppSettings) {
        saveContext()
    }

    // MARK: - Private Helpers

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("DataService: Failed to save context: \(error.localizedDescription)")
        }
    }
}
