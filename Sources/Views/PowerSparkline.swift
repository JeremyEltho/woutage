import Charts
import SwiftUI

/// System power draw over the last few minutes, sampled on each refresh.
struct PowerSparkline: View {
    let samples: [PowerSample]

    private var average: Double {
        guard !samples.isEmpty else { return 0 }
        return samples.map(\.watts).reduce(0, +) / Double(samples.count)
    }

    private var peak: Double { samples.map(\.watts).max() ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                stat("Now", samples.last?.watts ?? 0)
                stat("Avg", average)
                stat("Peak", peak)
            }

            if samples.count < 2 {
                Text("Collecting samples…")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity, minHeight: 50)
            } else {
                Chart(samples) { sample in
                    AreaMark(x: .value("Time", sample.date), y: .value("Watts", sample.watts))
                        .foregroundStyle(.linearGradient(
                            colors: [.orange.opacity(0.45), .orange.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Time", sample.date), y: .value("Watts", sample.watts))
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .interpolationMethod(.monotone)
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 2)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let w = value.as(Double.self) { Text("\(Int(w))W") }
                        }
                    }
                }
                .frame(height: 50)
            }
        }
    }

    private func stat(_ title: String, _ watts: Double) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(String(format: "%.1fW", watts))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
    }
}
