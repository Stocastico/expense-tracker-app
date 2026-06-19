import XCTest
import Foundation
@testable import ExpenseTracker

/// Tests for the locale-aware document date parser.
///
/// Documents are ~90% Spanish (rest Italian, Basque, English), so dates are
/// day-first European (`dd/mm/yyyy`, `dd-mm-yyyy`, `dd.mm.yyyy`), ISO, or
/// written with month names in those languages.
final class DocumentDateParserTests: XCTestCase {

    private static var utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func assertYMD(_ date: Date?, _ y: Int, _ m: Int, _ d: Int,
                           file: StaticString = #filePath, line: UInt = #line) {
        guard let date else {
            return XCTFail("expected a date, got nil", file: file, line: line)
        }
        let c = Self.utc.dateComponents([.year, .month, .day], from: date)
        XCTAssertEqual(c.year, y, "year", file: file, line: line)
        XCTAssertEqual(c.month, m, "month", file: file, line: line)
        XCTAssertEqual(c.day, d, "day", file: file, line: line)
    }

    // MARK: - Numeric European (day-first)

    func testSlashDayFirst() { assertYMD(DocumentDateParser.parse("14/03/2026"), 2026, 3, 14) }
    func testDashDayFirst() { assertYMD(DocumentDateParser.parse("14-03-2026"), 2026, 3, 14) }
    func testDotDayFirst() { assertYMD(DocumentDateParser.parse("14.03.2026"), 2026, 3, 14) }
    func testTwoDigitYear() { assertYMD(DocumentDateParser.parse("14/03/26"), 2026, 3, 14) }
    func testSingleDigitDayMonth() { assertYMD(DocumentDateParser.parse("5/1/2025"), 2025, 1, 5) }

    func testISO() { assertYMD(DocumentDateParser.parse("2026-03-14"), 2026, 3, 14) }

    func testAmericanSwappedWhenMonthOutOfRange() {
        // 03/14 → 14 is not a valid month, so interpret as MM/dd.
        assertYMD(DocumentDateParser.parse("03/14/2026"), 2026, 3, 14)
    }

    // MARK: - Month names

    func testSpanishLong() { assertYMD(DocumentDateParser.parse("14 de marzo de 2026"), 2026, 3, 14) }
    func testSpanishNoDe() { assertYMD(DocumentDateParser.parse("14 marzo 2026"), 2026, 3, 14) }
    func testSpanishAbbrev() { assertYMD(DocumentDateParser.parse("5 ene 2025"), 2025, 1, 5) }
    func testItalianLong() { assertYMD(DocumentDateParser.parse("31 dicembre 2024"), 2024, 12, 31) }
    func testBasque() { assertYMD(DocumentDateParser.parse("14 martxoa 2026"), 2026, 3, 14) }
    func testEnglishMonthDayYear() { assertYMD(DocumentDateParser.parse("March 14, 2026"), 2026, 3, 14) }
    func testEnglishAbbrevNoComma() { assertYMD(DocumentDateParser.parse("Mar 14 2026"), 2026, 3, 14) }

    // MARK: - Embedded & invalid

    func testEmbeddedInText() {
        assertYMD(DocumentDateParser.parse("Fecha valor: 14/03/2026  Importe 50,00"), 2026, 3, 14)
    }

    func testInvalidDayReturnsNil() { XCTAssertNil(DocumentDateParser.parse("32/03/2026")) }
    func testImpossibleDateReturnsNil() { XCTAssertNil(DocumentDateParser.parse("30/02/2026")) }
    func testNonDateReturnsNil() { XCTAssertNil(DocumentDateParser.parse("not a date")) }
    func testEmptyReturnsNil() { XCTAssertNil(DocumentDateParser.parse("")) }
}
