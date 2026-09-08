import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let model = PowerModel()
    var popover: NSPopover!

    private var baseIcon: NSImage?
    private var animationTimer: Timer?
    private var animationStart = Date()

    // Sprite frame is drawn into a canvas padded beyond the icon's own size so
    // the walk/bounce offsets never clip against the button's edges.
    private let iconHeight: CGFloat = 24
    private let bounceAmplitude: CGFloat = 2
    private let walkAmplitude: CGFloat = 1.5

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

    /// Redraws the sprite each tick with a small horizontal wiggle and a
    /// vertical bounce, so the icon reads as a tiny walking/bouncing
    /// character without ever leaving its fixed slot in the menu bar.
    private func startIconAnimation() {
        guard let baseIcon else { return }
        animationStart = Date()

        let canvasWidth = baseIcon.size.width + walkAmplitude * 2
        let canvasHeight = baseIcon.size.height + bounceAmplitude
        let canvasSize = NSSize(width: canvasWidth, height: canvasHeight)

        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
            guard let self, let button = self.statusItem.button else { return }
            let t = Date().timeIntervalSince(self.animationStart)
            let xOffset = self.walkAmplitude * CGFloat(sin(t * 4))
            // Frequency doubled and rectified so the bounce always lifts
            // upward, like a footstep, rather than drifting up and down.
            let yOffset = self.bounceAmplitude * CGFloat(abs(sin(t * 4)))

            let frame = NSImage(size: canvasSize)
            frame.lockFocus()
            baseIcon.draw(at: NSPoint(x: self.walkAmplitude + xOffset, y: yOffset),
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
