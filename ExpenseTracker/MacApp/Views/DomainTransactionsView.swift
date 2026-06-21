import SwiftUI
import SwiftData

/// A transactions list backed by the new `ExpenseDomain` via `ExpenseRepository`
/// — the first screen to read through the repository instead of the legacy
/// store. Thin shell over `ExpenseTransactionsListModel`, which owns the
/// filtering/search/sort logic.
struct DomainTransactionsView: View {
    /// The account selected in the global toolbar picker, used to scope the list.
    let selectedAccount: Account?

    @Environment(\.expenseRepository) private var repository
    @Environment(ExpenseErrorPresenter.self) private var errorPresenter
    @Query private var settingsResults: [AppSettings]
    @State private var model: ExpenseTransactionsListModel?
    @State private var showingAdd = false
    @State private var editingTransaction: ExpenseDomain.Transaction?

    private var currency: String { (settingsResults.first ?? AppSettings()).currency }

    var body: some View {
        Group {
            if let model {
                DomainTransactionsContent(
                    model: model,
                    currency: currency,
                    onEdit: { editingTransaction = $0 }
                )
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Expenses (beta)")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add Transaction", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddDomainTransactionView(onSaved: { model?.load() })
        }
        .sheet(item: $editingTransaction) { transaction in
            AddDomainTransactionView(editing: transaction, onSaved: { model?.load() })
        }
        .task {
            let model = ensureModel()
            model.accountFilter = selectedAccount?.id
            model.load()
        }
        .onChange(of: selectedAccount?.id) { _, newValue in
            model?.accountFilter = newValue
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

/// The loaded list: filter bar, searchable, and date-grouped rows. Split out so
/// it can hold a `@Bindable` reference to the model for the filter controls.
private struct DomainTransactionsContent: View {
    @Bindable var model: ExpenseTransactionsListModel
    let currency: String
    let onEdit: (ExpenseDomain.Transaction) -> Void

    @State private var useStartDate = false
    @State private var useEndDate = false
    @State private var startDate = Date().monthsAgo(1)
    @State private var endDate = Date()

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()

            if model.rows.isEmpty {
                ContentUnavailableView(
                    "No expenses",
                    systemImage: "tray",
                    description: Text("Add one with +, adjust the filters, or imported and migrated expenses will appear here.")
                )
            } else {
                list
            }
        }
        .searchable(text: $model.searchQuery, prompt: "Search expenses...")
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        HStack(spacing: 12) {
            Picker("Type", selection: $model.typeFilter) {
                Text("All").tag(TransactionType?.none)
                Text("Expense").tag(TransactionType?.some(.expense))
                Text("Income").tag(TransactionType?.some(.income))
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            Picker("Category", selection: $model.categoryFilter) {
                Text("All Categories").tag(ExpenseDomain.Category.ID?.none)
                Divider()
                ForEach(model.categories) { category in
                    Text(category.displayName).tag(ExpenseDomain.Category.ID?.some(category.id))
                }
            }
            .frame(width: 180)

            Spacer()

            dateRangeControls

            Menu {
                Button {
                    model.sortField = .date
                } label: {
                    Label("Date", systemImage: model.sortField == .date ? "checkmark" : "")
                }
                Button {
                    model.sortField = .amount
                } label: {
                    Label("Amount", systemImage: model.sortField == .amount ? "checkmark" : "")
                }
                Divider()
                Button {
                    model.sortAscending.toggle()
                } label: {
                    Label(model.sortAscending ? "Ascending" : "Descending",
                          systemImage: model.sortAscending ? "arrow.up" : "arrow.down")
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var dateRangeControls: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Toggle("From", isOn: $useStartDate)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                Text("From").font(.caption)
                DatePicker("", selection: $startDate, displayedComponents: .date)
                    .labelsHidden()
                    .disabled(!useStartDate)
                    .frame(width: 100)
            }
            .opacity(useStartDate ? 1.0 : 0.5)

            HStack(spacing: 6) {
                Toggle("To", isOn: $useEndDate)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                Text("To").font(.caption)
                DatePicker("", selection: $endDate, displayedComponents: .date)
                    .labelsHidden()
                    .disabled(!useEndDate)
                    .frame(width: 100)
            }
            .opacity(useEndDate ? 1.0 : 0.5)
        }
        .onChange(of: useStartDate) { applyDateRange() }
        .onChange(of: useEndDate) { applyDateRange() }
        .onChange(of: startDate) { applyDateRange() }
        .onChange(of: endDate) { applyDateRange() }
    }

    private func applyDateRange() {
        model.startDate = useStartDate ? startDate.startOfDay : nil
        model.endDate = useEndDate ? endDate.endOfDay : nil
    }

    // MARK: - List

    private var list: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.rows) { row in
                        DomainTransactionRowView(row: row, currency: currency)
                            .contextMenu {
                                Button("Edit") {
                                    if let transaction = model.transaction(id: row.id) { onEdit(transaction) }
                                }
                                Button("Delete", role: .destructive) { model.delete(id: row.id) }
                            }
                    }
                } header: {
                    if let title = section.title {
                        Text(title).font(.caption.weight(.semibold))
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    /// Rows grouped into relative-date sections when sorting by date; a single
    /// unlabeled section otherwise (date grouping is meaningless under amount sort).
    private var sections: [RowSection] {
        guard model.sortField == .date else {
            return [RowSection(id: "all", title: nil, rows: model.rows)]
        }
        let grouped = Dictionary(grouping: model.rows) { $0.date.relativeDescription }
        return grouped
            .map { RowSection(id: $0.key, title: $0.key, rows: $0.value) }
            .sorted { first, second in
                guard let d1 = first.rows.first?.date, let d2 = second.rows.first?.date else { return false }
                return model.sortAscending ? d1 < d2 : d1 > d2
            }
    }

    private struct RowSection: Identifiable {
        let id: String
        let title: String?
        let rows: [ExpenseTransactionsListModel.Row]
    }
}

private struct DomainTransactionRowView: View {
    let row: ExpenseTransactionsListModel.Row
    let currency: String

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
            Text(row.amount.formatted(.currency(code: currency)))
                .monospacedDigit()
                .foregroundStyle(row.type == .income ? Color.green : Color.primary)
        }
        .padding(.vertical, 2)
    }
}
