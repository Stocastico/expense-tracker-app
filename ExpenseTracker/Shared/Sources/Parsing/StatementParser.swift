import Foundation

/// A single transaction extracted from a statement line.
public struct StatementEntry: Equatable {
    public let date: Date?
    /// Absolute amount; sign is conveyed by `isExpense`.
    public let amount: Decimal
    public let isExpense: Bool
    public let description: String

    public init(date: Date?, amount: Decimal, isExpense: Bool, description: String) {
        self.date = date
        self.amount = amount
        self.isExpense = isExpense
        self.description = description
    }
}

/// Locale-aware (Spanish-first) parser that turns the raw text of a bank or
/// credit-card statement into structured transactions, reusing `MoneyParser`
/// and `DocumentDateParser`.
public enum StatementParser {

    /// Parses every transaction line found in `text`.
    public static func parse(_ text: String) -> [StatementEntry] {
        // Stub: implementation follows in the green commit.
        return []
    }

    /// Parses a single line into an entry, or `nil` if it is not a transaction.
    static func parseLine(_ raw: String) -> StatementEntry? {
        // Stub: implementation follows in the green commit.
        return nil
    }
}
