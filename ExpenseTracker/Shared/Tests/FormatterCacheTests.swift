import Testing
import Foundation

/// Drives `FormatterCache`: formatters are expensive to allocate and were
/// previously created on every call (per row render). They should be cached and
/// reused, keyed by what makes them distinct.
struct FormatterCacheTests {

    @Test("Currency formatters are cached per code and configured with 2 dp")
    func currencyCachedPerCode() {
        #expect(FormatterCache.currency(code: "EUR") === FormatterCache.currency(code: "EUR"))
        #expect(FormatterCache.currency(code: "USD") !== FormatterCache.currency(code: "EUR"))

        let eur = FormatterCache.currency(code: "EUR")
        #expect(eur.numberStyle == .currency)
        #expect(eur.currencyCode == "EUR")
        #expect(eur.minimumFractionDigits == 2)
        #expect(eur.maximumFractionDigits == 2)
    }

    @Test("Date formatters are cached per format string")
    func dateCachedPerFormat() {
        #expect(FormatterCache.dateFormat("d MMM") === FormatterCache.dateFormat("d MMM"))
        #expect(FormatterCache.dateFormat("MMMM yyyy") !== FormatterCache.dateFormat("d MMM"))
        #expect(FormatterCache.dateFormat("d MMM").dateFormat == "d MMM")
    }
}
