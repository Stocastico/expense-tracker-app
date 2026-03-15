import SwiftUI
import SwiftData

struct BudgetRowView: View {
    let budget: Budget
    let transactions: [Transaction]
    var startOfMonth: Int = 1

    private var category: Category {
        DefaultCategories.category(withId: budget.categoryId)
    }

    private var periodRange: (start: Date, end: Date) {
        budget.currentPeriodRange(startOfMonth: startOfMonth)
    }

    private var spent: Double {
        transactions.filter { transaction in
            transaction.transactionType == .expense
                && transaction.categoryId == budget.categoryId
                && transaction.date >= periodRange.start
                && transaction.date <= periodRange.end
        }
        .reduce(0.0) { $0 + $1.storedAmount }
    }

    private var budgetAmount: Double {
        budget.storedAmount
    }

    private var percentage: Double {
        guard budgetAmount > 0 else { return 0 }
        return (spent / budgetAmount) * 100.0
    }

    private var progressRatio: Double {
        guard budgetAmount > 0 else { return 0 }
        return min(spent / budgetAmount, 1.5)
    }

    private var statusColor: Color {
        if percentage > 100 {
            return .red
        } else if percentage >= 80 {
            return .orange
        } else {
            return .green
        }
    }

    private var statusIcon: String {
        if percentage > 100 {
            return "xmark.circle.fill"
        } else if percentage >= 80 {
            return "exclamationmark.triangle.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(category.icon)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(category.name)
                        .font(.headline)

                    Spacer()

                    Image(systemName: statusIcon)
                        .foregroundStyle(statusColor)

                    Text(String(format: "%.0f%%", percentage))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(statusColor)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(statusColor)
                            .frame(
                                width: min(geometry.size.width * CGFloat(min(progressRatio, 1.0)), geometry.size.width),
                                height: 8
                            )
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(spent.currencyFormatted(code: budget.currency)) / \(budgetAmount.currencyFormatted(code: budget.currency))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    let remaining = budgetAmount - spent
                    if remaining >= 0 {
                        Text("\(remaining.currencyFormatted(code: budget.currency)) remaining")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text("\(abs(remaining).currencyFormatted(code: budget.currency)) over budget")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
