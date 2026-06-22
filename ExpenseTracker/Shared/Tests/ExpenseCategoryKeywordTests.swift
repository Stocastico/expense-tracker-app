import Testing
import Foundation

/// Drives the pure keyword matcher that seeds an initial two-level category for
/// a description when nothing has been learned yet — the domain, two-level
/// equivalent of the legacy flat `DefaultCategories.detectCategory`.
struct ExpenseCategoryKeywordTests {

    private let spesa = UUID()
    private let supermercato = UUID()
    private let trasporti = UUID()
    private let benzina = UUID()

    @Test("Matches a keyword as a case-insensitive substring and carries the subcategory")
    func matchesSubstring() {
        let matcher = ExpenseDomain.CategoryKeywordMatcher([
            .init(keyword: "mercadona", categoryId: spesa, subcategoryId: supermercato),
        ])
        let suggestion = matcher.suggestion(for: "COMPRA EN MERCADONA 1234 BILBAO")
        #expect(suggestion?.categoryId == spesa)
        #expect(suggestion?.subcategoryId == supermercato)
    }

    @Test("Matching ignores diacritics")
    func ignoresDiacritics() {
        let matcher = ExpenseDomain.CategoryKeywordMatcher([
            .init(keyword: "cafe", categoryId: spesa, subcategoryId: nil),
        ])
        #expect(matcher.suggestion(for: "PAGO EN CAFÉ CENTRAL")?.categoryId == spesa)
    }

    @Test("The first matching rule wins (rules are in priority order)")
    func firstMatchWins() {
        let matcher = ExpenseDomain.CategoryKeywordMatcher([
            .init(keyword: "repsol", categoryId: trasporti, subcategoryId: benzina),
            .init(keyword: "sol", categoryId: spesa, subcategoryId: nil),
        ])
        #expect(matcher.suggestion(for: "REPSOL E.S. 42")?.categoryId == trasporti)
    }

    @Test("No keyword match yields no suggestion")
    func noMatch() {
        let matcher = ExpenseDomain.CategoryKeywordMatcher([
            .init(keyword: "mercadona", categoryId: spesa, subcategoryId: supermercato),
        ])
        #expect(matcher.suggestion(for: "Totally unrelated text") == nil)
    }

    @Test("An empty rule set never matches")
    func emptyRules() {
        let matcher = ExpenseDomain.CategoryKeywordMatcher([])
        #expect(matcher.suggestion(for: "Mercadona") == nil)
    }
}
