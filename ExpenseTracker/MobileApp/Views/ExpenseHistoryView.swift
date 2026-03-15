import SwiftUI
import SwiftData

struct ExpenseHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    @State private var searchText: String = ""
    @State private var selectedTransaction: Transaction?
    @State private var filterType: FilterType = .all

    enum FilterType: String, CaseIterable {
        case all = "All"
        case expense = "Expenses"
        case income = "Income"
    }

    // MARK: - Computed Properties

    private var filteredTransactions: [Transaction] {
        var result = Array(allTransactions.prefix(200))

        // Filter by type
        switch filterType {
        case .expense: result = result.filter { $0.type == .expense }
        case .income:  result = result.filter { $0.type == .income }
        case .all:     break
        }

        // Filter by search
        guard !searchText.isEmpty else { return result }
        let lowered = searchText.lowercased()
        return result.filter { transaction in
            transaction.descriptionText.lowercased().contains(lowered)
                || (transaction.merchant?.lowercased().contains(lowered) ?? false)
                || (transaction.notes?.lowercased().contains(lowered) ?? false)
                || DefaultCategories.category(withId: transaction.categoryId).name.lowercased().contains(lowered)
        }
    }

    private var groupedTransactions: [(date: String, transactions: [Transaction])] {
        let grouped = Dictionary(grouping: filteredTransactions) { transaction in
            transaction.date.relativeDescription
        }

        return grouped
            .map { (date: $0.key, transactions: $0.value) }
            .sorted { first, second in
                guard let firstDate = first.transactions.first?.date,
                      let secondDate = second.transactions.first?.date else {
                    return false
                }
                return firstDate > secondDate
            }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterChips
                Group {
                    if filteredTransactions.isEmpty {
                        emptyStateView
                    } else {
                        transactionList
                    }
                }
            }
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search transactions")
            .sheet(item: $selectedTransaction) { transaction in
                TransactionDetailSheet(transaction: transaction) { updated in
                    updateTransaction(updated)
                }
            }
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FilterType.allCases, id: \.self) { type in
                    filterChip(for: type)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func filterChip(for type: FilterType) -> some View {
        let isSelected = filterType == type
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                filterType = type
            }
        } label: {
            Text(type.rawValue)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Transactions", systemImage: "tray")
        } description: {
            if searchText.isEmpty && filterType == .all {
                Text("Add your first transaction to get started.")
            } else if !searchText.isEmpty {
                Text("No transactions match \"\(searchText)\".")
            } else {
                Text("No \(filterType.rawValue.lowercased()) found.")
            }
        }
    }

    // MARK: - Transaction List

    private var transactionList: some View {
        List {
            ForEach(groupedTransactions, id: \.date) { group in
                Section(header: Text(group.date)) {
                    ForEach(group.transactions) { transaction in
                        TransactionRow(transaction: transaction)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTransaction = transaction
                            }
                    }
                    .onDelete { indexSet in
                        deleteTransactions(from: group.transactions, at: indexSet)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Actions

    private func deleteTransactions(from transactions: [Transaction], at offsets: IndexSet) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()

        for index in offsets {
            let transaction = transactions[index]
            modelContext.delete(transaction)
        }
        do {
            try modelContext.save()
            generator.notificationOccurred(.success)
        } catch {
            print("Failed to delete transaction: \(error.localizedDescription)")
            generator.notificationOccurred(.error)
        }
    }

    private func updateTransaction(_ transaction: Transaction) {
        try? modelContext.save()
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    let transaction: Transaction

    private var category: Category {
        DefaultCategories.category(withId: transaction.categoryId)
    }

    private var amountColor: Color {
        transaction.type == .income ? .green : .red
    }

    private var formattedAmount: String {
        let prefix = transaction.type == .income ? "+" : "-"
        return "\(prefix)\(transaction.formattedAmount)"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: category.color).opacity(0.12))
                    .frame(width: 40, height: 40)
                Text(category.icon)
                    .font(.body)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.descriptionText)
                    .font(.body)
                    .lineLimit(1)

                if let accountName = transaction.account?.name {
                    Text(accountName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(category.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedAmount)
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(amountColor)
                if transaction.isRecurring {
                    Image(systemName: "repeat")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Transaction Detail Sheet

struct TransactionDetailSheet: View {
    let transaction: Transaction
    let onSave: (Transaction) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false

    private var category: Category {
        DefaultCategories.category(withId: transaction.categoryId)
    }

    var body: some View {
        NavigationStack {
            List {
                // Header card
                Section {
                    VStack(spacing: 8) {
                        Text(category.icon)
                            .font(.system(size: 44))
                        Text(transaction.type == .expense
                             ? "-\(transaction.formattedAmount)"
                             : "+\(transaction.formattedAmount)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(transaction.type == .expense ? .red : .green)
                        Text(transaction.descriptionText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }

                Section("Details") {
                    detailRow("Type", value: transaction.type.displayName)
                    detailRow("Category", value: category.displayName)
                    detailRow("Date", value: formattedDate(transaction.date))

                    if let accountName = transaction.account?.displayName {
                        detailRow("Account", value: accountName)
                    }

                    if let merchant = transaction.merchant, !merchant.isEmpty {
                        detailRow("Merchant", value: merchant)
                    }
                }

                if let notes = transaction.notes, !notes.isEmpty {
                    Section("Notes") {
                        Text(notes)
                            .font(.body)
                    }
                }

                if !transaction.tags.isEmpty {
                    Section("Tags") {
                        FlowLayout(spacing: 6) {
                            ForEach(transaction.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color(.systemGray5)))
                            }
                        }
                    }
                }

                if transaction.isRecurring {
                    Section("Recurring") {
                        detailRow("Frequency", value: transaction.recurringFrequency?.displayName ?? "Unknown")
                        if let endDate = transaction.recurringEndDate {
                            detailRow("End Date", value: formattedDate(endDate))
                        }
                    }
                }

                Section("Metadata") {
                    detailRow("Created", value: formattedDateTime(transaction.createdAt))
                    detailRow("Updated", value: formattedDateTime(transaction.updatedAt))
                }
            }
            .navigationTitle("Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formattedDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                                  proposal: .unspecified)
        }
    }

    private func layoutSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}

// MARK: - Transaction Identifiable Conformance

extension Transaction: @retroactive Identifiable {}
