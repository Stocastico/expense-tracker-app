import Testing
import Foundation

/// Drives the starter Italian/Spanish keyword seed that maps common merchant
/// names to the default two-level catalog. The mappings are intentionally
/// conservative (brand-heavy, low-ambiguity) and meant to be refined.
struct DefaultExpenseKeywordRulesTests {

    private let catalog = DefaultExpenseCategories.catalog

    /// The suggested top-level category name for a description, if any.
    private func categoryName(_ text: String) -> String? {
        let matcher = DefaultExpenseKeywordRules.matcher(for: catalog)
        guard let suggestion = matcher.suggestion(for: text) else { return nil }
        return catalog.categories.first { $0.id == suggestion.categoryId }?.displayName
    }

    @Test("Representative merchants map to the expected top-level category")
    func representativeMappings() {
        #expect(categoryName("COMPRA EN MERCADONA 1234") == "Spesa")
        #expect(categoryName("REPSOL E.S. 42 BILBAO") == "Trasporti")
        #expect(categoryName("NETFLIX.COM") == "Abbonamenti")
        #expect(categoryName("FARMACIA CRUZ VERDE") == "Salute")
        #expect(categoryName("ZARA BILBAO") == "Shopping")
        #expect(categoryName("RYANAIR") == "Viaggi")
        #expect(categoryName("IBERDROLA CLIENTES") == "Casa")
        #expect(categoryName("xyzzy unrelated") == nil)
    }

    @Test("A seeded merchant resolves to its subcategory too")
    func resolvesSubcategory() throws {
        let matcher = DefaultExpenseKeywordRules.matcher(for: catalog)
        let suggestion = try #require(matcher.suggestion(for: "MERCADONA"))
        let sub = catalog.subcategories.first { $0.id == suggestion.subcategoryId }
        #expect(sub?.displayName == "supermercato")
    }

    @Test("More specific multi-word keywords win over generic brand fallbacks")
    func specificBeatsGeneric() {
        // "uber eats" is delivery (Fuori casa), not a taxi (Trasporti).
        #expect(categoryName("UBER EATS AMSTERDAM") == "Fuori casa")
        // "amazon prime" is a subscription, while a bare "amazon" is shopping.
        #expect(categoryName("AMAZON PRIME") == "Abbonamenti")
        #expect(categoryName("AMAZON.ES") == "Shopping")
    }
}
