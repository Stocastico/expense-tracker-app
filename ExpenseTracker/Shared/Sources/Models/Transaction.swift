import Foundation
import SwiftData

@Model
public final class Transaction {
    public var id: UUID
    public var typeRaw: String
    public var storedAmount: Double
    public var currency: String
    public var descriptionText: String
    public var merchant: String?
    public var date: Date
    public var categoryId: String
    public var account: Account?
    public var tagsString: String
    public var notes: String?
    public var isRecurring: Bool
    public var recurringFrequencyRaw: String?
    public var recurringEndDate: Date?
    public var recurringParentId: UUID?
    @Attribute(.externalStorage)
    public var receiptData: Data?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        type: TransactionType = .expense,
        amount: Double = 0.0,
        currency: String = "EUR",
        descriptionText: String = "",
        merchant: String? = nil,
        date: Date = Date(),
        categoryId: String = "",
        account: Account? = nil,
        tags: [String] = [],
        notes: String? = nil,
        isRecurring: Bool = false,
        recurringFrequency: RecurringFrequency? = nil,
        recurringEndDate: Date? = nil,
        recurringParentId: UUID? = nil,
        receiptData: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.storedAmount = amount
        self.currency = currency
        self.descriptionText = descriptionText
        self.merchant = merchant
        self.date = date
        self.categoryId = categoryId
        self.account = account
        self.tagsString = tags.joined(separator: ",")
        self.notes = notes
        self.isRecurring = isRecurring
        self.recurringFrequencyRaw = recurringFrequency?.rawValue
        self.recurringEndDate = recurringEndDate
        self.recurringParentId = recurringParentId
        self.receiptData = receiptData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Computed Properties

extension Transaction {
    /// The transaction type derived from the stored raw value.
    public var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    /// Alias for `type` used by StatsService and DataService.
    public var transactionType: TransactionType {
        get { type }
        set { type = newValue }
    }

    /// The transaction amount as a Decimal for precise currency calculations.
    public var amount: Decimal {
        get { Decimal(storedAmount) }
        set { storedAmount = NSDecimalNumber(decimal: newValue).doubleValue }
    }

    /// Tags stored as a comma-separated string, exposed as an array.
    public var tags: [String] {
        get {
            guard !tagsString.isEmpty else { return [] }
            return tagsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        set {
            tagsString = newValue.joined(separator: ",")
        }
    }

    /// The recurring frequency derived from the stored raw value.
    public var recurringFrequency: RecurringFrequency? {
        get {
            guard let raw = recurringFrequencyRaw else { return nil }
            return RecurringFrequency(rawValue: raw)
        }
        set {
            recurringFrequencyRaw = newValue?.rawValue
        }
    }

    /// The signed amount: positive for income, negative for expense.
    public var signedAmount: Double {
        switch type {
        case .income: return storedAmount
        case .expense: return -storedAmount
        }
    }

    /// A formatted display string for the amount with currency.
    public var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: storedAmount)) ?? String(format: "%@ %.2f", currency, storedAmount)
    }
}
