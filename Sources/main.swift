import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let model = PowerModel()
    var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)
            image?.isTemplate = true
            button.image = image
            button.title = "  …"
            button.action = #selector(togglePopover)
            button.target = self
        }

        let hosting = NSHostingController(rootView: ContentView(model: model, quitAction: { [weak self] in
            self?.quit()
        }))
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = hosting

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
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
