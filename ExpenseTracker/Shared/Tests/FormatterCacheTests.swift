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

    /// 14 March 2026, 12:00 UTC — a day/month pair that orders differently across
    /// locales, so a fixed "d MMM" pattern would be wrong for en_US.
    private var sampleDate: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 14
        components.hour = 12
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    @Test("Localized templates order day/month fields per locale")
    func localizedTemplateOrdersByLocale() {
        let en = FormatterCache.localizedTemplate("dMMM", locale: Locale(identifier: "en_US"))
        let it = FormatterCache.localizedTemplate("dMMM", locale: Locale(identifier: "it_IT"))
        en.timeZone = TimeZone(identifier: "UTC")
        it.timeZone = TimeZone(identifier: "UTC")

        // en_US puts the month first ("Mar 14"); it_IT puts the day first ("14 mar").
        #expect(en.string(from: sampleDate).hasPrefix("Mar"))
        #expect(it.string(from: sampleDate).hasPrefix("14"))
    }

    @Test("Localized template month-year follows locale month names")
    func localizedTemplateMonthYear() {
        let en = FormatterCache.localizedTemplate("MMMMyyyy", locale: Locale(identifier: "en_US"))
        let it = FormatterCache.localizedTemplate("MMMMyyyy", locale: Locale(identifier: "it_IT"))
        en.timeZone = TimeZone(identifier: "UTC")
        it.timeZone = TimeZone(identifier: "UTC")

        #expect(en.string(from: sampleDate).contains("March"))
        #expect(it.string(from: sampleDate).contains("marzo"))
    }

    @Test("Localized templates are cached per locale + template")
    func localizedTemplateCached() {
        let a = FormatterCache.localizedTemplate("dMMM", locale: Locale(identifier: "en_US"))
        let b = FormatterCache.localizedTemplate("dMMM", locale: Locale(identifier: "en_US"))
        let c = FormatterCache.localizedTemplate("dMMM", locale: Locale(identifier: "it_IT"))
        #expect(a === b)
        #expect(a !== c)
    }
}
