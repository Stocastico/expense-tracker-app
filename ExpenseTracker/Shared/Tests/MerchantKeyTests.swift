import XCTest
import Foundation

/// Tests for the normalisation used as the lookup key for learned
/// category rules ("remember that this merchant means this category").
final class MerchantKeyTests: XCTestCase {

    func testUsesMerchantWhenPresent() {
        XCTAssertEqual(MerchantKey.normalize(merchant: "MERCADONA", description: "whatever"), "mercadona")
    }

    func testFallsBackToDescriptionWhenMerchantNil() {
        XCTAssertEqual(MerchantKey.normalize(merchant: nil, description: "Spotify"), "spotify")
    }

    func testFallsBackToDescriptionWhenMerchantBlank() {
        XCTAssertEqual(MerchantKey.normalize(merchant: "   ", description: "Spotify"), "spotify")
    }

    func testFoldsDiacritics() {
        XCTAssertEqual(MerchantKey.normalize(merchant: nil, description: "PAGO EN CAFÉ CENTRAL"),
                       "pago en cafe central")
    }

    func testDropsPureDigitTokens() {
        // Card/branch numbers vary per transaction and must not split the key.
        XCTAssertEqual(MerchantKey.normalize(merchant: "Mercadona 1234 BILBAO", description: ""),
                       "mercadona bilbao")
    }

    func testCollapsesWhitespaceAndPunctuation() {
        XCTAssertEqual(MerchantKey.normalize(merchant: "  AMAZON   *MKTPLACE  ", description: ""),
                       "amazon mktplace")
    }

    func testIsCaseInsensitive() {
        XCTAssertEqual(MerchantKey.normalize(merchant: "Amazon", description: ""),
                       MerchantKey.normalize(merchant: "AMAZON", description: ""))
    }

    func testReturnsNilWhenNothingUsable() {
        XCTAssertNil(MerchantKey.normalize(merchant: nil, description: "   "))
        XCTAssertNil(MerchantKey.normalize(merchant: "  ", description: "1234"))
    }
}
