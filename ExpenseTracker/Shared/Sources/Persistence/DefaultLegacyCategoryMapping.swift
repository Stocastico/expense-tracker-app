import Foundation

/// Maps a legacy flat category id (the `String` ids from `DefaultCategories`)
/// onto the new Italian two-level catalog. Produces a
/// `LegacyExpenseMigration.CategoryResolver` bound to a given catalog.
///
/// Categories the new fixed catalog deliberately omits (entertainment,
/// education, insurance, personal-care) fold into `Varie` ("misc"). Income ids
/// are absent from the table, so income transactions stay uncategorized.
public enum DefaultLegacyCategoryMapping {

    /// legacy id → (catalog category display name, optional subcategory name).
    static let table: [String: (category: String, subcategory: String?)] = [
        "food-dining": ("Fuori casa", nil),
        "groceries": ("Spesa", nil),
        "transport": ("Trasporti", nil),
        "housing": ("Casa", nil),
        "utilities": ("Casa", nil),
        "healthcare": ("Salute", nil),
        "entertainment": ("Varie", nil),
        "shopping": ("Shopping", nil),
        "education": ("Varie", nil),
        "travel": ("Viaggi", nil),
        "insurance": ("Varie", nil),
        "personal-care": ("Varie", nil),
        "gifts": ("Shopping", "regali"),
        "subscriptions": ("Abbonamenti", nil),
        "other": ("Varie", nil),
    ]

    /// Builds a resolver against the given catalog (defaults to the Italian seed).
    public static func resolver(
        catalog: ExpenseDomain.Catalog = DefaultExpenseCategories.catalog
    ) -> LegacyExpenseMigration.CategoryResolver {
        return { legacyId in
            guard
                let entry = table[legacyId],
                let category = catalog.category(named: entry.category)
            else {
                return nil
            }
            guard let subcategoryName = entry.subcategory else {
                return (category, nil)
            }
            let subcategory = catalog.subcategories(of: category)
                .first { $0.displayName == subcategoryName }
            return (category, subcategory)
        }
    }
}
