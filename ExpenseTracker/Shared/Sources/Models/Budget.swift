import Foundation
import SwiftData

@Model
public final class Budget {
    public var id: UUID
    public var categoryId: String
    public var storedAmount: Double
    public var currency: String
    public var periodRaw: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        categoryId: String,
        amount: Double = 0.0,
        currency: String = "EUR",
        period: BudgetPeriod = .monthly,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.categoryId = categoryId
        self.storedAmount = amount
        self.currency = currency
        self.periodRaw = period.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Computed Properties

extension Budget {
    /// The budget period derived from the stored raw value.
    public var period: BudgetPeriod {
        get { BudgetPeriod(rawValue: periodRaw) ?? .monthly }
        set {
            periodRaw = newValue.rawValue
            updatedAt = Date()
        }
    }

    /// The budget amount as a Decimal for precise currency calculations.
    public var amount: Decimal {
        get { Decimal(storedAmount) }
        set {
            storedAmount = NSDecimalNumber(decimal: newValue).doubleValue
            updatedAt = Date()
        }
    }

    /// Returns the date range for the current budget period.
    public func currentPeriodRange(startOfMonth: Int = 1) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch period {
        case .monthly:
            var components = calendar.dateComponents([.year, .month], from: now)
            components.day = startOfMonth
            components.hour = 0
            components.minute = 0
            components.second = 0
            let start = calendar.date(from: components) ?? now

            // If we haven't reached the start day yet this month, go back one month
            let adjustedStart: Date
            if now < start {
                adjustedStart = calendar.date(byAdding: .month, value: -1, to: start) ?? start
            } else {
                adjustedStart = start
            }

            // Use one second before the next period starts so that the range is
            // inclusive and callers can safely compare with <=.
            let nextStart = calendar.date(byAdding: .month, value: 1, to: adjustedStart) ?? now
            let end = calendar.date(byAdding: .second, value: -1, to: nextStart) ?? now
            return (adjustedStart, end)

        case .yearly:
            var components = calendar.dateComponents([.year], from: now)
            components.month = 1
            components.day = 1
            components.hour = 0
            components.minute = 0
            components.second = 0
            let start = calendar.date(from: components) ?? now
            let nextStart = calendar.date(byAdding: .year, value: 1, to: start) ?? now
            let end = calendar.date(byAdding: .second, value: -1, to: nextStart) ?? now
            return (start, end)
        }
    }
}
