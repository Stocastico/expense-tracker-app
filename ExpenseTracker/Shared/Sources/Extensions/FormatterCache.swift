import Foundation

/// Cached `NumberFormatter` / `DateFormatter` instances.
///
/// Formatters are expensive to allocate, and Foundation formatters are safe to
/// share for formatting (read-only use of `string(from:)`), so reuse them
/// instead of creating one per call — these were previously allocated on every
/// list-row render. Access to the caches is serialised with a lock.
public enum FormatterCache {
    private static let lock = NSLock()
    private static var currencyByCode: [String: NumberFormatter] = [:]
    private static var byDateFormat: [String: DateFormatter] = [:]
    private static var byTemplate: [String: DateFormatter] = [:]

    /// A currency formatter (2 fraction digits) for the given ISO 4217 code.
    public static func currency(code: String) -> NumberFormatter {
        lock.lock()
        defer { lock.unlock() }
        if let existing = currencyByCode[code] {
            return existing
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        currencyByCode[code] = formatter
        return formatter
    }

    /// A `DateFormatter` for the given `dateFormat` pattern.
    public static func dateFormat(_ format: String) -> DateFormatter {
        lock.lock()
        defer { lock.unlock() }
        if let existing = byDateFormat[format] {
            return existing
        }
        let formatter = DateFormatter()
        formatter.dateFormat = format
        byDateFormat[format] = formatter
        return formatter
    }

    /// A `DateFormatter` whose field *ordering* follows `locale`, built from a
    /// skeleton template (e.g. `"dMMM"`, `"MMMMyyyy"`) via
    /// `setLocalizedDateFormatFromTemplate`. Unlike `dateFormat(_:)`, which pins
    /// a literal pattern, this reorders day/month/year per the locale's
    /// conventions (en_US "Mar 14" vs it_IT "14 mar"). Cached per locale+template.
    public static func localizedTemplate(_ template: String, locale: Locale = .current) -> DateFormatter {
        lock.lock()
        defer { lock.unlock() }
        let key = "\(locale.identifier)|\(template)"
        if let existing = byTemplate[key] {
            return existing
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        byTemplate[key] = formatter
        return formatter
    }

    /// A medium-date / no-time formatter.
    public static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
