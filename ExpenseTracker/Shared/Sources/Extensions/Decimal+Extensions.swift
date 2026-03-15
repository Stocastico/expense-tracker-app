import Foundation

extension Decimal {
    /// Formats this decimal value as a currency string using the given currency code.
    ///
    /// - Parameter code: An ISO 4217 currency code (e.g., "EUR", "USD").
    /// - Returns: A localized currency string, or a fallback if formatting fails.
    public func currencyFormatted(code: String = "EUR") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let nsDecimal = self as NSDecimalNumber
        return formatter.string(from: nsDecimal) ?? "\(code) \(self)"
    }

    /// Returns the absolute value of this decimal.
    public var absoluteValue: Decimal {
        self < 0 ? -self : self
    }
}

extension Double {
    /// Formats this double value as a currency string using the given currency code.
    ///
    /// - Parameter code: An ISO 4217 currency code (e.g., "EUR", "USD").
    /// - Returns: A localized currency string, or a fallback if formatting fails.
    public func currencyFormatted(code: String = "EUR") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "\(code) \(self)"
    }
}
