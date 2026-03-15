import Foundation

// MARK: - TransactionType

public enum TransactionType: String, Codable, CaseIterable, Identifiable, Sendable {
    case expense
    case income

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .expense: return "Expense"
        case .income: return "Income"
        }
    }
}

// MARK: - RecurringFrequency

public enum RecurringFrequency: String, Codable, CaseIterable, Identifiable, Sendable {
    case daily
    case weekly
    case biweekly
    case monthly
    case quarterly
    case yearly

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .biweekly: return "Bi-Weekly"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .yearly: return "Yearly"
        }
    }

    /// Calculates the next occurrence date from a given starting date.
    public func nextDate(from date: Date) -> Date {
        let calendar = Calendar.current
        switch self {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }

    /// Returns the number of calendar days in one cycle of this frequency,
    /// calculated from a reference date.
    public func calendarDays(from referenceDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        let next = nextDate(from: referenceDate)
        return calendar.dateComponents([.day], from: referenceDate, to: next).day ?? 0
    }
}

// MARK: - BudgetPeriod

public enum BudgetPeriod: String, Codable, CaseIterable, Identifiable, Sendable {
    case monthly
    case yearly

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

// MARK: - CategoryType

public enum CategoryType: String, Codable, CaseIterable, Sendable {
    case expense
    case income
    case both

    public var displayName: String {
        switch self {
        case .expense: return "Expense"
        case .income: return "Income"
        case .both: return "Both"
        }
    }
}
