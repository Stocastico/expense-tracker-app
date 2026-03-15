import XCTest
import Foundation
import SwiftData
@testable import ExpenseTracker

final class ModelTests: XCTestCase {

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

    // MARK: - Transaction Tests

    func testTransactionCreationWithAllFields() throws {
        let id = UUID()
        let date = Date()
        let parentId = UUID()
        let receiptData = "receipt".data(using: .utf8)

        let transaction = Transaction(
            id: id,
            type: .expense,
            amount: 42.50,
            currency: "EUR",
            descriptionText: "Coffee at Starbucks",
            merchant: "Starbucks",
            date: date,
            categoryId: "food-dining",
            account: nil,
            tags: ["morning", "coffee"],
            notes: "Good latte",
            isRecurring: true,
            recurringFrequency: .weekly,
            recurringEndDate: date.addingTimeInterval(86400 * 30),
            recurringParentId: parentId,
            receiptData: receiptData
        )

        context.insert(transaction)
        try context.save()

        let descriptor = FetchDescriptor<Transaction>()
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)

        let t = fetched[0]
        XCTAssertEqual(t.id, id)
        XCTAssertEqual(t.type, .expense)
        XCTAssertEqual(t.storedAmount, 42.50)
        XCTAssertEqual(t.currency, "EUR")
        XCTAssertEqual(t.descriptionText, "Coffee at Starbucks")
        XCTAssertEqual(t.merchant, "Starbucks")
        XCTAssertEqual(t.date, date)
        XCTAssertEqual(t.categoryId, "food-dining")
        XCTAssertEqual(t.tags, ["morning", "coffee"])
        XCTAssertEqual(t.notes, "Good latte")
        XCTAssertTrue(t.isRecurring)
        XCTAssertEqual(t.recurringFrequency, .weekly)
        XCTAssertNotNil(t.recurringEndDate)
        XCTAssertEqual(t.recurringParentId, parentId)
        XCTAssertEqual(t.receiptData, receiptData)
    }

    func testTransactionTypeComputedProperty() {
        let transaction = Transaction(type: .income, amount: 100, descriptionText: "Salary")
        XCTAssertEqual(transaction.type, .income)
        XCTAssertEqual(transaction.typeRaw, "income")

        transaction.type = .expense
        XCTAssertEqual(transaction.type, .expense)
        XCTAssertEqual(transaction.typeRaw, "expense")
    }

    func testTransactionTagsComputedProperty() {
        let transaction = Transaction(descriptionText: "Test", tags: ["a", "b", "c"])
        XCTAssertEqual(transaction.tags, ["a", "b", "c"])
        XCTAssertEqual(transaction.tagsString, "a,b,c")

        transaction.tags = ["x", "y"]
        XCTAssertEqual(transaction.tagsString, "x,y")
        XCTAssertEqual(transaction.tags, ["x", "y"])
    }

    func testTransactionEmptyTags() {
        let transaction = Transaction(descriptionText: "Test", tags: [])
        XCTAssertTrue(transaction.tags.isEmpty)
        XCTAssertEqual(transaction.tagsString, "")
    }

    func testTransactionSignedAmount() {
        let expense = Transaction(type: .expense, amount: 50.0, descriptionText: "Food")
        XCTAssertEqual(expense.signedAmount, -50.0)

        let income = Transaction(type: .income, amount: 100.0, descriptionText: "Salary")
        XCTAssertEqual(income.signedAmount, 100.0)
    }

    func testTransactionRecurringFrequencyComputedProperty() {
        let transaction = Transaction(
            descriptionText: "Rent",
            isRecurring: true,
            recurringFrequency: .monthly
        )
        XCTAssertEqual(transaction.recurringFrequency, .monthly)
        XCTAssertEqual(transaction.recurringFrequencyRaw, "monthly")

        transaction.recurringFrequency = .yearly
        XCTAssertEqual(transaction.recurringFrequencyRaw, "yearly")

        transaction.recurringFrequency = nil
        XCTAssertNil(transaction.recurringFrequencyRaw)
    }

    // MARK: - Account Tests

    func testAccountCreationAndDefaults() throws {
        let account = Account(name: "Checking")

        XCTAssertEqual(account.name, "Checking")
        XCTAssertEqual(account.icon, "💳")
        XCTAssertEqual(account.color, "#007AFF")
        XCTAssertFalse(account.isDefault)
        XCTAssertTrue(account.transactions.isEmpty)

        context.insert(account)
        try context.save()

        let descriptor = FetchDescriptor<Account>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].name, "Checking")
    }

    func testAccountDisplayName() {
        let account = Account(name: "Savings", icon: "🐷")
        XCTAssertEqual(account.displayName, "🐷 Savings")
    }

    func testAccountBalance() throws {
        let account = Account(name: "Test", isDefault: true)
        context.insert(account)

        let income = Transaction(type: .income, amount: 1000, descriptionText: "Salary", account: account)
        let expense1 = Transaction(type: .expense, amount: 200, descriptionText: "Groceries", account: account)
        let expense2 = Transaction(type: .expense, amount: 100, descriptionText: "Gas", account: account)

        context.insert(income)
        context.insert(expense1)
        context.insert(expense2)
        try context.save()

        XCTAssertEqual(account.balance, 700.0, accuracy: 0.01)
    }

    func testAccountIsDefault() {
        let defaultAccount = Account(name: "Main", isDefault: true)
        let secondaryAccount = Account(name: "Secondary", isDefault: false)

        XCTAssertTrue(defaultAccount.isDefault)
        XCTAssertFalse(secondaryAccount.isDefault)
    }

    // MARK: - Budget Tests

    func testBudgetCreationAndPeriodComputed() throws {
        let budget = Budget(categoryId: "food-dining", amount: 500.0, currency: "USD", period: .monthly)

        XCTAssertEqual(budget.categoryId, "food-dining")
        XCTAssertEqual(budget.storedAmount, 500.0)
        XCTAssertEqual(budget.currency, "USD")
        XCTAssertEqual(budget.period, .monthly)
        XCTAssertEqual(budget.periodRaw, "monthly")

        context.insert(budget)
        try context.save()

        let descriptor = FetchDescriptor<Budget>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].period, .monthly)
    }

    func testBudgetPeriodComputedPropertySetter() {
        let budget = Budget(categoryId: "transport", amount: 200.0, period: .monthly)
        XCTAssertEqual(budget.period, .monthly)

        budget.period = .yearly
        XCTAssertEqual(budget.periodRaw, "yearly")
        XCTAssertEqual(budget.period, .yearly)
    }

    func testBudgetAmountDecimalPrecision() {
        let budget = Budget(categoryId: "groceries", amount: 123.45)
        let decimal = budget.amount
        XCTAssertEqual(NSDecimalNumber(decimal: decimal).doubleValue, 123.45, accuracy: 0.001)
    }

    // MARK: - TransactionType Enum Tests

    func testTransactionTypeRawValueRoundtrip() {
        for type in TransactionType.allCases {
            let raw = type.rawValue
            let restored = TransactionType(rawValue: raw)
            XCTAssertEqual(restored, type, "Roundtrip failed for \(type)")
        }
    }

    func testTransactionTypeDisplayName() {
        XCTAssertEqual(TransactionType.expense.displayName, "Expense")
        XCTAssertEqual(TransactionType.income.displayName, "Income")
    }

    func testTransactionTypeRawValues() {
        XCTAssertEqual(TransactionType.expense.rawValue, "expense")
        XCTAssertEqual(TransactionType.income.rawValue, "income")
    }

    // MARK: - RecurringFrequency Tests

    func testRecurringFrequencyNextDateDaily() {
        let calendar = Calendar.current
        let startDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 14))!
        let next = RecurringFrequency.daily.nextDate(from: startDate)
        let expected = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))!
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: next),
                       calendar.dateComponents([.year, .month, .day], from: expected))
    }

    func testRecurringFrequencyNextDateWeekly() {
        let calendar = Calendar.current
        let startDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 14))!
        let next = RecurringFrequency.weekly.nextDate(from: startDate)
        let expected = calendar.date(from: DateComponents(year: 2026, month: 3, day: 21))!
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: next),
                       calendar.dateComponents([.year, .month, .day], from: expected))
    }

    func testRecurringFrequencyNextDateMonthly() {
        let calendar = Calendar.current
        let startDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 31))!
        let next = RecurringFrequency.monthly.nextDate(from: startDate)
        // Adding 1 month from Jan 31 should give Feb 28 (2026 is not a leap year)
        let components = calendar.dateComponents([.year, .month, .day], from: next)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 2)
        // February 28 in a non-leap year
        XCTAssertEqual(components.day, 28)
    }

    func testRecurringFrequencyNextDateYearly() {
        let calendar = Calendar.current
        let startDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 14))!
        let next = RecurringFrequency.yearly.nextDate(from: startDate)
        let expected = calendar.date(from: DateComponents(year: 2027, month: 3, day: 14))!
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: next),
                       calendar.dateComponents([.year, .month, .day], from: expected))
    }

    func testRecurringFrequencyRawValueRoundtrip() {
        for freq in RecurringFrequency.allCases {
            let raw = freq.rawValue
            let restored = RecurringFrequency(rawValue: raw)
            XCTAssertEqual(restored, freq, "Roundtrip failed for \(freq)")
        }
    }

    // MARK: - Category Codable Tests

    func testCategoryCodableEncodeDecode() throws {
        let category = Category(
            id: "test-cat",
            name: "Test Category",
            icon: "🧪",
            color: "#FF0000",
            type: .expense,
            keywords: ["test", "sample"],
            isCustom: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(category)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Category.self, from: data)

        XCTAssertEqual(decoded.id, "test-cat")
        XCTAssertEqual(decoded.name, "Test Category")
        XCTAssertEqual(decoded.icon, "🧪")
        XCTAssertEqual(decoded.color, "#FF0000")
        XCTAssertEqual(decoded.type, .expense)
        XCTAssertEqual(decoded.keywords, ["test", "sample"])
        XCTAssertTrue(decoded.isCustom)
    }

    func testCategoryCodableArray() throws {
        let categories = [
            Category(id: "a", name: "A", icon: "1", color: "#111", type: .expense),
            Category(id: "b", name: "B", icon: "2", color: "#222", type: .income),
            Category(id: "c", name: "C", icon: "3", color: "#333", type: .both),
        ]

        let data = try JSONEncoder().encode(categories)
        let decoded = try JSONDecoder().decode([Category].self, from: data)

        XCTAssertEqual(decoded.count, 3)
        XCTAssertEqual(decoded[0].id, "a")
        XCTAssertEqual(decoded[1].type, .income)
        XCTAssertEqual(decoded[2].type, .both)
    }

    func testCategoryMatchesText() {
        let category = Category(
            id: "food",
            name: "Food",
            icon: "🍕",
            color: "#FF0000",
            type: .expense,
            keywords: ["restaurant", "pizza"]
        )

        XCTAssertTrue(category.matchesText("Pizza Hut dinner"))
        XCTAssertTrue(category.matchesText("RESTAURANT CHARGE"))
        XCTAssertFalse(category.matchesText("Gas station"))
    }

    // MARK: - AppSettings Tests

    @MainActor
    func testAppSettingsSingletonPattern() throws {
        // First call creates a new AppSettings
        let settings1 = AppSettings.shared(in: context)
        XCTAssertEqual(settings1.currency, "EUR")

        // Second call returns the same instance
        let settings2 = AppSettings.shared(in: context)
        XCTAssertEqual(settings1.id, settings2.id)

        // Modify and verify it persists
        settings1.currency = "USD"
        let settings3 = AppSettings.shared(in: context)
        XCTAssertEqual(settings3.currency, "USD")
    }

    func testAppSettingsCustomCategories() {
        let settings = AppSettings()

        XCTAssertTrue(settings.customCategories.isEmpty)

        let custom1 = Category(
            id: "custom-1",
            name: "Custom One",
            icon: "⭐",
            color: "#AABBCC",
            type: .expense,
            isCustom: true
        )
        let custom2 = Category(
            id: "custom-2",
            name: "Custom Two",
            icon: "🌟",
            color: "#DDEEFF",
            type: .income,
            isCustom: true
        )

        settings.customCategories = [custom1, custom2]

        let retrieved = settings.customCategories
        XCTAssertEqual(retrieved.count, 2)
        XCTAssertEqual(retrieved[0].id, "custom-1")
        XCTAssertEqual(retrieved[0].name, "Custom One")
        XCTAssertEqual(retrieved[1].id, "custom-2")
        XCTAssertTrue(retrieved[0].isCustom)
    }

    func testAppSettingsCustomCategoriesEmptyReturnsNilData() {
        let settings = AppSettings()
        settings.customCategories = []
        XCTAssertNil(settings.customCategoriesData)
    }

    func testAppSettingsAllCategoriesMerge() {
        let settings = AppSettings()

        let customCategory = Category(
            id: "custom-new",
            name: "My Custom",
            icon: "🎯",
            color: "#123456",
            type: .expense,
            isCustom: true
        )
        settings.customCategories = [customCategory]

        let allCats = settings.allCategories
        // Should contain all defaults plus the custom one
        XCTAssertTrue(allCats.count > DefaultCategories.all.count)
        XCTAssertTrue(allCats.contains(where: { $0.id == "custom-new" }))
    }

    func testAppSettingsAddAndRemoveCustomCategory() {
        let settings = AppSettings()

        let category = Category(
            id: "removable",
            name: "Removable",
            icon: "🗑",
            color: "#000000",
            type: .expense,
            isCustom: true
        )

        settings.addCustomCategory(category)
        XCTAssertEqual(settings.customCategories.count, 1)
        XCTAssertEqual(settings.customCategories[0].id, "removable")

        settings.removeCustomCategory(withId: "removable")
        XCTAssertTrue(settings.customCategories.isEmpty)
    }

    func testAppSettingsDefaultValues() {
        let settings = AppSettings()
        XCTAssertEqual(settings.currency, "EUR")
        XCTAssertFalse(settings.darkMode)
        XCTAssertEqual(settings.startOfMonth, 1)
        XCTAssertNil(settings.defaultAccountId)
    }
}
