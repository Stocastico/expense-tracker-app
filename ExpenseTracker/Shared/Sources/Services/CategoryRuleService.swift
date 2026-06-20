import Foundation
import SwiftData

/// Stores and looks up learned category rules so the app remembers which
/// category the user assigned to a given merchant/description.
///
/// Lookup precedence is the caller's responsibility, but learned rules are
/// meant to win over heuristic/LLM suggestions.
public struct CategoryRuleService {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Records that the given merchant/description maps to `categoryId`,
    /// creating a rule or reinforcing (and updating) an existing one.
    ///
    /// - Returns: The stored rule, or `nil` if no usable key could be derived.
    @discardableResult
    public func learn(merchant: String?, description: String, categoryId: String) -> CategoryRule? {
        guard let key = MerchantKey.normalize(merchant: merchant, description: description) else {
            return nil
        }

        if let existing = rule(forKey: key) {
            existing.categoryId = categoryId
            existing.hitCount += 1
            existing.updatedAt = Date()
            try? modelContext.save()
            return existing
        }

        let rule = CategoryRule(key: key, categoryId: categoryId)
        modelContext.insert(rule)
        try? modelContext.save()
        return rule
    }

    /// The learned category id for the given merchant/description, if any.
    public func suggestedCategoryId(merchant: String?, description: String) -> String? {
        guard let key = MerchantKey.normalize(merchant: merchant, description: description) else {
            return nil
        }
        return rule(forKey: key)?.categoryId
    }

    /// The rule stored for an already-normalised key, if any.
    public func rule(forKey key: String) -> CategoryRule? {
        var descriptor = FetchDescriptor<CategoryRule>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    /// All learned rules, most-reinforced first.
    public func allRules() -> [CategoryRule] {
        let descriptor = FetchDescriptor<CategoryRule>(
            sortBy: [SortDescriptor(\.hitCount, order: .reverse), SortDescriptor(\.key)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Deletes a learned rule.
    public func delete(_ rule: CategoryRule) {
        modelContext.delete(rule)
        try? modelContext.save()
    }

    /// Changes the category a learned rule maps to.
    public func setCategory(_ rule: CategoryRule, to categoryId: String) {
        rule.categoryId = categoryId
        rule.updatedAt = Date()
        try? modelContext.save()
    }
}
