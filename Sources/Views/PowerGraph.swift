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

