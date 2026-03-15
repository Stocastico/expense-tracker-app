import SwiftUI
import SwiftData

struct ExpenseHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    @State private var searchText: String = ""
    @State private var selectedTransaction: Transaction?

    // MARK: - Computed Properties

    private var filteredTransactions: [Transaction] {
        let limited = Array(allTransactions.prefix(50))
        guard !searchText.isEmpty else { return limited }
        let lowered = searchText.lowercased()
        return limited.filter { transaction in
            transaction.descriptionText.lowercased().contains(lowered)
            || (transaction.merchant?.lowercased().contains(lowered) ?? false)
            || (transaction.notes?.lowercased().contains(lowered) ?? false)
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
            Group {
                if filteredTransactions.isEmpty {
                    emptyStateView
                } else {
                    transactionList
                }
            }
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search transactions")
            .sheet(item: $selectedTransaction) { transaction in
                TransactionDetailSheet(transaction: transaction)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Transactions", systemImage: "tray")
        } description: {
            if searchText.isEmpty {
                Text("Add your first transaction to get started.")
            } else {
                Text("No transactions match your search.")
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
        for index in offsets {
            let transaction = transactions[index]
            modelContext.delete(transaction)
        }
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete transaction: \(error.localizedDescription)")
        }
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
            Text(category.icon)
                .font(.title2)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.descriptionText)
                    .font(.body)
                    .lineLimit(1)

                if let accountName = transaction.account?.name {
                    Text(accountName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(formattedAmount)
                .font(.body.weight(.medium).monospacedDigit())
                .foregroundStyle(amountColor)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Transaction Detail Sheet

struct TransactionDetailSheet: View {
    let transaction: Transaction
    @Environment(\.dismiss) private var dismiss

    private var category: Category {
        DefaultCategories.category(withId: transaction.categoryId)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Details") {
                    detailRow("Type", value: transaction.type.displayName)
                    detailRow("Amount", value: transaction.formattedAmount)
                    detailRow("Description", value: transaction.descriptionText)
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
