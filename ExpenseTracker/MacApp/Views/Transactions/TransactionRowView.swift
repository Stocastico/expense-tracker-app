import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction
    var currency: String = "EUR"

    private var category: Category {
        DefaultCategories.category(withId: transaction.categoryId)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Category icon with colored circle
            Text(category.icon)
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color(hex: category.color).opacity(0.15))
                )

            // Description + merchant
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.descriptionText)
                    .font(.body)
                    .lineLimit(1)

                if let merchant = transaction.merchant, !merchant.isEmpty {
                    Text(merchant)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Amount colored by type
            VStack(alignment: .trailing, spacing: 3) {
                Text(transaction.type == .expense
                    ? "-\(transaction.storedAmount.currencyFormatted(code: currency))"
                    : "+\(transaction.storedAmount.currencyFormatted(code: currency))")
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(transaction.type == .expense ? .red : .green)

                // Date
                Text(transaction.date.shortDateString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
