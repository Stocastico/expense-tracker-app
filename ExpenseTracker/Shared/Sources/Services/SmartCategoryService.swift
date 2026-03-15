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
    /// Checks if the text contains the keyword as a whole word (word boundary matching).
    private static func containsWord(_ text: String, keyword: String) -> Bool {
        // For single-word keywords, use word boundary matching to avoid false positives
        // (e.g. "gas" matching inside "mortgage")
        if !keyword.contains(" ") {
            let words = text.components(separatedBy: .alphanumerics.inverted)
            return words.contains(where: { $0 == keyword })
        }
        // For multi-word keywords, substring matching is appropriate
        return text.contains(keyword)
    }

    public static func suggestCategory(for description: String, merchant: String?) -> String? {
        let allCategories = DefaultCategories.all

        let descriptionLower = description.lowercased()
        let merchantLower = merchant?.lowercased()

        // First pass: check merchant name against keywords (higher confidence)
        if let merchantLower = merchantLower, !merchantLower.isEmpty {
            for category in allCategories {
                for keyword in category.keywords {
                    let keywordLower = keyword.lowercased()
                    if containsWord(merchantLower, keyword: keywordLower) {
                        return category.id
                    }
                }
            }
        }

        // Second pass: check description against keywords
        for category in allCategories {
            for keyword in category.keywords {
                let keywordLower = keyword.lowercased()
                if containsWord(descriptionLower, keyword: keywordLower) {
                    return category.id
                }
            }
        }

        // Third pass: check if merchant name itself matches a category name
        if let merchantLower = merchantLower, !merchantLower.isEmpty {
            for category in allCategories {
                if containsWord(merchantLower, keyword: category.name.lowercased()) {
                    return category.id
                }
            }
        }

        return nil
    }
}
