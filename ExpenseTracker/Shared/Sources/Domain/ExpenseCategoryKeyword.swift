import Foundation

extension ExpenseDomain {

    // MARK: - Keyword rule

    /// A keyword → two-level category rule. Used to seed an initial category for
    /// a transaction description when nothing has been learned for it yet.
    public struct CategoryKeyword: Hashable, Sendable {
        /// Matched case-insensitively and diacritic-insensitively, as a substring
        /// of the (normalised) description.
        public let keyword: String
        public let categoryId: UUID
        public let subcategoryId: UUID?

        public init(keyword: String, categoryId: UUID, subcategoryId: UUID? = nil) {
            self.keyword = keyword
            self.categoryId = categoryId
            self.subcategoryId = subcategoryId
        }
    }

    // MARK: - Matcher

    /// A pure, ordered keyword matcher: the two-level, domain analogue of the
    /// legacy flat `DefaultCategories.detectCategory`. Rules are tried in order,
    /// so earlier (more specific) rules take precedence over later ones.
    public struct CategoryKeywordMatcher: Sendable {

        private static let posixLocale = Locale(identifier: "en_US_POSIX")

        /// The rules, in priority order, with their keywords pre-normalised.
        private let rules: [CategoryKeyword]

        public init(_ rules: [CategoryKeyword]) {
            self.rules = rules.map {
                CategoryKeyword(
                    keyword: Self.normalize($0.keyword),
                    categoryId: $0.categoryId,
                    subcategoryId: $0.subcategoryId
                )
            }
        }

        /// The first rule whose keyword appears in `text`, as a suggestion, or
        /// `nil` if none match.
        public func suggestion(for text: String) -> CategorySuggestion? {
            let haystack = Self.normalize(text)
            guard let rule = rules.first(where: { !$0.keyword.isEmpty && haystack.contains($0.keyword) })
            else {
                return nil
            }
            return CategorySuggestion(categoryId: rule.categoryId, subcategoryId: rule.subcategoryId)
        }

        /// Folds diacritics and lowercases, matching `MerchantKey`'s folding so
        /// keyword matching and learned-rule lookup treat text the same way.
        private static func normalize(_ text: String) -> String {
            text.folding(options: [.diacriticInsensitive], locale: posixLocale).lowercased()
        }
    }
}
