import Foundation

extension Date {
    /// Returns the first moment of the current month.
    public var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }

    /// Returns the last moment of the current month (start of next month minus one second).
    public var endOfMonth: Date {
        let calendar = Calendar.current
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return self
        }
        return calendar.date(byAdding: .second, value: -1, to: nextMonth) ?? self
    }

    /// Returns the first moment of the current year.
    public var startOfYear: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: self)
        return calendar.date(from: components) ?? self
    }

    /// Returns the last moment of the current year.
    public var endOfYear: Date {
        let calendar = Calendar.current
        guard let nextYear = calendar.date(byAdding: .year, value: 1, to: startOfYear) else {
            return self
        }
        return calendar.date(byAdding: .second, value: -1, to: nextYear) ?? self
    }

    /// Returns a string like "March 2026".
    public var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: self)
    }

    /// Returns a string like "14 Mar".
    public var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: self)
    }

    /// Checks whether this date falls in the same calendar month as another date.
    public func isInSameMonth(as other: Date) -> Bool {
        let calendar = Calendar.current
        let selfComponents = calendar.dateComponents([.year, .month], from: self)
        let otherComponents = calendar.dateComponents([.year, .month], from: other)
        return selfComponents.year == otherComponents.year && selfComponents.month == otherComponents.month
    }

    /// Returns a date that is `n` months before this date.
    public func monthsAgo(_ n: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .month, value: -n, to: self) ?? self
    }

    /// Returns a date that is `n` months after this date.
    public func monthsFromNow(_ n: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .month, value: n, to: self) ?? self
    }

    /// Returns the start of the day for this date.
    public var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Returns the end of the day for this date (23:59:59).
    public var endOfDay: Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return calendar.date(byAdding: components, to: startOfDay) ?? self
    }

    /// Returns a relative description like "Today", "Yesterday", or a formatted date.
    public var relativeDescription: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return "Today"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else if calendar.isDate(self, equalTo: Date(), toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: self)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: self)
        }
    }
}
