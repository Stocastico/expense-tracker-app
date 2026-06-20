import SwiftUI

private struct ExpenseRepositoryKey: EnvironmentKey {
    /// An in-memory, pre-seeded repository — a safe default for SwiftUI
    /// previews. The running app overrides this with the SwiftData-backed one.
    static let defaultValue: any ExpenseRepository = ExpenseDomain.InMemoryRepository.seeded()
}

extension EnvironmentValues {
    /// The expense-domain repository for the two-level categorization model.
    var expenseRepository: any ExpenseRepository {
        get { self[ExpenseRepositoryKey.self] }
        set { self[ExpenseRepositoryKey.self] = newValue }
    }
}
