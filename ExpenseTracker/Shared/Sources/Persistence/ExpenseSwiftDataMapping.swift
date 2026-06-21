import Foundation

// MARK: - Record ⇄ domain mapping

extension ExpenseTransactionRecord {
    /// Creates a record from a domain transaction, embedding its category,
    /// subcategory and tag values.
    public convenience init(from transaction: ExpenseDomain.Transaction) {
        self.init(
            id: transaction.id,
            amount: transaction.amount,
            date: transaction.date,
            typeRaw: transaction.type.rawValue,
            merchant: transaction.merchant,
            descriptionText: transaction.descriptionText,
            categoryId: transaction.category?.id,
            categoryName: transaction.category?.displayName,
            subcategoryId: transaction.subcategory?.id,
            subcategoryName: transaction.subcategory?.displayName,
            subcategoryParentId: transaction.subcategory?.parentId,
            accountId: transaction.accountId,
            note: transaction.note,
            // Sorted for a stable on-disk representation; tags are a Set in the domain.
            tags: transaction.tags
                .map { StoredExpenseTag(id: $0.id, displayName: $0.displayName) }
                .sorted { $0.id.uuidString < $1.id.uuidString }
        )
    }

    /// Copies a domain transaction's fields onto this existing record.
    public func update(from transaction: ExpenseDomain.Transaction) {
        amount = transaction.amount
        date = transaction.date
        typeRaw = transaction.type.rawValue
        merchant = transaction.merchant
        descriptionText = transaction.descriptionText
        categoryId = transaction.category?.id
        categoryName = transaction.category?.displayName
        subcategoryId = transaction.subcategory?.id
        subcategoryName = transaction.subcategory?.displayName
        subcategoryParentId = transaction.subcategory?.parentId
        accountId = transaction.accountId
        note = transaction.note
        tags = transaction.tags
            .map { StoredExpenseTag(id: $0.id, displayName: $0.displayName) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    /// Reconstructs the domain transaction from this record.
    public func toDomain() -> ExpenseDomain.Transaction {
        let category: ExpenseDomain.Category? = categoryId.flatMap { id in
            categoryName.map { ExpenseDomain.Category(id: id, displayName: $0) }
        }
        let subcategory: ExpenseDomain.Subcategory? = {
            guard let id = subcategoryId, let name = subcategoryName, let parentId = subcategoryParentId else {
                return nil
            }
            return ExpenseDomain.Subcategory(id: id, displayName: name, parentId: parentId)
        }()

        return ExpenseDomain.Transaction(
            id: id,
            amount: amount,
            date: date,
            type: TransactionType(rawValue: typeRaw) ?? .expense,
            merchant: merchant,
            descriptionText: descriptionText,
            category: category,
            subcategory: subcategory,
            tags: Set(tags.map { ExpenseDomain.Tag(id: $0.id, displayName: $0.displayName) }),
            accountId: accountId,
            note: note
        )
    }
}
