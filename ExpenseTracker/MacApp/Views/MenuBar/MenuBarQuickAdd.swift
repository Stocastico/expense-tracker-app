import SwiftUI
import SwiftData

/// Compact quick-add form shown in the menu bar popover, for jotting down a
/// single expense or income without opening the main window or importing a
/// document. Writes through `ExpenseRepository` (the two-level domain) via
/// `ExpenseTransactionFormModel`; the popover stays open for repeated entries.
struct MenuBarQuickAdd: View {
    @Environment(\.expenseRepository) private var repository
    @Environment(ExpenseErrorPresenter.self) private var errorPresenter
    @Query(sort: \Account.createdAt) private var accounts: [Account]

    @State private var model: ExpenseTransactionFormModel?
    @State private var justSaved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Add")
                .font(.headline)

            if let model {
                form(model)
            } else {
                ProgressView()
            }
        }
        .padding()
        .frame(width: 280)
        .task { ensureModel() }
    }

    @ViewBuilder
    private func form(_ model: ExpenseTransactionFormModel) -> some View {
        @Bindable var model = model

        Picker("Type", selection: $model.type) {
            ForEach(TransactionType.allCases) { type in
                Text(type.displayName).tag(type)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()

        TextField("Amount", text: $model.amountText)
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 20, weight: .semibold, design: .rounded))

        TextField("Description", text: $model.descriptionText)
            .textFieldStyle(.roundedBorder)

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

        if !model.accounts.isEmpty {
            Picker("Account", selection: $model.selectedAccountId) {
                Text("None").tag(UUID?.none)
                ForEach(model.accounts) { account in
                    Text(account.name).tag(UUID?.some(account.id))
                }
            }
        }

        HStack {
            if justSaved {
                Label("Saved", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            Spacer()
            Button("Add") { save(model) }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Actions

    private func ensureModel() {
        guard model == nil else { return }
        let created = ExpenseTransactionFormModel(
            repository: repository,
            errorPresenter: errorPresenter,
            accounts: accounts.map { .init(id: $0.id, name: $0.name) }
        )
        created.load()
        // Default to the user's default account (or the first), as the legacy
        // quick-add did, so the common case needs no extra tap.
        let defaultAccount = accounts.first(where: { $0.isDefault }) ?? accounts.first
        created.selectedAccountId = defaultAccount?.id
        model = created
    }

    private func save(_ model: ExpenseTransactionFormModel) {
        guard model.save() else { return }
        // Keep the popover open for the next entry: clear the content but reuse
        // the chosen type/category/account.
        model.reset()
        justSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            justSaved = false
        }
    }
}
