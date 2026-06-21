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

    /// Resolves a legacy flat category id to the new two-level catalog when
    /// mirroring writes into the domain store (same resolver the launch
    /// migration uses, so categories line up).
    private let resolveCategory: LegacyExpenseMigration.CategoryResolver

    public init(
        modelContext: ModelContext,
        resolveCategory: @escaping LegacyExpenseMigration.CategoryResolver = DefaultLegacyCategoryMapping.resolver()
    ) {
        self.modelContext = modelContext
        self.resolveCategory = resolveCategory
    }

    // MARK: - Fetch Operations

    public func fetchTransactions(filter: TransactionFilter? = nil) -> [Transaction] {
        // Push the scalar filters (type/category/date) and the sort into the
        // store via the FetchDescriptor, so SwiftData does the work instead of
        // fetching every row and filtering/sorting in memory. The relationship
        // (account) and substring (search) filters are applied to the smaller
        // result set afterwards.
        let filterByType = filter?.type != nil
        let typeRawValue = filter?.type?.rawValue ?? ""
        let filterByCategory = filter?.categoryId != nil
        let categoryValue = filter?.categoryId ?? ""
        let startDate = filter?.startDate ?? .distantPast
        let endDate = filter?.endDate ?? .distantFuture

        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { transaction in
                (!filterByType || transaction.typeRaw == typeRawValue)
                    && (!filterByCategory || transaction.categoryId == categoryValue)
                    && transaction.date >= startDate
                    && transaction.date <= endDate
            }
        )

        let order: SortOrder = (filter?.sortAscending ?? false) ? .forward : .reverse
        switch filter?.sortBy ?? .date {
        case .date:
            descriptor.sortBy = [SortDescriptor(\.date, order: order)]
        case .amount:
            descriptor.sortBy = [SortDescriptor(\.storedAmount, order: order)]
        }

        var results: [Transaction]
        do {
            results = try modelContext.fetch(descriptor)
        } catch {
            print("DataService: Failed to fetch transactions: \(error.localizedDescription)")
            return []
        }

        guard let filter = filter else { return results }

        if let searchText = filter.searchText, !searchText.isEmpty {
            let lowered = searchText.lowercased()
            results = results.filter { transaction in
                transaction.descriptionText.lowercased().contains(lowered)
                    || (transaction.merchant?.lowercased().contains(lowered) ?? false)
                    || (transaction.notes?.lowercased().contains(lowered) ?? false)
            }
        }

        if let accountId = filter.accountId {
            results = results.filter { $0.account?.id == accountId }
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
            defaultAccountId: nil
        )
        modelContext.insert(defaults)
        saveContext()
        return defaults
    }

    // MARK: - Transaction Operations

    public func addTransaction(_ transaction: Transaction) {
        modelContext.insert(transaction)
        mirror(transaction)
        saveContext()
    }

    public func updateTransaction(_ transaction: Transaction) {
        transaction.updatedAt = Date()
        mirror(transaction)
        saveContext()
    }

    public func deleteTransaction(_ transaction: Transaction) {
        removeMirror(id: transaction.id)
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
                removeMirror(id: t.id)
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
        account.updatedAt = Date()
        saveContext()
    }

    public func deleteAccount(_ account: Account) {
        let accounts = fetchAccounts()
        guard accounts.count > 1 else {
            print("DataService: Cannot delete the last account.")
            return
        }

        // Reassign orphaned transactions to another account before deletion
        let fallbackAccount = accounts.first { $0.id != account.id }
        let orphanedTransactions = account.transactions
        for transaction in orphanedTransactions {
            transaction.account = fallbackAccount
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

    // MARK: - Domain mirror (write-through)

    /// Upserts the `ExpenseTransactionRecord` mirroring `transaction`, keeping the
    /// new domain store current with legacy writes so repository-backed readers
    /// don't go stale between launches. The mirror shares the legacy id, so it
    /// stays consistent with (and idempotent against) the launch migration.
    private func mirror(_ transaction: Transaction) {
        let domain = LegacyExpenseMigration.migrate(transaction, resolveCategory: resolveCategory)
        if let existing = mirrorRecord(id: domain.id) {
            existing.update(from: domain)
        } else {
            modelContext.insert(ExpenseTransactionRecord(from: domain))
        }
    }

    /// Removes the mirroring domain record for a legacy transaction id, if present.
    private func removeMirror(id: UUID) {
        if let existing = mirrorRecord(id: id) {
            modelContext.delete(existing)
        }
    }

    private func mirrorRecord(id: UUID) -> ExpenseTransactionRecord? {
        let descriptor = FetchDescriptor<ExpenseTransactionRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
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
