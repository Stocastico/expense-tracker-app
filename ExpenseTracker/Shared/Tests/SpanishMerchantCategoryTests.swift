import XCTest
import Foundation

/// Auto-categorisation coverage for the real Spanish/Basque merchant names that
/// appear on the user's Kutxabank statements. Exercises the live path used by
/// the manual form and statement import (`DefaultCategories.detectCategory`).
final class SpanishMerchantCategoryTests: XCTestCase {

    private func category(_ text: String, _ type: TransactionType = .expense) -> String {
        DefaultCategories.detectCategory(from: text, transactionType: type).id
    }

    func testGroceries() {
        XCTAssertEqual(category("COMPRA EN EROSKI 201 GARBERA"), "groceries")
        XCTAssertEqual(category("COMPRA EN EROSKI CENTER ARCCO AMARA"), "groceries")
        XCTAssertEqual(category("365 DIAS SUPERMERCADO"), "groceries")
        XCTAssertEqual(category("COMPRA EN FRUTERIA AMARA BERRI"), "groceries")
        XCTAssertEqual(category("COMPRA EN ALIMENTACION ARGOTE"), "groceries")
    }

    func testTransportAndFuelAndTolls() {
        XCTAssertEqual(category("COMPRA EN CARBURANTE TFE SUR"), "transport")
        XCTAssertEqual(category("COMPRA EN CEDIPSA ES ANOETA I"), "transport")
        XCTAssertEqual(category("COMPRA EN TJ 2203819165 MUGI"), "transport")
        XCTAssertEqual(category("DURANGO-ZARAUT/BIDEGI A-8 GIPU"), "transport")
        XCTAssertEqual(category("COMPRA EN PARKING VERDE"), "transport")
    }

    func testTravel() {
        XCTAssertEqual(category("COMPRA EN VUELING AIRLINES"), "travel")
        XCTAssertEqual(category("COMPRA EN WWW.CICAR.COM"), "travel")
        XCTAssertEqual(category("COMPRA EN HOMEEXCHANGE"), "travel")
    }

    func testHealthcarePharmacy() {
        XCTAssertEqual(category("COMPRA EN FCIA RODRIGUEZ CASAIS"), "healthcare")
        XCTAssertEqual(category("COMPRA EN FARMACIA CENTRAL"), "healthcare")
    }

    func testShoppingAndHousing() {
        XCTAssertEqual(category("COMPRA EN AMZN Mktp ES"), "shopping")
        XCTAssertEqual(category("COMPRA EN FERRETERIA ORIA"), "housing")
    }

    func testSubscriptions() {
        XCTAssertEqual(category("COMPRA EN OPENAI *CHATGPT SUBSCR"), "subscriptions")
    }

    func testFoodAndDining() {
        XCTAssertEqual(category("COMPRA EN PIZZERIA AMICI"), "food-dining")
        XCTAssertEqual(category("COMPRA EN BAR UDANE"), "food-dining")
        XCTAssertEqual(category("COMPRA EN KAFE BOTANIKA"), "food-dining")
    }

    func testIncomeSalaryAndRefund() {
        XCTAssertEqual(category("NOMINA GRUP MEDIAPRO, S.L.U.", .income), "salary")
        XCTAssertEqual(category("DEVOLUCION COMPRA", .income), "other-income")
    }
}
