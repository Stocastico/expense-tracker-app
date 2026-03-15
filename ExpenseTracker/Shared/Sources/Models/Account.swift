import Foundation
import SwiftData

@Model
public final class Account {
    public var id: UUID
    public var name: String
    public var icon: String
    public var color: String
    public var isDefault: Bool
    public var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Transaction.account)
    public var transactions: [Transaction]

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String = "💳",
        color: String = "#007AFF",
        isDefault: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.transactions = []
    }
}

// MARK: - Computed Properties

extension Account {
    /// Calculates the current balance for this account by summing incomes and subtracting expenses.
    public var balance: Double {
        transactions.reduce(0.0) { result, transaction in
            switch transaction.type {
            case .income:
                return result + transaction.storedAmount
            case .expense:
                return result - transaction.storedAmount
            }
        }
    }

    /// Returns the display string combining icon and name.
    public var displayName: String {
        "\(icon) \(name)"
    }
}
