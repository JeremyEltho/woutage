import AppKit

struct ProcessRow: Identifiable {
    let id = UUID()
    let icon: NSImage
    let name: String
    let subtitle: String?
    let value: String
    /// Set when the row is a real installed app, so clicking it can bring it forward.
    let bundleID: String?
}
