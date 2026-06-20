import Foundation

/// Default Italian categorization seed for the expense domain.
///
/// Ids are derived deterministically from stable string keys
/// (`ExpenseDomain.StableID`), so seeding twice yields identical ids and a
/// seeded entity keeps its identity once persisted.
public enum DefaultExpenseCategories {

    /// Top-level category → its subcategories, in display order. `Varie`
    /// ("misc") intentionally has no subcategories.
    private static let definitions: [(category: String, subcategories: [String])] = [
        ("Casa", ["mutuo/affitto", "bollette", "internet/telefono", "manutenzione", "condominio"]),
        ("Spesa", ["supermercato", "fruttivendolo/macelleria", "prodotti per la casa"]),
        ("Fuori casa", ["bar/caffetteria", "ristoranti", "take-away/delivery"]),
        ("Trasporti", ["benzina", "mezzi pubblici", "assicurazione/bollo", "taxi", "manutenzione veicolo"]),
        ("Salute", ["farmacia", "medico/dentista", "palestra"]),
        ("Abbonamenti", ["streaming", "software", "cloud", "riviste"]),
        ("Shopping", ["vestiti", "elettronica", "libri", "regali"]),
        ("Viaggi", ["voli", "hotel", "vacanze"]),
        ("Varie", []),
    ]

    /// A few orthogonal starter tags. Tags are not part of the hierarchy.
    private static let tagNames = ["work", "personal", "reimbursable", "vacanza", "regalo"]

    /// The seeded categories with their subcategories and integrity checks.
    public static var catalog: ExpenseDomain.Catalog {
        var categories: [ExpenseDomain.Category] = []
        var subcategories: [ExpenseDomain.Subcategory] = []

        for definition in definitions {
            let category = ExpenseDomain.Category(
                id: ExpenseDomain.StableID.make("category:\(definition.category)"),
                displayName: definition.category
            )
            categories.append(category)

            for name in definition.subcategories {
                subcategories.append(
                    ExpenseDomain.Subcategory(
                        id: ExpenseDomain.StableID.make("subcategory:\(definition.category)/\(name)"),
                        displayName: name,
                        parentId: category.id
                    )
                )
            }
        }

        return ExpenseDomain.Catalog(categories: categories, subcategories: subcategories)
    }

    /// The seeded starter tags.
    public static var tags: [ExpenseDomain.Tag] {
        tagNames.map { name in
            ExpenseDomain.Tag(
                id: ExpenseDomain.StableID.make("tag:\(name)"),
                displayName: name
            )
        }
    }
}
