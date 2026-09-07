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

            SectionHeader(title: "Last 12 hours")
            ChargeHistoryChart(history: model.chargeHistory)

            FaintDivider()

            SectionHeader(title: "Power distribution")
            PowerGraph(
                batteryPower: model.batteryPower,
                externalPower: model.externalPower,
                systemPower: model.systemPower
            )

            FaintDivider()

            SectionHeader(title: "Apps with High Energy Usage")
            if model.processes.isEmpty {
                Text("No apps using significant energy")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
            } else {
                ForEach(model.processes) { proc in
                    HStack(spacing: 8) {
                        Image(nsImage: proc.icon)
                            .resizable()
                            .frame(width: 18, height: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(proc.name)
                                .foregroundColor(.primary)
                                .font(.system(size: 13))
                                .lineLimit(1)
                            if let subtitle = proc.subtitle {
                                Text(subtitle)
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 10))
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Text(proc.value)
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                    }
                    .padding(.vertical, 3)
                }
            }

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
