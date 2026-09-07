import AppKit
import IOKit
import IOKit.ps

/// Reads battery state from IOKit. No privileged helper required.
final class PowerModel: ObservableObject {
    @Published var level: Int = 0
    @Published var isCharging: Bool = false
    @Published var acConnected: Bool = false

    private var timer: Timer?

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first,
              let info = IOPSGetPowerSourceDescription(snapshot, first)?.takeUnretainedValue() as? [String: AnyObject]
        else { return }

        let level = info[kIOPSCurrentCapacityKey] as? Int ?? 0
        let isCharging = info[kIOPSIsChargingKey] as? Bool ?? false

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        defer { IOObjectRelease(service) }
        func regValue<T>(_ key: String) -> T? {
            guard service != 0, let ref = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0) else { return nil }
            return ref.takeRetainedValue() as? T
        }
        let acConnected: Bool = regValue("ExternalConnected") ?? false

        DispatchQueue.main.async {
            self.level = level
            self.isCharging = isCharging
            self.acConnected = acConnected
        }
    }
}
