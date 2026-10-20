import SwiftUI

/// The panel's hero: a ring gauge for the charge level, with the status and
/// time estimate beside it. The ring tints by level and glows while charging.
struct BatteryHeader: View {
    let level: Int
    let isCharging: Bool
    let acConnected: Bool
    let timeText: String

    private var tint: Color {
        if isCharging || acConnected { return .green }
        switch level {
        case ..<11: return .red
        case ..<21: return .orange
        default: return .green
        }
    }

    private var statusText: String {
        if isCharging { return "Charging" }
        if acConnected { return "Plugged In · Not Charging" }
        return "On Battery"
    }

    private var detailText: String {
        // PowerModel reports "Calculating…" until macOS has an estimate.
        let estimating = timeText.hasPrefix("Calculating")
        if isCharging { return estimating ? "Estimating time to full…" : "Full in \(timeText)" }
        if acConnected { return "On AC power" }
        return estimating ? "Estimating time left…" : "\(timeText) left"
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.18), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: CGFloat(level) / 100)
                    .stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    // A steady glow, not a pulsing one: a repeat-forever
                    // animation keeps SwiftUI rendering at the display's
                    // refresh rate even while the panel is closed.
                    .shadow(color: tint.opacity(isCharging ? 0.6 : 0.2), radius: isCharging ? 5 : 2)
                    .animation(.spring(duration: 0.6), value: level)
                VStack(spacing: 0) {
                    if isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(tint)
                    }
                    Text("\(level)%")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .frame(width: 66, height: 66)

            VStack(alignment: .leading, spacing: 3) {
                Text(statusText)
                    .font(.system(size: 15, weight: .semibold))
                Text(detailText)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
    }
}
