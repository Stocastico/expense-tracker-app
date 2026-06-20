import Foundation

/// Structured result of scanning a receipt/invoice image's OCR text.
public struct ReceiptScan: Equatable {
    public let amount: Decimal?
    public let date: Date?
    public let merchant: String?

    public init(amount: Decimal?, date: Date?, merchant: String?) {
        self.amount = amount
        self.date = date
        self.merchant = merchant
    }
}

/// Locale-aware (Spanish-first) extractor that turns the OCR text of a receipt
/// or invoice into a structured `ReceiptScan`, reusing `MoneyParser` and
/// `DocumentDateParser`.
public enum ReceiptParser {

    /// Extracts total amount, date and merchant from OCR `text`.
    public static func parse(_ text: String) -> ReceiptScan {
        // Stub: implementation follows in the green commit.
        return ReceiptScan(amount: nil, date: nil, merchant: nil)
    }
}
