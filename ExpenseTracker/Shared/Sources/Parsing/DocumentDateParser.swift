import Foundation

/// Locale-aware parser for dates found in statements, receipts and invoices.
///
/// Defaults to day-first European notation and understands ISO dates and
/// month names in Spanish, Italian, Basque (Euskera) and English. Returns a
/// `Date` anchored at noon UTC so the calendar day is stable regardless of the
/// reader's time zone.
public enum DocumentDateParser {

    /// Parses the first date found in `raw`, or `nil` if none is recognised.
    public static func parse(_ raw: String) -> Date? {
        // Stub: implementation follows in the green commit.
        return nil
    }
}
