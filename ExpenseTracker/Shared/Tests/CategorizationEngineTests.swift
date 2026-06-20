import XCTest
import Foundation
import SwiftData

final class CategorizationEngineTests: XCTestCase {

    // MARK: - Heuristic engine

    func testHeuristicMatchesKeyword() async {
        let engine = HeuristicCategorizationEngine()
        let id = await engine.suggestCategoryId(merchant: nil, description: "netflix monthly",
                                                candidates: DefaultCategories.all)
        XCTAssertEqual(id, "subscriptions")
    }

    func testHeuristicUsesMerchant() async {
        let engine = HeuristicCategorizationEngine()
        let id = await engine.suggestCategoryId(merchant: "Uber", description: "ride",
                                                candidates: DefaultCategories.all)
        XCTAssertEqual(id, "transport")
    }

    func testHeuristicReturnsNilForUnknown() async {
        let engine = HeuristicCategorizationEngine()
        let id = await engine.suggestCategoryId(merchant: nil, description: "zzzqwxyz",
                                                candidates: DefaultCategories.all)
        XCTAssertNil(id)
    }

    func testHeuristicRespectsCandidateList() async {
        // Even though "netflix" maps to subscriptions, exclude it from candidates.
        let engine = HeuristicCategorizationEngine()
        let candidates = DefaultCategories.all.filter { $0.id != "subscriptions" }
        let id = await engine.suggestCategoryId(merchant: nil, description: "netflix",
                                                candidates: candidates)
        XCTAssertNil(id)
    }

    // MARK: - Resolver (learned rules + engine)

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Transaction.self, Account.self, Budget.self, AppSettings.self, CategoryRule.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    func testResolverPrefersLearnedRuleOverEngine() async throws {
        let context = try makeContext()
        // Learn a deliberately different category to prove precedence.
        CategoryRuleService(modelContext: context).learn(merchant: "Netflix", description: "", categoryId: "shopping")

        let resolver = CategoryResolver(modelContext: context)
        let id = await resolver.resolve(merchant: "Netflix", description: "netflix monthly",
                                        candidates: DefaultCategories.all)
        XCTAssertEqual(id, "shopping")
    }

    func testResolverFallsBackToEngine() async throws {
        let context = try makeContext()
        let resolver = CategoryResolver(modelContext: context)
        let id = await resolver.resolve(merchant: nil, description: "uber ride downtown",
                                        candidates: DefaultCategories.all)
        XCTAssertEqual(id, "transport")
    }

    func testResolverReturnsNilWhenNothingMatches() async throws {
        let context = try makeContext()
        let resolver = CategoryResolver(modelContext: context)
        let id = await resolver.resolve(merchant: nil, description: "zzzqwxyz",
                                        candidates: DefaultCategories.all)
        XCTAssertNil(id)
    }
}
