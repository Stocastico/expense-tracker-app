import Foundation

// MARK: - Recurring Service

public struct RecurringService {

    private static let calendar = Calendar.current

    /// Generates future transaction instances for a recurring transaction.
    ///
    /// - Parameters:
    ///   - transaction: The parent recurring transaction to generate instances from.
    ///   - endDate: The date to generate instances until. Defaults to 1 year from now.
    /// - Returns: An array of new Transaction instances with recurringParentId set.
    public static func generateInstances(
        for transaction: Transaction,
        until endDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    ) -> [Transaction] {
        guard transaction.isRecurring,
              let frequency = transaction.recurringFrequency else {
            return []
        }

        let effectiveEndDate: Date
        if let recurringEnd = transaction.recurringEndDate {
            effectiveEndDate = min(recurringEnd, endDate)
        } else {
            effectiveEndDate = endDate
        }

        var instances: [Transaction] = []
        var currentDate = transaction.date

        while true {
            guard let nextDate = nextOccurrenceDate(from: currentDate, frequency: frequency) else {
                break
            }

            if nextDate > effectiveEndDate {
                break
            }

            let instance = Transaction(
                id: UUID(),
                type: transaction.type,
                amount: transaction.storedAmount,
                currency: transaction.currency,
                descriptionText: transaction.descriptionText,
                merchant: transaction.merchant,
                date: nextDate,
                categoryId: transaction.categoryId,
                account: transaction.account,
                tags: transaction.tags,
                notes: transaction.notes,
                isRecurring: false,
                recurringFrequency: nil,
                recurringEndDate: nil,
                recurringParentId: transaction.id,
                receiptData: nil,
                createdAt: Date(),
                updatedAt: Date()
            )

            instances.append(instance)
            currentDate = nextDate
        }

        return instances
    }

    /// Returns the next occurrence date for a recurring transaction.
    ///
    /// - Parameter transaction: The recurring transaction.
    /// - Returns: The next date after the transaction's current date, or nil.
    public static func getNextOccurrence(for transaction: Transaction) -> Date? {
        guard transaction.isRecurring,
              let frequency = transaction.recurringFrequency else {
            return nil
        }

        let nextDate = nextOccurrenceDate(from: transaction.date, frequency: frequency)

        // Respect recurring end date
        if let recurringEnd = transaction.recurringEndDate,
           let nextDate = nextDate,
           nextDate > recurringEnd {
            return nil
        }

        return nextDate
    }

    // MARK: - Private Helpers

    private static func nextOccurrenceDate(from date: Date, frequency: RecurringFrequency) -> Date? {
        switch frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: date)
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date)
        }
    }
}
