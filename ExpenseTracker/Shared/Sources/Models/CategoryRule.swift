import Foundation
import SwiftData

/// A learned association between a normalised merchant/description key and a
/// category. Created or reinforced whenever the user manually assigns a
/// category, so the app can auto-apply it to future transactions with the
/// same name.
@Model
public final class CategoryRule {
    public var id: UUID
    /// Normalised lookup key (see `MerchantKey.normalize`).
    public var key: String
    public var categoryId: String
    /// How many times this rule has been set/reinforced.
    public var hitCount: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        key: String,
        categoryId: String,
        hitCount: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.key = key
        self.categoryId = categoryId
        self.hitCount = hitCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
