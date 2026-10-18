import Foundation
import IOKit.pwr_mgt

/// Keeps the Mac (and its display) from idle-sleeping, like `caffeinate -d`,
/// using a power assertion that macOS drops automatically if the app quits.
final class KeepAwake: ObservableObject {
    enum Duration: Hashable, Identifiable {
        case minutes(Int)
        case indefinitely
        var id: String { label }

        var label: String {
            switch self {
            case .minutes(let m) where m >= 60: return "\(m / 60) hr"
            case .minutes(let m): return "\(m) min"
            case .indefinitely: return "∞"
            }
        }
    }

    static let choices: [Duration] = [.minutes(30), .minutes(60), .minutes(120), .indefinitely]

    @Published private(set) var isActive = false
    @Published private(set) var selected: Duration?
    /// When the assertion ends; nil while off or when running indefinitely.
    @Published private(set) var endsAt: Date?

    private var assertionID: IOPMAssertionID = 0
    private var expiryTimer: Timer?

    func start(_ duration: Duration) {
        stop()
        let reason = "woutage Keep Awake" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID)
        guard result == kIOReturnSuccess else { return }

        isActive = true
        selected = duration
        if case .minutes(let m) = duration {
            let end = Date().addingTimeInterval(TimeInterval(m * 60))
            endsAt = end
            expiryTimer = Timer.scheduledTimer(withTimeInterval: end.timeIntervalSinceNow, repeats: false) { [weak self] _ in
                self?.stop()
            }
        }
    }

    func stop() {
        expiryTimer?.invalidate()
        expiryTimer = nil
        if isActive {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
        isActive = false
        selected = nil
        endsAt = nil
    }
}
