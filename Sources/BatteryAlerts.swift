import Foundation
import UserNotifications

/// Posts a notification the first time the battery drops to each chosen
/// level while unplugged. A level re-arms once the battery climbs back above
/// it or the charger is connected, so each threshold fires once per discharge.
final class BatteryAlerts: ObservableObject {
    static let availableThresholds = [5, 10, 15, 20, 30, 50]

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "lowBatteryAlertsEnabled")
            if isEnabled { requestPermission() }
        }
    }
    @Published var thresholds: Set<Int> {
        didSet { UserDefaults.standard.set(Array(thresholds), forKey: "lowBatteryThresholds") }
    }

    private var fired: Set<Int> = []

    init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.object(forKey: "lowBatteryAlertsEnabled") as? Bool ?? true
        thresholds = Set(defaults.array(forKey: "lowBatteryThresholds") as? [Int] ?? [20, 10])
        if isEnabled { requestPermission() }
    }

    func toggle(_ threshold: Int) {
        if thresholds.contains(threshold) {
            thresholds.remove(threshold)
        } else {
            thresholds.insert(threshold)
        }
    }

    /// Call on every battery refresh.
    func check(level: Int, acConnected: Bool) {
        if acConnected {
            fired.removeAll()
            return
        }
        fired = fired.filter { level <= $0 }
        guard isEnabled else { return }

        // Only announce the lowest newly-crossed level, so a big drop between
        // refreshes (e.g. after sleep) doesn't post a pile of notifications.
        let crossed = thresholds.filter { level <= $0 && !fired.contains($0) }
        guard let lowest = crossed.min() else { return }
        fired.formUnion(crossed)
        post(level: level, threshold: lowest)
    }

    private func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func post(level: Int, threshold: Int) {
        let content = UNMutableNotificationContent()
        content.title = threshold <= 10 ? "Battery critically low" : "Battery low"
        content.body = "\(level)% remaining. Plug in soon."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "low-battery-\(threshold)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
