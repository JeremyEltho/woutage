import SwiftUI

struct ContentView: View {
    @ObservedObject var model: PowerModel
    @ObservedObject var alerts: BatteryAlerts
    let quitAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BatteryHeader(
                level: model.level,
                isCharging: model.isCharging,
                acConnected: model.acConnected,
                timeText: model.timeText
            )

            FaintDivider()

            SectionHeader(title: "Live power draw")
            PowerSparkline(samples: model.powerSamples)

            FaintDivider()

            SectionHeader(title: "Power distribution")
            PowerGraph(
                batteryPower: model.batteryPower,
                externalPower: model.externalPower,
                systemPower: model.systemPower
            )

            FaintDivider()

            SectionHeader(title: "Battery")
            if let temp = model.temperatureC {
                Button {
                    model.useFahrenheit.toggle()
                } label: {
                    InfoRow(label: "Temperature", value: formatTemperature(temp))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Click to switch between °C and °F")
            }
            if let cycles = model.cycleCount {
                InfoRow(label: "Cycle Count", value: "\(cycles)")
            }
            HealthRow(healthPct: model.healthPct)

            FaintDivider()

            SectionHeader(title: "Last 12 hours")
            ChargeHistoryChart(history: model.chargeHistory)

            FaintDivider()

            SectionHeader(title: "Apps with High Energy Usage")
            if model.processes.isEmpty {
                Text("No apps using significant energy")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
            } else {
                ForEach(model.processes) { proc in
                    AppEnergyRow(proc: proc)
                }
            }

            FaintDivider()

            Toggle(isOn: $alerts.isEnabled) {
                Text("Low battery alerts")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            if alerts.isEnabled {
                HStack(spacing: 5) {
                    ForEach(BatteryAlerts.availableThresholds, id: \.self) { level in
                        Chip(title: "\(level)%", isOn: alerts.thresholds.contains(level)) {
                            alerts.toggle(level)
                        }
                    }
                }
                .padding(.top, 4)
            }

            FaintDivider()

            HStack {
                Text("Menu bar")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
                Spacer()
                Picker("Menu bar", selection: $model.menuBarStyle) {
                    ForEach(MenuBarStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }

            FaintDivider()

            HStack(spacing: 8) {
                ShortcutButton(title: "Battery Settings", symbol: "gearshape") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
                ShortcutButton(title: "Activity Monitor", symbol: "waveform.path.ecg") {
                    NSWorkspace.shared.openApplication(
                        at: URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"),
                        configuration: NSWorkspace.OpenConfiguration())
                }
            }
            .padding(.bottom, 8)

            quitButton
        }
        .padding(16)
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
        .modifier(PanelGlassBackground())
    }

    private func formatTemperature(_ celsius: Double) -> String {
        model.useFahrenheit
            ? String(format: "%.1f°F", celsius * 9 / 5 + 32)
            : String(format: "%.1f°C", celsius)
    }

    @ViewBuilder
    private var quitButton: some View {
        let label = HStack {
            Text("Quit woutage")
                .foregroundColor(.primary)
                .font(.system(size: 13))
            Spacer()
            Text("⌘Q")
                .foregroundColor(.secondary)
                .font(.system(size: 13))
        }
        .contentShape(Rectangle())

        if #available(macOS 26, *) {
            Button(action: quitAction) { label }
                .buttonStyle(.glass)
                .keyboardShortcut("q")
        } else {
            Button(action: quitAction) { label }
                .buttonStyle(.plain)
                .keyboardShortcut("q")
        }
    }
}

/// Battery health with a capacity bar, tinted by how worn the battery is.
private struct HealthRow: View {
    let healthPct: Int?

    private var tint: Color {
        guard let healthPct else { return .secondary }
        switch healthPct {
        case 90...: return .green
        case 80..<90: return .yellow
        default: return .orange
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            InfoRow(label: "Battery Health", value: healthPct.map { "\($0)%" } ?? "…")
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(tint)
                        .frame(width: geo.size.width * CGFloat(healthPct ?? 0) / 100)
                }
            }
            .frame(height: 5)
        }
    }
}

/// One energy-hungry app. Real apps highlight on hover and come to the front on click.
private struct AppEnergyRow: View {
    let proc: ProcessRow
    @State private var hovering = false

    var body: some View {
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
                .monospacedDigit()
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.primary.opacity(hovering && proc.bundleID != nil ? 0.08 : 0))
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { activate() }
        .help(proc.bundleID != nil ? "Bring \(proc.name) to the front" : "")
    }

    private func activate() {
        guard let bundleID = proc.bundleID,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
        else { return }
        app.activate()
    }
}

private struct Chip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isOn ? .semibold : .regular))
                .monospacedDigit()
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(isOn ? Color.orange.opacity(0.85) : Color.primary.opacity(0.08)))
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct ShortcutButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity)
        }
        .controlSize(.regular)
    }
}

/// The popover's frosted panel. On macOS 26+ this uses the real Liquid Glass
/// material (`glassEffect`); on older systems it falls back to
/// `.ultraThinMaterial` with a hand-drawn edge highlight to approximate it.
private struct PanelGlassBackground: ViewModifier {
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 14, style: .continuous) }

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                .glassEffect(.regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial)
                .overlay(shape.strokeBorder(.white.opacity(0.15), lineWidth: 1))
                .clipShape(shape)
        }
    }
}
