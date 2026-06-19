import Foundation

/// Locale-aware parser for monetary tokens found in bank/credit-card
/// statements, receipts and invoices.
///
/// Documents are predominantly Spanish (with some Italian, Basque and
/// English), so the parser defaults to European notation — comma decimal
/// separator, dot thousands separator — while still understanding US
/// notation. It returns a signed `Decimal`: negative for outflows expressed
/// with a leading/trailing minus or surrounding parentheses.
public enum MoneyParser {

    /// Parses the first monetary amount found in `raw`.
    ///
    /// - Parameter raw: Text that may contain currency symbols, thousands and
    ///   decimal separators, sign markers and surrounding words.
    /// - Returns: The signed amount as a `Decimal`, or `nil` if no numeric
    ///   value could be found.
    public static func parse(_ raw: String) -> Decimal? {
        // Stub: implementation follows in the green commit.
        return nil
    }
}
