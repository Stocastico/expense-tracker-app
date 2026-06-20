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
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return ReceiptScan(
            amount: extractAmount(lines),
            date: extractDate(lines),
            merchant: extractMerchant(lines)
        )
    }

    // MARK: - Amount

    /// Total keywords by priority (lower index wins).
    private static let totalKeywords = [
        "total a pagar", "importe total", "total a abonar", "total €", "total eur",
        "total:", "total", "importe", "a pagar", "suma", "grand total",
        "amount due", "balance due"
    ]

    private static func extractAmount(_ lines: [String]) -> Decimal? {
        var best: (amount: Decimal, priority: Int)?
        for line in lines {
            let l = line.lowercased()
            for (priority, keyword) in totalKeywords.enumerated() {
                guard l.contains(keyword) else { continue }
                // Don't let "subtotal"/"base imponible" masquerade as the total.
                if keyword == "total" && (l.contains("subtotal") || l.contains("base imponible")) { continue }
                guard let amount = MoneyParser.allAmounts(in: line).max() else { continue }
                if best == nil || priority < best!.priority {
                    best = (amount, priority)
                }
            }
        }
        if let best { return best.amount }
        // No total keyword: fall back to the largest amount seen.
        return lines.flatMap { MoneyParser.allAmounts(in: $0) }.max()
    }

    // MARK: - Date

    private static func extractDate(_ lines: [String]) -> Date? {
        for line in lines {
            if let date = DocumentDateParser.parse(line) { return date }
        }
        return nil
    }

    // MARK: - Merchant

    private static let merchantSkip = [
        "c/", "calle", "avda", "av.", "plaza", "tel", "cif", "nif", "iva",
        "factura", "ticket", "gracias", "www", ".com", "@", "fecha",
        "total", "importe", "subtotal"
    ]

    private static func extractMerchant(_ lines: [String]) -> String? {
        for line in lines {
            guard line.count >= 3, line.count <= 40 else { continue }
            if DocumentDateParser.parse(line) != nil { continue }
            if !MoneyParser.allAmounts(in: line).isEmpty { continue }
            let l = line.lowercased()
            if merchantSkip.contains(where: { l.contains($0) }) { continue }
            if line.filter({ $0.isLetter }).count >= 3 { return line }
        }
        return nil
    }
}
