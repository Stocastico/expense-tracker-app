import Foundation
import Vision

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - OCR Result

public struct OCRResult {
    public let amount: Double?
    public let merchant: String?
    public let date: Date?

    public init(amount: Double?, merchant: String?, date: Date?) {
        self.amount = amount
        self.merchant = merchant
        self.date = date
    }
}

// MARK: - OCR Service

public struct OCRService {

    // MARK: - Errors

    public enum OCRError: Error, LocalizedError {
        case invalidImageData
        case recognitionFailed(String)
        case noTextFound

        public var errorDescription: String? {
            switch self {
            case .invalidImageData:
                return "Could not create image from provided data."
            case .recognitionFailed(let message):
                return "Text recognition failed: \(message)"
            case .noTextFound:
                return "No text was found in the image."
            }
        }
    }

    // MARK: - Text Recognition

    public static func recognizeText(from imageData: Data) async throws -> String {
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else {
            throw OCRError.invalidImageData
        }
        #elseif canImport(AppKit)
        guard let nsImage = NSImage(data: imageData),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.invalidImageData
        }
        #else
        throw OCRError.invalidImageData
        #endif

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation],
                      !observations.isEmpty else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }

                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                let fullText = recognizedStrings.joined(separator: "\n")
                continuation.resume(returning: fullText)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
            }
        }
    }

    // MARK: - Extract Expense from Text

    public static func extractExpenseFromText(_ text: String) -> OCRResult? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }

        let amount = extractAmount(from: lines)
        let date = extractDate(from: lines)
        let merchant = extractMerchant(from: lines)

        // Return nil only if we found absolutely nothing
        guard amount != nil || date != nil || merchant != nil else { return nil }

        return OCRResult(amount: amount, merchant: merchant, date: date)
    }

    // MARK: - Private Extraction Helpers

    private static func extractAmount(from lines: [String]) -> Double? {
        // Strategy 1: Look for lines containing "total", "amount", "sum", "grand total", "balance due"
        let totalKeywords = ["total", "amount due", "amount", "sum", "grand total", "balance due", "you owe", "charge"]
        var candidateAmounts: [(amount: Double, priority: Int)] = []

        for line in lines {
            let lowerLine = line.lowercased()

            for (index, keyword) in totalKeywords.enumerated() {
                if lowerLine.contains(keyword) {
                    if let amount = extractMonetaryAmount(from: line) {
                        // Lower index = higher priority keyword
                        candidateAmounts.append((amount: amount, priority: index))
                    }
                }
            }
        }

        // Return the amount associated with the highest-priority keyword
        if let best = candidateAmounts.min(by: { $0.priority < $1.priority }) {
            return best.amount
        }

        // Strategy 2: Find the largest monetary amount in the text (likely the total)
        var allAmounts: [Double] = []
        for line in lines {
            if let amount = extractMonetaryAmount(from: line) {
                allAmounts.append(amount)
            }
        }

        return allAmounts.max()
    }

    private static func extractMonetaryAmount(from text: String) -> Double? {
        let pattern = "[\\$€£¥₹]\\s*([\\d,]+\\.\\d{2})|([\\d,]+\\.\\d{2})\\s*[\\$€£¥₹]?|([\\d,]+\\.\\d{2})"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)

        var amounts: [Double] = []
        for match in matches {
            for groupIndex in 1..<match.numberOfRanges {
                let groupRange = match.range(at: groupIndex)
                if groupRange.location != NSNotFound,
                   let swiftRange = Range(groupRange, in: text) {
                    let numberString = String(text[swiftRange]).replacingOccurrences(of: ",", with: "")
                    if let value = Double(numberString), value > 0 {
                        amounts.append(value)
                    }
                }
            }
        }

        // Return the largest amount found in this line
        return amounts.max()
    }

    private static func extractDate(from lines: [String]) -> Date? {
        let datePatterns: [(pattern: String, format: String)] = [
            ("\\d{2}/\\d{2}/\\d{4}", "MM/dd/yyyy"),
            ("\\d{2}-\\d{2}-\\d{4}", "MM-dd-yyyy"),
            ("\\d{4}-\\d{2}-\\d{2}", "yyyy-MM-dd"),
            ("\\d{1,2} [A-Za-z]{3,9} \\d{4}", "d MMMM yyyy"),
            ("[A-Za-z]{3,9} \\d{1,2},? \\d{4}", "MMMM d, yyyy"),
            ("\\d{2}\\.\\d{2}\\.\\d{4}", "dd.MM.yyyy"),
        ]

        for line in lines {
            for (pattern, format) in datePatterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
                let range = NSRange(line.startIndex..., in: line)
                if let match = regex.firstMatch(in: line, options: [], range: range),
                   let matchRange = Range(match.range, in: line) {
                    let dateString = String(line[matchRange])

                    // Try the expected format first
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "en_US_POSIX")

                    formatter.dateFormat = format
                    if let date = formatter.date(from: dateString) {
                        return date
                    }

                    // Try abbreviated month names as well
                    if format.contains("MMMM") {
                        formatter.dateFormat = format.replacingOccurrences(of: "MMMM", with: "MMM")
                        if let date = formatter.date(from: dateString) {
                            return date
                        }
                    }

                    // Fallback: use PDFImportService's parser
                    if let date = PDFImportService.parseDateFromString(dateString) {
                        return date
                    }
                }
            }
        }

        return nil
    }

    private static func extractMerchant(from lines: [String]) -> String? {
        // Skip common receipt header elements
        let skipPatterns: [String] = [
            "receipt", "invoice", "tax", "date", "time", "tel", "phone", "fax",
            "www\\.", "http", "@", "\\d{3}[-.\\s]\\d{3,4}[-.\\s]\\d{4}",
            "thank", "welcome", "address", "street", "ave", "blvd",
            "total", "subtotal", "change", "cash", "card", "visa", "mastercard",
            "^\\d+$", "^\\$", "^#"
        ]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard trimmed.count >= 3 && trimmed.count <= 50 else { continue }

            let lowerTrimmed = trimmed.lowercased()

            var shouldSkip = false
            for pattern in skipPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(lowerTrimmed.startIndex..., in: lowerTrimmed)
                    if regex.firstMatch(in: lowerTrimmed, options: [], range: range) != nil {
                        shouldSkip = true
                        break
                    }
                }
            }

            if shouldSkip { continue }

            // The first non-skipped line is likely the merchant name
            // Verify it looks like a name (contains letters, not just numbers/symbols)
            let letterCount = trimmed.filter { $0.isLetter }.count
            if letterCount >= 2 {
                return trimmed
            }
        }

        return nil
    }
}
