import Foundation

/// Produces a stable, normalised key from a transaction's merchant or
/// description, used to look up and store learned category rules so the app
/// can remember "this name → this category".
public enum MerchantKey {

    private static let posixLocale = Locale(identifier: "en_US_POSIX")

    /// Normalises the merchant (or, if absent, the description) into a lookup
    /// key: diacritics folded, lowercased, punctuation collapsed to single
    /// spaces, and pure-digit tokens (card/branch numbers) dropped.
    ///
    /// - Returns: The normalised key, or `nil` if nothing usable remains.
    public static func normalize(merchant: String?, description: String) -> String? {
        let source: String
        if let merchant, !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            source = merchant
        } else {
            source = description
        }

        let folded = source
            .folding(options: [.diacriticInsensitive], locale: posixLocale)
            .lowercased()

        let tokens = folded
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { token in !token.allSatisfy { $0.isNumber } }

        let key = tokens.joined(separator: " ")
        return key.isEmpty ? nil : key
    }
}
