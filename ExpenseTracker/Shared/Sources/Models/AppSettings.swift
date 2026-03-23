import Foundation
import SwiftData

@Model
public final class AppSettings {
    public var id: UUID
    public var currency: String
    public var darkMode: Bool
    public var startOfMonth: Int
    public var defaultAccountId: UUID?
    public var customCategoriesData: Data?

    public init(
        id: UUID = UUID(),
        currency: String = "EUR",
        darkMode: Bool = false,
        startOfMonth: Int = 1,
        defaultAccountId: UUID? = nil,
        customCategories: [Category] = []
    ) {
        self.id = id
        self.currency = currency
        self.darkMode = darkMode
        self.startOfMonth = startOfMonth
        self.defaultAccountId = defaultAccountId
        if customCategories.isEmpty {
            self.customCategoriesData = nil
        } else {
            self.customCategoriesData = try? JSONEncoder().encode(customCategories)
        }
    }
}

// MARK: - Computed Properties

extension AppSettings {
    /// Custom categories decoded from the stored JSON data.
    public var customCategories: [Category] {
        get {
            guard let data = customCategoriesData else { return [] }
            return (try? JSONDecoder().decode([Category].self, from: data)) ?? []
        }
        set {
            if newValue.isEmpty {
                customCategoriesData = nil
            } else {
                customCategoriesData = try? JSONEncoder().encode(newValue)
            }
        }
    }

    /// Returns all available categories: defaults merged with any custom ones.
    /// Custom categories with the same ID as a default will override the default.
    public var allCategories: [Category] {
        let defaults = DefaultCategories.all
        let custom = customCategories
        let customIds = Set(custom.map(\.id))
        let filteredDefaults = defaults.filter { !customIds.contains($0.id) }
        return filteredDefaults + custom
    }

    /// Adds a custom category. If a category with the same ID exists, it is replaced.
    public func addCustomCategory(_ category: Category) {
        var categories = customCategories
        var mutableCategory = category
        mutableCategory.isCustom = true
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = mutableCategory
        } else {
            categories.append(mutableCategory)
        }
        customCategories = categories
    }

    /// Removes a custom category by ID.
    public func removeCustomCategory(withId id: String) {
        var categories = customCategories
        categories.removeAll { $0.id == id }
        customCategories = categories
    }
}

// MARK: - Singleton Access

extension AppSettings {
    /// Fetches the singleton AppSettings from the given model context, creating one if none exists.
    @MainActor
    public static func shared(in context: ModelContext) -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let settings = AppSettings()
        context.insert(settings)
        return settings
    }
}
