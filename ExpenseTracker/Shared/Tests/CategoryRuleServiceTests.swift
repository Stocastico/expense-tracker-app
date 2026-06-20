import XCTest
import Foundation
import SwiftData

final class CategoryRuleServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var service: CategoryRuleService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([Transaction.self, Account.self, Budget.self, AppSettings.self, CategoryRule.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
        service = CategoryRuleService(modelContext: context)
    }

    override func tearDown() {
        service = nil
        context = nil
        container = nil
        super.tearDown()
    }

    func testLearnThenSuggestReturnsCategory() {
        service.learn(merchant: "Mercadona", description: "", categoryId: "groceries")
        XCTAssertEqual(service.suggestedCategoryId(merchant: "Mercadona", description: ""), "groceries")
    }

    func testSuggestionIsNilForUnknownMerchant() {
        XCTAssertNil(service.suggestedCategoryId(merchant: "Totally Unknown", description: ""))
    }

    func testLearningAppliesNormalisationSoBranchNumbersMatch() {
        // Learn with one branch/card number, look up with another: same key.
        service.learn(merchant: "MERCADONA 1234 BILBAO", description: "", categoryId: "groceries")
        XCTAssertEqual(service.suggestedCategoryId(merchant: "Mercadona 9876 BILBAO", description: ""), "groceries")
    }

    func testRelearningUpdatesCategoryAndReinforces() {
        service.learn(merchant: "Amazon", description: "", categoryId: "shopping")
        service.learn(merchant: "AMAZON", description: "", categoryId: "subscriptions")

        XCTAssertEqual(service.suggestedCategoryId(merchant: "amazon", description: ""), "subscriptions")

        let rule = service.rule(forKey: "amazon")
        XCTAssertNotNil(rule)
        XCTAssertEqual(rule?.hitCount, 2)
    }

    func testDoesNotCreateDuplicateRulesForSameKey() throws {
        service.learn(merchant: "Spotify", description: "", categoryId: "subscriptions")
        service.learn(merchant: "spotify", description: "", categoryId: "subscriptions")

        let all = try context.fetch(FetchDescriptor<CategoryRule>())
        XCTAssertEqual(all.count, 1)
    }

    func testLearnReturnsNilWhenNoUsableKey() {
        XCTAssertNil(service.learn(merchant: nil, description: "   ", categoryId: "groceries"))
    }

    func testAllRulesSortedByHitCountDescending() {
        service.learn(merchant: "Mercadona", description: "", categoryId: "groceries") // hit 1
        service.learn(merchant: "Spotify", description: "", categoryId: "subscriptions") // hit 1
        service.learn(merchant: "Spotify", description: "", categoryId: "subscriptions") // hit 2

        let rules = service.allRules()
        XCTAssertEqual(rules.count, 2)
        XCTAssertEqual(rules.first?.key, "spotify")
        XCTAssertEqual(rules.first?.hitCount, 2)
    }

    func testDeleteRemovesRule() {
        service.learn(merchant: "Spotify", description: "", categoryId: "subscriptions")
        let rule = service.rule(forKey: "spotify")
        XCTAssertNotNil(rule)

        service.delete(rule!)

        XCTAssertTrue(service.allRules().isEmpty)
        XCTAssertNil(service.suggestedCategoryId(merchant: "Spotify", description: ""))
    }

    func testSetCategoryUpdatesRule() {
        service.learn(merchant: "Amazon", description: "", categoryId: "shopping")
        let rule = service.rule(forKey: "amazon")!

        service.setCategory(rule, to: "subscriptions")

        XCTAssertEqual(service.suggestedCategoryId(merchant: "Amazon", description: ""), "subscriptions")
    }
}
