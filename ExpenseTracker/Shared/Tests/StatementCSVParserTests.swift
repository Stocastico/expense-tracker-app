import XCTest
import Foundation

/// Tests for the bank-account CSV reader, using a fixture that mirrors a real
/// Kutxabank "Movimientos de cuenta" sheet saved as CSV (semicolon-delimited,
/// comma decimals, `fecha;concepto;fecha valor;importe;saldo`).
final class StatementCSVParserTests: XCTestCase {

    private func dec(_ s: String) -> Decimal { Decimal(string: s, locale: Locale(identifier: "en_US_POSIX"))! }

    private let accountCSV = """
    Movimientos de cuenta

    fecha;concepto;fecha valor;importe;saldo
    01/01/2026;TARJ.CRDTO 4921074014350600;01/01/2026;-905,01;11570,99
    01/01/2026;RBO TELEFONO MOV.xxxxxx925.ene;01/01/2026;-11,21;11559,78
    02/01/2026;LIQ. DE INT.HASTA 31.12.25;31/12/2025;0,00;11559,78
    04/01/2026;ENVIO BIZUM idk kanalla;04/01/2026;65,00;11624,78
    04/01/2026;ENVIO BIZUM idk estais invitados;04/01/2026;-15,00;11609,78
    05/01/2026;TRASPASO A P6 BASKEPENSIONES 60;05/01/2026;-100,00;11509,78
    06/01/2026;OP.NET Orden Permanente;06/01/2026;-1300,00;10209,78
    10/01/2026;TRASPASO A 912436733;10/01/2026;-100,00;10109,78
    19/01/2026;ENVIO BIZUM parking milesker;19/01/2026;-20,00;10089,78
    21/01/2026;TJ 2203819165 MUGI;21/01/2026;-20,00;10069,78
    21/01/2026;TJ 4080123314 MUGI;21/01/2026;-20,00;10049,78
    23/01/2026;ENVIO BIZUM Bascula;23/01/2026;15,00;10064,78
    27/01/2026;TRANSF. MASNERI STEFANO;27/01/2026;60000,00;70064,78
    28/01/2026;NOMINA GRUP MEDIAPRO, S.L.U.;28/01/2026;3584,68;73649,46
    29/01/2026;TRANSF. 1544 Transfer MyInv;29/01/2026;-2000,00;71649,46
    29/01/2026;TRASPASO A 9902090524;29/01/2026;-3800,00;67849,46
    """

    private func entries() -> [StatementEntry] { StatementCSVParser.parse(accountCSV) }

    private func entry(containing needle: String) -> StatementEntry? {
        entries().first { $0.description.uppercased().contains(needle.uppercased()) }
    }

    func testParsesEveryMovementRow() {
        // 16 movement rows; the title and header lines are skipped.
        XCTAssertEqual(entries().count, 16)
    }

    func testAmountColumnIsUsedNotSaldo() {
        // The transaction amount, not the running balance, must be taken.
        let phone = entry(containing: "RBO TELEFONO")
        XCTAssertEqual(phone?.kind, .expense)
        XCTAssertEqual(phone?.amount, dec("11.21"))
    }

    func testNominaIsIncomeFromSign() {
        let nomina = entry(containing: "NOMINA")
        XCTAssertEqual(nomina?.kind, .income)
        XCTAssertEqual(nomina?.amount, dec("3584.68"))
    }

    func testPositiveBizumIsIncome() {
        XCTAssertEqual(entry(containing: "kanalla")?.kind, .income)
    }

    func testNegativeBizumIsExpense() {
        XCTAssertEqual(entry(containing: "estais invitados")?.kind, .expense)
    }

    func testCardSettlementIsIgnored() {
        XCTAssertEqual(entry(containing: "TARJ.CRDTO")?.kind, .ignored)
    }

    func testZeroAmountLineIsIgnored() {
        XCTAssertEqual(entry(containing: "LIQ. DE INT")?.kind, .ignored)
    }

    func testOwnAccountTransfersAreIgnored() {
        XCTAssertEqual(entry(containing: "MASNERI STEFANO")?.kind, .ignored)
        XCTAssertEqual(entry(containing: "Transfer MyInv")?.kind, .ignored)
        XCTAssertEqual(entry(containing: "TRASPASO A 9902090524")?.kind, .ignored)
    }

    func testPensionContributionIsIgnored() {
        XCTAssertEqual(entry(containing: "BASKEPENSIONES")?.kind, .ignored)
    }

    func testOverallKindBreakdown() {
        let all = entries()
        XCTAssertEqual(all.filter { $0.kind == .ignored }.count, 7)
        XCTAssertEqual(all.filter { $0.kind == .income }.count, 3)
        XCTAssertEqual(all.filter { $0.kind == .expense }.count, 6)
    }

    func testEmptyTextReturnsNoEntries() {
        XCTAssertTrue(StatementCSVParser.parse("").isEmpty)
    }
}
