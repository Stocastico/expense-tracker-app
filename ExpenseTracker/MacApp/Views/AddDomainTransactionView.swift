import SwiftUI

/// A minimal add-transaction sheet that writes through `ExpenseRepository`.
/// Thin shell over `ExpenseTransactionFormModel`.
struct AddDomainTransactionView: View {
    /// Called after a successful save (so the list can reload).
    let onSaved: () -> Void

    @Environment(\.expenseRepository) private var repository
    @Environment(ExpenseErrorPresenter.self) private var errorPresenter
    @Environment(\.dismiss) private var dismiss
    @State private var model: ExpenseTransactionFormModel?

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    form(model)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("New transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { model?.save() }
                        .disabled(model == nil)
                }
            }
        }
        .frame(minWidth: 380, minHeight: 320)
        .task { ensureModel() }
    }

    @ViewBuilder
    private func form(_ model: ExpenseTransactionFormModel) -> some View {
        @Bindable var model = model
        Form {
            TextField("Amount", text: $model.amountText)
                .textFieldStyle(.roundedBorder)

            Picker("Type", selection: $model.type) {
                Text("Expense").tag(TransactionType.expense)
                Text("Income").tag(TransactionType.income)
            }
            .pickerStyle(.segmented)

            if model.type == .expense {
                Picker("Category", selection: $model.selectedCategoryId) {
                    Text("None").tag(UUID?.none)
                    ForEach(model.categories) { category in
                        Text(category.displayName).tag(UUID?.some(category.id))
                    }
                }
                if !model.subcategories.isEmpty {
                    Picker("Subcategory", selection: $model.selectedSubcategoryId) {
                        Text("None").tag(UUID?.none)
                        ForEach(model.subcategories) { subcategory in
                            Text(subcategory.displayName).tag(UUID?.some(subcategory.id))
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func ensureModel() {
        guard model == nil else { return }
        let created = ExpenseTransactionFormModel(
            repository: repository,
            errorPresenter: errorPresenter,
            onSaved: {
                dismiss()
                onSaved()
            }
        )
        created.load()
        model = created
    }
}
