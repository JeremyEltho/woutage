import Charts
import SwiftUI

/// Battery level over the last 12 hours, with shaded bands for the stretches the
/// charger was plugged in.
struct ChargeHistoryChart: View {
    let history: ChargeHistory

    var body: some View {
        if history.isEmpty {
            Text("Waiting for data…")
                .foregroundColor(.secondary)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, minHeight: 80)
        } else {
            Chart {
                ForEach(history.pluggedIntervals) { interval in
                    RectangleMark(
                        xStart: .value("Start", interval.start),
                        xEnd: .value("End", interval.end),
                        yStart: .value("Level", 0),
                        yEnd: .value("Level", 100)
                    )
                    .foregroundStyle(.green)
                    .opacity(0.15)
                }

                ForEach(history.points) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("Battery Level", point.level)
                    )
                    .foregroundStyle(.green)
                    .interpolationMethod(.monotone)
                }
            }
            .chartYScale(domain: 0 ... 100)
            .chartYAxis {
                AxisMarks(values: [0, 50, 100]) {
                    AxisValueLabel(format: Decimal.FormatStyle.Percent.percent.scale(1))
                }
                AxisMarks(values: [0, 25, 50, 75, 100]) {
                    AxisGridLine()
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 3, roundLowerBound: true)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date, format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                        }
                        AxisGridLine()
                        AxisTick()
                    }
                }
            }
            .chartLegend(.hidden)
            .frame(height: 90)
        }
    }
}
