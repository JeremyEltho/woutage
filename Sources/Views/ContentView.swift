import SwiftUI

struct ContentView: View {
    @ObservedObject var model: PowerModel
    let quitAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InfoRow(label: "Battery", value: "\(model.level)%", bold: true)
                .padding(.bottom, 4)

            InfoRow(label: model.isCharging ? "Time to Full" : "Time Left", value: model.timeText)
            InfoRow(label: "Power Source", value: model.acConnected ? "AC Power" : "Battery")
            InfoRow(label: "Status", value: model.isCharging ? "Charging" : "Discharging")

            FaintDivider()

            if let temp = model.temperatureC {
                InfoRow(label: "Temperature", value: String(format: "%.1f°C", temp))
            }
            if let cycles = model.cycleCount {
                InfoRow(label: "Cycle Count", value: "\(cycles)")
            }
            InfoRow(label: "Battery Health", value: model.healthPct.map { "\($0)%" } ?? "…")

            FaintDivider()

            Button(action: quitAction) {
                HStack {
                    Text("Quit woutage")
                        .foregroundColor(.primary)
                        .font(.system(size: 13))
                    Spacer()
                    Text("⌘Q")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(width: 280)
        .fixedSize(horizontal: false, vertical: true)
        .background(.regularMaterial)
    }
}
