import Foundation

/// A reviewable draft produced from a receipt/invoice image: the parsed fields
/// plus a suggested category. The user confirms/edits these before they become
/// transactions.
public struct ReceiptDraft: Equatable, Sendable {
    public let amount: Decimal?
    public let date: Date?
    public let merchant: String?
    public let categoryId: String?

    public init(amount: Decimal?, date: Date?, merchant: String?, categoryId: String?) {
        self.amount = amount
        self.date = date
        self.merchant = merchant
        self.categoryId = categoryId
    }
}

/// Turns the OCR text of one or more receipt/invoice images into categorized
/// drafts, reusing `ReceiptParser` (locale-aware amount/date/merchant extraction)
/// and a `CategorizationEngine` (heuristic today, on-device LLM when available)
/// for the category suggestion. The OCR step (`OCRService.recognizeText`) is the
/// caller's responsibility, which keeps this pipeline pure and testable.
public enum ReceiptImportPipeline {

    /// Builds a single draft from one image's OCR text.
    public static func makeDraft(
        fromText text: String,
        engine: CategorizationEngine = HeuristicCategorizationEngine(),
        candidates: [Category] = DefaultCategories.expenseCategories
    ) async -> ReceiptDraft {
        let scan = ReceiptParser.parse(text)
        let categoryId = await engine.suggestCategoryId(
            merchant: scan.merchant,
            description: scan.merchant ?? "",
            candidates: candidates
        )
        return ReceiptDraft(
            amount: scan.amount,
            date: scan.date,
            merchant: scan.merchant,
            categoryId: categoryId
        )
    }

    /// Builds a draft per image text, preserving order.
    public static func makeDrafts(
        fromTexts texts: [String],
        engine: CategorizationEngine = HeuristicCategorizationEngine(),
        candidates: [Category] = DefaultCategories.expenseCategories
    ) async -> [ReceiptDraft] {
        var drafts: [ReceiptDraft] = []
        drafts.reserveCapacity(texts.count)
        for text in texts {
            drafts.append(await makeDraft(fromText: text, engine: engine, candidates: candidates))
        }
        return drafts
    }
}
