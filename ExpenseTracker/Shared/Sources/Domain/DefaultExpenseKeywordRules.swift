import Foundation

/// Starter Italian/Spanish keyword seed mapping common merchant names to the
/// default two-level catalog, used to suggest an initial category for an
/// imported transaction when nothing has been learned for it yet.
///
/// **These mappings are intentionally a conservative starting point** —
/// brand-heavy and low-ambiguity, biased toward Spanish (Kutxabank) and Italian
/// statements. Refine freely: add/keywords, reorder, or retune. Order matters —
/// rules are tried top-to-bottom and the first substring match wins, so more
/// specific multi-word keywords (e.g. `uber eats`, `amazon prime`) are listed
/// before generic brand fallbacks (`uber`, `amazon`).
public enum DefaultExpenseKeywordRules {

    /// (top-level category, subcategory or nil, keywords) in priority order.
    /// Names must match `DefaultExpenseCategories`.
    private static let groups: [(category: String, subcategory: String?, keywords: [String])] = [
        // Food delivery before ride-hailing, so "uber eats" doesn't read as a taxi.
        ("Fuori casa", "take-away/delivery", ["glovo", "just eat", "justeat", "deliveroo", "uber eats", "ubereats"]),

        // Subscriptions: "amazon prime" / "movistar+" before the generic brands below.
        ("Abbonamenti", "streaming", ["netflix", "spotify", "disney+", "disney plus", "hbo", "dazn", "prime video", "amazon prime", "filmin", "movistar+"]),
        ("Abbonamenti", "software", ["adobe", "microsoft 365", "office 365", "jetbrains", "github", "openai", "chatgpt"]),
        ("Abbonamenti", "cloud", ["icloud", "dropbox", "google one"]),

        ("Trasporti", "benzina", ["repsol", "cepsa", "galp", "gasolinera", "estacion de servicio", "agip", "tamoil", "q8"]),
        ("Trasporti", "mezzi pubblici", ["renfe", "euskotren", "metro bilbao", "trenitalia", "alsa"]),
        ("Trasporti", "taxi", ["taxi", "cabify", "free now", "freenow", "bolt.eu", "uber"]),

        ("Salute", "farmacia", ["farmacia", "parafarmacia"]),
        ("Salute", "palestra", ["gimnasio", "palestra", "basic-fit", "basicfit", "mcfit", "vivagym"]),

        ("Casa", "bollette", ["iberdrola", "endesa", "naturgy", "enel", "gas natural"]),
        ("Casa", "internet/telefono", ["vodafone", "movistar", "orange", "jazztel", "masmovil", "mas movil", "telefonica", "fastweb", "wind tre"]),
        ("Casa", "mutuo/affitto", ["hipoteca", "alquiler", "affitto", "mutuo"]),

        ("Spesa", "supermercato", ["mercadona", "carrefour", "eroski", "lidl", "alcampo", "consum", "esselunga", "conad", "supermercato", "supermercado"]),
        ("Spesa", "fruttivendolo/macelleria", ["carniceria", "fruteria", "macelleria", "fruttivendolo", "pescaderia"]),

        ("Fuori casa", "ristoranti", ["restaurante", "ristorante", "pizzeria", "trattoria", "osteria"]),
        ("Fuori casa", "bar/caffetteria", ["cafeteria", "caffetteria", "starbucks", "panaderia", "pasticceria"]),

        ("Shopping", "vestiti", ["zara", "h&m", "primark", "decathlon", "bershka", "pull&bear", "uniqlo", "stradivarius"]),
        ("Shopping", "elettronica", ["mediamarkt", "media markt", "pccomponentes", "fnac", "worten"]),
        ("Shopping", "libri", ["casa del libro", "libreria", "feltrinelli"]),
        // Generic shopping fallback — after "amazon prime" above.
        ("Shopping", nil, ["amazon", "aliexpress", "ebay"]),

        ("Viaggi", "voli", ["ryanair", "vueling", "iberia", "easyjet", "ita airways", "air europa", "lufthansa", "wizz air", "klm"]),
        ("Viaggi", "hotel", ["booking", "airbnb", "hotel", "hostal", "parador"]),
    ]

    /// Resolves the seed against a catalog: category/subcategory ids are looked
    /// up by display name; groups whose category isn't present are skipped.
    public static func rules(for catalog: ExpenseDomain.Catalog) -> [ExpenseDomain.CategoryKeyword] {
        var rules: [ExpenseDomain.CategoryKeyword] = []
        for group in groups {
            guard let category = catalog.categories.first(where: { $0.displayName == group.category }) else {
                continue
            }
            let subcategoryId = group.subcategory.flatMap { name in
                catalog.subcategories(of: category).first { $0.displayName == name }?.id
            }
            for keyword in group.keywords {
                rules.append(ExpenseDomain.CategoryKeyword(
                    keyword: keyword, categoryId: category.id, subcategoryId: subcategoryId
                ))
            }
        }
        return rules
    }

    /// A matcher built from the seed resolved against `catalog`.
    public static func matcher(for catalog: ExpenseDomain.Catalog) -> ExpenseDomain.CategoryKeywordMatcher {
        ExpenseDomain.CategoryKeywordMatcher(rules(for: catalog))
    }
}
