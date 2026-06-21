import Testing
import Foundation

/// Drives `ReceiptImportPipeline`, which turns the OCR text of one or more
/// receipt/invoice images into categorized drafts by reusing `ReceiptParser`
/// (amount/date/merchant) and a `CategorizationEngine` (category suggestion).
struct ReceiptImportPipelineTests {

    /// A deterministic engine so the pipeline can be tested without depending on
    /// the heuristic's keyword set.
    private struct StubEngine: CategorizationEngine {
        let suggestion: String?
        func suggestCategoryId(merchant: String?, description: String, candidates: [Category]) async -> String? {
            suggestion
        }
    }

    private let mercadonaReceipt = """
    MERCADONA S.A.
    C/ Mayor 1
    TOTAL: 42,50 €
    14/03/2026
    GRACIAS POR SU COMPRA
    """

    @Test("A draft combines the parsed fields with the engine's category suggestion")
    func combinesFieldsAndCategory() async {
        let draft = await ReceiptImportPipeline.makeDraft(
            fromText: mercadonaReceipt,
            engine: StubEngine(suggestion: "groceries")
        )
        #expect(draft.amount == Decimal(string: "42.50")!)
        #expect(draft.merchant?.contains("MERCADONA") == true)
        #expect(draft.categoryId == "groceries")
    }

    @Test("No confident suggestion leaves the category nil but keeps the fields")
    func noCategorySuggestion() async {
        let draft = await ReceiptImportPipeline.makeDraft(
            fromText: mercadonaReceipt,
            engine: StubEngine(suggestion: nil)
        )
        #expect(draft.amount == Decimal(string: "42.50")!)
        #expect(draft.categoryId == nil)
    }

    @Test("The heuristic engine categorizes a known merchant end to end")
    func heuristicCategorizesKnownMerchant() async {
        let draft = await ReceiptImportPipeline.makeDraft(
            fromText: mercadonaReceipt,
            engine: HeuristicCategorizationEngine()
        )
        #expect(draft.categoryId == "groceries")
    }

    @Test("Batch import produces one draft per input text, in order")
    func batchProducesOneDraftPerText() async {
        let other = """
        FARMACIA CENTRAL
        TOTAL 9,90 €
        """
        let drafts = await ReceiptImportPipeline.makeDrafts(
            fromTexts: [mercadonaReceipt, other],
            engine: StubEngine(suggestion: "x")
        )
        #expect(drafts.count == 2)
        #expect(drafts[0].merchant?.contains("MERCADONA") == true)
        #expect(drafts[1].amount == Decimal(string: "9.90")!)
    }
}
