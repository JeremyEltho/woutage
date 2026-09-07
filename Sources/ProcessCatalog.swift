import Foundation

/// Plain-English descriptions for macOS system processes, so the list explains what is
/// actually using power instead of showing cryptic daemon names like "mds_stores".
enum ProcessCatalog {
    static let descriptions: [String: String] = [
        // Core system / graphics
        "kernel_task": "macOS Kernel — thermal & CPU management",
        "WindowServer": "Display & graphics compositor",
        "WindowManager": "Stage Manager & window handling",
        "Dock": "Dock, Mission Control & Spaces",
        "Finder": "Finder — files & desktop",
        "SystemUIServer": "Menu bar items",
        "ControlCenter": "Control Center",
        "loginwindow": "Login session",
        "launchd": "Service & process manager",
        "runningboardd": "App lifecycle manager",
        "logd": "System logging",
        "syslogd": "System logging",
        "UserEventAgent": "System event agent",
        "distnoted": "System notification relay",
        "notifyd": "System notification relay",
        "cfprefsd": "App preferences store",
        "opendirectoryd": "User accounts & directory services",
        "diskarbitrationd": "Disk mounting",
        "fseventsd": "File system change tracking",
        "configd": "Network configuration",
        "powerd": "Power management",
        "thermald": "Thermal management",
        "watchdogd": "System watchdog",
        "hidd": "Keyboard, mouse & trackpad input",
        "pboard": "Clipboard",
        "amfid": "App code-signature verification",
        "syspolicyd": "Gatekeeper security policy",
        "tccd": "Privacy permissions",
        "trustd": "Certificate validation",
        "securityd": "Keychain & security",
        "secd": "Keychain sync",
        "sysmond": "System resource monitoring",
        "symptomsd": "Network diagnostics",
        "iconservicesagent": "App icon rendering",
        "quicklookd": "Quick Look previews",
        "lsd": "Launch Services (app registry)",
        "talagent": "Window restoration",
        "universalaccessd": "Accessibility features",
        "coreservicesd": "Core system services",
        "locationd": "Location Services",
        "NotificationCenter": "Notification Center",
        "TextInputMenuAgent": "Input menu",
        "TextInputSwitcher": "Input source switching",
        "ScreenSaverEngine": "Screen saver",
        "screencaptureui": "Screenshot tool",
        "ReportCrash": "Crash reporting",
        "spindump": "System responsiveness diagnostics",
        "coreduetd": "Device activity prediction",
        "dasd": "Background task scheduling",
        "duetexpertd": "System usage prediction",
        "contextstored": "System context tracking",
        "networkserviceproxy": "Network proxy",
        "trustdFileHelper": "Certificate validation",

    ]

    /// Resolves a raw process name to a friendly description. `top` truncates long
    /// command names, so fall back to prefix matching when there's no exact hit.
    static func description(for raw: String) -> String? {
        if let exact = descriptions[raw] { return exact }

        let lower = raw.lowercased()
        if let caseInsensitive = descriptions.first(where: { $0.key.lowercased() == lower }) {
            return caseInsensitive.value
        }
        return nil
    }
}
