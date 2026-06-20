import XCTest
import Foundation

/// Unit tests for the shared expense/income/ignored classification rules.
final class StatementClassifierTests: XCTestCase {

    private func ignored(_ description: String, _ amount: String) -> Bool {
        StatementClassifier.isIgnored(
            description: description,
            amount: Decimal(string: amount, locale: Locale(identifier: "en_US_POSIX"))!
        )
    }

    func testZeroAmountIsIgnored() {
        XCTAssertTrue(ignored("LIQ. DE INT.HASTA 31.12.25", "0"))
    }

    func testCardSettlementVariantsAreIgnored() {
        XCTAssertTrue(ignored("PAGO RECIBO 4921074014350600", "905.01"))
        XCTAssertTrue(ignored("TARJ.CRDTO 4921074014350600", "-905.01"))
    }

    func testMaskedPanDoesNotTriggerSettlement() {
        // The 10-digit masked PAN printed on every card row is not a settlement.
        XCTAssertFalse(ignored("******4014350600 COMPRA EN PARKING VERDE", "-6.00"))
    }

    func testPagoReciboWithoutCardNumberIsNotIgnored() {
        XCTAssertFalse(ignored("PAGO RECIBO AGUA", "-30.00"))
    }

    func testTransfersAreIgnored() {
        XCTAssertTrue(ignored("TRASPASO A 912436733", "-100.00"))
        XCTAssertTrue(ignored("TRANSF. MASNERI STEFANO", "60000.00"))
        XCTAssertTrue(ignored("TRANSF. 1544 Transfer MyInv", "-2000.00"))
    }

    func testPensionIsIgnored() {
        XCTAssertTrue(ignored("TRASPASO A P6 BASKEPENSIONES 60", "-100.00"))
        XCTAssertTrue(ignored("APORTACION PENSIONES", "-50.00"))
    }

    func testOrdinaryPurchaseIsNotIgnored() {
        XCTAssertFalse(ignored("COMPRA EN MERCADONA BILBAO", "-45.90"))
        XCTAssertFalse(ignored("NOMINA GRUP MEDIAPRO, S.L.U.", "3584.68"))
        XCTAssertFalse(ignored("TJ 2203819165 MUGI", "-20.00"))
    }
}
