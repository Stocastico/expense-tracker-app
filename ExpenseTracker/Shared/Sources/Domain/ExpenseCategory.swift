import Foundation

extension ExpenseDomain {

    // MARK: - Category (top level)

    /// A top-level, user-editable expense category. Identity is a stable `UUID`
    /// rather than an enum case so the category list can be created and edited
    /// by the user at runtime.
    public struct Category: Identifiable, Hashable, Sendable {
        public let id: UUID
        public var displayName: String

        public init(id: UUID = UUID(), displayName: String) {
            self.id = id
            self.displayName = displayName
        }
    }

    // MARK: - Subcategory (child)

    /// A second-level category that references its parent `Category` by id.
    /// A subcategory is only meaningful in the context of its parent; one whose
    /// `parentId` matches no category is an orphan (see `Catalog`).
    public struct Subcategory: Identifiable, Hashable, Sendable {
        public let id: UUID
        public var displayName: String
        public let parentId: UUID

        public init(id: UUID = UUID(), displayName: String, parentId: UUID) {
            self.id = id
            self.displayName = displayName
            self.parentId = parentId
        }

        /// Whether this subcategory belongs to the given category.
        public func isChild(of category: Category) -> Bool {
            parentId == category.id
        }
    }

    // MARK: - Tag

    /// A free-form label orthogonal to the category hierarchy. Tags are *not* a
    /// third level: a transaction has at most one category + subcategory plus
    /// any number of tags (e.g. a restaurant dinner tagged `work`).
    public struct Tag: Identifiable, Hashable, Sendable {
        public let id: UUID
        public var displayName: String

        public init(id: UUID = UUID(), displayName: String) {
            self.id = id
            self.displayName = displayName
        }
    }

    // MARK: - Catalog

    /// A bundle of categories with their subcategories, plus integrity checks.
    /// Backs both the seed data and any user-edited category set.
    public struct Catalog: Hashable, Sendable {
        public let categories: [Category]
        public let subcategories: [Subcategory]

        public init(categories: [Category], subcategories: [Subcategory]) {
            self.categories = categories
            self.subcategories = subcategories
        }

        /// The subcategories belonging to a given category, in declared order.
        public func subcategories(of category: Category) -> [Subcategory] {
            subcategories.filter { $0.parentId == category.id }
        }

        /// Finds a top-level category by display name.
        public func category(named name: String) -> Category? {
            categories.first { $0.displayName == name }
        }

        /// Subcategories whose `parentId` matches no category in the catalog.
        public var orphanedSubcategories: [Subcategory] {
            let ids = Set(categories.map(\.id))
            return subcategories.filter { !ids.contains($0.parentId) }
        }

        /// A catalog is valid when every subcategory has a present parent.
        public var isValid: Bool {
            orphanedSubcategories.isEmpty
        }
    }
}
