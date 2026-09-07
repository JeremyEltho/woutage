import SwiftUI

let powerFormatter: MeasurementFormatter = {
    let formatter = MeasurementFormatter()
    formatter.unitStyle = .short
    let numberFormatter = NumberFormatter()
    numberFormatter.numberStyle = .decimal
    numberFormatter.minimumFractionDigits = 1
    numberFormatter.maximumFractionDigits = 1
    formatter.numberFormatter = numberFormatter
    return formatter
}()

private enum PowerGraphItemType: String {
    case battery = "battery.100"
    case external = "bolt.fill"
    case system = "laptopcomputer"
}

private struct PowerGraphItem: View {
    let type: PowerGraphItemType
    let power: Float

    var body: some View {
        GroupBox {
            HStack(spacing: 5) {
                Image(systemName: type.rawValue)
                    .frame(width: 20, height: 20)
                Text(powerFormatter.string(from: Measurement(value: Double(power), unit: UnitPower.watts)))
                    .monospacedDigit()
            }
            .frame(width: 80, height: 20)
        }
    }
}

/// Sources on the left, destinations on the right, arrow between — battery is a source
/// while discharging (positive power) and a destination while charging (negative).
struct PowerGraph: View {
    let batteryPower: Float
    let externalPower: Float
    let systemPower: Float

    private func sourceItems() -> [PowerGraphItem] {
        var items = [PowerGraphItem]()
        if batteryPower > 0 {
            items.append(PowerGraphItem(type: .battery, power: batteryPower))
        }
        if externalPower > 0 {
            items.append(PowerGraphItem(type: .external, power: externalPower))
        }
        items.sort { $0.power > $1.power }
        return items
    }

    private func targetItems() -> [PowerGraphItem] {
        var items = [PowerGraphItem]()
        if batteryPower < 0 {
            items.append(PowerGraphItem(type: .battery, power: abs(batteryPower)))
        }
        items.append(PowerGraphItem(type: .system, power: systemPower))
        items.sort { $0.power > $1.power }
        return items
    }

    var body: some View {
        HStack {
            VStack {
                ForEach(sourceItems(), id: \.type) { $0 }
            }
            Spacer()
            Image(systemName: "arrow.forward")
            Spacer()
            VStack {
                ForEach(targetItems(), id: \.type) { $0 }
            }
        }
        .foregroundColor(.secondary)
        .font(.callout)
    }
}
