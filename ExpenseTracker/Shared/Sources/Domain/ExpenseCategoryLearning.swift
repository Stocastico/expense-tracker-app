import Foundation

extension ExpenseDomain {

    // MARK: - Suggestion

    /// A learned two-level category assignment suggested for a merchant: a
    /// top-level category and, when one was learned, its subcategory.
    public struct CategorySuggestion: Hashable, Sendable {
        public let categoryId: UUID
        public let subcategoryId: UUID?

        public init(categoryId: UUID, subcategoryId: UUID? = nil) {
            self.categoryId = categoryId
            self.subcategoryId = subcategoryId
        }
    }

    // MARK: - Rule

    /// A learned association between a normalised merchant/description key and a
    /// two-level category assignment. Created or reinforced whenever the user
    /// manually assigns a category, so the app can auto-apply it to future
    /// transactions with the same name.
    ///
    /// The domain analogue of the legacy flat `CategoryRule`, but a pure value
    /// type holding `UUID` category ids (two levels) instead of a SwiftData
    /// `@Model` keyed on a flat-catalog string id.
    public struct CategoryRule: Identifiable, Hashable, Sendable {
        public let id: UUID
        /// Normalised lookup key (see `MerchantKey.normalize`).
        public let key: String
        public var categoryId: UUID
        public var subcategoryId: UUID?
        /// How many times this rule has been set/reinforced.
        public var hitCount: Int
        public var createdAt: Date
        public var updatedAt: Date

        public init(
            id: UUID = UUID(),
            key: String,
            categoryId: UUID,
            subcategoryId: UUID? = nil,
            hitCount: Int = 1,
            createdAt: Date = Date(),
            updatedAt: Date = Date()
        ) {
            self.id = id
            self.key = key
            self.categoryId = categoryId
            self.subcategoryId = subcategoryId
            self.hitCount = hitCount
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }

        /// The assignment this rule suggests.
        public var suggestion: CategorySuggestion {
            CategorySuggestion(categoryId: categoryId, subcategoryId: subcategoryId)
        }
    }

    // MARK: - Learner

    /// A pure, persistence-agnostic store of learned category rules.
    ///
    /// Keys are derived with `MerchantKey.normalize` so they line up with the
    /// legacy rule scheme (diacritics folded, case-insensitive, branch/card
    /// numbers dropped). Learning a key that already exists updates its
    /// assignment and reinforces it rather than creating a duplicate, so the
    /// most recent manual choice always wins.
    public struct CategoryLearner: Equatable, Sendable {

        /// Rules keyed by their normalised lookup key.
        private var rulesByKey: [String: CategoryRule]

        public init(rules: [CategoryRule] = []) {
            rulesByKey = Dictionary(rules.map { ($0.key, $0) }) { _, latest in latest }
        }

        /// All learned rules, most-reinforced first (ties broken by key).
        public var rules: [CategoryRule] {
            rulesByKey.values.sorted {
                $0.hitCount != $1.hitCount ? $0.hitCount > $1.hitCount : $0.key < $1.key
            }
        }

        /// The rule stored for an already-normalised key, if any.
        public func rule(forKey key: String) -> CategoryRule? {
            rulesByKey[key]
        }

        /// The learned assignment for the given merchant/description, if any.
        public func suggestion(merchant: String?, description: String) -> CategorySuggestion? {
            guard let key = MerchantKey.normalize(merchant: merchant, description: description) else {
                return nil
            }
            return rulesByKey[key]?.suggestion
        }

        /// Records that the given merchant/description maps to the assignment,
        /// creating a rule or reinforcing (and updating) an existing one.
        ///
        /// - Returns: The stored rule, or `nil` if no usable key could be derived.
        @discardableResult
        public mutating func learn(
            merchant: String?,
            description: String,
            categoryId: UUID,
            subcategoryId: UUID?,
            date: Date = Date()
        ) -> CategoryRule? {
            guard let key = MerchantKey.normalize(merchant: merchant, description: description) else {
                return nil
            }

            if var existing = rulesByKey[key] {
                existing.categoryId = categoryId
                existing.subcategoryId = subcategoryId
                existing.hitCount += 1
                existing.updatedAt = date
                rulesByKey[key] = existing
                return existing
            }

            let rule = CategoryRule(
                key: key,
                categoryId: categoryId,
                subcategoryId: subcategoryId,
                createdAt: date,
                updatedAt: date
            )
            rulesByKey[key] = rule
            return rule
        }
    }
}
