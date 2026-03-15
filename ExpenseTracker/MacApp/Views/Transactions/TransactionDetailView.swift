import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    let transaction: Transaction
    let currency: String

    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false

    private var category: Category {
        DefaultCategories.category(withId: transaction.categoryId)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Transaction Details")
                    .font(.headline)
                Spacer()
                Button {
                    showingEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(.bordered)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Amount hero
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text(transaction.type == .expense ? "Expense" : "Income")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(transaction.type == .expense
                                ? "-\(transaction.storedAmount.currencyFormatted(code: currency))"
                                : "+\(transaction.storedAmount.currencyFormatted(code: currency))")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(transaction.type == .expense ? .red : .green)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)

                    // Details grid
                    VStack(spacing: 16) {
                        detailRow(label: "Description", value: transaction.descriptionText)

                        if let merchant = transaction.merchant, !merchant.isEmpty {
                            detailRow(label: "Merchant", value: merchant)
                        }

                        detailRow(label: "Category", value: "\(category.icon) \(category.name)")

                        detailRow(label: "Date", value: formatDate(transaction.date))

                        if let account = transaction.account {
                            detailRow(label: "Account", value: account.displayName)
                        }

                        let tags = transaction.tags
                        if !tags.isEmpty {
                            HStack(alignment: .top) {
                                Text("Tags")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 100, alignment: .leading)
                                FlowLayout(spacing: 4) {
                                    ForEach(tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(
                                                Capsule()
                                                    .fill(Color.accentColor.opacity(0.12))
                                            )
                                    }
                                }
                            }
                        }

                        if let notes = transaction.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(notes)
                                    .font(.body)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.secondary.opacity(0.08))
                                    )
                            }
                        }

                        if transaction.isRecurring {
                            detailRow(
                                label: "Recurring",
                                value: transaction.recurringFrequency?.displayName ?? "Yes"
                            )
                            if let endDate = transaction.recurringEndDate {
                                detailRow(label: "Ends", value: formatDate(endDate))
                            }
                        }
                    }

                    // Receipt image
                    if let data = transaction.receiptData, let nsImage = NSImage(data: data) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Receipt")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 250)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .shadow(radius: 2)
                        }
                    }

                    // Metadata
                    VStack(spacing: 4) {
                        Divider()
                        HStack {
                            Text("Created: \(formatDate(transaction.createdAt))")
                            Spacer()
                            Text("Updated: \(formatDate(transaction.updatedAt))")
                        }
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    }
                }
                .padding()
            }

            Divider()

            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .sheet(isPresented: $showingEditSheet) {
            TransactionFormView(transaction: transaction, currency: currency)
                .frame(minWidth: 500, minHeight: 600)
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.body)
            Spacer()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

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
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
