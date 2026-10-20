import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let model = PowerModel()
    let keepAwake = KeepAwake()
    let alerts = BatteryAlerts()
    let launchAtLogin = LaunchAtLogin()
    var popover: NSPopover!
    private var outsideClickMonitor: Any?

    private var baseIcon: NSImage?
    private var phaseTimer: Timer?
    private let spriteLayer = CALayer()
    private let sweatLayer = CAShapeLayer()
    private var spriteHost: NSView?

    // Sprite frame is drawn into a canvas padded beyond the icon's own size so
    // the random jump/wiggle offsets never clip against the button's edges.
    private let iconHeight: CGFloat = 24
    private let maxWalk: CGFloat = 2
    private let maxBounce: CGFloat = 3

    // Random-walk animation state: the sprite hops to a random offset over a
    // random duration, then idles for a random pause before picking a new
    // target, so it never settles into a fixed loop.
    private var offsetX: CGFloat = 0
    private var offsetY: CGFloat = 0
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
        popover.delegate = self

        // Closing when another app takes focus covers Cmd-Tab and clicking
        // into other windows; the outside-click monitor below covers clicks
        // on other menu bar items, which don't change the active app.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.closePopover()
        }

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
            closePopover()
        } else {
            launchAtLogin.refresh()
            // A menu-bar-only app never comes to the front by itself, and a
            // transient popover only auto-closes while its app is active.
            if #available(macOS 14, *) {
                NSApp.activate()
            } else {
                NSApp.activate(ignoringOtherApps: true)
            }
            model.isPanelVisible = true
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            button.highlight(true)

            // Clicks anywhere outside the app, including other menu bar items,
            // close the panel like a regular menu.
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self] _ in
                self?.closePopover()
            }
        }
    }

    private func closePopover() {
        guard popover.isShown else { return }
        popover.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        model.isPanelVisible = false
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
        statusItem.button?.highlight(false)
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

    /// Sets up the sprite: the button gets a fixed, transparent placeholder
    /// image once, and the sprite lives on its own layer on top, so the status
    /// item itself never has to re-layout or redraw.
    private func startIconAnimation() {
        guard let baseIcon, let button = statusItem.button else { return }

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

        // A little sweat drop by the sprite's head, shown when the battery runs
        // hot. It's a sublayer of the sprite so it hops along with it.
        let drop = CGMutablePath()
        drop.move(to: CGPoint(x: 1.5, y: 5))
        drop.addCurve(to: CGPoint(x: 1.5, y: 0), control1: CGPoint(x: 1.5, y: 3.5), control2: CGPoint(x: -0.5, y: 1))
        drop.addCurve(to: CGPoint(x: 1.5, y: 5), control1: CGPoint(x: 3.5, y: 1), control2: CGPoint(x: 1.5, y: 3.5))
        sweatLayer.path = drop
        sweatLayer.fillColor = NSColor.systemCyan.cgColor
        sweatLayer.isHidden = true
        spriteLayer.addSublayer(sweatLayer)
        button.addSubview(host)
        spriteHost = host

        nextPhase()
    }

    /// Alternates between a hop to a random spot and an idle pause in place.
    ///
    /// Each hop is handed to Core Animation, which interpolates it in the
    /// window server, so the app does no per-frame work at all: it only wakes
    /// up once per hop or pause to pick the next one. (Driving it from a 60fps
    /// timer kept the main thread busy all the time, even while napping.)
    ///
    /// How lively it is depends on the machine: it scurries harder the more
    /// power the Mac draws, bounces high while charging, and drags itself
    /// around half-asleep when the battery is low.
    private func nextPhase() {
        let mood = SpriteMood(model: model)
        // Cheap, and once per phase is often enough to pick up layout, scale
        // and mood changes.
        layoutSprite(mood: mood)

        let duration: TimeInterval
        if isMoving {
            isMoving = false
            duration = Double.random(in: mood.pauseRange)
        } else {
            isMoving = true
            offsetX = CGFloat.random(in: -maxWalk...maxWalk) * mood.reach
            offsetY = CGFloat.random(in: mood.minBounce...1) * maxBounce * mood.reach
            duration = Double.random(in: mood.hopRange)

            let from = spriteLayer.position
            let to = spritePosition()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            spriteLayer.position = to
            CATransaction.commit()

            let hop = CABasicAnimation(keyPath: "position")
            hop.fromValue = NSValue(point: from)
            hop.toValue = NSValue(point: to)
            hop.duration = duration
            hop.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            spriteLayer.add(hop, forKey: "hop")
        }

        let timer = Timer(timeInterval: duration, repeats: false) { [weak self] _ in
            self?.nextPhase()
        }
        // Lets macOS coalesce this wakeup with others.
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        phaseTimer = timer
    }

    /// Size factor from the sprite's own points to the button's image rect
    /// (AppKit may scale the image down if the canvas is taller than the bar).
    private var spriteFit: CGFloat = 1

    /// Where the sprite layer sits for the current offset, snapped to whole
    /// device pixels so it doesn't shimmer between them.
    private func spritePosition() -> CGPoint {
        let scale = statusItem.button?.window?.backingScaleFactor ?? 2
        func snap(_ v: CGFloat) -> CGFloat { (v * scale).rounded() / scale }
        return CGPoint(x: snap((maxWalk + offsetX) * spriteFit), y: snap(offsetY * spriteFit))
    }

    private func layoutSprite(mood: SpriteMood) {
        guard let button = statusItem.button, let host = spriteHost, let baseIcon else { return }

        // Keep the overlay pinned to wherever the button draws its image.
        let imageRect = button.cell?.imageRect(forBounds: button.bounds) ?? host.frame
        if host.frame != imageRect { host.frame = imageRect }

        let scale = button.window?.backingScaleFactor ?? 2
        spriteFit = min(imageRect.width / (baseIcon.size.width + maxWalk * 2),
                        imageRect.height / (baseIcon.size.height + maxBounce))
        let spriteSize = CGSize(width: baseIcon.size.width * spriteFit, height: baseIcon.size.height * spriteFit)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if spriteLayer.contentsScale != scale || spriteLayer.contents == nil {
            spriteLayer.contentsScale = scale
            spriteLayer.contents = baseIcon.layerContents(forContentsScale: scale)
        }
        spriteLayer.bounds.size = spriteSize
        spriteLayer.opacity = mood.isSleepy ? 0.65 : 1

        sweatLayer.isHidden = !mood.isHot
        if mood.isHot, sweatLayer.animation(forKey: "drip") == nil {
            // Drip down the side of the head and fade, on a loop. Runs in the
            // window server like the hops, so it costs the app nothing.
            let top = CGPoint(x: spriteSize.width - 1, y: spriteSize.height * 0.75)
            let bottom = CGPoint(x: spriteSize.width - 1, y: spriteSize.height * 0.35)
            sweatLayer.position = top
            let slide = CABasicAnimation(keyPath: "position")
            slide.fromValue = NSValue(point: top)
            slide.toValue = NSValue(point: bottom)
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1
            fade.toValue = 0
            let drip = CAAnimationGroup()
            drip.animations = [slide, fade]
            drip.duration = 1.2
            drip.repeatCount = .infinity
            sweatLayer.add(drip, forKey: "drip")
        } else if !mood.isHot {
            sweatLayer.removeAnimation(forKey: "drip")
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
