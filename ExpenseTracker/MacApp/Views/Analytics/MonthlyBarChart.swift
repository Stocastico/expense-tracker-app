import SwiftUI
import Charts

struct MonthlyBarChart: View {
    let data: [MonthlyTotal]

    var body: some View {
        GroupBox("Monthly Income vs Expenses") {
            if data.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.bar",
                    description: Text("Add transactions to see monthly trends.")
                )
                .frame(height: 250)
            } else {
                Chart {
                    ForEach(data) { item in
                        BarMark(
                            x: .value("Month", item.month.monthYearString),
                            y: .value("Amount", item.income)
                        )
                        .foregroundStyle(.green)
                        .position(by: .value("Type", "Income"))

                        BarMark(
                            x: .value("Month", item.month.monthYearString),
                            y: .value("Amount", item.expenses)
                        )
                        .foregroundStyle(.red)
                        .position(by: .value("Type", "Expenses"))
                    }
                }
                .chartForegroundStyleScale([
                    "Income": Color.green,
                    "Expenses": Color.red
                ])
                .chartLegend(position: .bottom, alignment: .center)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(doubleValue.currencyFormatted(code: "USD"))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.caption2)
                                    .rotationEffect(.degrees(-30))
                            }
                        }
                    }
                }
                .frame(height: 280)
                .padding(.top, 8)
            }
        }
    }
}
