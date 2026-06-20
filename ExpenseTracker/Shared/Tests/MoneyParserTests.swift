import XCTest
import Foundation

/// Tests for the locale-aware monetary parser.
///
/// The documents this app ingests are ~90% Spanish, with a minority in
/// Italian, Basque (Euskera) and English, so the parser must default to
/// European notation (comma decimal separator, dot thousands separator,
/// `€` symbol) while still understanding US notation.
final class MoneyParserTests: XCTestCase {

    private func dec(_ s: String) -> Decimal { Decimal(string: s, locale: Locale(identifier: "en_US_POSIX"))! }

    // MARK: - European notation (primary)

    func testEuropeanDecimalComma() {
        XCTAssertEqual(MoneyParser.parse("12,50"), dec("12.50"))
    }

    func testEuropeanThousandsDotAndDecimalComma() {
        XCTAssertEqual(MoneyParser.parse("1.234,56"), dec("1234.56"))
    }

    func testEuropeanMillionsWithTwoDotGroups() {
        XCTAssertEqual(MoneyParser.parse("1.234.567,89"), dec("1234567.89"))
    }

    func testLoneDotThreeDigitsIsThousands() {
        // "1.500" in Spanish/European is one thousand five hundred, not 1.5
        XCTAssertEqual(MoneyParser.parse("1.500"), dec("1500"))
    }

    func testLoneDotTwoDigitsIsDecimal() {
        XCTAssertEqual(MoneyParser.parse("1.50"), dec("1.50"))
    }

    func testLoneCommaTwoDigitsIsDecimal() {
        XCTAssertEqual(MoneyParser.parse("99,99"), dec("99.99"))
    }

    // MARK: - US notation (minority)

    func testUSThousandsCommaAndDecimalDot() {
        XCTAssertEqual(MoneyParser.parse("1,234.56"), dec("1234.56"))
    }

    func testUSPlainDecimalDot() {
        XCTAssertEqual(MoneyParser.parse("42.50"), dec("42.50"))
    }

    // MARK: - Currency symbols and whitespace

    func testEuroSymbolPrefixed() {
        XCTAssertEqual(MoneyParser.parse("€ 1.234,56"), dec("1234.56"))
    }

    func testEuroSymbolSuffixed() {
        XCTAssertEqual(MoneyParser.parse("1.234,56 €"), dec("1234.56"))
    }

    func testDollarAndPoundSymbols() {
        XCTAssertEqual(MoneyParser.parse("$1,234.56"), dec("1234.56"))
        XCTAssertEqual(MoneyParser.parse("£99.99"), dec("99.99"))
    }

    // MARK: - Signs

    func testLeadingMinusIsNegative() {
        XCTAssertEqual(MoneyParser.parse("-45,00"), dec("-45.00"))
    }

    func testTrailingMinusIsNegative() {
        // Common in Spanish/German statements: "1.234,56-"
        XCTAssertEqual(MoneyParser.parse("1.234,56-"), dec("-1234.56"))
    }

    func testParenthesesAreNegative() {
        XCTAssertEqual(MoneyParser.parse("(45,00)"), dec("-45.00"))
    }

    func testLeadingPlusIsPositive() {
        XCTAssertEqual(MoneyParser.parse("+100,00"), dec("100.00"))
    }

    // MARK: - Integers and edge cases

    func testPlainInteger() {
        XCTAssertEqual(MoneyParser.parse("100"), dec("100"))
    }

    func testNonNumericReturnsNil() {
        XCTAssertNil(MoneyParser.parse("not an amount"))
    }

    func testEmptyReturnsNil() {
        XCTAssertNil(MoneyParser.parse(""))
    }

    func testWhitespaceOnlyReturnsNil() {
        XCTAssertNil(MoneyParser.parse("   "))
    }

    func testEmbeddedInTextExtractsAmount() {
        // The parser should isolate the numeric token from surrounding text.
        XCTAssertEqual(MoneyParser.parse("Importe: 1.234,56 EUR"), dec("1234.56"))
    }
}
