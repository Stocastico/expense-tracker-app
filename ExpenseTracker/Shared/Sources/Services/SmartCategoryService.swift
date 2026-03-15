import Foundation

// MARK: - Smart Category Service

public struct SmartCategoryService {

    /// Suggests a category ID by matching the transaction description and merchant
    /// against the keyword mappings defined in DefaultCategories.
    ///
    /// - Parameters:
    ///   - description: The transaction description text.
    ///   - merchant: An optional merchant name.
    /// - Returns: A category ID string if a match is found, nil otherwise.
    public static func suggestCategory(for description: String, merchant: String?) -> String? {
        let allCategories = DefaultCategories.all

        let descriptionLower = description.lowercased()
        let merchantLower = merchant?.lowercased()

        // First pass: check merchant name against keywords (higher confidence)
        if let merchantLower = merchantLower, !merchantLower.isEmpty {
            for category in allCategories {
                for keyword in category.keywords {
                    let keywordLower = keyword.lowercased()
                    if merchantLower.contains(keywordLower) {
                        return category.id
                    }
                }
            }
        }

        // Second pass: check description against keywords
        for category in allCategories {
            for keyword in category.keywords {
                let keywordLower = keyword.lowercased()
                if descriptionLower.contains(keywordLower) {
                    return category.id
                }
            }
        }

        // Third pass: check if merchant name itself matches a category name
        if let merchantLower = merchantLower, !merchantLower.isEmpty {
            for category in allCategories {
                if merchantLower.contains(category.name.lowercased()) {
                    return category.id
                }
            }
        }

        return nil
    }
}
