import Testing
import Foundation

/// Drives the default legacy-id → Italian-catalog mapping used when migrating
/// old data. Resolves against `DefaultExpenseCategories.catalog`.
struct DefaultLegacyCategoryMappingTests {

    private let resolve = DefaultLegacyCategoryMapping.resolver()

    @Test("A clean legacy category maps to its catalog category, no subcategory")
    func mapsCleanCategory() {
        let resolved = resolve("transport")
        #expect(resolved?.category.displayName == "Trasporti")
        #expect(resolved?.subcategory == nil)
    }

    @Test("Legacy utilities folds into Casa (bollette/internet live there)")
    func mapsUtilitiesIntoCasa() {
        #expect(resolve("utilities")?.category.displayName == "Casa")
    }

    @Test("Legacy gifts maps to Shopping › regali, and the subcategory is a child")
    func mapsGiftsToShoppingRegali() throws {
        let resolved = try #require(resolve("gifts"))
        #expect(resolved.category.displayName == "Shopping")
        #expect(resolved.subcategory?.displayName == "regali")
        #expect(resolved.subcategory?.isChild(of: resolved.category) == true)
    }

    @Test("The four orphan categories all fold into Varie")
    func mapsOrphansToVarie() {
        for id in ["entertainment", "education", "insurance", "personal-care"] {
            #expect(resolve(id)?.category.displayName == "Varie")
            #expect(resolve(id)?.subcategory == nil)
        }
    }

    @Test("Income ids, unknown ids and empty strings resolve to nil")
    func unknownAndIncomeReturnNil() {
        #expect(resolve("salary") == nil)
        #expect(resolve("does-not-exist") == nil)
        #expect(resolve("") == nil)
    }

    @Test("Every mapped expense category exists in the catalog")
    func resolvedCategoriesExistInCatalog() throws {
        let catalog = DefaultExpenseCategories.catalog
        let legacyExpenseIds = [
            "food-dining", "groceries", "transport", "housing", "utilities",
            "healthcare", "entertainment", "shopping", "education", "travel",
            "insurance", "personal-care", "gifts", "subscriptions", "other",
        ]
        for id in legacyExpenseIds {
            let resolved = try #require(resolve(id), "expected a mapping for \(id)")
            #expect(catalog.categories.contains(resolved.category))
        }
    }
}
