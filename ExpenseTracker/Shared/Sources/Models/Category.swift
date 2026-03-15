import Foundation

/// Represents an expense/income category. This is a plain struct rather than a SwiftData model
/// because categories are either built-in defaults or stored as JSON in AppSettings.
public struct Category: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var icon: String
    public var color: String
    public var type: CategoryType
    public var keywords: [String]
    public var isCustom: Bool

    public init(
        id: String,
        name: String,
        icon: String,
        color: String,
        type: CategoryType,
        keywords: [String] = [],
        isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.type = type
        self.keywords = keywords
        self.isCustom = isCustom
    }

    /// Returns the display string combining icon and name.
    public var displayName: String {
        "\(icon) \(name)"
    }

    /// Checks whether the given text matches any of this category's keywords.
    /// Matching is case-insensitive and checks if the keyword is contained in the text.
    public func matchesText(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return keywords.contains { keyword in
            lowercased.contains(keyword.lowercased())
        }
    }
}

// MARK: - Category Lookup Helpers

extension Array where Element == Category {
    /// Finds the first category whose keywords match the given text.
    public func autoDetectCategory(from text: String) -> Category? {
        first { $0.matchesText(text) }
    }

    /// Returns only expense categories (type == .expense or .both).
    public var expenseCategories: [Category] {
        filter { $0.type == .expense || $0.type == .both }
    }

    /// Returns only income categories (type == .income or .both).
    public var incomeCategories: [Category] {
        filter { $0.type == .income || $0.type == .both }
    }

    /// Finds a category by its id.
    public func category(withId id: String) -> Category? {
        first { $0.id == id }
    }
}
