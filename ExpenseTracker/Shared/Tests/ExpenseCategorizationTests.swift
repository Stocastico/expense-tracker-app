import Testing
import Foundation

/// Tests driving out the pure, persistence-agnostic two-level expense
/// categorization domain (`ExpenseDomain`). Written with Swift Testing.
struct ExpenseCategorizationTests {

    // MARK: - Category / Subcategory hierarchy

    @Test("A subcategory references its parent category by id")
    func subcategoryReferencesParent() {
        let casa = ExpenseDomain.Category(displayName: "Casa")
        let bollette = ExpenseDomain.Subcategory(displayName: "bollette", parentId: casa.id)

        #expect(bollette.parentId == casa.id)
        #expect(bollette.isChild(of: casa))
    }

    @Test("A subcategory whose parent id differs is not a child of the category")
    func orphanSubcategoryIsNotChild() {
        let casa = ExpenseDomain.Category(displayName: "Casa")
        let spesa = ExpenseDomain.Category(displayName: "Spesa")
        let orphan = ExpenseDomain.Subcategory(displayName: "bollette", parentId: spesa.id)

        #expect(orphan.isChild(of: casa) == false)
    }

    @Test("A catalog flags subcategories whose parent is missing as orphans")
    func catalogDetectsOrphans() {
        let casa = ExpenseDomain.Category(displayName: "Casa")
        let valid = ExpenseDomain.Subcategory(displayName: "bollette", parentId: casa.id)
        let orphan = ExpenseDomain.Subcategory(displayName: "ghost", parentId: UUID())

        let good = ExpenseDomain.Catalog(categories: [casa], subcategories: [valid])
        #expect(good.orphanedSubcategories.isEmpty)
        #expect(good.isValid)

        let bad = ExpenseDomain.Catalog(categories: [casa], subcategories: [valid, orphan])
        #expect(bad.orphanedSubcategories == [orphan])
        #expect(bad.isValid == false)
    }

    // MARK: - Seed data

    @Test("Seed catalog has no orphaned subcategories")
    func seedCatalogIsValid() {
        #expect(DefaultExpenseCategories.catalog.isValid)
    }

    @Test("Seed data contains the 9 expected Italian top-level categories")
    func seedHasNineTopLevelCategories() {
        let names = DefaultExpenseCategories.catalog.categories.map(\.displayName)
        #expect(names == [
            "Casa", "Spesa", "Fuori casa", "Trasporti", "Salute",
            "Abbonamenti", "Shopping", "Viaggi", "Varie",
        ])
    }

    @Test("Each top-level category has the expected subcategories")
    func seedHasExpectedSubcategories() {
        let expected: [String: [String]] = [
            "Casa": ["mutuo/affitto", "bollette", "internet/telefono", "manutenzione", "condominio"],
            "Spesa": ["supermercato", "fruttivendolo/macelleria", "prodotti per la casa"],
            "Fuori casa": ["bar/caffetteria", "ristoranti", "take-away/delivery"],
            "Trasporti": ["benzina", "mezzi pubblici", "assicurazione/bollo", "taxi", "manutenzione veicolo"],
            "Salute": ["farmacia", "medico/dentista", "palestra"],
            "Abbonamenti": ["streaming", "software", "cloud", "riviste"],
            "Shopping": ["vestiti", "elettronica", "libri", "regali"],
            "Viaggi": ["voli", "hotel", "vacanze"],
            "Varie": [],
        ]

        let catalog = DefaultExpenseCategories.catalog
        for category in catalog.categories {
            let actual = catalog.subcategories(of: category).map(\.displayName)
            #expect(actual == expected[category.displayName], "subcategories of \(category.displayName)")
        }
    }

    // MARK: - Identity: unique & stable

    @Test("All seeded ids are unique across categories, subcategories and tags")
    func seededIdsAreUnique() {
        let catalog = DefaultExpenseCategories.catalog
        var ids: [UUID] = []
        ids += catalog.categories.map(\.id)
        ids += catalog.subcategories.map(\.id)
        ids += DefaultExpenseCategories.tags.map(\.id)

        #expect(Set(ids).count == ids.count)
    }

    @Test("Seeded ids are stable across repeated seeding")
    func seededIdsAreStable() {
        let first = DefaultExpenseCategories.catalog
        let second = DefaultExpenseCategories.catalog

        #expect(first.categories.map(\.id) == second.categories.map(\.id))
        #expect(first.subcategories.map(\.id) == second.subcategories.map(\.id))
    }

    // MARK: - Transaction

    @Test("An income transaction carries no expense category or subcategory")
    func incomeHasNoCategory() {
        let salary = ExpenseDomain.Transaction(
            amount: Decimal(string: "2500.00")!,
            type: .income
        )
        #expect(salary.category == nil)
        #expect(salary.subcategory == nil)
        #expect(throws: Never.self) { try salary.validate() }
    }

    @Test("Validation rejects an income transaction that has an expense category")
    func incomeWithCategoryIsInvalid() {
        let casa = ExpenseDomain.Category(displayName: "Casa")
        let bad = ExpenseDomain.Transaction(
            amount: Decimal(string: "100.00")!,
            type: .income,
            category: casa
        )
        #expect(throws: ExpenseDomain.ValidationError.incomeHasCategory) {
            try bad.validate()
        }
    }

    @Test("Validation rejects a subcategory that does not belong to the category")
    func mismatchedSubcategoryIsInvalid() {
        let casa = ExpenseDomain.Category(displayName: "Casa")
        let spesa = ExpenseDomain.Category(displayName: "Spesa")
        let supermercato = ExpenseDomain.Subcategory(displayName: "supermercato", parentId: spesa.id)

        let bad = ExpenseDomain.Transaction(
            amount: Decimal(string: "30.00")!,
            type: .expense,
            category: casa,
            subcategory: supermercato
        )
        #expect(throws: ExpenseDomain.ValidationError.subcategoryParentMismatch) {
            try bad.validate()
        }
    }

    @Test("A transaction can hold multiple tags alongside one category and subcategory")
    func transactionHoldsTagsAndCategory() throws {
        let fuoriCasa = ExpenseDomain.Category(displayName: "Fuori casa")
        let ristoranti = ExpenseDomain.Subcategory(displayName: "ristoranti", parentId: fuoriCasa.id)
        let work = ExpenseDomain.Tag(displayName: "work")
        let reimbursable = ExpenseDomain.Tag(displayName: "reimbursable")

        let dinner = ExpenseDomain.Transaction(
            amount: Decimal(string: "84.50")!,
            type: .expense,
            category: fuoriCasa,
            subcategory: ristoranti,
            tags: [work, reimbursable]
        )

        #expect(dinner.category == fuoriCasa)
        #expect(dinner.subcategory == ristoranti)
        #expect(dinner.tags.count == 2)
        #expect(dinner.tags.contains(work))
        try dinner.validate()
    }

    // MARK: - Money precision

    @Test("Money uses Decimal and sums without floating-point rounding error")
    func decimalMoneyHasNoRoundingError() {
        let a = ExpenseDomain.Transaction(amount: Decimal(string: "0.10")!, type: .expense)
        let b = ExpenseDomain.Transaction(amount: Decimal(string: "0.20")!, type: .expense)

        let sum = a.amount + b.amount
        #expect(sum == Decimal(string: "0.30")!)
        // Sanity check that the equivalent Double computation would NOT be exact.
        #expect(0.1 + 0.2 != 0.3)
    }

    // MARK: - Grouping helper

    @Test("Total spend is grouped per top-level category, ignoring income")
    func totalSpendPerCategory() {
        let casa = ExpenseDomain.Category(displayName: "Casa")
        let spesa = ExpenseDomain.Category(displayName: "Spesa")

        let transactions = [
            ExpenseDomain.Transaction(amount: Decimal(string: "800.00")!, type: .expense, category: casa),
            ExpenseDomain.Transaction(amount: Decimal(string: "50.00")!, type: .expense, category: casa),
            ExpenseDomain.Transaction(amount: Decimal(string: "120.00")!, type: .expense, category: spesa),
            ExpenseDomain.Transaction(amount: Decimal(string: "2500.00")!, type: .income),
        ]

        let totals = ExpenseDomain.totalSpendByCategory(transactions)
        #expect(totals[casa] == Decimal(string: "850.00")!)
        #expect(totals[spesa] == Decimal(string: "120.00")!)
        #expect(totals.count == 2)
    }
}
