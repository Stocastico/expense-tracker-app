import SwiftUI
import SwiftData

struct TransactionListView: View {
    let selectedAccount: Account?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query private var settingsResults: [AppSettings]
    @Query(sort: \Account.createdAt) private var accounts: [Account]

    @State private var searchText = ""
    @State private var typeFilter: TransactionType? = nil
    @State private var categoryFilter: String? = nil
    @State private var sortField: TransactionFilter.SortField = .date
    @State private var sortAscending = false
    @State private var showingAddSheet = false
    @State private var showingPDFImport = false
    @State private var selectedTransaction: Transaction? = nil
    @State private var transactionToDelete: Transaction? = nil
    @State private var showDeleteConfirmation = false
    @State private var useStartDate = false
    @State private var useEndDate = false
    @State private var filterStartDate = Date().monthsAgo(1)
    @State private var filterEndDate = Date()

    private var settings: AppSettings {
        settingsResults.first ?? AppSettings()
    }

    private var currency: String { settings.currency }

    private var filteredTransactions: [Transaction] {
        var results = allTransactions

        // Account filter
        if let account = selectedAccount {
            results = results.filter { $0.account?.id == account.id }
        }

        // Search
        if !searchText.isEmpty {
            let lowered = searchText.lowercased()
            results = results.filter {
                $0.descriptionText.lowercased().contains(lowered)
                    || ($0.merchant?.lowercased().contains(lowered) ?? false)
                    || ($0.notes?.lowercased().contains(lowered) ?? false)
            }
        }

        // Type filter
        if let typeFilter {
            results = results.filter { $0.type == typeFilter }
        }

        // Category filter
        if let categoryFilter {
            results = results.filter { $0.categoryId == categoryFilter }
        }

        // Date range
        if useStartDate {
            results = results.filter { $0.date >= filterStartDate.startOfDay }
        }
        if useEndDate {
            results = results.filter { $0.date <= filterEndDate.endOfDay }
        }

        // Sort
        switch sortField {
        case .date:
            results.sort { sortAscending ? $0.date < $1.date : $0.date > $1.date }
        case .amount:
            results.sort { sortAscending ? $0.storedAmount < $1.storedAmount : $0.storedAmount > $1.storedAmount }
        }

        return results
    }

    private var groupedTransactions: [(key: String, transactions: [Transaction])] {
        let grouped = Dictionary(grouping: filteredTransactions) { transaction in
            transaction.date.relativeDescription
        }

        return grouped
            .map { (key: $0.key, transactions: $0.value) }
            .sorted { first, second in
                guard let d1 = first.transactions.first?.date,
                      let d2 = second.transactions.first?.date else { return false }
                return sortAscending ? d1 < d2 : d1 > d2
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()

            if filteredTransactions.isEmpty {
                emptyState
            } else {
                transactionList
            }
        }
        .navigationTitle("Transactions")
        .searchable(text: $searchText, prompt: "Search transactions...")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    showingPDFImport = true
                } label: {
                    Label("Import PDF", systemImage: "doc.text")
                }

                Button {
                    selectedTransaction = nil
                    showingAddSheet = true
                } label: {
                    Label("Add Transaction", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            TransactionFormView(transaction: selectedTransaction, currency: currency)
                .frame(minWidth: 500, minHeight: 600)
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailView(transaction: transaction, currency: currency)
                .frame(minWidth: 500, minHeight: 400)
        }
        .sheet(isPresented: $showingPDFImport) {
            PDFImportView(currency: currency)
                .frame(minWidth: 600, minHeight: 500)
        }
        .confirmationDialog(
            "Delete Transaction",
            isPresented: $showDeleteConfirmation,
            presenting: transactionToDelete
        ) { transaction in
            Button("Delete", role: .destructive) {
                let dataService = DataService(modelContext: modelContext)
                if transaction.isRecurring {
                    dataService.deleteTransactionAndRecurrences(transaction)
                } else {
                    dataService.deleteTransaction(transaction)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { transaction in
            Text("Are you sure you want to delete \"\(transaction.descriptionText)\"?")
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 12) {
            // Type picker
            Picker("Type", selection: $typeFilter) {
                Text("All").tag(TransactionType?.none)
                Text("Expense").tag(TransactionType?.some(.expense))
                Text("Income").tag(TransactionType?.some(.income))
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            // Category dropdown
            Picker("Category", selection: $categoryFilter) {
                Text("All Categories").tag(String?.none)
                Divider()
                ForEach(DefaultCategories.all, id: \.id) { cat in
                    Text("\(cat.icon) \(cat.name)").tag(String?.some(cat.id))
                }
            }
            .frame(width: 180)

            Spacer()

            // Date range toggles
            HStack(spacing: 6) {
                Toggle("From:", isOn: $useStartDate)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                Text("From")
                    .font(.caption)
                DatePicker("", selection: $filterStartDate, displayedComponents: .date)
                    .labelsHidden()
                    .disabled(!useStartDate)
                    .frame(width: 100)
            }
            .opacity(useStartDate ? 1.0 : 0.5)

            HStack(spacing: 6) {
                Toggle("To:", isOn: $useEndDate)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                Text("To")
                    .font(.caption)
                DatePicker("", selection: $filterEndDate, displayedComponents: .date)
                    .labelsHidden()
                    .disabled(!useEndDate)
                    .frame(width: 100)
            }
            .opacity(useEndDate ? 1.0 : 0.5)

            // Sort
            Menu {
                Button {
                    sortField = .date
                } label: {
                    Label("Date", systemImage: sortField == .date ? "checkmark" : "")
                }
                Button {
                    sortField = .amount
                } label: {
                    Label("Amount", systemImage: sortField == .amount ? "checkmark" : "")
                }
                Divider()
                Button {
                    sortAscending.toggle()
                } label: {
                    Label(sortAscending ? "Ascending" : "Descending",
                          systemImage: sortAscending ? "arrow.up" : "arrow.down")
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Transactions")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Add a transaction to get started, or adjust your filters.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Button {
                selectedTransaction = nil
                showingAddSheet = true
            } label: {
                Label("Add Transaction", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Transaction List

    private var transactionList: some View {
        List {
            ForEach(groupedTransactions, id: \.key) { group in
                Section(header: Text(group.key).font(.caption.weight(.semibold))) {
                    ForEach(group.transactions) { transaction in
                        TransactionRowView(transaction: transaction, currency: currency)
                            .onTapGesture {
                                selectedTransaction = transaction
                            }
                            .contextMenu {
                                Button {
                                    selectedTransaction = transaction
                                    showingAddSheet = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    transactionToDelete = transaction
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    transactionToDelete = transaction
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
}
