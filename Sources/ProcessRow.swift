import AppKit

struct ProcessRow: Identifiable {
    let id = UUID()
    let icon: NSImage
    let name: String
    let subtitle: String?
    let value: String
}
