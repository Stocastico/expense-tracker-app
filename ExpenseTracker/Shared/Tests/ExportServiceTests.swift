import XCTest
import Foundation
import SwiftData
@testable import ExpenseTracker

final class ExportServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([Transaction.self, Account.self, Budget.self, AppSettings.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeAccount(name: String = "Test Account", isDefault: Bool = true) -> Account {
        let account = Account(name: name, icon: "💳", color: "#007AFF", isDefault: isDefault)
        context.insert(account)
        return account
    }

    private func makeTransaction(
        type: TransactionType = .expense,
        amount: Double = 42.50,
        description: String = "Test Transaction",
        categoryId: String = "food-dining",
        account: Account? = nil,
        date: Date = Date()
    ) -> Transaction {
        let transaction = Transaction(
            type: type,
            amount: amount,
            currency: "EUR",
            descriptionText: description,
            date: date,
            categoryId: categoryId,
            account: account
        )
        context.insert(transaction)
        return transaction
    }

    private func makeSettings() -> AppSettings {
        let settings = AppSettings(
            currency: "EUR",
            darkMode: false,
            startOfMonth: 1
        )
        context.insert(settings)
        return settings
    }

    // MARK: - CSV Export Tests

    func testCSVExportFormatHasHeaders() {
        let transactions: [Transaction] = []
        let csv = ExportService.exportToCSV(transactions: transactions, categories: DefaultCategories.all)

        let lines = csv.components(separatedBy: "\n")
        XCTAssertTrue(lines.count >= 1)

        let header = lines[0]
        XCTAssertTrue(header.contains("Date"))
        XCTAssertTrue(header.contains("Type"))
        XCTAssertTrue(header.contains("Amount"))
        XCTAssertTrue(header.contains("Currency"))
        XCTAssertTrue(header.contains("Category"))
        XCTAssertTrue(header.contains("Merchant"))
        XCTAssertTrue(header.contains("Description"))
        XCTAssertTrue(header.contains("Tags"))
        XCTAssertTrue(header.contains("Notes"))
        XCTAssertTrue(header.contains("Account"))
        XCTAssertTrue(header.contains("Recurring"))
    }

    func testCSVExportContainsCorrectNumberOfRows() throws {
        let account = makeAccount()
        let _ = makeTransaction(description: "Transaction 1", account: account)
        let _ = makeTransaction(description: "Transaction 2", account: account)
        let _ = makeTransaction(description: "Transaction 3", account: account)
        try context.save()

        let descriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(descriptor)

        let csv = ExportService.exportToCSV(transactions: transactions, categories: DefaultCategories.all)
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }

        // 1 header + 3 data rows
        XCTAssertEqual(lines.count, 4)
    }

    func testCSVExportEscapesCommasInFields() {
        let transaction = Transaction(
            type: .expense,
            amount: 100,
            currency: "EUR",
            descriptionText: "Item one, item two",
            date: Date(),
            categoryId: "shopping"
        )

        let csv = ExportService.exportToCSV(transactions: [transaction], categories: DefaultCategories.all)
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }

        XCTAssertEqual(lines.count, 2)

        // The description containing a comma should be quoted
        let dataLine = lines[1]
        XCTAssertTrue(dataLine.contains("\"Item one, item two\""))
    }

    func testCSVExportEscapesQuotesInFields() {
        let transaction = Transaction(
            type: .expense,
            amount: 50,
            currency: "EUR",
            descriptionText: "Book \"Swift Programming\"",
            date: Date(),
            categoryId: "education"
        )

        let csv = ExportService.exportToCSV(transactions: [transaction], categories: DefaultCategories.all)

        // Quotes should be doubled per CSV escaping rules
        XCTAssertTrue(csv.contains("\"\"Swift Programming\"\""))
    }

    func testCSVExportTransactionData() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        let date = dateFormatter.date(from: "2026-03-14")!

        let transaction = Transaction(
            type: .expense,
            amount: 42.50,
            currency: "EUR",
            descriptionText: "Coffee",
            merchant: "Starbucks",
            date: date,
            categoryId: "food-dining"
        )

        let csv = ExportService.exportToCSV(transactions: [transaction], categories: DefaultCategories.all)
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }

        XCTAssertEqual(lines.count, 2)
        let dataLine = lines[1]
        XCTAssertTrue(dataLine.contains("2026-03-14"))
        XCTAssertTrue(dataLine.contains("expense"))
        XCTAssertTrue(dataLine.contains("Coffee"))
        XCTAssertTrue(dataLine.contains("Starbucks"))
    }

    // MARK: - JSON Export Tests

    func testJSONExportContainsAllDataSections() throws {
        let account = makeAccount()
        let _ = makeTransaction(account: account)
        let budget = Budget(categoryId: "food-dining", amount: 500, currency: "EUR", period: .monthly)
        context.insert(budget)
        let settings = makeSettings()
        try context.save()

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let budgets = try context.fetch(FetchDescriptor<Budget>())
        let accounts = try context.fetch(FetchDescriptor<Account>())

        let jsonData = ExportService.exportToJSON(
            transactions: transactions,
            budgets: budgets,
            settings: settings,
            accounts: accounts
        )

        XCTAssertFalse(jsonData.isEmpty)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportData = try decoder.decode(ExportData.self, from: jsonData)

        XCTAssertEqual(exportData.version, "1.0")
        XCTAssertFalse(exportData.transactions.isEmpty)
        XCTAssertFalse(exportData.budgets.isEmpty)
        XCTAssertFalse(exportData.accounts.isEmpty)
        XCTAssertEqual(exportData.settings.currency, "EUR")
    }

    func testJSONExportTransactionFields() throws {
        let account = makeAccount(name: "Checking")
        let transaction = Transaction(
            type: .expense,
            amount: 99.99,
            currency: "USD",
            descriptionText: "Test purchase",
            merchant: "Test Store",
            date: Date(),
            categoryId: "shopping",
            account: account,
            tags: ["tag1", "tag2"],
            notes: "Test note"
        )
        context.insert(transaction)
        let settings = makeSettings()
        try context.save()

        let jsonData = ExportService.exportToJSON(
            transactions: [transaction],
            budgets: [],
            settings: settings,
            accounts: [account]
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportData = try decoder.decode(ExportData.self, from: jsonData)

        XCTAssertEqual(exportData.transactions.count, 1)
        let exported = exportData.transactions[0]
        XCTAssertEqual(exported.type, "expense")
        XCTAssertEqual(exported.amount, 99.99, accuracy: 0.01)
        XCTAssertEqual(exported.currency, "USD")
        XCTAssertEqual(exported.descriptionText, "Test purchase")
        XCTAssertEqual(exported.merchant, "Test Store")
        XCTAssertEqual(exported.categoryId, "shopping")
        XCTAssertEqual(exported.notes, "Test note")
    }

    // MARK: - JSON Roundtrip Tests

    func testJSONRoundtripExportThenImport() throws {
        // Create test data
        let account = makeAccount(name: "Main Account")
        let transaction1 = Transaction(
            type: .expense,
            amount: 42.50,
            currency: "EUR",
            descriptionText: "Coffee",
            merchant: "Starbucks",
            date: Date(),
            categoryId: "food-dining",
            account: account
        )
        let transaction2 = Transaction(
            type: .income,
            amount: 3000,
            currency: "EUR",
            descriptionText: "Salary",
            date: Date(),
            categoryId: "salary",
            account: account
        )
        context.insert(transaction1)
        context.insert(transaction2)

        let budget = Budget(categoryId: "food-dining", amount: 500, currency: "EUR", period: .monthly)
        context.insert(budget)

        let settings = makeSettings()
        settings.currency = "EUR"
        settings.darkMode = true
        settings.startOfMonth = 15

        try context.save()

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let budgets = try context.fetch(FetchDescriptor<Budget>())
        let accounts = try context.fetch(FetchDescriptor<Account>())

        // Export
        let jsonData = ExportService.exportToJSON(
            transactions: transactions,
            budgets: budgets,
            settings: settings,
            accounts: accounts
        )

        // Create a fresh context for import
        let importSchema = Schema([Transaction.self, Account.self, Budget.self, AppSettings.self])
        let importConfig = ModelConfiguration(isStoredInMemoryOnly: true)
        let importContainer = try ModelContainer(for: importSchema, configurations: [importConfig])
        let importContext = ModelContext(importContainer)

        // Import
        try ExportService.importFromJSON(jsonData, context: importContext)

        // Verify imported data
        let importedTransactions = try importContext.fetch(FetchDescriptor<Transaction>())
        let importedBudgets = try importContext.fetch(FetchDescriptor<Budget>())
        let importedAccounts = try importContext.fetch(FetchDescriptor<Account>())
        let importedSettings = try importContext.fetch(FetchDescriptor<AppSettings>())

        XCTAssertEqual(importedTransactions.count, 2)
        XCTAssertEqual(importedBudgets.count, 1)
        XCTAssertEqual(importedAccounts.count, 1)
        XCTAssertEqual(importedSettings.count, 1)

        // Verify transaction content matches
        let importedExpense = importedTransactions.first(where: { $0.typeRaw == "expense" })
        XCTAssertNotNil(importedExpense)
        XCTAssertEqual(importedExpense?.descriptionText, "Coffee")
        XCTAssertEqual(importedExpense?.storedAmount ?? 0, 42.50, accuracy: 0.01)

        let importedIncome = importedTransactions.first(where: { $0.typeRaw == "income" })
        XCTAssertNotNil(importedIncome)
        XCTAssertEqual(importedIncome?.descriptionText, "Salary")

        // Verify settings
        XCTAssertEqual(importedSettings[0].currency, "EUR")
        XCTAssertTrue(importedSettings[0].darkMode)
        XCTAssertEqual(importedSettings[0].startOfMonth, 15)

        // Verify budget
        XCTAssertEqual(importedBudgets[0].categoryId, "food-dining")
        XCTAssertEqual(importedBudgets[0].storedAmount, 500.0, accuracy: 0.01)
    }

    // MARK: - Edge Cases

    func testJSONExportEmptyData() throws {
        let settings = makeSettings()
        try context.save()

        let jsonData = ExportService.exportToJSON(
            transactions: [],
            budgets: [],
            settings: settings,
            accounts: []
        )

        XCTAssertFalse(jsonData.isEmpty)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportData = try decoder.decode(ExportData.self, from: jsonData)

        XCTAssertTrue(exportData.transactions.isEmpty)
        XCTAssertTrue(exportData.budgets.isEmpty)
        XCTAssertTrue(exportData.accounts.isEmpty)
    }

    func testCSVExportEmptyTransactions() {
        let csv = ExportService.exportToCSV(transactions: [], categories: DefaultCategories.all)
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }

        // Should have only the header line
        XCTAssertEqual(lines.count, 1)
        XCTAssertTrue(lines[0].contains("Date"))
    }
}
