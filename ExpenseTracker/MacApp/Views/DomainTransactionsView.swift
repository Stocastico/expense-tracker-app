import SwiftUI

/// A transactions list backed by the new `ExpenseDomain` via `ExpenseRepository`
/// — the first screen to read through the repository instead of the legacy
/// store. Thin shell over `ExpenseTransactionsListModel`.
struct DomainTransactionsView: View {
    @Environment(\.expenseRepository) private var repository
    @Environment(ExpenseErrorPresenter.self) private var errorPresenter
    @State private var model: ExpenseTransactionsListModel?

    var body: some View {
        Group {
            if let model, !model.rows.isEmpty {
                List(model.rows) { row in
                    DomainTransactionRowView(row: row)
                }
            } else {
                ContentUnavailableView(
                    "No expenses yet",
                    systemImage: "tray",
                    description: Text("Imported and migrated expenses will appear here.")
                )
            }
        }
        .navigationTitle("Expenses (beta)")
        .task {
            ensureModel().load()
        }
    }

    private func ensureModel() -> ExpenseTransactionsListModel {
        if let model { return model }
        let created = ExpenseTransactionsListModel(
            repository: repository,
            errorPresenter: errorPresenter
        )
        model = created
        return created
    }
}

private struct DomainTransactionRowView: View {
    let row: ExpenseTransactionsListModel.Row

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                if let categoryPath = row.categoryPath {
                    Text(categoryPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !row.tagNames.isEmpty {
                    Text(row.tagNames.map { "#\($0)" }.joined(separator: " "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Text(row.amount.formatted(.currency(code: "EUR")))
                .monospacedDigit()
                .foregroundStyle(row.type == .income ? Color.green : Color.primary)
        }
        .padding(.vertical, 2)
    }
}
