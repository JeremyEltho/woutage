import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let model = PowerModel()
    var popover: NSPopover!

    private var baseIcon: NSImage?
    private var animationTimer: Timer?
    private let spriteLayer = CALayer()
    private var spriteHost: NSView?

    // Sprite frame is drawn into a canvas padded beyond the icon's own size so
    // the random jump/wiggle offsets never clip against the button's edges.
    private let iconHeight: CGFloat = 28
    private let maxWalk: CGFloat = 3
    private let maxBounce: CGFloat = 4

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

        let hosting = NSHostingController(rootView: ContentView(model: model, quitAction: { [weak self] in
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
            self.statusItem.button?.title = "  \(self.model.level)% · \(wattsStr)"
        }
        model.start()
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
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
    private func scheduleNextPhase() {
        phaseStart = Date()
        if isMoving {
            isMoving = false
            phaseDuration = Double.random(in: 0.15...1.4)
        } else {
            isMoving = true
            fromX = offsetX
            fromY = offsetY
            toX = CGFloat.random(in: -maxWalk...maxWalk)
            toY = CGFloat.random(in: 0...maxBounce)
            phaseDuration = Double.random(in: 0.12...0.35)
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

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        spriteLayer.bounds.size = CGSize(width: baseIcon.size.width * fit, height: baseIcon.size.height * fit)
        spriteLayer.position = CGPoint(x: x, y: y)
        CATransaction.commit()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
