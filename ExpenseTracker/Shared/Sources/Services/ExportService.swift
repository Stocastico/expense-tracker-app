import Foundation
import SwiftData

// MARK: - Export Data Structures

public struct ExportData: Codable {
    public let transactions: [ExportTransaction]
    public let budgets: [ExportBudget]
    public let accounts: [ExportAccount]
    public let settings: ExportSettings
}

public struct ExportTransaction: Codable {
    let id: String
    let type: String
    let amount: Double
    let currency: String
    let description: String
    let merchant: String?
    let date: String
    let categoryId: String
    let accountName: String?
    let tags: [String]
    let notes: String?
    let isRecurring: Bool
    let recurringFrequency: String?
}

public struct ExportBudget: Codable {
    let id: String
    let categoryId: String
    let amount: Double
    let currency: String
    let period: String
}

public struct ExportAccount: Codable {
    let id: String
    let name: String
    let icon: String
    let color: String
    let isDefault: Bool
}

public struct ExportSettings: Codable {
    let currency: String
    let darkMode: Bool
    let startOfMonth: Int
}

// MARK: - Electron Import Structures

private struct ElectronExportData: Codable {
    let transactions: [ElectronTransaction]?
    let accounts: [ElectronAccount]?
    let budgets: [ElectronBudget]?
    let settings: ElectronSettings?
    let categories: [ElectronCategory]?
}

private struct ElectronTransaction: Codable {
    let id: String?
    let type: String?
    let amount: Double?
    let currency: String?
    let description: String?
    let merchant: String?
    let date: String?
    let category: String?
    let categoryId: String?
    let account: String?
    let accountId: String?
    let tags: [String]?
    let notes: String?
    let isRecurring: Bool?
    let recurringFrequency: String?
}

private struct ElectronAccount: Codable {
    let id: String?
    let name: String?
    let icon: String?
    let color: String?
    let isDefault: Bool?
}

private struct ElectronBudget: Codable {
    let id: String?
    let category: String?
    let categoryId: String?
    let amount: Double?
    let currency: String?
    let period: String?
}

private struct ElectronSettings: Codable {
    let currency: String?
    let darkMode: Bool?
    let startOfMonth: Int?
    let categories: [ElectronCategory]?
}

private struct ElectronCategory: Codable {
    let id: String?
    let name: String?
    let icon: String?
    let color: String?
    let type: String?
}

// MARK: - Export Service

public struct ExportService {

    // MARK: - CSV Export

    /// Exports transactions to CSV format with proper escaping.
    /// Headers: Date,Type,Amount,Currency,Category,Merchant,Description,Tags,Notes,Account,Recurring
    /// Dates use ISO8601 format.
    public static func exportToCSV(transactions: [Transaction], categories: [Category]) -> String {
        var csv = "Date,Type,Amount,Currency,Category,Merchant,Description,Tags,Notes,Account,Recurring\n"

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })

        for transaction in transactions {
            let dateStr = isoFormatter.string(from: transaction.date)
            let typeStr = transaction.typeRaw
            let amountStr = String(format: "%.2f", transaction.storedAmount)
            let currencyStr = csvEscape(transaction.currency)
            let categoryName = csvEscape(categoryMap[transaction.categoryId] ?? transaction.categoryId)
            let merchantStr = csvEscape(transaction.merchant ?? "")
            let descriptionStr = csvEscape(transaction.descriptionText)
            let tagsStr = csvEscape(transaction.tags.joined(separator: ";"))
            let notesStr = csvEscape(transaction.notes ?? "")
            let accountStr = csvEscape(transaction.account?.name ?? "")
            let recurringStr = transaction.isRecurring ? "Yes" : "No"

            csv += "\(dateStr),\(typeStr),\(amountStr),\(currencyStr),\(categoryName),\(merchantStr),\(descriptionStr),\(tagsStr),\(notesStr),\(accountStr),\(recurringStr)\n"
        }

        return csv
    }

    // MARK: - JSON Export (Full Backup)

    /// Exports all data to JSON format for backup purposes.
    public static func exportToJSON(
        transactions: [Transaction],
        budgets: [Budget],
        settings: AppSettings,
        accounts: [Account]
    ) -> Data? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        let exportTransactions = transactions.map { t in
            ExportTransaction(
                id: t.id.uuidString,
                type: t.typeRaw,
                amount: t.storedAmount,
                currency: t.currency,
                description: t.descriptionText,
                merchant: t.merchant,
                date: isoFormatter.string(from: t.date),
                categoryId: t.categoryId,
                accountName: t.account?.name,
                tags: t.tags,
                notes: t.notes,
                isRecurring: t.isRecurring,
                recurringFrequency: t.recurringFrequencyRaw
            )
        }

        let exportBudgets = budgets.map { b in
            ExportBudget(
                id: b.id.uuidString,
                categoryId: b.categoryId,
                amount: b.storedAmount,
                currency: b.currency,
                period: b.periodRaw
            )
        }

        let exportAccounts = accounts.map { a in
            ExportAccount(
                id: a.id.uuidString,
                name: a.name,
                icon: a.icon,
                color: a.color,
                isDefault: a.isDefault
            )
        }

        let exportSettings = ExportSettings(
            currency: settings.currency,
            darkMode: settings.darkMode,
            startOfMonth: settings.startOfMonth
        )

        let exportData = ExportData(
            transactions: exportTransactions,
            budgets: exportBudgets,
            accounts: exportAccounts,
            settings: exportSettings
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            return try encoder.encode(exportData)
        } catch {
            print("ExportService: Failed to encode export data: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - JSON Import

    /// Imports data from a JSON backup, creating SwiftData objects and inserting them into the context.
    public static func importFromJSON(_ data: Data, context: ModelContext) throws {
        let decoder = JSONDecoder()

        let exportData: ExportData
        do {
            exportData = try decoder.decode(ExportData.self, from: data)
        } catch {
            throw ImportError.decodingFailed(error.localizedDescription)
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        // Create accounts first so transactions can reference them
        var accountMap: [String: Account] = [:]

        for ea in exportData.accounts {
            let account = Account(
                id: UUID(uuidString: ea.id) ?? UUID(),
                name: ea.name,
                icon: ea.icon,
                color: ea.color,
                isDefault: ea.isDefault
            )
            context.insert(account)
            accountMap[ea.name] = account
        }

        // Create transactions
        for et in exportData.transactions {
            let transactionDate = isoFormatter.date(from: et.date) ?? Date()
            let account = et.accountName.flatMap { accountMap[$0] }

            let transactionType = TransactionType(rawValue: et.type) ?? .expense
            let recurringFreq: RecurringFrequency? = et.recurringFrequency.flatMap { RecurringFrequency(rawValue: $0) }

            let transaction = Transaction(
                id: UUID(uuidString: et.id) ?? UUID(),
                type: transactionType,
                amount: et.amount,
                currency: et.currency,
                descriptionText: et.description,
                merchant: et.merchant,
                date: transactionDate,
                categoryId: et.categoryId,
                account: account,
                tags: et.tags,
                notes: et.notes,
                isRecurring: et.isRecurring,
                recurringFrequency: recurringFreq
            )
            context.insert(transaction)
        }

        // Create budgets
        for eb in exportData.budgets {
            let budgetPeriod = BudgetPeriod(rawValue: eb.period) ?? .monthly
            let budget = Budget(
                id: UUID(uuidString: eb.id) ?? UUID(),
                categoryId: eb.categoryId,
                amount: eb.amount,
                currency: eb.currency,
                period: budgetPeriod
            )
            context.insert(budget)
        }

        // Update or create settings
        let settingsDescriptor = FetchDescriptor<AppSettings>()
        let existingSettings = try? context.fetch(settingsDescriptor)

        if let existing = existingSettings?.first {
            existing.currency = exportData.settings.currency
            existing.darkMode = exportData.settings.darkMode
            existing.startOfMonth = exportData.settings.startOfMonth
        } else {
            let settings = AppSettings(
                currency: exportData.settings.currency,
                darkMode: exportData.settings.darkMode,
                startOfMonth: exportData.settings.startOfMonth
            )
            context.insert(settings)
        }

        try context.save()
    }

    // MARK: - Electron JSON Import

    /// Imports data from the old Electron app JSON format, handling differences in field naming
    /// (e.g., `description` instead of `descriptionText`, `accountId` as string, categories array in settings).
    public static func importFromElectronJSON(_ data: Data, context: ModelContext) throws {
        let decoder = JSONDecoder()

        let electronData: ElectronExportData
        do {
            electronData = try decoder.decode(ElectronExportData.self, from: data)
        } catch {
            throw ImportError.decodingFailed(error.localizedDescription)
        }

        // Build account map from Electron data
        var accountMap: [String: Account] = [:]

        if let electronAccounts = electronData.accounts {
            for ea in electronAccounts {
                let name = ea.name ?? "Imported Account"
                let account = Account(
                    name: name,
                    icon: ea.icon ?? "\u{1F4B3}",
                    color: ea.color ?? "#007AFF",
                    isDefault: ea.isDefault ?? false
                )
                context.insert(account)

                if let electronId = ea.id {
                    accountMap[electronId] = account
                }
                accountMap[name] = account
            }
        }

        // Ensure at least one account exists
        if accountMap.isEmpty {
            let defaultAccount = Account(
                name: "Main Account",
                icon: "\u{1F4B3}",
                color: "#007AFF",
                isDefault: true
            )
            context.insert(defaultAccount)
            accountMap["default"] = defaultAccount
        }

        // Date parsing helpers
        let isoFormatter = ISO8601DateFormatter()
        let fallbackFormatter = DateFormatter()
        fallbackFormatter.locale = Locale(identifier: "en_US_POSIX")
        let fallbackFormats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "dd/MM/yyyy",
        ]

        // Import transactions
        if let electronTransactions = electronData.transactions {
            for et in electronTransactions {
                // Parse date
                var transactionDate = Date()
                if let dateString = et.date {
                    if let parsed = isoFormatter.date(from: dateString) {
                        transactionDate = parsed
                    } else {
                        for format in fallbackFormats {
                            fallbackFormatter.dateFormat = format
                            if let parsed = fallbackFormatter.date(from: dateString) {
                                transactionDate = parsed
                                break
                            }
                        }
                    }
                }

                // Resolve category
                let categoryId = resolveCategoryId(
                    electronCategoryId: et.categoryId,
                    electronCategoryName: et.category
                )

                // Resolve account
                var account: Account?
                if let accountId = et.accountId, let found = accountMap[accountId] {
                    account = found
                } else if let accountName = et.account, let found = accountMap[accountName] {
                    account = found
                } else {
                    account = accountMap.values.first
                }

                // Map type
                let transactionType = mapElectronType(et.type)
                let recurringFreq: RecurringFrequency? = et.recurringFrequency.flatMap { RecurringFrequency(rawValue: $0) }

                let transaction = Transaction(
                    type: transactionType,
                    amount: et.amount ?? 0,
                    currency: et.currency ?? electronData.settings?.currency ?? "USD",
                    descriptionText: et.description ?? "",
                    merchant: et.merchant,
                    date: transactionDate,
                    categoryId: categoryId,
                    account: account,
                    tags: et.tags ?? [],
                    notes: et.notes,
                    isRecurring: et.isRecurring ?? false,
                    recurringFrequency: recurringFreq
                )
                context.insert(transaction)
            }
        }

        // Import budgets
        if let electronBudgets = electronData.budgets {
            for eb in electronBudgets {
                let categoryId = resolveCategoryId(
                    electronCategoryId: eb.categoryId,
                    electronCategoryName: eb.category
                )
                let budgetPeriod = BudgetPeriod(rawValue: eb.period ?? "monthly") ?? .monthly

                let budget = Budget(
                    categoryId: categoryId,
                    amount: eb.amount ?? 0,
                    currency: eb.currency ?? electronData.settings?.currency ?? "USD",
                    period: budgetPeriod
                )
                context.insert(budget)
            }
        }

        // Import settings
        if let es = electronData.settings {
            let settingsDescriptor = FetchDescriptor<AppSettings>()
            let existingSettings = try? context.fetch(settingsDescriptor)

            if let existing = existingSettings?.first {
                existing.currency = es.currency ?? existing.currency
                existing.darkMode = es.darkMode ?? existing.darkMode
                existing.startOfMonth = es.startOfMonth ?? existing.startOfMonth
            } else {
                let settings = AppSettings(
                    currency: es.currency ?? "USD",
                    darkMode: es.darkMode ?? false,
                    startOfMonth: es.startOfMonth ?? 1
                )
                context.insert(settings)
            }
        }

        try context.save()
    }

    // MARK: - Errors

    public enum ImportError: Error, LocalizedError {
        case decodingFailed(String)
        case invalidData

        public var errorDescription: String? {
            switch self {
            case .decodingFailed(let message):
                return "Failed to decode import data: \(message)"
            case .invalidData:
                return "The provided data is not valid for import."
            }
        }
    }

    // MARK: - Private Helpers

    private static func csvEscape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }

    private static func resolveCategoryId(electronCategoryId: String?, electronCategoryName: String?) -> String {
        // Try direct ID match
        if let categoryId = electronCategoryId {
            let found = DefaultCategories.all.category(withId: categoryId)
            if found != nil {
                return categoryId
            }
        }

        // Try matching by name
        if let name = electronCategoryName ?? electronCategoryId {
            let lowerName = name.lowercased()
            for category in DefaultCategories.all {
                if category.name.lowercased() == lowerName || category.id.lowercased() == lowerName {
                    return category.id
                }
            }

            // Fuzzy match: check if the name contains a category name or vice versa
            for category in DefaultCategories.all {
                if lowerName.contains(category.name.lowercased()) || category.name.lowercased().contains(lowerName) {
                    return category.id
                }
            }
        }

        return "other"
    }

    private static func mapElectronType(_ type: String?) -> TransactionType {
        guard let type = type?.lowercased() else { return .expense }
        switch type {
        case "income", "earning", "credit":
            return .income
        default:
            return .expense
        }
    }
}
