import XCTest
import Foundation
@testable import ExpenseTracker

final class SmartCategoryTests: XCTestCase {

    // MARK: - Known Keyword Tests

    func testUberMapsToTransport() {
        let result = SmartCategoryService.suggestCategory(for: "uber ride downtown", merchant: nil)
        XCTAssertEqual(result, "transport")
    }

    func testNetflixMapsToSubscriptions() {
        let result = SmartCategoryService.suggestCategory(for: "netflix monthly", merchant: nil)
        XCTAssertEqual(result, "subscriptions")
    }

    func testAmazonMapsToShopping() {
        let result = SmartCategoryService.suggestCategory(for: "amazon purchase", merchant: nil)
        XCTAssertEqual(result, "shopping")
    }

    func testStarbucksMapsToFoodDining() {
        let result = SmartCategoryService.suggestCategory(for: "starbucks coffee", merchant: nil)
        XCTAssertEqual(result, "food-dining")
    }

    func testWalmartMapsToGroceries() {
        let result = SmartCategoryService.suggestCategory(for: "walmart grocery run", merchant: nil)
        XCTAssertEqual(result, "groceries")
    }

    func testSpotifyMapsToSubscriptions() {
        let result = SmartCategoryService.suggestCategory(for: "spotify premium", merchant: nil)
        XCTAssertEqual(result, "subscriptions")
    }

    func testDoctorMapsToHealthcare() {
        let result = SmartCategoryService.suggestCategory(for: "doctor visit copay", merchant: nil)
        XCTAssertEqual(result, "healthcare")
    }

    func testRentMapsToHousing() {
        let result = SmartCategoryService.suggestCategory(for: "monthly rent payment", merchant: nil)
        XCTAssertEqual(result, "housing")
    }

    // MARK: - Case Insensitivity Tests

    func testCaseInsensitivityUppercase() {
        let result = SmartCategoryService.suggestCategory(for: "UBER RIDE", merchant: nil)
        XCTAssertEqual(result, "transport")
    }

    func testCaseInsensitivityMixedCase() {
        let result = SmartCategoryService.suggestCategory(for: "Netflix Premium", merchant: nil)
        XCTAssertEqual(result, "subscriptions")
    }

    func testCaseInsensitivityAllCaps() {
        let result = SmartCategoryService.suggestCategory(for: "AMAZON MARKETPLACE", merchant: nil)
        XCTAssertEqual(result, "shopping")
    }

    func testCaseInsensitivityMerchant() {
        let result = SmartCategoryService.suggestCategory(for: "monthly charge", merchant: "NETFLIX")
        XCTAssertEqual(result, "subscriptions")
    }

    // MARK: - Partial Matching Tests

    func testPartialMatchContainsKeyword() {
        // "uber" should match even within a longer string
        let result = SmartCategoryService.suggestCategory(for: "uber eats delivery charge", merchant: nil)
        // Should match because "uber" is contained in the description
        XCTAssertNotNil(result)
    }

    func testPartialMatchMerchant() {
        let result = SmartCategoryService.suggestCategory(for: "payment", merchant: "Starbucks Reserve")
        XCTAssertEqual(result, "food-dining")
    }

    func testPartialMatchInLongerText() {
        // "gym" keyword matches in "personal-care" category
        let result = SmartCategoryService.suggestCategory(for: "my gym membership renewal", merchant: nil)
        XCTAssertEqual(result, "personal-care")
    }

    // MARK: - Unknown Merchant Returns Nil

    func testUnknownMerchantReturnsNil() {
        let result = SmartCategoryService.suggestCategory(for: "xyzabc123", merchant: nil)
        XCTAssertNil(result)
    }

    func testUnknownDescriptionAndMerchantReturnsNil() {
        let result = SmartCategoryService.suggestCategory(for: "qwerty", merchant: "zzzunknown")
        XCTAssertNil(result)
    }

    func testEmptyDescriptionUnknownMerchantReturnsNil() {
        let result = SmartCategoryService.suggestCategory(for: "", merchant: "totallyunknownmerchant12345")
        XCTAssertNil(result)
    }

    // MARK: - Merchant Priority Over Description

    func testMerchantTakesPriorityOverDescription() {
        // Description matches "transport" (uber), but merchant matches "food-dining" (starbucks)
        // Merchant should be checked first per SmartCategoryService logic
        let result = SmartCategoryService.suggestCategory(for: "uber ride", merchant: "Starbucks")
        XCTAssertEqual(result, "food-dining")
    }

    func testMerchantPriorityWithDifferentCategories() {
        // Description matches shopping (amazon), but merchant matches subscriptions (netflix)
        let result = SmartCategoryService.suggestCategory(for: "amazon order", merchant: "Netflix Inc")
        XCTAssertEqual(result, "subscriptions")
    }

    func testFallsBackToDescriptionWhenMerchantUnknown() {
        let result = SmartCategoryService.suggestCategory(for: "netflix subscription", merchant: "unknown_co")
        XCTAssertEqual(result, "subscriptions")
    }

    func testFallsBackToDescriptionWhenMerchantNil() {
        let result = SmartCategoryService.suggestCategory(for: "uber trip to airport", merchant: nil)
        XCTAssertEqual(result, "transport")
    }

    func testFallsBackToDescriptionWhenMerchantEmpty() {
        let result = SmartCategoryService.suggestCategory(for: "grocery shopping at walmart", merchant: "")
        XCTAssertEqual(result, "groceries")
    }

    // MARK: - Edge Cases

    func testEmptyDescription() {
        let result = SmartCategoryService.suggestCategory(for: "", merchant: nil)
        XCTAssertNil(result)
    }

    func testEmptyDescriptionWithKnownMerchant() {
        let result = SmartCategoryService.suggestCategory(for: "", merchant: "Uber")
        XCTAssertEqual(result, "transport")
    }
}
