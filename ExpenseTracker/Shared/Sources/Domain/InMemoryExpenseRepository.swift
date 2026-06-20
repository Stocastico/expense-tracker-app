import Foundation

extension ExpenseDomain {

    /// Errors raised by an `ExpenseRepository`.
    public enum RepositoryError: Error, Equatable, Sendable {
        /// An update referenced a transaction id that is not stored.
        case transactionNotFound
    }

    /// An in-memory `ExpenseRepository`. Doubles as the unit-test fake and as a
    /// usable store for previews / pre-persistence app states. Backed entirely
    /// by domain value types, so it has no persistence dependency.
    public final class InMemoryRepository: ExpenseRepository {
        private var storedCatalog: Catalog
        private var storedTags: [Tag]
        private var storedTransactions: [Transaction]

        public init(
            catalog: Catalog = Catalog(categories: [], subcategories: []),
            tags: [Tag] = [],
            transactions: [Transaction] = []
        ) {
            self.storedCatalog = catalog
            self.storedTags = tags
            self.storedTransactions = transactions
        }

        /// A repository pre-populated with the default Italian seed.
        public static func seeded() -> InMemoryRepository {
            InMemoryRepository(
                catalog: DefaultExpenseCategories.catalog,
                tags: DefaultExpenseCategories.tags
            )
        }

        // MARK: Reads

        public func catalog() throws -> Catalog { storedCatalog }
        public func tags() throws -> [Tag] { storedTags }
        public func transactions() throws -> [Transaction] { storedTransactions }

        // MARK: Catalog & tags

        public func saveCatalog(_ catalog: Catalog) throws {
            storedCatalog = catalog
        }

        public func saveTag(_ tag: Tag) throws {
            if let index = storedTags.firstIndex(where: { $0.id == tag.id }) {
                storedTags[index] = tag
            } else {
                storedTags.append(tag)
            }
        }

        // MARK: Transactions

        public func addTransaction(_ transaction: Transaction) throws {
            try transaction.validate()
            storedTransactions.append(transaction)
        }

        public func updateTransaction(_ transaction: Transaction) throws {
            try transaction.validate()
            guard let index = storedTransactions.firstIndex(where: { $0.id == transaction.id }) else {
                throw RepositoryError.transactionNotFound
            }
            storedTransactions[index] = transaction
        }

        public func deleteTransaction(id: UUID) throws {
            storedTransactions.removeAll { $0.id == id }
        }
    }
}
