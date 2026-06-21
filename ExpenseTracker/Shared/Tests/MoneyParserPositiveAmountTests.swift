import Testing
import Foundation

/// `MoneyParser.parsePositiveAmount` — the convenience for manual amount entry
/// (e.g. the menu-bar quick-add): parse a user-typed amount in European/US
/// notation and accept it only when it's strictly positive.
struct MoneyParserPositiveAmountTests {

    private func dec(_ s: String) -> Decimal { Decimal(string: s, locale: Locale(identifier: "en_US_POSIX"))! }

    @Test("accepts a bare integer")
    func bareInteger() {
        #expect(MoneyParser.parsePositiveAmount("12") == dec("12"))
    }

    @Test("accepts European thousands + decimal comma")
    func europeanThousands() {
        #expect(MoneyParser.parsePositiveAmount("1.234,56") == dec("1234.56"))
    }

    @Test("accepts a leading currency symbol")
    func currencySymbol() {
        #expect(MoneyParser.parsePositiveAmount("€12,50") == dec("12.50"))
    }

    @Test("accepts US notation")
    func usNotation() {
        #expect(MoneyParser.parsePositiveAmount("12.50") == dec("12.50"))
    }

    @Test("rejects zero, negatives and non-numeric input")
    func rejectsNonPositive() {
        #expect(MoneyParser.parsePositiveAmount("0") == nil)
        #expect(MoneyParser.parsePositiveAmount("-5,00") == nil)
        #expect(MoneyParser.parsePositiveAmount("") == nil)
        #expect(MoneyParser.parsePositiveAmount("abc") == nil)
    }
}
