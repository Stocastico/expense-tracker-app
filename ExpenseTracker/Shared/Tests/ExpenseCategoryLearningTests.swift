import Testing
import Foundation

/// Drives the pure, two-level category learner: it remembers which
/// category/subcategory the user assigned to a merchant and suggests it for
/// future transactions with the same (normalised) name. This is the domain
/// analogue of the legacy flat `CategoryRuleService`, but free of SwiftData.
struct ExpenseCategoryLearningTests {

    private let groceries = UUID()
    private let supermarket = UUID()
    private let subscriptions = UUID()

    @Test("Learning a merchant then suggesting returns the same assignment")
    func learnThenSuggest() {
        var learner = ExpenseDomain.CategoryLearner()
        learner.learn(merchant: "Mercadona", description: "",
                      categoryId: groceries, subcategoryId: supermarket)

        let suggestion = learner.suggestion(merchant: "Mercadona", description: "")
        #expect(suggestion?.categoryId == groceries)
        #expect(suggestion?.subcategoryId == supermarket)
    }

    @Test("An unknown merchant yields no suggestion")
    func unknownMerchant() {
        let learner = ExpenseDomain.CategoryLearner()
        #expect(learner.suggestion(merchant: "Totally Unknown", description: "") == nil)
    }

    @Test("Normalisation matches across branch/card numbers and case")
    func normalisationMatches() {
        var learner = ExpenseDomain.CategoryLearner()
        learner.learn(merchant: "MERCADONA 1234 BILBAO", description: "",
                      categoryId: groceries, subcategoryId: supermarket)

        let suggestion = learner.suggestion(merchant: "Mercadona 9876 BILBAO", description: "")
        #expect(suggestion?.categoryId == groceries)
        #expect(suggestion?.subcategoryId == supermarket)
    }

    @Test("A subcategory-less assignment is remembered with no subcategory")
    func learnsWithoutSubcategory() {
        var learner = ExpenseDomain.CategoryLearner()
        learner.learn(merchant: "Spotify", description: "",
                      categoryId: subscriptions, subcategoryId: nil)

        let suggestion = learner.suggestion(merchant: "spotify", description: "")
        #expect(suggestion?.categoryId == subscriptions)
        #expect(suggestion?.subcategoryId == nil)
    }

    @Test("Relearning the same key updates the assignment and reinforces it")
    func relearningUpdatesAndReinforces() {
        var learner = ExpenseDomain.CategoryLearner()
        learner.learn(merchant: "Amazon", description: "",
                      categoryId: groceries, subcategoryId: nil)
        learner.learn(merchant: "AMAZON", description: "",
                      categoryId: subscriptions, subcategoryId: nil)

        #expect(learner.suggestion(merchant: "amazon", description: "")?.categoryId == subscriptions)
        // No duplicate rule for the same normalised key, and the hit count grew.
        #expect(learner.rules.count == 1)
        #expect(learner.rules.first?.hitCount == 2)
    }

    @Test("Learning returns nil when no usable key can be derived")
    func learnReturnsNilWithoutUsableKey() {
        var learner = ExpenseDomain.CategoryLearner()
        #expect(learner.learn(merchant: nil, description: "   ",
                              categoryId: groceries, subcategoryId: nil) == nil)
        #expect(learner.rules.isEmpty)
    }

    @Test("Rules are exposed most-reinforced first")
    func rulesSortedByHitCount() {
        var learner = ExpenseDomain.CategoryLearner()
        learner.learn(merchant: "Mercadona", description: "", categoryId: groceries, subcategoryId: nil)
        learner.learn(merchant: "Spotify", description: "", categoryId: subscriptions, subcategoryId: nil)
        learner.learn(merchant: "Spotify", description: "", categoryId: subscriptions, subcategoryId: nil)

        #expect(learner.rules.count == 2)
        #expect(learner.rules.first?.key == "spotify")
        #expect(learner.rules.first?.hitCount == 2)
    }
}
