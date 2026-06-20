import Foundation
import SwiftData

/// App-facing categoriser that layers, in priority order:
/// 1. learned rules (a category the user assigned to this name before),
/// 2. a `CategorizationEngine` (heuristic today, on-device LLM when available).
public struct CategoryResolver {
    private let ruleService: CategoryRuleService
    private let engine: CategorizationEngine

    public init(modelContext: ModelContext, engine: CategorizationEngine = HeuristicCategorizationEngine()) {
        self.ruleService = CategoryRuleService(modelContext: modelContext)
        self.engine = engine
    }

    public func resolve(merchant: String?, description: String, candidates: [Category]) async -> String? {
        if let learned = ruleService.suggestedCategoryId(merchant: merchant, description: description) {
            return learned
        }
        return await engine.suggestCategoryId(merchant: merchant, description: description, candidates: candidates)
    }
}
