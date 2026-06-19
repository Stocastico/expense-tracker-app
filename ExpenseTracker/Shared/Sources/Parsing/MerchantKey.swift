import Foundation

/// Produces a stable, normalised key from a transaction's merchant or
/// description, used to look up and store learned category rules so the app
/// can remember "this name → this category".
public enum MerchantKey {

    /// Normalises the merchant (or, if absent, the description) into a lookup
    /// key: diacritics folded, lowercased, punctuation collapsed to single
    /// spaces, and pure-digit tokens (card/branch numbers) dropped.
    ///
    /// - Returns: The normalised key, or `nil` if nothing usable remains.
    public static func normalize(merchant: String?, description: String) -> String? {
        // Stub: implementation follows in the green commit.
        return nil
    }
}
