import SwiftUI
import Charts

struct CategoryPieChart: View {
    let data: [CategoryBreakdown]
    var currency: String = "EUR"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Spending by Category")
                .font(.headline)

            if data.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.pie")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No expense data for this period")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            } else {
                HStack(alignment: .top, spacing: 24) {
                    Chart(data) { item in
                        SectorMark(
                            angle: .value("Amount", item.total),
                            innerRadius: .ratio(0.55),
                            angularInset: 1.5
                        )
                        .foregroundStyle(Color(hex: item.categoryColor))
                        .cornerRadius(4)
                    }
                    .frame(width: 200, height: 200)

                    legendView
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
    }

    private var legendView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(data) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: item.categoryColor))
                        .frame(width: 10, height: 10)

                    Text(item.categoryIcon)
                        .font(.caption)

                    Text(item.categoryName)
                        .font(.caption)
                        .lineLimit(1)

                    Spacer()

                    Text(item.total.currencyFormatted(code: currency))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Text(String(format: "%.0f%%", item.percentage))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 35, alignment: .trailing)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
