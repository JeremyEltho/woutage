import SwiftUI

/// The panel's hero: a ring gauge for the charge level, with the status and
/// time estimate beside it. The ring tints by level and pulses while charging.
struct BatteryHeader: View {
    let level: Int
    let isCharging: Bool
    let acConnected: Bool
    let timeText: String

    @State private var pulse = false

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

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.18), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: CGFloat(level) / 100)
                    .stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: tint.opacity(pulse ? 0.7 : 0.2), radius: pulse ? 6 : 2)
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
                Text(isCharging ? "Full in \(timeText)" : acConnected ? "On AC power" : "\(timeText) left")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .onAppear { updatePulse() }
        .onChange(of: isCharging) { updatePulse() }
    }

    private func updatePulse() {
        if isCharging {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true }
        } else {
            withAnimation(.easeOut(duration: 0.3)) { pulse = false }
        }
    }
}
