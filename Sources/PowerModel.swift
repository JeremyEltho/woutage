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
        }

        fetchHealth()
    }
}
