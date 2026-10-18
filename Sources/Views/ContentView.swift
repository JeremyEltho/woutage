import SwiftUI

struct ContentView: View {
    @ObservedObject var model: PowerModel
    @ObservedObject var keepAwake: KeepAwake
    @ObservedObject var alerts: BatteryAlerts
    @ObservedObject var launchAtLogin: LaunchAtLogin
    let quitAction: () -> Void

    @State private var contentHeight: CGFloat = 600
    @State private var showSettings = false

    /// Tallest the panel may get: the screen's usable height (below the menu
    /// bar) minus room for the popover arrow. Anything taller scrolls instead
    /// of pushing the top of the panel off screen.
    private var maxPanelHeight: CGFloat {
        (NSScreen.main?.visibleFrame.height ?? 800) - 24
    }

    var body: some View {
        ScrollView(.vertical) {
            panelContent
                .background(GeometryReader { geo in
                    Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                })
        }
        .scrollIndicators(contentHeight > maxPanelHeight ? .automatic : .never)
        .scrollBounceBehavior(.basedOnSize)
        .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
        .frame(width: 300, height: min(contentHeight, maxPanelHeight))
        .modifier(PanelGlassBackground())
    }

    private var panelContent: some View {
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

            SectionHeader(title: "Keep Awake")
            KeepAwakeRow(keepAwake: keepAwake)

            FaintDivider()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showSettings.toggle() }
            } label: {
                HStack {
                    Text("Settings")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(showSettings ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showSettings {
                settings
                    .padding(.top, 10)
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
        // Pinned leading so that if anything is ever too wide it gets cut
        // off on the right, rather than the whole column shifting left.
        .frame(width: 300, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Set-and-forget options, folded away so the panel stays short.
    private var settings: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
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
                }
            }

            Toggle(isOn: Binding(get: { launchAtLogin.isEnabled }, set: { launchAtLogin.set($0) })) {
                Text("Launch at login")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            if let error = launchAtLogin.errorText {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }

            HStack {
                Text("Menu bar")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
                    .fixedSize()
                Spacer(minLength: 8)
                Picker("Menu bar", selection: $model.menuBarStyle) {
                    ForEach(MenuBarStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
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

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
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

/// Off plus one chip per duration; the active chip shows the time remaining.
private struct KeepAwakeRow: View {
    @ObservedObject var keepAwake: KeepAwake

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Chip(title: "Off", isOn: !keepAwake.isActive) { keepAwake.stop() }
                ForEach(KeepAwake.choices) { choice in
                    Chip(title: choice.label, isOn: keepAwake.selected == choice) { keepAwake.start(choice) }
                }
            }
            if keepAwake.isActive {
                HStack(spacing: 4) {
                    Image(systemName: "cup.and.saucer.fill")
                    if let endsAt = keepAwake.endsAt {
                        Text("Awake until \(endsAt, format: .dateTime.hour().minute())")
                    } else {
                        Text("Awake until you turn it off")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.orange)
            }
        }
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
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                // Chips share their row's width evenly, so a row of them
                // never pushes the panel wider than it is.
                .frame(maxWidth: .infinity)
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
