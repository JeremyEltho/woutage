import AppKit
import IOKit
import IOKit.ps

/// Reads battery state from IOKit. No privileged helper required.
final class PowerModel: ObservableObject {
    @Published var level: Int = 0
    @Published var isCharging: Bool = false
    @Published var acConnected: Bool = false
    @Published var watts: Double = 0
    @Published var cycleCount: Int?
    @Published var temperatureC: Double?
    @Published var timeText: String = "…"
    @Published var healthPct: Int?
    @Published var processes: [ProcessRow] = []

    var onUpdate: (() -> Void)?

    /// Sample window for energy impact, in seconds.
    static let energyDuration = 180

    private var timer: Timer?
    private var cachedHealthPct: Int?
    private var lastHealthFetch: Date?

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    /// Battery health as macOS itself reports it in System Information. The raw IOKit
    /// capacity keys do not agree with Apple's own figure, so read the source of truth.
    func fetchHealth() {
        // system_profiler takes about a second, and battery health barely moves, so
        // only pay for it every few minutes.
        if let cached = cachedHealthPct, let last = lastHealthFetch, Date().timeIntervalSince(last) < 300 {
            DispatchQueue.main.async { self.healthPct = cached }
            return
        }
        DispatchQueue.global(qos: .utility).async {
            let task = Process()
            task.launchPath = "/usr/sbin/system_profiler"
            task.arguments = ["SPPowerDataType"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            var result: Int? = nil
            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                task.waitUntilExit()
                if let output = String(data: data, encoding: .utf8) {
                    for line in output.split(separator: "\n") {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.hasPrefix("Maximum Capacity:") {
                            result = Int(trimmed.filter { $0.isNumber })
                            break
                        }
                    }
                }
            } catch {}
            DispatchQueue.main.async {
                if let result {
                    self.cachedHealthPct = result
                    self.lastHealthFetch = Date()
                    self.healthPct = result
                }
            }
        }
    }

    static func formatMinutes(_ minutes: Int) -> String {
        guard minutes > 0, minutes < 1440 else { return "Calculating…" }
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? "\(h) hr, \(m) min" : "\(m) min"
    }

    func refresh() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first,
              let info = IOPSGetPowerSourceDescription(snapshot, first)?.takeUnretainedValue() as? [String: AnyObject]
        else { return }

        let level = info[kIOPSCurrentCapacityKey] as? Int ?? 0
        let isCharging = info[kIOPSIsChargingKey] as? Bool ?? false
        let timeLeft = info[kIOPSTimeToEmptyKey] as? Int ?? -1
        let timeToCharge = info[kIOPSTimeToFullChargeKey] as? Int ?? -1

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        defer { IOObjectRelease(service) }
        func regValue<T>(_ key: String) -> T? {
            guard service != 0, let ref = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0) else { return nil }
            return ref.takeRetainedValue() as? T
        }
        let acConnected: Bool = regValue("ExternalConnected") ?? false
        let voltageMV: Int = regValue("Voltage") ?? 0
        let amperageMA: Int = regValue("Amperage") ?? 0
        // Voltage x Amperage straight from the gas gauge. Verified against ioreg, and
        // self-consistent whether charging or discharging.
        let watts = abs(Double(voltageMV) * Double(amperageMA)) / 1_000_000.0
        let cycleCount: Int? = regValue("CycleCount")
        let virtualTemp: Int? = regValue("VirtualTemperature")
        let temperatureC = virtualTemp.map { Double($0) / 100.0 }

        DispatchQueue.main.async {
            self.level = level
            self.isCharging = isCharging
            self.acConnected = acConnected
            self.watts = watts
            self.cycleCount = cycleCount
            self.temperatureC = temperatureC
            self.timeText = Self.formatMinutes(isCharging ? timeToCharge : timeLeft)
            self.onUpdate?()
        }

        fetchHealth()
        fetchProcesses()
    }

    /// Energy impact per app, via the same private API Activity Monitor and BatFi use:
    /// `systemstats_get_top_coalitions` in libsystemstats. "Coalitions" are the kernel's
    /// own process grouping, so an app's helper processes (Chrome's renderers, etc.) are
    /// already aggregated for us. No root required, unlike powermetrics.
    private static let topCoalitions: ((Int, Int) -> Unmanaged<NSDictionary>)? = {
        guard let handle = dlopen("/usr/lib/libsystemstats.dylib", RTLD_LAZY),
              let sym = dlsym(handle, "systemstats_get_top_coalitions") else { return nil }
        typealias Fn = @convention(c) (Int, Int) -> Unmanaged<NSDictionary>
        return unsafeBitCast(sym, to: Fn.self)
    }()

    /// Turns a coalition bundle id into something readable: a real app name when the
    /// bundle resolves, otherwise the daemon name looked up in ProcessCatalog.
    static func label(forBundleID bundleID: String) -> (title: String, subtitle: String?, icon: NSImage) {
        let genericIcon = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: nil)
            ?? NSWorkspace.shared.icon(for: .unixExecutable)

        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            if let bundle = Bundle(url: url) {
                let name = bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String
                    ?? bundle.infoDictionary?["CFBundleDisplayName"] as? String
                    ?? bundle.localizedInfoDictionary?[kCFBundleNameKey as String] as? String
                    ?? bundle.infoDictionary?[kCFBundleNameKey as String] as? String
                if let name { return (name, nil, icon) }
            }
            return (url.deletingPathExtension().lastPathComponent, nil, icon)
        }

        // Not an installed app — derive the daemon name from the bundle id
        // ("com.apple.spotlightknowledged.updater" → "spotlightknowledged").
        var derived = bundleID
        if derived.hasPrefix("com.apple.") { derived.removeFirst("com.apple.".count) }
        let daemon = derived.split(separator: ".").first.map(String.init) ?? derived

        if let explanation = ProcessCatalog.description(for: daemon) {
            return (explanation, daemon, genericIcon)
        }
        return (daemon, bundleID == daemon ? nil : bundleID, genericIcon)
    }

    func fetchProcesses() {
        DispatchQueue.global(qos: .utility).async {
            guard let fn = Self.topCoalitions,
                  let dict = fn(Self.energyDuration, 10000).takeUnretainedValue() as? [String: Any],
                  let bundleIDs = dict["bundle_identifiers"] as? [String],
                  let impacts = dict["energy_impacts"] as? [Double],
                  bundleIDs.count == impacts.count
            else {
                DispatchQueue.main.async { self.processes = [] }
                return
            }

            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0

            var rows: [ProcessRow] = []
            for (index, bundleID) in bundleIDs.enumerated() {
                guard rows.count < 6 else { break }
                // Impacts are totals over the sample window; normalize to a rate.
                let impact = impacts[index] / Double(Self.energyDuration)
                guard impact >= 1 else { break }
                guard bundleID != "REDACTED" else { continue }

                let info = Self.label(forBundleID: bundleID)
                rows.append(ProcessRow(
                    icon: info.icon,
                    name: info.title,
                    subtitle: info.subtitle,
                    value: formatter.string(from: NSNumber(value: impact)) ?? "\(Int(impact))"
                ))
            }

            DispatchQueue.main.async {
                self.processes = rows
            }
        }
    }
}
