import XCTest
import Foundation

/// Tests for the Spanish-first bank/credit-card statement parser.
///
/// These use synthetic fixtures in a plausible Spanish layout; they will be
/// tuned against a real statement once one is available. European notation is
/// the default (comma decimal, dot thousands, day-first dates).
final class StatementParserTests: XCTestCase {

    private static var utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func dec(_ s: String) -> Decimal { Decimal(string: s, locale: Locale(identifier: "en_US_POSIX"))! }

    private func ymd(_ date: Date?) -> (Int, Int, Int)? {
        guard let date else { return nil }
        let c = Self.utc.dateComponents([.year, .month, .day], from: date)
        return (c.year!, c.month!, c.day!)
    }

    private let sampleStatement = """
    Extracto de cuenta
    Fecha       Concepto                          Importe
    01/03/2026  COMPRA TARJ. MERCADONA BILBAO     -45,90
    03/03/2026  RECIBO ENDESA ENERGIA             -75,30
    05/03/2026  NOMINA ACME SL                    1.500,00
    28/03/2026  BIZUM RECIBIDO DE ANA             20,00
    Saldo final                                   1.398,80
    """

    func testParsesOnlyTransactionLines() {
        let entries = StatementParser.parse(sampleStatement)
        // 4 transactions; header, title and "Saldo final" are skipped.
        XCTAssertEqual(entries.count, 4)
    }

    func testFirstEntryFields() {
        let entries = StatementParser.parse(sampleStatement)
        let first = entries[0]
        XCTAssertEqual(ymd(first.date)?.0, 2026)
        XCTAssertEqual(ymd(first.date)?.1, 3)
        XCTAssertEqual(ymd(first.date)?.2, 1)
        XCTAssertEqual(first.amount, dec("45.90"))
        XCTAssertTrue(first.isExpense)
        XCTAssertTrue(first.description.uppercased().contains("MERCADONA"))
        XCTAssertFalse(first.description.contains("45,90"))
    }

    func testNominaIsIncomeViaKeyword() {
        let entries = StatementParser.parse(sampleStatement)
        let nomina = entries.first { $0.description.uppercased().contains("ACME") }
        XCTAssertNotNil(nomina)
        XCTAssertEqual(nomina?.amount, dec("1500.00"))
        XCTAssertFalse(nomina!.isExpense)
    }

    func testBizumRecibidoIsIncome() {
        let entries = StatementParser.parse(sampleStatement)
        let bizum = entries.first { $0.description.uppercased().contains("ANA") }
        XCTAssertEqual(bizum?.isExpense, false)
        XCTAssertEqual(bizum?.amount, dec("20.00"))
    }

    func testSaldoLineIsSkipped() {
        XCTAssertNil(StatementParser.parseLine("Saldo final                 1.398,80"))
    }

    func testHeaderLineIsSkipped() {
        XCTAssertNil(StatementParser.parseLine("Fecha   Concepto   Importe"))
    }

    func testLineWithoutAmountIsSkipped() {
        XCTAssertNil(StatementParser.parseLine("01/03/2026  ANOTACION SIN IMPORTE"))
    }

    func testLineWithoutDateIsSkipped() {
        XCTAssertNil(StatementParser.parseLine("COMPRA SIN FECHA   -10,00"))
    }

    func testNegativeSignMarksExpense() {
        let entry = StatementParser.parseLine("02/03/2026  PAGO RECIBO AGUA   -30,00")
        XCTAssertEqual(entry?.isExpense, true)
        XCTAssertEqual(entry?.amount, dec("30.00"))
    }

    func testValueDateLineUsesFirstDate() {
        // Operation date + value date on the same line.
        let entry = StatementParser.parseLine("02/03/2026 03/03/2026  PAGO RECIBO LUZ  -30,00")
        XCTAssertEqual(ymd(entry?.date)?.2, 2)
        XCTAssertTrue(entry!.description.uppercased().contains("LUZ"))
        XCTAssertFalse(entry!.description.contains("/2026"))
    }

    func testUnsignedExpenseDefaults() {
        // Positive amount, no income keyword → treated as expense by default.
        let entry = StatementParser.parseLine("10/03/2026  COMPRA FNAC   12,99")
        XCTAssertEqual(entry?.isExpense, true)
        XCTAssertEqual(entry?.amount, dec("12.99"))
    }

    func testEmptyTextReturnsNoEntries() {
        XCTAssertTrue(StatementParser.parse("").isEmpty)
    }

    // MARK: - Real Kutxabank credit-card layout
    //
    // "Movimientos de tarjeta": Fecha · Tarjeta (masked PAN) · Concepto ·
    // Situación · Importe, amounts as "-6,00 €" / "905,01 €".

    func testCardPurchaseIsExpense() {
        let entry = StatementParser.parseLine(
            "01/01/2026 ******4014350600 COMPRA EN PARKING VERDE -6,00 €")
        XCTAssertEqual(entry?.kind, .expense)
        XCTAssertEqual(entry?.amount, dec("6.00"))
        XCTAssertTrue(entry!.description.uppercased().contains("PARKING VERDE"))
        XCTAssertFalse(entry!.description.contains("€"))
    }

    func testCardThousandsAmountParsed() {
        let entry = StatementParser.parseLine(
            "08/01/2026 ******4014350600 COMPRA EN WWW.CICAR.COM -157,38 €")
        XCTAssertEqual(entry?.kind, .expense)
        XCTAssertEqual(entry?.amount, dec("157.38"))
    }

    func testCardBillSettlementIsIgnored() {
        // Positive "PAGO RECIBO <16-digit card>" is the monthly bill payment.
        let entry = StatementParser.parseLine(
            "01/01/2026 ******4014350600 PAGO RECIBO 4921074014350600 905,01 €")
        XCTAssertEqual(entry?.kind, .ignored)
    }

    func testPagoReciboWithoutCardNumberStaysExpense() {
        // A utility "PAGO RECIBO" (no card number) must remain a normal expense.
        let entry = StatementParser.parseLine("02/03/2026  PAGO RECIBO AGUA  -30,00")
        XCTAssertEqual(entry?.kind, .expense)
    }

    func testCardRefundIsIncome() {
        let entry = StatementParser.parseLine(
            "17/01/2026 ******4014350600 DEVOLUCION WWW.CICAR.COM 30,00 €")
        XCTAssertEqual(entry?.kind, .income)
        XCTAssertEqual(entry?.amount, dec("30.00"))
    }
}
