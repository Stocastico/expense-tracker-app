#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// On-device LLM categoriser backed by Apple Foundation Models (Apple
/// Intelligence). Private and free; runs entirely on device.
///
/// Requires macOS 26 + Apple Silicon at runtime and the macOS 26 SDK
/// (Xcode 17) to build — hence the `canImport` guard, which keeps the rest of
/// the app building on Xcode 16 and in CI. On any unavailability or error this
/// returns `nil` so callers fall back to `HeuristicCategorizationEngine`.
///
/// NOTE: This path cannot run in the current CI (Xcode 16) and should be
/// validated on a macOS 26 toolchain before relying on it.
@available(macOS 26.0, *)
public struct FoundationModelsCategorizationEngine: CategorizationEngine {
    public init() {}

    public func suggestCategoryId(merchant: String?, description: String, candidates: [Category]) async -> String? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        guard !candidates.isEmpty else { return nil }

        let catalogue = candidates.map { "\($0.id) — \($0.name)" }.joined(separator: "\n")
        let prompt = """
        You categorise a single bank/credit-card transaction.
        Merchant: \(merchant ?? "(unknown)")
        Description: \(description)

        Choose the single best matching category from this list and answer with \
        ONLY its id (the text before the dash), nothing else:
        \(catalogue)
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            let answer = response.content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            if let exact = candidates.first(where: { $0.id.lowercased() == answer }) {
                return exact.id
            }
            // The model may wrap the id in extra words; match by containment.
            if let contained = candidates.first(where: { answer.contains($0.id.lowercased()) }) {
                return contained.id
            }
            return nil
        } catch {
            return nil
        }
    }
}
#endif
