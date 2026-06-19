import SwiftUI

struct SavingsRateView: View {
    let rate: Double
    let income: Double
    let expenses: Double
    let currency: String

    var body: some View {
        GroupBox("Savings Rate") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Savings Rate:")
                        .font(.headline)
                    Spacer()
                    Text(String(format: "%.1f%%", rate))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(rateColor)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 16)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(rateColor)
                            .frame(width: max(0, geometry.size.width * clampedRate), height: 16)
                    }
                }
                .frame(height: 16)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Income")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(income.currencyFormatted(code: currency))
                            .font(.callout)
                            .foregroundStyle(.green)
                    }

                    Text("-")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Expenses")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(expenses.currencyFormatted(code: currency))
                            .font(.callout)
                            .foregroundStyle(.red)
                    }

                    Text("=")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Savings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(savings.currencyFormatted(code: currency))
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(savings >= 0 ? .green : .red)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var savings: Double {
        income - expenses
    }

    private var clampedRate: Double {
        min(max(rate / 100.0, 0), 1.0)
    }

    private var rateColor: Color {
        if rate >= 20 {
            return .green
        } else if rate >= 10 {
            return .yellow
        } else if rate >= 0 {
            return .orange
        } else {
            return .red
        }
    }
}
