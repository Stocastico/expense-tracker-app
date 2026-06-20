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
        text.components(separatedBy: .newlines).compactMap { parseLine($0) }
    }

    /// Parses a single line into an entry, or `nil` if it is not a transaction.
    static func parseLine(_ raw: String) -> StatementEntry? {
        let line = raw.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty, !isSkippable(line) else { return nil }

        guard let date = DocumentDateParser.parse(line) else { return nil }
        guard let token = lastAmountToken(in: line),
              let signed = MoneyParser.parse(token) else { return nil }

        let isExpense = signed < 0 ? true : !hasIncomeKeyword(line)
        let description = cleanDescription(line, amountToken: token)

        return StatementEntry(
            date: date,
            amount: signed.absoluteValue,
            isExpense: isExpense,
            description: description
        )
    }

    // MARK: - Skip rules

    /// Header rows, account metadata and balance lines that are not transactions.
    private static let skipSubstrings = [
        "saldo", "concepto", "extracto", "iban", "titular",
        "página", "pagina", "resumen", "n.º de cuenta", "numero de cuenta"
    ]

    private static func isSkippable(_ line: String) -> Bool {
        let l = line.lowercased()
        if skipSubstrings.contains(where: { l.contains($0) }) { return true }
        // Column header like "Fecha ... Importe".
        if l.contains("fecha") && l.contains("importe") { return true }
        return false
    }

    // MARK: - Income detection

    private static let incomeKeywords = [
        "nomina", "nómina", "abono", "ingreso", "bizum recibido",
        "transferencia recibida", "transf. recibida", "devolucion", "devolución",
        "reembolso", "traspaso recibido", "salary", "deposit", "refund", "credit"
    ]

    private static func hasIncomeKeyword(_ line: String) -> Bool {
        let l = line.lowercased()
        return incomeKeywords.contains { l.contains($0) }
    }

    // MARK: - Amount extraction

    /// Matches a monetary amount with a two-digit decimal part, optional
    /// thousands separators, sign, parentheses and currency symbol.
    private static let amountRegex = try! NSRegularExpression(
        pattern: "[-+(]?\\s*€?\\s*(?:\\d{1,3}(?:[.,]\\d{3})+|\\d+)[.,]\\d{2}\\s*€?\\)?\\s*-?"
    )

    private static func lastAmountToken(in line: String) -> String? {
        let range = NSRange(line.startIndex..., in: line)
        let matches = amountRegex.matches(in: line, range: range)
        guard let last = matches.last, let r = Range(last.range, in: line) else { return nil }
        return line[r].trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Date stripping (for the description)

    private static let dateRegexes: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: "\\d{4}-\\d{2}-\\d{2}"),
        try! NSRegularExpression(pattern: "\\d{1,2}[/.\\-]\\d{1,2}[/.\\-]\\d{2,4}")
    ]

    private static func cleanDescription(_ line: String, amountToken: String) -> String {
        var result = line
        for regex in dateRegexes {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: " ")
        }
        if let tokenRange = result.range(of: amountToken) {
            result.removeSubrange(tokenRange)
        }
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: CharacterSet(charactersIn: " -.,"))
    }
}
