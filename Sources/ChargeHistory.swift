import Foundation

struct ChargePoint: Identifiable {
    let id = UUID()
    let date: Date
    let level: Int
}

/// A stretch of time the charger was connected, drawn as a shaded band.
struct PluggedInterval: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date
}

struct ChargeHistory {
    var points: [ChargePoint] = []
    var pluggedIntervals: [PluggedInterval] = []
    var isEmpty: Bool { points.count < 2 }
}

/// Battery charge history straight from the system, via the same private
/// libsystemstats library used for energy impact. Because macOS records this
/// continuously, the graph is populated on first launch instead of only showing
/// data gathered since the app was installed.
enum ChargeHistoryReader {
    private static let chargeGraph: (() -> Unmanaged<NSDictionary>)? = {
        guard let handle = dlopen("/usr/lib/libsystemstats.dylib", RTLD_LAZY),
              let sym = dlsym(handle, "systemstats_get_battery_charge_graph") else { return nil }
        typealias Fn = @convention(c) () -> Unmanaged<NSDictionary>
        return unsafeBitCast(sym, to: Fn.self)
    }()

    /// Maximum points to hand to the chart. The raw series can hold tens of
    /// thousands of samples going back months.
    private static let maxPoints = 240

    static func history(hours: Double = 12) -> ChargeHistory {
        guard let fn = chargeGraph,
              let dict = fn().takeUnretainedValue() as? [String: Any],
              let levels = dict["charge_levels"] as? [UInt8],
              let chargeTimes = dict["charge_times"] as? [UInt],
              levels.count == chargeTimes.count
        else { return ChargeHistory() }

        let now = Date()
        let window = hours * 3600

        // The time arrays hold seconds *before now*, ordered oldest first.
        var points: [ChargePoint] = []
        for (index, secondsAgo) in chargeTimes.enumerated() {
            let age = Double(secondsAgo)
            guard age <= window else { continue }
            points.append(ChargePoint(date: now.addingTimeInterval(-age), level: Int(levels[index])))
        }
        points.sort { $0.date < $1.date }

        var intervals: [PluggedInterval] = []
        if let states = dict["battery_states"] as? [Bool],
           let stateTimes = dict["battery_times"] as? [UInt],
           states.count == stateTimes.count {
            let cutoff = now.addingTimeInterval(-window)
            // Each entry marks a change; it holds until the next one. `true` means
            // running on battery, so the charger is connected while it is false.
            var changes = zip(states, stateTimes)
                .map { (onBattery: $0.0, date: now.addingTimeInterval(-Double($0.1))) }
            changes.sort { $0.date < $1.date }

            for (index, change) in changes.enumerated() {
                guard !change.onBattery else { continue }
                let end = index + 1 < changes.count ? changes[index + 1].date : now
                guard end > cutoff else { continue }
                intervals.append(PluggedInterval(start: max(change.date, cutoff), end: end))
            }
        }

        return ChargeHistory(points: downsample(points), pluggedIntervals: intervals)
    }

    /// Keeps every nth point so the chart stays responsive, always preserving the
    /// most recent sample so the line reaches the right edge.
    private static func downsample(_ points: [ChargePoint]) -> [ChargePoint] {
        guard points.count > maxPoints else { return points }
        let stride = Int((Double(points.count) / Double(maxPoints)).rounded(.up))
        var result = points.enumerated().compactMap { $0.offset % stride == 0 ? $0.element : nil }
        if let last = points.last, result.last?.date != last.date {
            result.append(last)
        }
        return result
    }
}
