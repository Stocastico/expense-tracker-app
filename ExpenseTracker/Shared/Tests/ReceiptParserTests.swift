import XCTest
import Foundation

/// Tests for receipt/invoice extraction from OCR text (Spanish-first).
final class ReceiptParserTests: XCTestCase {

    private static var utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func dec(_ s: String) -> Decimal { Decimal(string: s, locale: Locale(identifier: "en_US_POSIX"))! }
    private func ymd(_ d: Date?) -> (Int, Int, Int)? {
        guard let d else { return nil }
        let c = Self.utc.dateComponents([.year, .month, .day], from: d)
        return (c.year!, c.month!, c.day!)
    }

    private let sampleReceipt = """
    SUPERMERCADO EL ARBOL
    C/ Mayor 12, Bilbao
    CIF B12345678
    14/03/2026  12:45
    Leche             1,20
    Pan               0,90
    Huevos            2,40
    TOTAL A PAGAR     4,50 €
    Gracias por su compra
    """

    func testExtractsTotalAmount() {
        XCTAssertEqual(ReceiptParser.parse(sampleReceipt).amount, dec("4.50"))
    }

    func testExtractsDate() {
        XCTAssertEqual(ymd(ReceiptParser.parse(sampleReceipt).date)?.0, 2026)
        XCTAssertEqual(ymd(ReceiptParser.parse(sampleReceipt).date)?.1, 3)
        XCTAssertEqual(ymd(ReceiptParser.parse(sampleReceipt).date)?.2, 14)
    }

    func testExtractsMerchant() {
        let merchant = ReceiptParser.parse(sampleReceipt).merchant
        XCTAssertNotNil(merchant)
        XCTAssertTrue(merchant!.uppercased().contains("SUPERMERCADO"))
    }

    func testPrefersTotalOverSubtotal() {
        let text = """
        TIENDA
        10/03/2026
        SUBTOTAL   4,00
        IVA        0,50
        TOTAL      4,50
        """
        XCTAssertEqual(ReceiptParser.parse(text).amount, dec("4.50"))
    }

    func testFallsBackToLargestAmountWithoutTotalKeyword() {
        let text = """
        BAR PEPE
        11/03/2026
        Cafe     1,50
        Tostada  2,80
        """
        XCTAssertEqual(ReceiptParser.parse(text).amount, dec("2.80"))
    }

    func testEmptyTextYieldsNils() {
        let scan = ReceiptParser.parse("")
        XCTAssertNil(scan.amount)
        XCTAssertNil(scan.date)
        XCTAssertNil(scan.merchant)
    }
}

/// Tests for the multi-amount helper used by receipt parsing.
final class MoneyAllAmountsTests: XCTestCase {
    private func dec(_ s: String) -> Decimal { Decimal(string: s, locale: Locale(identifier: "en_US_POSIX"))! }

    func testFindsEachAmountInLine() {
        XCTAssertEqual(MoneyParser.allAmounts(in: "Subtotal 10,00 IVA 2,50 Total 12,50"),
                       [dec("10.00"), dec("2.50"), dec("12.50")])
    }

    func testReturnsEmptyWhenNoAmounts() {
        XCTAssertTrue(MoneyParser.allAmounts(in: "no amounts here").isEmpty)
    }
}
