import Foundation

extension ExpenseDomain {

    /// Expands a recurring template into the concrete occurrences it generates,
    /// up to and including `endDate`.
    ///
    /// Each occurrence copies the template's fields, gets a fresh `id`, carries
    /// the same `recurrence`, and points back at the template via
    /// `recurringParentId`. The date steps by the recurrence frequency starting
    /// from the first cadence after the template's own date (so the template
    /// itself is not duplicated). The receipt is intentionally left on the
    /// template only. Returns empty when the template has no recurrence.
    public static func recurringOccurrences(
        of template: Transaction,
        until endDate: Date
    ) -> [Transaction] {
        guard let recurrence = template.recurrence else { return [] }

        var occurrences: [Transaction] = []
        var date = recurrence.frequency.nextDate(from: template.date)
        while date <= endDate {
            occurrences.append(
                Transaction(
                    amount: template.amount,
                    date: date,
                    type: template.type,
                    merchant: template.merchant,
                    descriptionText: template.descriptionText,
                    category: template.category,
                    subcategory: template.subcategory,
                    tags: template.tags,
                    accountId: template.accountId,
                    note: template.note,
                    recurrence: recurrence,
                    recurringParentId: template.id,
                    receiptData: nil
                )
            )
            date = recurrence.frequency.nextDate(from: date)
        }
        return occurrences
    }
}
