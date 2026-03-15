import Foundation
import PDFKit

// MARK: - Parsed Transaction

public struct ParsedTransaction {
    public let date: Date?
    public let amount: Double?
    public let description: String
    public let isExpense: Bool

    public init(date: Date?, amount: Double?, description: String, isExpense: Bool) {
        self.date = date
        self.amount = amount
        self.description = description
        self.isExpense = isExpense
    }
}

// MARK: - PDF Import Service

public struct PDFImportService {

    // MARK: - Extract Transactions from PDF

    public static func extractTransactions(from url: URL) -> [ParsedTransaction] {
        guard let document = PDFDocument(url: url) else {
            print("PDFImportService: Failed to open PDF at \(url.path)")
            return []
        }

        var fullText = ""
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex),
                  let pageText = page.string else {
                continue
            }
            fullText += pageText + "\n"
        }

        return parseText(fullText)
    }

    // MARK: - Parse Text into Transactions

    public static func parseText(_ text: String) -> [ParsedTransaction] {
        let lines = text.components(separatedBy: .newlines)
        var transactions: [ParsedTransaction] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Skip header-like lines
            let lowerLine = trimmed.lowercased()
            if lowerLine.contains("statement") && lowerLine.contains("period") { continue }
            if lowerLine.contains("opening balance") || lowerLine.contains("closing balance") { continue }
            if lowerLine.hasPrefix("date") && (lowerLine.contains("description") || lowerLine.contains("amount")) { continue }
            if lowerLine.contains("page ") && lowerLine.contains(" of ") { continue }

            // Try to extract date and amount from the line
            let parsedDate = extractDateFromLine(trimmed)
            let parsedAmount = extractAmountFromLine(trimmed)

            // Only consider lines that have at least a date or an amount
            guard parsedDate != nil || parsedAmount != nil else { continue }

            // Build description from remaining text
            var descriptionText = trimmed

            // Remove date patterns from description
            descriptionText = removeDatePatterns(from: descriptionText)

            // Remove amount patterns from description
            descriptionText = removeAmountPatterns(from: descriptionText)

            // Clean up description
            descriptionText = descriptionText
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)

            let isExpense = parsedAmount?.isExpense ?? true
            let amount = parsedAmount?.amount

            if !descriptionText.isEmpty || amount != nil {
                transactions.append(ParsedTransaction(
                    date: parsedDate,
                    amount: amount,
                    description: descriptionText,
                    isExpense: isExpense
                ))
            }
        }

        return transactions
    }

    // MARK: - Date Parsing

    public static func parseDateFromString(_ s: String) -> Date? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)

        let formatters: [(String, String)] = [
            ("dd/MM/yyyy", "\\d{2}/\\d{2}/\\d{4}"),
            ("MM/dd/yyyy", "\\d{2}/\\d{2}/\\d{4}"),
            ("yyyy-MM-dd", "\\d{4}-\\d{2}-\\d{2}"),
            ("dd-MM-yyyy", "\\d{2}-\\d{2}-\\d{4}"),
            ("MM-dd-yyyy", "\\d{2}-\\d{2}-\\d{4}"),
            ("dd MMM yyyy", "\\d{1,2} [A-Za-z]{3} \\d{4}"),
            ("d MMM yyyy", "\\d{1,2} [A-Za-z]{3} \\d{4}"),
            ("MMM dd, yyyy", "[A-Za-z]{3} \\d{1,2}, \\d{4}"),
            ("MMM d, yyyy", "[A-Za-z]{3} \\d{1,2}, \\d{4}"),
            ("dd.MM.yyyy", "\\d{2}\\.\\d{2}\\.\\d{4}"),
        ]

        for (format, _) in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        return nil
    }

    // MARK: - Amount Parsing

    public static func parseAmountFromString(_ s: String) -> (amount: Double, isExpense: Bool)? {
        var cleaned = s.trimmingCharacters(in: .whitespaces)

        // Determine expense/income from indicators
        var isExpense = true

        let lowerCleaned = cleaned.lowercased()
        if lowerCleaned.hasSuffix("cr") || lowerCleaned.hasSuffix("cr.") {
            isExpense = false
            cleaned = cleaned
                .replacingOccurrences(of: "(?i)cr\\.?$", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
        } else if lowerCleaned.hasSuffix("dr") || lowerCleaned.hasSuffix("dr.") {
            isExpense = true
            cleaned = cleaned
                .replacingOccurrences(of: "(?i)dr\\.?$", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
        }

        if cleaned.hasPrefix("+") {
            isExpense = false
            cleaned = String(cleaned.dropFirst())
        } else if cleaned.hasPrefix("-") {
            isExpense = true
            cleaned = String(cleaned.dropFirst())
        }

        // Strip currency symbols and whitespace
        let currencySymbols: [String] = ["$", "€", "£", "¥", "₹", "CHF", "CAD", "AUD", "USD", "EUR", "GBP"]
        for symbol in currencySymbols {
            cleaned = cleaned.replacingOccurrences(of: symbol, with: "")
        }

        cleaned = cleaned.trimmingCharacters(in: .whitespaces)

        // Remove thousands separators (commas) but keep decimal point
        cleaned = cleaned.replacingOccurrences(of: ",", with: "")

        // Parse the number
        guard let amount = Double(cleaned), amount > 0 else {
            return nil
        }

        return (amount: amount, isExpense: isExpense)
    }

    // MARK: - Private Helpers

    private static func extractDateFromLine(_ line: String) -> Date? {
        // Try various date patterns in the line
        let datePatterns: [String] = [
            "\\d{4}-\\d{2}-\\d{2}",                          // YYYY-MM-DD
            "\\d{2}/\\d{2}/\\d{4}",                          // DD/MM/YYYY or MM/DD/YYYY
            "\\d{1,2} [A-Za-z]{3} \\d{4}",                   // 14 Mar 2026
            "[A-Za-z]{3} \\d{1,2},? \\d{4}",                 // Mar 14, 2026
            "\\d{2}\\.\\d{2}\\.\\d{4}",                      // DD.MM.YYYY
            "\\d{2}-\\d{2}-\\d{4}",                          // DD-MM-YYYY
        ]

        for pattern in datePatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let range = NSRange(line.startIndex..., in: line)
            if let match = regex.firstMatch(in: line, options: [], range: range) {
                let matchRange = Range(match.range, in: line)!
                let dateString = String(line[matchRange])
                if let date = parseDateFromString(dateString) {
                    return date
                }
            }
        }

        return nil
    }

    private static func extractAmountFromLine(_ line: String) -> (amount: Double, isExpense: Bool)? {
        // Look for monetary amounts: optional currency symbol, digits with optional commas, decimal point, 2 digits
        // Also handles negative amounts and CR/DR suffixes
        let amountPattern = "[-+]?[\\$€£¥₹]?\\s*[\\d,]+\\.\\d{2}(?:\\s*(?:CR|DR|cr|dr)\\.?)?"
        guard let regex = try? NSRegularExpression(pattern: amountPattern, options: []) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        let matches = regex.matches(in: line, options: [], range: range)

        // Take the last amount on the line (typically the transaction amount, not a running balance first column)
        guard let lastMatch = matches.last else { return nil }
        let matchRange = Range(lastMatch.range, in: line)!
        let amountString = String(line[matchRange])
        return parseAmountFromString(amountString)
    }

    private static func removeDatePatterns(from text: String) -> String {
        var result = text
        let datePatterns: [String] = [
            "\\d{4}-\\d{2}-\\d{2}",
            "\\d{2}/\\d{2}/\\d{4}",
            "\\d{1,2} [A-Za-z]{3} \\d{4}",
            "[A-Za-z]{3} \\d{1,2},? \\d{4}",
            "\\d{2}\\.\\d{2}\\.\\d{4}",
            "\\d{2}-\\d{2}-\\d{4}",
        ]
        for pattern in datePatterns {
            result = result.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return result
    }

    private static func removeAmountPatterns(from text: String) -> String {
        let amountPattern = "[-+]?[\\$€£¥₹]?\\s*[\\d,]+\\.\\d{2}(?:\\s*(?:CR|DR|cr|dr)\\.?)?"
        return text.replacingOccurrences(of: amountPattern, with: "", options: .regularExpression)
    }
}
