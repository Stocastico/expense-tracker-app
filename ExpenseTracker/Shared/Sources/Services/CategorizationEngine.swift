import Foundation

/// Abstraction over "what category does this transaction belong to?", so the
/// on-device LLM path (Apple Foundation Models) can be swapped for a
/// deterministic heuristic in tests/CI and on older systems.
public protocol CategorizationEngine {
    /// Suggests a category id for a transaction, restricted to `candidates`.
    /// Returns `nil` if no confident suggestion is available.
    func suggestCategoryId(merchant: String?, description: String, candidates: [Category]) async -> String?
}

/// Deterministic keyword-based engine (no AI). Always available; used as the
/// fallback when the on-device model is unavailable.
public struct HeuristicCategorizationEngine: CategorizationEngine {
    public init() {}

    public func suggestCategoryId(merchant: String?, description: String, candidates: [Category]) async -> String? {
        guard let id = SmartCategoryService.suggestCategory(for: description, merchant: merchant) else {
            return nil
        }
        return candidates.contains(where: { $0.id == id }) ? id : nil
    }
}
