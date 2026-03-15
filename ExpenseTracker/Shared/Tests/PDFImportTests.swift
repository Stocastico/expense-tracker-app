import XCTest
import Foundation
@testable import ExpenseTracker

final class PDFImportTests: XCTestCase {

    // MARK: - parseText Tests

    func testParseTextWithSampleBankStatement() {
        let text = """
        Statement Period: 01/03/2026 - 31/03/2026
        Date  Description  Amount
        14/03/2026  AMAZON PURCHASE  -€42.50
        15/03/2026  SALARY DEPOSIT  +€3000.00
        16/03/2026  GROCERY STORE  -€85.30
        """

        let transactions = PDFImportService.parseText(text)

        // Should skip the header lines and parse 3 transaction lines
        XCTAssertEqual(transactions.count, 3)

        // First transaction
        XCTAssertNotNil(transactions[0].date)
        XCTAssertEqual(transactions[0].amount, 42.50, accuracy: 0.01)
        XCTAssertTrue(transactions[0].isExpense)
        XCTAssertTrue(transactions[0].description.contains("AMAZON"))

        // Second transaction (income)
        XCTAssertEqual(transactions[1].amount, 3000.00, accuracy: 0.01)
        XCTAssertFalse(transactions[1].isExpense)

        // Third transaction
        XCTAssertEqual(transactions[2].amount, 85.30, accuracy: 0.01)
        XCTAssertTrue(transactions[2].isExpense)
    }

    func testParseTextWithMultipleFormats() {
        let text = """
        2026-03-14  Netflix Subscription  -€15.99
        03/14/2026  Uber Ride  -$25.00
        14 Mar 2026  Coffee Shop  -£4.50
        """

        let transactions = PDFImportService.parseText(text)

        XCTAssertEqual(transactions.count, 3)

        for transaction in transactions {
            XCTAssertNotNil(transaction.date)
            XCTAssertNotNil(transaction.amount)
            XCTAssertTrue(transaction.isExpense)
        }
    }

    // MARK: - Date Parsing Tests

    func testDateParsingDDMMYYYY() {
        let date = PDFImportService.parseDateFromString("14/03/2026")
        XCTAssertNotNil(date)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date!)
        XCTAssertEqual(components.day, 14)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.year, 2026)
    }

    func testDateParsingMMDDYYYY() {
        // Note: 03/14/2026 - the parser tries DD/MM/YYYY first, but 14 > 12 so it
        // falls back to MM/DD/YYYY for valid interpretations.
        // Actually, the parser tries DD/MM first with "14" as day and "03" as month,
        // which is valid (day=14, month=3). So this would parse as March 14.
        let date = PDFImportService.parseDateFromString("03/14/2026")
        XCTAssertNotNil(date)

        if let date = date {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            // It should parse as March 14 regardless of which format matched
            XCTAssertEqual(components.year, 2026)
            // Either DD/MM (fails: day=3, month=14 invalid) or MM/DD (day=14, month=3)
            XCTAssertEqual(components.month, 3)
            XCTAssertEqual(components.day, 14)
        }
    }

    func testDateParsingISOFormat() {
        let date = PDFImportService.parseDateFromString("2026-03-14")
        XCTAssertNotNil(date)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 14)
    }

    func testDateParsingTextFormat() {
        let date = PDFImportService.parseDateFromString("14 Mar 2026")
        XCTAssertNotNil(date)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 14)
    }

    func testDateParsingInvalidStringReturnsNil() {
        let date = PDFImportService.parseDateFromString("not a date")
        XCTAssertNil(date)
    }

    func testDateParsingEmptyStringReturnsNil() {
        let date = PDFImportService.parseDateFromString("")
        XCTAssertNil(date)
    }

    // MARK: - Amount Parsing Tests

    func testAmountParsingEuroCurrency() {
        let result = PDFImportService.parseAmountFromString("€42.50")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.amount, 42.50, accuracy: 0.01)
    }

    func testAmountParsingNegativeSign() {
        let result = PDFImportService.parseAmountFromString("-42.50")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.amount, 42.50, accuracy: 0.01)
        XCTAssertTrue(result!.isExpense)
    }

    func testAmountParsingCRSuffix() {
        let result = PDFImportService.parseAmountFromString("42.50 CR")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.amount, 42.50, accuracy: 0.01)
        XCTAssertFalse(result!.isExpense)
    }

    func testAmountParsingDRSuffix() {
        let result = PDFImportService.parseAmountFromString("42.50 DR")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.amount, 42.50, accuracy: 0.01)
        XCTAssertTrue(result!.isExpense)
    }

    func testAmountParsingDollarWithCommas() {
        let result = PDFImportService.parseAmountFromString("$1,234.56")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.amount, 1234.56, accuracy: 0.01)
    }

    func testAmountParsingPositiveSign() {
        let result = PDFImportService.parseAmountFromString("+100.00")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.amount, 100.00, accuracy: 0.01)
        XCTAssertFalse(result!.isExpense)
    }

    func testAmountParsingPound() {
        let result = PDFImportService.parseAmountFromString("£99.99")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.amount, 99.99, accuracy: 0.01)
    }

    func testAmountParsingInvalidReturnsNil() {
        let result = PDFImportService.parseAmountFromString("not an amount")
        XCTAssertNil(result)
    }

    // MARK: - Full Line Parsing Tests

    func testFullLineParsingAmazonPurchase() {
        let text = "14/03/2026  AMAZON PURCHASE  -€42.50"
        let transactions = PDFImportService.parseText(text)

        XCTAssertEqual(transactions.count, 1)

        let t = transactions[0]
        XCTAssertNotNil(t.date)
        XCTAssertEqual(t.amount, 42.50, accuracy: 0.01)
        XCTAssertTrue(t.isExpense)
        XCTAssertTrue(t.description.uppercased().contains("AMAZON"))
    }

    func testFullLineParsingIncomeDeposit() {
        let text = "2026-03-14  EMPLOYER SALARY DEPOSIT  +€4500.00"
        let transactions = PDFImportService.parseText(text)

        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transactions[0].amount, 4500.00, accuracy: 0.01)
        XCTAssertFalse(transactions[0].isExpense)
    }

    // MARK: - Garbage/Header Line Tests

    func testSkipsStatementPeriodHeader() {
        let text = "Statement Period: 01/01/2026 - 31/01/2026"
        let transactions = PDFImportService.parseText(text)
        XCTAssertTrue(transactions.isEmpty)
    }

    func testSkipsOpeningBalanceLine() {
        let text = "Opening Balance  €5,000.00"
        let transactions = PDFImportService.parseText(text)
        XCTAssertTrue(transactions.isEmpty)
    }

    func testSkipsClosingBalanceLine() {
        let text = "Closing Balance  €4,500.00"
        let transactions = PDFImportService.parseText(text)
        XCTAssertTrue(transactions.isEmpty)
    }

    func testSkipsColumnHeaderLine() {
        let text = "Date  Description  Amount"
        let transactions = PDFImportService.parseText(text)
        XCTAssertTrue(transactions.isEmpty)
    }

    func testSkipsPageFooter() {
        let text = "Page 1 of 3"
        let transactions = PDFImportService.parseText(text)
        XCTAssertTrue(transactions.isEmpty)
    }

    func testSkipsEmptyLines() {
        let text = "\n\n\n"
        let transactions = PDFImportService.parseText(text)
        XCTAssertTrue(transactions.isEmpty)
    }

    func testSkipsPureTextWithNoDateOrAmount() {
        let text = "Thank you for banking with us."
        let transactions = PDFImportService.parseText(text)
        XCTAssertTrue(transactions.isEmpty)
    }

    func testMixedValidAndGarbageLines() {
        let text = """
        BANK STATEMENT
        Statement Period: 01/03/2026 - 31/03/2026
        Date  Description  Amount

        14/03/2026  COFFEE SHOP  -€4.50

        Page 1 of 1
        Opening Balance  €1,000.00
        15/03/2026  PAYCHECK  +€2,500.00
        Closing Balance  €3,495.50
        Thank you for your business.
        """

        let transactions = PDFImportService.parseText(text)

        // Should only parse the two valid transaction lines
        XCTAssertEqual(transactions.count, 2)
        XCTAssertEqual(transactions[0].amount, 4.50, accuracy: 0.01)
        XCTAssertEqual(transactions[1].amount, 2500.00, accuracy: 0.01)
    }
}
