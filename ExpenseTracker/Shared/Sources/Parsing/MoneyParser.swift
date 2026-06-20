import Foundation

/// Locale-aware parser for monetary tokens found in bank/credit-card
/// statements, receipts and invoices.
///
/// Documents are predominantly Spanish (with some Italian, Basque and
/// English), so the parser defaults to European notation — comma decimal
/// separator, dot thousands separator — while still understanding US
/// notation. It returns a signed `Decimal`: negative for outflows expressed
/// with a leading/trailing minus or surrounding parentheses.
public enum MoneyParser {

    private static let currencySkip: Set<Character> = ["€", "$", "£", "¥", "₹", " ", "\t"]
    private static let posixLocale = Locale(identifier: "en_US_POSIX")

    /// Parses the first monetary amount found in `raw`.
    ///
    /// - Parameter raw: Text that may contain currency symbols, thousands and
    ///   decimal separators, sign markers and surrounding words.
    /// - Returns: The signed amount as a `Decimal`, or `nil` if no numeric
    ///   value could be found.
    public static func parse(_ raw: String) -> Decimal? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let tokenRange = bestNumberRange(in: trimmed) else { return nil }
        let token = String(trimmed[tokenRange])

        guard let magnitude = normalizedDecimal(from: token) else { return nil }

        let negative = isNegative(trimmed, tokenRange: tokenRange)
        return negative ? -magnitude : magnitude
    }

    // MARK: - Token extraction

    private static let amountTokenRegex = try! NSRegularExpression(
        pattern: "[-+(]?\\s*€?\\s*(?:\\d{1,3}(?:[.,]\\d{3})+|\\d+)[.,]\\d{2}\\s*€?\\)?\\s*-?"
    )

    /// Parses every monetary amount (two-decimal tokens) found in `text`, in
    /// order. Used by receipt parsing to inspect all amounts on a line.
    public static func allAmounts(in text: String) -> [Decimal] {
        let range = NSRange(text.startIndex..., in: text)
        return amountTokenRegex.matches(in: text, range: range).compactMap { match in
            guard let r = Range(match.range, in: text) else { return nil }
            return parse(String(text[r]))
        }
    }

    /// Finds the numeric token (digits plus `.`/`,` separators) containing the
    /// most digits — i.e. the most amount-like run in the string.
    private static func bestNumberRange(in text: String) -> Range<String.Index>? {
        let pattern = "[0-9]+(?:[.,][0-9]+)*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange)

        var best: (range: Range<String.Index>, digits: Int)?
        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            let digits = text[range].filter { $0.isNumber }.count
            if best == nil || digits > best!.digits {
                best = (range, digits)
            }
        }
        return best?.range
    }

    // MARK: - Normalisation

    /// Converts a numeric token using European/US separator heuristics into a
    /// POSIX-formatted decimal string and parses it.
    private static func normalizedDecimal(from token: String) -> Decimal? {
        let decimalSep = decimalSeparator(in: token)

        var normalized = ""
        for ch in token {
            if ch == "." || ch == "," {
                if ch == decimalSep { normalized.append(".") }
                // otherwise it is a thousands separator → drop it
            } else {
                normalized.append(ch)
            }
        }

        guard !normalized.isEmpty else { return nil }
        return Decimal(string: normalized, locale: posixLocale)
    }

    /// Decides which character (if any) acts as the decimal separator.
    ///
    /// - Both `.` and `,` present → the one occurring last is the decimal.
    /// - Only one kind present → it is the decimal separator only when it
    ///   appears once and is followed by one or two digits (e.g. `12,50`,
    ///   `1.50`); otherwise it is a thousands separator (e.g. `1.500`).
    private static func decimalSeparator(in token: String) -> Character? {
        let lastDot = token.lastIndex(of: ".")
        let lastComma = token.lastIndex(of: ",")

        switch (lastDot, lastComma) {
        case let (dot?, comma?):
            return dot > comma ? "." : ","
        case (let dot?, nil):
            return isDecimal(token, separatorIndex: dot, separator: ".") ? "." : nil
        case (nil, let comma?):
            return isDecimal(token, separatorIndex: comma, separator: ",") ? "," : nil
        case (nil, nil):
            return nil
        }
    }

    private static func isDecimal(_ token: String, separatorIndex: String.Index, separator: Character) -> Bool {
        let occurrences = token.filter { $0 == separator }.count
        guard occurrences == 1 else { return false }
        let trailing = token.distance(from: token.index(after: separatorIndex), to: token.endIndex)
        return trailing == 1 || trailing == 2
    }

    // MARK: - Sign detection

    private static func isNegative(_ text: String, tokenRange: Range<String.Index>) -> Bool {
        if text.contains("(") && text.contains(")") { return true }

        // Look left of the token, skipping currency symbols and whitespace.
        var i = tokenRange.lowerBound
        while i > text.startIndex {
            i = text.index(before: i)
            let ch = text[i]
            if ch == "-" { return true }
            if ch == "+" { return false }
            if currencySkip.contains(ch) { continue }
            break
        }

        // Look right of the token (trailing minus, e.g. "1.234,56-").
        var j = tokenRange.upperBound
        while j < text.endIndex {
            let ch = text[j]
            if ch == "-" { return true }
            if currencySkip.contains(ch) { j = text.index(after: j); continue }
            break
        }

        return false
    }
}
