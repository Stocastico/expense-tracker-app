import XCTest
import Foundation
import SwiftData
@testable import ExpenseTracker

// MARK: - Sync Payload Codable Tests

final class SyncPayloadCodableTests: XCTestCase {

    // MARK: - SyncAccount Encoding/Decoding

    func testSyncAccountCodableRoundtrip() throws {
        let id = UUID()
        let date = Date()
        let account = SyncAccount(
            id: id,
            name: "Personal",
            icon: "💳",
            color: "#007AFF",
            isDefault: true,
            createdAt: date
        )

        let data = try JSONEncoder().encode(account)
        let decoded = try JSONDecoder().decode(SyncAccount.self, from: data)

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.name, "Personal")
        XCTAssertEqual(decoded.icon, "💳")
        XCTAssertEqual(decoded.color, "#007AFF")
        XCTAssertTrue(decoded.isDefault)
        XCTAssertEqual(decoded.createdAt.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
    }

    func testSyncAccountNonDefaultValues() throws {
        let account = SyncAccount(
            id: UUID(),
            name: "Business",
            icon: "🏢",
            color: "#34C759",
            isDefault: false,
            createdAt: Date()
        )

        let data = try JSONEncoder().encode(account)
        let decoded = try JSONDecoder().decode(SyncAccount.self, from: data)

        XCTAssertEqual(decoded.name, "Business")
        XCTAssertFalse(decoded.isDefault)
    }

    // MARK: - SyncTransaction Encoding/Decoding

    func testSyncTransactionCodableRoundtripAllFields() throws {
        let id = UUID()
        let accountId = UUID()
        let parentId = UUID()
        let date = Date()
        let endDate = Date().addingTimeInterval(86400 * 30)
        let receipt = "receipt-image-data".data(using: .utf8)!

        let transaction = SyncTransaction(
            id: id,
            typeRaw: "expense",
            storedAmount: 42.50,
            currency: "EUR",
            descriptionText: "Coffee at Starbucks",
            merchant: "Starbucks",
            date: date,
            categoryId: "food-dining",
            accountId: accountId,
            tagsString: "morning,coffee",
            notes: "Good latte",
            isRecurring: true,
            recurringFrequencyRaw: "weekly",
            recurringEndDate: endDate,
            recurringParentId: parentId,
            receiptData: receipt,
            createdAt: date,
            updatedAt: date
        )

        let data = try JSONEncoder().encode(transaction)
        let decoded = try JSONDecoder().decode(SyncTransaction.self, from: data)

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.typeRaw, "expense")
        XCTAssertEqual(decoded.storedAmount, 42.50, accuracy: 0.001)
        XCTAssertEqual(decoded.currency, "EUR")
        XCTAssertEqual(decoded.descriptionText, "Coffee at Starbucks")
        XCTAssertEqual(decoded.merchant, "Starbucks")
        XCTAssertEqual(decoded.date.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(decoded.categoryId, "food-dining")
        XCTAssertEqual(decoded.accountId, accountId)
        XCTAssertEqual(decoded.tagsString, "morning,coffee")
        XCTAssertEqual(decoded.notes, "Good latte")
        XCTAssertTrue(decoded.isRecurring)
        XCTAssertEqual(decoded.recurringFrequencyRaw, "weekly")
        XCTAssertNotNil(decoded.recurringEndDate)
        XCTAssertEqual(decoded.recurringParentId, parentId)
        XCTAssertEqual(decoded.receiptData, receipt)
    }

    func testSyncTransactionCodableWithNilOptionals() throws {
        let transaction = SyncTransaction(
            id: UUID(),
            typeRaw: "income",
            storedAmount: 3000.0,
            currency: "USD",
            descriptionText: "Salary",
            merchant: nil,
            date: Date(),
            categoryId: "salary",
            accountId: nil,
            tagsString: "",
            notes: nil,
            isRecurring: false,
            recurringFrequencyRaw: nil,
            recurringEndDate: nil,
            recurringParentId: nil,
            receiptData: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        let data = try JSONEncoder().encode(transaction)
        let decoded = try JSONDecoder().decode(SyncTransaction.self, from: data)

        XCTAssertEqual(decoded.typeRaw, "income")
        XCTAssertEqual(decoded.storedAmount, 3000.0, accuracy: 0.001)
        XCTAssertNil(decoded.merchant)
        XCTAssertNil(decoded.accountId)
        XCTAssertEqual(decoded.tagsString, "")
        XCTAssertNil(decoded.notes)
        XCTAssertFalse(decoded.isRecurring)
        XCTAssertNil(decoded.recurringFrequencyRaw)
        XCTAssertNil(decoded.recurringEndDate)
        XCTAssertNil(decoded.recurringParentId)
        XCTAssertNil(decoded.receiptData)
    }

    // MARK: - SyncPayload Encoding/Decoding

    func testSyncPayloadCodableRoundtrip() throws {
        let account = SyncAccount(
            id: UUID(),
            name: "Main",
            icon: "💰",
            color: "#FF0000",
            isDefault: true,
            createdAt: Date()
        )
        let transaction = SyncTransaction(
            id: UUID(),
            typeRaw: "expense",
            storedAmount: 15.99,
            currency: "EUR",
            descriptionText: "Lunch",
            merchant: nil,
            date: Date(),
            categoryId: "food-dining",
            accountId: account.id,
            tagsString: "lunch",
            notes: nil,
            isRecurring: false,
            recurringFrequencyRaw: nil,
            recurringEndDate: nil,
            recurringParentId: nil,
            receiptData: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let sentAt = Date()
        let payload = SyncPayload(
            transactions: [transaction],
            accounts: [account],
            sentAt: sentAt
        )

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(SyncPayload.self, from: data)

        XCTAssertEqual(decoded.transactions.count, 1)
        XCTAssertEqual(decoded.accounts.count, 1)
        XCTAssertEqual(decoded.transactions[0].id, transaction.id)
        XCTAssertEqual(decoded.accounts[0].id, account.id)
        XCTAssertEqual(decoded.sentAt.timeIntervalSince1970, sentAt.timeIntervalSince1970, accuracy: 0.001)
    }

    func testSyncPayloadEmptyCollections() throws {
        let payload = SyncPayload(
            transactions: [],
            accounts: [],
            sentAt: Date()
        )

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(SyncPayload.self, from: data)

        XCTAssertTrue(decoded.transactions.isEmpty)
        XCTAssertTrue(decoded.accounts.isEmpty)
    }

    func testSyncPayloadMultipleItems() throws {
        let accounts = (0..<5).map { i in
            SyncAccount(
                id: UUID(),
                name: "Account \(i)",
                icon: "💳",
                color: "#00\(i)AFF",
                isDefault: i == 0,
                createdAt: Date()
            )
        }
        let transactions = (0..<10).map { i in
            SyncTransaction(
                id: UUID(),
                typeRaw: i % 2 == 0 ? "expense" : "income",
                storedAmount: Double(i) * 10.0 + 5.0,
                currency: "EUR",
                descriptionText: "Transaction \(i)",
                merchant: nil,
                date: Date(),
                categoryId: "other",
                accountId: accounts[i % accounts.count].id,
                tagsString: "",
                notes: nil,
                isRecurring: false,
                recurringFrequencyRaw: nil,
                recurringEndDate: nil,
                recurringParentId: nil,
                receiptData: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
        }

        let payload = SyncPayload(
            transactions: transactions,
            accounts: accounts,
            sentAt: Date()
        )

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(SyncPayload.self, from: data)

        XCTAssertEqual(decoded.accounts.count, 5)
        XCTAssertEqual(decoded.transactions.count, 10)

        // Verify alternating types
        XCTAssertEqual(decoded.transactions[0].typeRaw, "expense")
        XCTAssertEqual(decoded.transactions[1].typeRaw, "income")
        XCTAssertEqual(decoded.transactions[2].typeRaw, "expense")
    }

    func testSyncPayloadPreservesReceiptData() throws {
        let largeData = Data(repeating: 0xAB, count: 1024 * 100) // 100KB

        let transaction = SyncTransaction(
            id: UUID(),
            typeRaw: "expense",
            storedAmount: 25.0,
            currency: "EUR",
            descriptionText: "Receipt scan",
            merchant: nil,
            date: Date(),
            categoryId: "other",
            accountId: nil,
            tagsString: "",
            notes: nil,
            isRecurring: false,
            recurringFrequencyRaw: nil,
            recurringEndDate: nil,
            recurringParentId: nil,
            receiptData: largeData,
            createdAt: Date(),
            updatedAt: Date()
        )

        let payload = SyncPayload(transactions: [transaction], accounts: [], sentAt: Date())
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(SyncPayload.self, from: data)

        XCTAssertEqual(decoded.transactions[0].receiptData?.count, 1024 * 100)
        XCTAssertEqual(decoded.transactions[0].receiptData, largeData)
    }
}

// MARK: - Sync Merge Logic Tests

final class SyncMergeTests: XCTestCase {

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

    private func makeSyncAccount(
        id: UUID = UUID(),
        name: String = "Test",
        icon: String = "💳",
        color: String = "#007AFF",
        isDefault: Bool = false,
        createdAt: Date = Date()
    ) -> SyncAccount {
        SyncAccount(id: id, name: name, icon: icon, color: color, isDefault: isDefault, createdAt: createdAt)
    }

    private func makeSyncTransaction(
        id: UUID = UUID(),
        typeRaw: String = "expense",
        amount: Double = 25.0,
        currency: String = "EUR",
        description: String = "Test transaction",
        merchant: String? = nil,
        categoryId: String = "other",
        accountId: UUID? = nil,
        tags: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) -> SyncTransaction {
        SyncTransaction(
            id: id,
            typeRaw: typeRaw,
            storedAmount: amount,
            currency: currency,
            descriptionText: description,
            merchant: merchant,
            date: Date(),
            categoryId: categoryId,
            accountId: accountId,
            tagsString: tags,
            notes: nil,
            isRecurring: false,
            recurringFrequencyRaw: nil,
            recurringEndDate: nil,
            recurringParentId: nil,
            receiptData: nil,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func makePayload(
        transactions: [SyncTransaction] = [],
        accounts: [SyncAccount] = []
    ) -> SyncPayload {
        SyncPayload(transactions: transactions, accounts: accounts, sentAt: Date())
    }

    // MARK: - Account Merge Tests

    func testMergeInsertsNewAccount() throws {
        let syncAccount = makeSyncAccount(name: "Remote Account")
        let payload = makePayload(accounts: [syncAccount])

        try SyncService.mergePayload(payload, into: context)

        let accounts = try context.fetch(FetchDescriptor<Account>())
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0].id, syncAccount.id)
        XCTAssertEqual(accounts[0].name, "Remote Account")
    }

    func testMergeInsertsMultipleNewAccounts() throws {
        let accounts = (0..<3).map { i in
            makeSyncAccount(name: "Account \(i)")
        }
        let payload = makePayload(accounts: accounts)

        try SyncService.mergePayload(payload, into: context)

        let fetched = try context.fetch(FetchDescriptor<Account>())
        XCTAssertEqual(fetched.count, 3)
    }

    func testMergeUpdatesExistingAccountWhenIncomingIsNewer() throws {
        let sharedId = UUID()
        let olderDate = Date(timeIntervalSince1970: 1000)
        let newerDate = Date(timeIntervalSince1970: 2000)

        // Insert existing account with older createdAt
        let existing = Account(id: sharedId, name: "Old Name", icon: "💳", color: "#000", isDefault: false, createdAt: olderDate)
        context.insert(existing)
        try context.save()

        // Merge with newer account data
        let syncAccount = makeSyncAccount(id: sharedId, name: "New Name", icon: "🏦", color: "#FFF", isDefault: true, createdAt: newerDate)
        let payload = makePayload(accounts: [syncAccount])

        try SyncService.mergePayload(payload, into: context)

        let accounts = try context.fetch(FetchDescriptor<Account>())
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0].name, "New Name")
        XCTAssertEqual(accounts[0].icon, "🏦")
        XCTAssertEqual(accounts[0].color, "#FFF")
        XCTAssertTrue(accounts[0].isDefault)
    }

    func testMergeKeepsLocalAccountWhenLocalIsNewer() throws {
        let sharedId = UUID()
        let olderDate = Date(timeIntervalSince1970: 1000)
        let newerDate = Date(timeIntervalSince1970: 2000)

        // Insert existing account with newer createdAt
        let existing = Account(id: sharedId, name: "Local Name", icon: "🏠", color: "#ABC", isDefault: true, createdAt: newerDate)
        context.insert(existing)
        try context.save()

        // Merge with older account data
        let syncAccount = makeSyncAccount(id: sharedId, name: "Remote Name", icon: "📱", color: "#DEF", isDefault: false, createdAt: olderDate)
        let payload = makePayload(accounts: [syncAccount])

        try SyncService.mergePayload(payload, into: context)

        let accounts = try context.fetch(FetchDescriptor<Account>())
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0].name, "Local Name")
        XCTAssertEqual(accounts[0].icon, "🏠")
        XCTAssertTrue(accounts[0].isDefault)
    }

    func testMergeAccountWithSameTimestampKeepsLocal() throws {
        let sharedId = UUID()
        let sameDate = Date(timeIntervalSince1970: 1500)

        let existing = Account(id: sharedId, name: "Local", createdAt: sameDate)
        context.insert(existing)
        try context.save()

        let syncAccount = makeSyncAccount(id: sharedId, name: "Remote", createdAt: sameDate)
        let payload = makePayload(accounts: [syncAccount])

        try SyncService.mergePayload(payload, into: context)

        let accounts = try context.fetch(FetchDescriptor<Account>())
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0].name, "Local") // Same timestamp, local wins
    }

    func testMergeAccountPreservesIcon() throws {
        let syncAccount = makeSyncAccount(icon: "🐷")
        let payload = makePayload(accounts: [syncAccount])

        try SyncService.mergePayload(payload, into: context)

        let accounts = try context.fetch(FetchDescriptor<Account>())
        XCTAssertEqual(accounts[0].icon, "🐷")
    }

    // MARK: - Transaction Merge Tests

    func testMergeInsertsNewTransaction() throws {
        let syncTx = makeSyncTransaction(description: "Remote expense")
        let payload = makePayload(transactions: [syncTx])

        try SyncService.mergePayload(payload, into: context)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transactions[0].id, syncTx.id)
        XCTAssertEqual(transactions[0].descriptionText, "Remote expense")
    }

    func testMergeInsertsMultipleNewTransactions() throws {
        let txs = (0..<5).map { i in
            makeSyncTransaction(description: "Transaction \(i)", amount: Double(i) * 10.0)
        }
        let payload = makePayload(transactions: txs)

        try SyncService.mergePayload(payload, into: context)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions.count, 5)
    }

    func testMergeUpdatesTransactionWhenIncomingIsNewer() throws {
        let sharedId = UUID()
        let olderDate = Date(timeIntervalSince1970: 1000)
        let newerDate = Date(timeIntervalSince1970: 2000)

        // Insert existing transaction with older updatedAt
        let existing = Transaction(
            id: sharedId,
            type: .expense,
            amount: 10.0,
            descriptionText: "Old description",
            categoryId: "other",
            updatedAt: olderDate
        )
        context.insert(existing)
        try context.save()

        // Merge with newer transaction data
        let syncTx = makeSyncTransaction(
            id: sharedId,
            amount: 99.99,
            description: "Updated description",
            categoryId: "food-dining",
            updatedAt: newerDate
        )
        let payload = makePayload(transactions: [syncTx])

        try SyncService.mergePayload(payload, into: context)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transactions[0].descriptionText, "Updated description")
        XCTAssertEqual(transactions[0].storedAmount, 99.99, accuracy: 0.001)
        XCTAssertEqual(transactions[0].categoryId, "food-dining")
    }

    func testMergeKeepsLocalTransactionWhenLocalIsNewer() throws {
        let sharedId = UUID()
        let olderDate = Date(timeIntervalSince1970: 1000)
        let newerDate = Date(timeIntervalSince1970: 2000)

        // Insert existing transaction with newer updatedAt
        let existing = Transaction(
            id: sharedId,
            type: .expense,
            amount: 50.0,
            descriptionText: "Local version",
            categoryId: "shopping",
            updatedAt: newerDate
        )
        context.insert(existing)
        try context.save()

        // Merge with older transaction data
        let syncTx = makeSyncTransaction(
            id: sharedId,
            amount: 10.0,
            description: "Remote version",
            categoryId: "other",
            updatedAt: olderDate
        )
        let payload = makePayload(transactions: [syncTx])

        try SyncService.mergePayload(payload, into: context)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transactions[0].descriptionText, "Local version")
        XCTAssertEqual(transactions[0].storedAmount, 50.0, accuracy: 0.001)
    }

    func testMergeTransactionWithSameTimestampKeepsLocal() throws {
        let sharedId = UUID()
        let sameDate = Date(timeIntervalSince1970: 1500)

        let existing = Transaction(
            id: sharedId,
            type: .expense,
            amount: 30.0,
            descriptionText: "Local",
            categoryId: "other",
            updatedAt: sameDate
        )
        context.insert(existing)
        try context.save()

        let syncTx = makeSyncTransaction(id: sharedId, description: "Remote", updatedAt: sameDate)
        let payload = makePayload(transactions: [syncTx])

        try SyncService.mergePayload(payload, into: context)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transactions[0].descriptionText, "Local")
    }

    func testMergeUpdatesAllTransactionFields() throws {
        let sharedId = UUID()
        let olderDate = Date(timeIntervalSince1970: 1000)
        let newerDate = Date(timeIntervalSince1970: 2000)
        let parentId = UUID()

        let existing = Transaction(
            id: sharedId,
            type: .expense,
            amount: 10.0,
            currency: "EUR",
            descriptionText: "Old",
            date: olderDate,
            categoryId: "other",
            updatedAt: olderDate
        )
        context.insert(existing)
        try context.save()

        let syncTx = SyncTransaction(
            id: sharedId,
            typeRaw: "income",
            storedAmount: 999.0,
            currency: "USD",
            descriptionText: "Updated",
            merchant: "Acme Corp",
            date: newerDate,
            categoryId: "salary",
            accountId: nil,
            tagsString: "work,bonus",
            notes: "Year-end bonus",
            isRecurring: true,
            recurringFrequencyRaw: "monthly",
            recurringEndDate: newerDate.addingTimeInterval(86400 * 365),
            recurringParentId: parentId,
            receiptData: "data".data(using: .utf8),
            createdAt: olderDate,
            updatedAt: newerDate
        )
        let payload = makePayload(transactions: [syncTx])

        try SyncService.mergePayload(payload, into: context)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let t = transactions[0]
        XCTAssertEqual(t.typeRaw, "income")
        XCTAssertEqual(t.storedAmount, 999.0, accuracy: 0.001)
        XCTAssertEqual(t.currency, "USD")
        XCTAssertEqual(t.descriptionText, "Updated")
        XCTAssertEqual(t.merchant, "Acme Corp")
        XCTAssertEqual(t.categoryId, "salary")
        XCTAssertEqual(t.tagsString, "work,bonus")
        XCTAssertEqual(t.notes, "Year-end bonus")
        XCTAssertTrue(t.isRecurring)
        XCTAssertEqual(t.recurringFrequencyRaw, "monthly")
        XCTAssertNotNil(t.recurringEndDate)
        XCTAssertEqual(t.recurringParentId, parentId)
        XCTAssertNotNil(t.receiptData)
    }

    // MARK: - Transaction-Account Linking

    func testMergeLinksTransactionToNewAccount() throws {
        let accountId = UUID()
        let syncAccount = makeSyncAccount(id: accountId, name: "Linked Account")
        let syncTx = makeSyncTransaction(accountId: accountId)
        let payload = makePayload(transactions: [syncTx], accounts: [syncAccount])

        try SyncService.mergePayload(payload, into: context)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions.count, 1)
        XCTAssertNotNil(transactions[0].account)
        XCTAssertEqual(transactions[0].account?.name, "Linked Account")
    }

    func testMergeLinksTransactionToExistingAccount() throws {
        let accountId = UUID()
        let existingAccount = Account(id: accountId, name: "Existing Account")
        context.insert(existingAccount)
        try context.save()

        let syncTx = makeSyncTransaction(accountId: accountId)
        let payload = makePayload(transactions: [syncTx])

        try SyncService.mergePayload(payload, into: context)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions[0].account?.id, accountId)
        XCTAssertEqual(transactions[0].account?.name, "Existing Account")
    }

    func testMergeTransactionWithNilAccountId() throws {
        let syncTx = makeSyncTransaction(accountId: nil)
        let payload = makePayload(transactions: [syncTx])

        try SyncService.mergePayload(payload, into: context)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertNil(transactions[0].account)
    }

    func testMergeTransactionWithNonExistentAccountId() throws {
        let fakeAccountId = UUID()
        let syncTx = makeSyncTransaction(accountId: fakeAccountId)
        let payload = makePayload(transactions: [syncTx])

        try SyncService.mergePayload(payload, into: context)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions.count, 1)
        // Account doesn't exist, so it should be nil
        XCTAssertNil(transactions[0].account)
    }

    // MARK: - Mixed Merge Scenarios

    func testMergeMixOfNewAndExistingTransactions() throws {
        let existingId = UUID()
        let olderDate = Date(timeIntervalSince1970: 1000)
        let newerDate = Date(timeIntervalSince1970: 2000)

        // Pre-existing transaction
        let existing = Transaction(
            id: existingId,
            type: .expense,
            amount: 20.0,
            descriptionText: "Existing",
            categoryId: "other",
            updatedAt: olderDate
        )
        context.insert(existing)
        try context.save()

        // Merge: update existing + add new
        let updatedTx = makeSyncTransaction(id: existingId, description: "Updated existing", updatedAt: newerDate)
        let newTx = makeSyncTransaction(description: "Brand new")
        let payload = makePayload(transactions: [updatedTx, newTx])

        try SyncService.mergePayload(payload, into: context)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions.count, 2)

        let updated = transactions.first { $0.id == existingId }
        let brandNew = transactions.first { $0.id == newTx.id }

        XCTAssertNotNil(updated)
        XCTAssertEqual(updated?.descriptionText, "Updated existing")
        XCTAssertNotNil(brandNew)
        XCTAssertEqual(brandNew?.descriptionText, "Brand new")
    }

    func testMergeMixOfNewAndExistingAccounts() throws {
        let existingId = UUID()
        let olderDate = Date(timeIntervalSince1970: 1000)
        let newerDate = Date(timeIntervalSince1970: 2000)

        let existing = Account(id: existingId, name: "Old Account", createdAt: olderDate)
        context.insert(existing)
        try context.save()

        let updatedAccount = makeSyncAccount(id: existingId, name: "Updated Account", createdAt: newerDate)
        let newAccount = makeSyncAccount(name: "New Account")
        let payload = makePayload(accounts: [updatedAccount, newAccount])

        try SyncService.mergePayload(payload, into: context)

        let accounts = try context.fetch(FetchDescriptor<Account>())
        XCTAssertEqual(accounts.count, 2)

        let updated = accounts.first { $0.id == existingId }
        XCTAssertEqual(updated?.name, "Updated Account")

        let fresh = accounts.first { $0.id == newAccount.id }
        XCTAssertEqual(fresh?.name, "New Account")
    }

    // MARK: - Empty Payload

    func testMergeEmptyPayloadChangesNothing() throws {
        // Pre-populate with data
        let account = Account(name: "Existing")
        context.insert(account)
        let transaction = Transaction(type: .expense, amount: 42.0, descriptionText: "Existing tx", categoryId: "other")
        context.insert(transaction)
        try context.save()

        // Merge empty payload
        let payload = makePayload()
        try SyncService.mergePayload(payload, into: context)

        let accounts = try context.fetch(FetchDescriptor<Account>())
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(accounts[0].name, "Existing")
        XCTAssertEqual(transactions[0].descriptionText, "Existing tx")
    }

    func testMergeEmptyPayloadIntoEmptyContext() throws {
        let payload = makePayload()
        try SyncService.mergePayload(payload, into: context)

        let accounts = try context.fetch(FetchDescriptor<Account>())
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertTrue(accounts.isEmpty)
        XCTAssertTrue(transactions.isEmpty)
    }

    // MARK: - Transaction Type Preservation

    func testMergePreservesIncomeType() throws {
        let syncTx = makeSyncTransaction(typeRaw: "income", amount: 5000.0, description: "Salary")
        let payload = makePayload(transactions: [syncTx])

        try SyncService.mergePayload(payload, into: context)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions[0].type, .income)
        XCTAssertEqual(transactions[0].storedAmount, 5000.0, accuracy: 0.001)
    }

    func testMergePreservesExpenseType() throws {
        let syncTx = makeSyncTransaction(typeRaw: "expense", amount: 15.0, description: "Coffee")
        let payload = makePayload(transactions: [syncTx])

        try SyncService.mergePayload(payload, into: context)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions[0].type, .expense)
    }

    func testMergePreservesTags() throws {
        let syncTx = makeSyncTransaction(tags: "work,travel,urgent")
        let payload = makePayload(transactions: [syncTx])

        try SyncService.mergePayload(payload, into: context)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions[0].tags, ["work", "travel", "urgent"])
    }

    func testMergePreservesEmptyTags() throws {
        let syncTx = makeSyncTransaction(tags: "")
        let payload = makePayload(transactions: [syncTx])

        try SyncService.mergePayload(payload, into: context)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertTrue(transactions[0].tags.isEmpty)
    }

    // MARK: - Currency Preservation

    func testMergePreservesCurrency() throws {
        let syncTx = makeSyncTransaction(currency: "JPY", amount: 1500)
        let payload = makePayload(transactions: [syncTx])

        try SyncService.mergePayload(payload, into: context)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions[0].currency, "JPY")
    }

    // MARK: - Idempotency

    func testMergeSamePayloadTwiceIsIdempotent() throws {
        let syncAccount = makeSyncAccount(name: "Idempotent Account")
        let syncTx = makeSyncTransaction(description: "Idempotent Tx")
        let payload = makePayload(transactions: [syncTx], accounts: [syncAccount])

        try SyncService.mergePayload(payload, into: context)
        try SyncService.mergePayload(payload, into: context)

        let accounts = try context.fetch(FetchDescriptor<Account>())
        let transactions = try context.fetch(FetchDescriptor<Transaction>())

        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(accounts[0].name, "Idempotent Account")
        XCTAssertEqual(transactions[0].descriptionText, "Idempotent Tx")
    }

    // MARK: - Conflict Resolution Edge Cases

    func testMergeConflictOnlyUpdatesChangedFields() throws {
        let sharedId = UUID()
        let olderDate = Date(timeIntervalSince1970: 1000)
        let newerDate = Date(timeIntervalSince1970: 2000)

        let existing = Transaction(
            id: sharedId,
            type: .expense,
            amount: 10.0,
            currency: "EUR",
            descriptionText: "Original",
            merchant: "Local Merchant",
            categoryId: "shopping",
            updatedAt: olderDate
        )
        context.insert(existing)
        try context.save()

        // Incoming update changes description and amount but also overwrites merchant
        let syncTx = SyncTransaction(
            id: sharedId,
            typeRaw: "expense",
            storedAmount: 20.0,
            currency: "EUR",
            descriptionText: "Modified",
            merchant: "Remote Merchant",
            date: Date(),
            categoryId: "shopping",
            accountId: nil,
            tagsString: "",
            notes: nil,
            isRecurring: false,
            recurringFrequencyRaw: nil,
            recurringEndDate: nil,
            recurringParentId: nil,
            receiptData: nil,
            createdAt: olderDate,
            updatedAt: newerDate
        )
        let payload = makePayload(transactions: [syncTx])

        try SyncService.mergePayload(payload, into: context)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        // All fields from the newer payload should be applied
        XCTAssertEqual(transactions[0].descriptionText, "Modified")
        XCTAssertEqual(transactions[0].storedAmount, 20.0, accuracy: 0.001)
        XCTAssertEqual(transactions[0].merchant, "Remote Merchant")
    }

    func testMergeMultipleConflictsInSamePayload() throws {
        let id1 = UUID()
        let id2 = UUID()
        let olderDate = Date(timeIntervalSince1970: 1000)
        let newerDate = Date(timeIntervalSince1970: 2000)

        let tx1 = Transaction(id: id1, type: .expense, amount: 10.0, descriptionText: "Local 1", categoryId: "a", updatedAt: olderDate)
        let tx2 = Transaction(id: id2, type: .expense, amount: 20.0, descriptionText: "Local 2", categoryId: "b", updatedAt: newerDate)
        context.insert(tx1)
        context.insert(tx2)
        try context.save()

        // tx1 gets updated (incoming is newer), tx2 stays (local is newer)
        let syncTx1 = makeSyncTransaction(id: id1, description: "Remote 1", updatedAt: newerDate)
        let syncTx2 = makeSyncTransaction(id: id2, description: "Remote 2", updatedAt: olderDate)
        let payload = makePayload(transactions: [syncTx1, syncTx2])

        try SyncService.mergePayload(payload, into: context)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions.count, 2)

        let fetched1 = transactions.first { $0.id == id1 }
        let fetched2 = transactions.first { $0.id == id2 }

        XCTAssertEqual(fetched1?.descriptionText, "Remote 1")  // Updated
        XCTAssertEqual(fetched2?.descriptionText, "Local 2")   // Kept local
    }

    // MARK: - Recurring Transaction Merge

    func testMergeRecurringTransaction() throws {
        let parentId = UUID()
        let endDate = Date().addingTimeInterval(86400 * 365)
        let syncTx = SyncTransaction(
            id: UUID(),
            typeRaw: "expense",
            storedAmount: 9.99,
            currency: "EUR",
            descriptionText: "Netflix",
            merchant: "Netflix",
            date: Date(),
            categoryId: "subscriptions",
            accountId: nil,
            tagsString: "streaming",
            notes: nil,
            isRecurring: true,
            recurringFrequencyRaw: "monthly",
            recurringEndDate: endDate,
            recurringParentId: parentId,
            receiptData: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let payload = makePayload(transactions: [syncTx])

        try SyncService.mergePayload(payload, into: context)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(transactions.count, 1)
        XCTAssertTrue(transactions[0].isRecurring)
        XCTAssertEqual(transactions[0].recurringFrequency, .monthly)
        XCTAssertEqual(transactions[0].recurringParentId, parentId)
        XCTAssertNotNil(transactions[0].recurringEndDate)
    }

    // MARK: - Large Payload

    func testMergeLargePayload() throws {
        let accounts = (0..<10).map { i in
            makeSyncAccount(name: "Account \(i)")
        }
        let transactions = (0..<100).map { i in
            makeSyncTransaction(
                amount: Double(i) * 1.5,
                description: "Transaction \(i)",
                accountId: accounts[i % 10].id
            )
        }
        let payload = makePayload(transactions: transactions, accounts: accounts)

        try SyncService.mergePayload(payload, into: context)

        let fetchedAccounts = try context.fetch(FetchDescriptor<Account>())
        let fetchedTransactions = try context.fetch(FetchDescriptor<Transaction>())

        XCTAssertEqual(fetchedAccounts.count, 10)
        XCTAssertEqual(fetchedTransactions.count, 100)

        // Verify all transactions are linked to accounts
        let linkedCount = fetchedTransactions.filter { $0.account != nil }.count
        XCTAssertEqual(linkedCount, 100)
    }
}

// MARK: - SyncService State Machine Tests

final class SyncServiceStateTests: XCTestCase {

    @MainActor
    func testInitialStateIsIdle() {
        let service = SyncService(role: .advertiser, displayName: "Test Mac")
        XCTAssertFalse(service.isActive)
        XCTAssertNil(service.connectedPeerName)
        XCTAssertNil(service.lastSyncDate)
        XCTAssertEqual(service.syncStatus, .idle)
    }

    @MainActor
    func testAdvertiserStartSetsAdvertisingStatus() {
        let service = SyncService(role: .advertiser, displayName: "Test Mac")
        service.start()

        XCTAssertTrue(service.isActive)
        XCTAssertEqual(service.syncStatus, .advertising)
    }

    @MainActor
    func testBrowserStartSetsBrowsingStatus() {
        let service = SyncService(role: .browser, displayName: "Test iPhone")
        service.start()

        XCTAssertTrue(service.isActive)
        XCTAssertEqual(service.syncStatus, .browsing)
    }

    @MainActor
    func testStopResetsState() {
        let service = SyncService(role: .advertiser, displayName: "Test Mac")
        service.start()
        XCTAssertTrue(service.isActive)

        service.stop()

        XCTAssertFalse(service.isActive)
        XCTAssertNil(service.connectedPeerName)
        XCTAssertEqual(service.syncStatus, .idle)
    }

    @MainActor
    func testStartWhileAlreadyActiveDoesNothing() {
        let service = SyncService(role: .browser, displayName: "Test iPhone")
        service.start()
        XCTAssertEqual(service.syncStatus, .browsing)

        // Start again should be no-op
        service.start()
        XCTAssertEqual(service.syncStatus, .browsing)
        XCTAssertTrue(service.isActive)
    }

    @MainActor
    func testStopWhileIdleIsNoOp() {
        let service = SyncService(role: .advertiser, displayName: "Test Mac")
        XCTAssertFalse(service.isActive)

        // Stop when already idle
        service.stop()
        XCTAssertFalse(service.isActive)
        XCTAssertEqual(service.syncStatus, .idle)
    }

    @MainActor
    func testSyncNowOnAdvertiserDoesNothing() {
        let service = SyncService(role: .advertiser, displayName: "Test Mac")
        service.start()
        // syncNow is only for browser role, should be no-op for advertiser
        service.syncNow()
        // Should not crash or change state
        XCTAssertEqual(service.syncStatus, .advertising)
    }

    @MainActor
    func testStartStopCycle() {
        let service = SyncService(role: .browser, displayName: "Test iPhone")

        // Cycle 1
        service.start()
        XCTAssertTrue(service.isActive)
        XCTAssertEqual(service.syncStatus, .browsing)

        service.stop()
        XCTAssertFalse(service.isActive)
        XCTAssertEqual(service.syncStatus, .idle)

        // Cycle 2
        service.start()
        XCTAssertTrue(service.isActive)
        XCTAssertEqual(service.syncStatus, .browsing)

        service.stop()
        XCTAssertFalse(service.isActive)
        XCTAssertEqual(service.syncStatus, .idle)
    }

    // MARK: - SyncStatus Equatable

    func testSyncStatusEquatable() {
        XCTAssertEqual(SyncService.SyncStatus.idle, SyncService.SyncStatus.idle)
        XCTAssertEqual(SyncService.SyncStatus.advertising, SyncService.SyncStatus.advertising)
        XCTAssertEqual(SyncService.SyncStatus.browsing, SyncService.SyncStatus.browsing)
        XCTAssertEqual(SyncService.SyncStatus.connecting, SyncService.SyncStatus.connecting)
        XCTAssertEqual(SyncService.SyncStatus.syncing, SyncService.SyncStatus.syncing)
        XCTAssertEqual(SyncService.SyncStatus.completed, SyncService.SyncStatus.completed)
        XCTAssertEqual(SyncService.SyncStatus.error("test"), SyncService.SyncStatus.error("test"))

        XCTAssertNotEqual(SyncService.SyncStatus.idle, SyncService.SyncStatus.browsing)
        XCTAssertNotEqual(SyncService.SyncStatus.error("a"), SyncService.SyncStatus.error("b"))
        XCTAssertNotEqual(SyncService.SyncStatus.advertising, SyncService.SyncStatus.completed)
    }
}
