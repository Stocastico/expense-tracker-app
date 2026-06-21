import Foundation
import SwiftData

/// Reads legacy `Transaction` rows from a `ModelContext` and writes the
/// corresponding `ExpenseTransactionRecord`s (the SwiftData form of the new
/// domain). Safe to run more than once: a legacy transaction whose id is already
/// present as a domain record is skipped, so re-running never duplicates data.
public enum LegacyExpenseMigrationRunner {

    /// The outcome of a migration pass.
    public struct Summary: Equatable, Sendable {
        public var migrated: Int
        public var skipped: Int

        public init(migrated: Int, skipped: Int) {
            self.migrated = migrated
            self.skipped = skipped
        }
    }

    /// Migrates every legacy transaction in `context` that has not already been
    /// migrated. The migrated records share the legacy transaction's id, which is
    /// what makes the pass idempotent.
    @discardableResult
    public static func run(
        in context: ModelContext,
        resolveCategory: LegacyExpenseMigration.CategoryResolver = DefaultLegacyCategoryMapping.resolver()
    ) throws -> Summary {
        let legacy = try context.fetch(FetchDescriptor<Transaction>())
        let alreadyMigrated = Set(
            try context.fetch(FetchDescriptor<ExpenseTransactionRecord>()).map(\.id)
        )

        var migrated = 0
        var skipped = 0
        for transaction in legacy {
            guard !alreadyMigrated.contains(transaction.id) else {
                skipped += 1
                continue
            }
            let domain = LegacyExpenseMigration.migrate(transaction, resolveCategory: resolveCategory)
            context.insert(ExpenseTransactionRecord(from: domain))
            migrated += 1
        }

        if migrated > 0 {
            try context.save()
        }
        return Summary(migrated: migrated, skipped: skipped)
    }
}
