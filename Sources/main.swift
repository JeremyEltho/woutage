import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let model = PowerModel()
    let keepAwake = KeepAwake()
    let alerts = BatteryAlerts()
    let launchAtLogin = LaunchAtLogin()
    var popover: NSPopover!

    private var baseIcon: NSImage?
    private var animationTimer: Timer?
    private let spriteLayer = CALayer()
    private let sweatLayer = CAShapeLayer()
    private var spriteHost: NSView?

    // Sprite frame is drawn into a canvas padded beyond the icon's own size so
    // the random jump/wiggle offsets never clip against the button's edges.
    private let iconHeight: CGFloat = 16
    private let maxWalk: CGFloat = 2
    private let maxBounce: CGFloat = 3

    // Random-walk animation state: the sprite eases from (fromX, fromY) to
    // (toX, toY) over a random duration, then idles for a random pause
    // before picking a new target — so it never settles into a fixed loop.
    private var offsetX: CGFloat = 0
    private var offsetY: CGFloat = 0
    private var fromX: CGFloat = 0
    private var fromY: CGFloat = 0
    private var toX: CGFloat = 0
    private var toY: CGFloat = 0
    private var phaseStart = Date()
    private var phaseDuration: TimeInterval = 0
    private var isMoving = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        baseIcon = Self.loadMenuBarIcon(height: iconHeight)
        if let button = statusItem.button {
            button.title = "  …"
            // Monospaced digits keep the title width fixed as the numbers
            // change, so neighbouring menu bar items don't shuffle around.
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.action = #selector(togglePopover)
            button.target = self
        }
        startIconAnimation()

        let hosting = NSHostingController(rootView: ContentView(model: model, keepAwake: keepAwake, alerts: alerts, launchAtLogin: launchAtLogin, quitAction: { [weak self] in
            self?.quit()
        }))
        // Without this the popover keeps a stale content size and clips the panel
        // against the top of the screen.
        hosting.sizingOptions = [.preferredContentSize]
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = hosting

        model.onUpdate = { [weak self] in
            guard let self else { return }
            let wattsStr = String(format: "%.1fW", self.model.watts)
            let title: String
            switch self.model.menuBarStyle {
            case .full: title = "  \(self.model.level)% · \(wattsStr)"
            case .percent: title = "  \(self.model.level)%"
            case .watts: title = "  \(wattsStr)"
            case .iconOnly: title = ""
            }
            self.statusItem.button?.title = title
            self.alerts.check(level: self.model.level, acConnected: self.model.acConnected)
        }
        model.start()
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            launchAtLogin.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    /// Loads the Claude Code sprite bundled in Contents/Resources and scales
    /// it to the given height. Kept as a color image (not a template) so the
    /// orange mark stays visible in both menu bar themes.
    private static func loadMenuBarIcon(height: CGFloat) -> NSImage? {
        guard let path = Bundle.main.path(forResource: "claude-icon", ofType: "svg"),
              let image = NSImage(contentsOfFile: path) else {
            return NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)
        }
        let width = height * (image.size.width / image.size.height)
        image.size = NSSize(width: width, height: height)
        image.isTemplate = false
        return image
    }

    /// Picks the sprite's next move: either a fresh random target position
    /// (an "eased" hop over a short random duration) or a random idle pause
    /// at its current spot, alternating so the movement never repeats on a
    /// fixed cadence.
    ///
    /// How lively it is depends on the machine: it scurries harder the more
    /// power the Mac draws, bounces high while charging, and drags itself
    /// around half-asleep when the battery is low.
    private func scheduleNextPhase() {
        phaseStart = Date()
        let mood = SpriteMood(model: model)
        if isMoving {
            isMoving = false
            phaseDuration = Double.random(in: mood.pauseRange)
        } else {
            isMoving = true
            fromX = offsetX
            fromY = offsetY
            toX = CGFloat.random(in: -maxWalk...maxWalk) * mood.reach
            toY = CGFloat.random(in: mood.minBounce...1) * maxBounce * mood.reach
            phaseDuration = Double.random(in: mood.hopRange)
        }
    }

    /// Moves the sprite each tick to its current random-walk offset, so it
    /// reads as a tiny character idling, then hopping to an unpredictable
    /// spot, without ever leaving its fixed slot in the menu bar.
    ///
    /// The button gets a fixed, transparent placeholder image once, and the
    /// sprite lives on its own layer on top. Only that layer's position
    /// changes per tick; swapping `button.image` every frame forced the whole
    /// status item to re-layout and redraw, which made it flicker and jitter.
    private func startIconAnimation() {
        guard let baseIcon, let button = statusItem.button else { return }
        scheduleNextPhase()

        let canvasSize = NSSize(width: baseIcon.size.width + maxWalk * 2,
                                height: baseIcon.size.height + maxBounce)
        let placeholder = NSImage(size: canvasSize)
        placeholder.isTemplate = false
        button.image = placeholder
        button.imagePosition = .imageLeft

        let host = NSView(frame: NSRect(origin: .zero, size: canvasSize))
        host.wantsLayer = true
        host.layer?.masksToBounds = false
        spriteLayer.anchorPoint = .zero
        spriteLayer.bounds = CGRect(origin: .zero, size: baseIcon.size)
        spriteLayer.contentsGravity = .resizeAspect
        host.layer?.addSublayer(spriteLayer)

        // A little sweat drop by the sprite's head, shown when the battery runs hot.
        let drop = CGMutablePath()
        drop.move(to: CGPoint(x: 1.5, y: 5))
        drop.addCurve(to: CGPoint(x: 1.5, y: 0), control1: CGPoint(x: 1.5, y: 3.5), control2: CGPoint(x: -0.5, y: 1))
        drop.addCurve(to: CGPoint(x: 1.5, y: 5), control1: CGPoint(x: 3.5, y: 1), control2: CGPoint(x: 1.5, y: 3.5))
        sweatLayer.path = drop
        sweatLayer.fillColor = NSColor.systemCyan.cgColor
        sweatLayer.isHidden = true
        host.layer?.addSublayer(sweatLayer)
        button.addSubview(host)
        spriteHost = host

        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tickAnimation()
        }
        RunLoop.main.add(animationTimer!, forMode: .common)
        tickAnimation()
    }

    private func tickAnimation() {
        guard let button = statusItem.button, let host = spriteHost, let baseIcon else { return }

        var elapsed = Date().timeIntervalSince(phaseStart)
        if elapsed >= phaseDuration {
            scheduleNextPhase()
            elapsed = 0
        }
        if isMoving {
            let progress = min(elapsed / phaseDuration, 1)
            let eased = progress * progress * (3 - 2 * progress) // smoothstep
            offsetX = fromX + (toX - fromX) * CGFloat(eased)
            offsetY = fromY + (toY - fromY) * CGFloat(eased)
        }

        // Keep the overlay pinned to wherever the button draws its image
        // (AppKit may scale it down if the canvas is taller than the bar).
        let imageRect = button.cell?.imageRect(forBounds: button.bounds) ?? host.frame
        if host.frame != imageRect { host.frame = imageRect }

        let scale = button.window?.backingScaleFactor ?? 2
        let fit = min(imageRect.width / (baseIcon.size.width + maxWalk * 2),
                      imageRect.height / (baseIcon.size.height + maxBounce))
        if spriteLayer.contentsScale != scale || spriteLayer.contents == nil {
            spriteLayer.contentsScale = scale
            spriteLayer.contents = baseIcon.layerContents(forContentsScale: scale)
        }

        // Snap to whole device pixels so the sprite doesn't shimmer as it
        // passes between them.
        func snap(_ v: CGFloat) -> CGFloat { (v * scale).rounded() / scale }
        let x = snap((maxWalk + offsetX) * fit)
        let y = snap(offsetY * fit)

        let mood = SpriteMood(model: model)
        let spriteSize = CGSize(width: baseIcon.size.width * fit, height: baseIcon.size.height * fit)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        spriteLayer.bounds.size = spriteSize
        spriteLayer.position = CGPoint(x: x, y: y)
        spriteLayer.opacity = mood.isSleepy ? 0.65 : 1
        sweatLayer.isHidden = !mood.isHot
        if mood.isHot {
            // Drip down the side of the head, then start again.
            let t = CGFloat(Date().timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.2) / 1.2)
            sweatLayer.position = CGPoint(x: x + spriteSize.width - 1, y: y + spriteSize.height * (0.75 - 0.4 * t))
            sweatLayer.opacity = Float(1 - t)
        }
        CATransaction.commit()
    }
}

/// How the sprite should behave right now, derived from the battery state.
private struct SpriteMood {
    let pauseRange: ClosedRange<Double>
    let hopRange: ClosedRange<Double>
    /// Scales how far it wanders and how high it hops.
    let reach: CGFloat
    /// Lowest hop as a fraction of the max, so charging hops are always big.
    let minBounce: CGFloat
    let isSleepy: Bool
    let isHot: Bool

    init(model: PowerModel) {
        isHot = (model.temperatureC ?? 0) >= 40
        isSleepy = model.level < 20 && !model.acConnected

        if isSleepy {
            pauseRange = 1.5...4
            hopRange = 0.5...0.9
            reach = 0.4
            minBounce = 0
            return
        }

        // 0 when idle, 1 at ~30W and up: more power, busier sprite.
        let energy = Double(min(max(model.systemPower / 30, 0), 1))
        let maxPause = 1.6 - 1.4 * energy
        pauseRange = (maxPause * 0.15)...maxPause
        let maxHop = 0.4 - 0.25 * energy
        hopRange = (maxHop * 0.5)...maxHop
        reach = model.isCharging ? 1 : 0.6 + 0.4 * CGFloat(energy)
        minBounce = model.isCharging ? 0.7 : 0
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
