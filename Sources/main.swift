import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let model = PowerModel()
    var popover: NSPopover!

    private var baseIcon: NSImage?
    private var animationTimer: Timer?

    // Sprite frame is drawn into a canvas padded beyond the icon's own size so
    // the random jump/wiggle offsets never clip against the button's edges.
    private let iconHeight: CGFloat = 26
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

    /// Redraws the sprite each tick at its current random-walk offset, so it
    /// reads as a tiny character idling, then hopping to an unpredictable
    /// spot, without ever leaving its fixed slot in the menu bar.
    private func startIconAnimation() {
        guard let baseIcon else { return }
        scheduleNextPhase()

        let canvasWidth = baseIcon.size.width + maxWalk * 2
        let canvasHeight = baseIcon.size.height + maxBounce
        let canvasSize = NSSize(width: canvasWidth, height: canvasHeight)

        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self, let button = self.statusItem.button else { return }

            var elapsed = Date().timeIntervalSince(self.phaseStart)
            if elapsed >= self.phaseDuration {
                self.scheduleNextPhase()
                elapsed = 0
            }

            if self.isMoving {
                let progress = min(elapsed / self.phaseDuration, 1)
                let eased = progress * progress * (3 - 2 * progress) // smoothstep
                self.offsetX = self.fromX + (self.toX - self.fromX) * CGFloat(eased)
                self.offsetY = self.fromY + (self.toY - self.fromY) * CGFloat(eased)
            }

            let frame = NSImage(size: canvasSize)
            frame.lockFocus()
            baseIcon.draw(at: NSPoint(x: self.maxWalk + self.offsetX, y: self.offsetY),
                          from: .zero, operation: .sourceOver, fraction: 1)
            frame.unlockFocus()
            frame.isTemplate = false
            button.image = frame
        }
        RunLoop.main.add(animationTimer!, forMode: .common)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
