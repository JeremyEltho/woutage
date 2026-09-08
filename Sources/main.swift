import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let model = PowerModel()
    var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if let button = statusItem.button {
            let image = Self.loadMenuBarIcon()
            button.image = image
            button.title = "  …"
            button.action = #selector(togglePopover)
            button.target = self
        }

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

    /// Loads the Claude sunburst icon bundled in Contents/Resources and scales
    /// it to the status bar's icon height. Kept as a color image (not a
    /// template) so the orange mark stays visible in both menu bar themes.
    private static func loadMenuBarIcon() -> NSImage? {
        guard let path = Bundle.main.path(forResource: "claude-icon", ofType: "svg"),
              let image = NSImage(contentsOfFile: path) else {
            return NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)
        }
        let height: CGFloat = 18
        let width = height * (image.size.width / image.size.height)
        image.size = NSSize(width: width, height: height)
        image.isTemplate = false
        return image
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
