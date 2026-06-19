import SwiftUI
import Charts

struct BalanceTrendChart: View {
    let data: [BalancePoint]

    var body: some View {
        GroupBox("Net Balance Trend") {
            if data.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Add transactions to see balance trends.")
                )
                .frame(height: 250)
            } else {
                Chart {
                    ForEach(data) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Balance", point.balance)
                        )
                        .foregroundStyle(lineColor)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Balance", point.balance)
                        )
                        .foregroundStyle(areaGradient)
                        .interpolationMethod(.catmullRom)
                    }
                }
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
                        AxisGridLine()
                        AxisValueLabel {
                            if let dateValue = value.as(Date.self) {
                                Text(dateValue.shortDateString)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 250)
                .padding(.top, 8)
            }
        }
    }

    private var isPositiveTrend: Bool {
        guard let last = data.last else { return true }
        return last.balance >= 0
    }

    private var lineColor: Color {
        isPositiveTrend ? .green : .red
    }

    private var areaGradient: LinearGradient {
        let baseColor = isPositiveTrend ? Color.green : Color.red
        return LinearGradient(
            colors: [baseColor.opacity(0.3), baseColor.opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
