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

        // Spotlight / indexing
        "mds": "Spotlight indexing",
        "mds_stores": "Spotlight index storage",
        "mdworker": "Spotlight file indexing",
        "mdworker_shared": "Spotlight file indexing",
        "mdsync": "Spotlight index sync",
        "Spotlight": "Spotlight search",
        "spotlightknowledged": "Spotlight suggestions",
        "corespotlightd": "Spotlight app content indexing",

        // Audio / video / media
        "coreaudiod": "Audio system",
        "audiomxd": "Audio processing",
        "avconferenced": "FaceTime video",
        "VTDecoderXPCService": "Video decoding",
        "mediaanalysisd": "Photos & media analysis",
        "photoanalysisd": "Photos face & scene analysis",
        "photolibraryd": "Photos library",
        "AMPLibraryAgent": "Music library",
        "airplayd": "AirPlay",
        "AirPlayXPCHelper": "AirPlay",

        // Network / connectivity
        "mDNSResponder": "Network discovery & DNS",
        "bluetoothd": "Bluetooth",
        "wifid": "Wi-Fi",
        "airportd": "Wi-Fi",
        "nsurlsessiond": "Background downloads & uploads",
        "netbiosd": "Network file sharing",
        "nesessionmanager": "VPN & network extensions",
        "sharingd": "AirDrop, Handoff & sharing",
        "rapportd": "Continuity (Handoff, Universal Clipboard)",
        "remoted": "Device connectivity",
        "usbd": "USB devices",

        // iCloud / accounts / sync
        "bird": "iCloud Drive sync",
        "cloudd": "iCloud sync",
        "cloudphotod": "iCloud Photos sync",
        "accountsd": "Internet accounts",
        "identityservicesd": "iMessage & FaceTime",
        "callservicesd": "Phone & FaceTime calls",
        "apsd": "Apple Push Notifications",
        "akd": "Apple ID authentication",
        "itunescloudd": "Apple Music sync",
        "gamed": "Game Center",

        // Siri / intelligence
        "assistantd": "Siri",
        "corespeechd": "Siri speech recognition",
        "suggestd": "Siri suggestions & proactive features",
        "knowledge-agent": "Screen Time & usage tracking",
        "parsecd": "Siri & Spotlight suggestions",
        "generativeexperiencesd": "Apple Intelligence",

        // Updates / installs / backup
        "softwareupdated": "Software Update",
        "installd": "App installation",
        "installcoordinationd": "App installation",
        "storeaccountd": "App Store account",
        "appstoreagent": "App Store",
        "backupd": "Time Machine backup",
        "backupd-helper": "Time Machine backup",
        "XProtect": "Malware protection scan",
        "XProtectRemediatorScan": "Malware protection scan",

        // Common third-party helpers
        "node": "Node.js script or dev server",
        "python3": "Python script",
        "ruby": "Ruby script",
        "java": "Java application",
        "docker": "Docker",
        "com.docker.backend": "Docker",
        "top": "System monitor (this list's sampler)",
        "claude": "Claude Code CLI",
        "remotepairingd": "Device pairing (iPhone/iPad)",
        "usernoted": "User notifications",
        "automationmoded": "Automation & shortcuts",
        "IOUserBluetoothSerialDriver": "Bluetooth serial driver",
        "ThemeWidgetControlViewService": "Widgets",
        "UsageTrackingAgent": "Screen Time usage tracking",
        "Activity Monitor": "Activity Monitor",
        "sourcekit-lsp": "Xcode/Swift code intelligence",
        "SourceKitService": "Xcode/Swift code completion",
        "swift-frontend": "Swift compiler",
        "clang": "C/C++ compiler",
        "gopls": "Go language server",
        "rust-analyzer": "Rust language server",
        "tsserver": "TypeScript language server",
    ]

    /// Resolves a raw process name to a friendly description. `top` truncates long
    /// command names, so fall back to prefix matching when there's no exact hit.
    static func description(for raw: String) -> String? {
        if let exact = descriptions[raw] { return exact }

        let lower = raw.lowercased()
        if let caseInsensitive = descriptions.first(where: { $0.key.lowercased() == lower }) {
            return caseInsensitive.value
        }
        // Truncated name from top (e.g. "automationmode-w"): match dictionary keys it prefixes.
        if lower.count >= 6, let prefixed = descriptions.first(where: { $0.key.lowercased().hasPrefix(lower) }) {
            return prefixed.value
        }
        // Version-number-looking binaries ("2.1.263") are almost always bundled helpers.
        if raw.range(of: #"^[\d.]+$"#, options: .regularExpression) != nil {
            return "Background helper process"
        }
        // Reverse-DNS binaries are Apple/vendor background services.
        if lower.hasPrefix("com.apple.") { return "Apple system service" }
        if lower.hasPrefix("com.") { return "Background service" }
        // Daemons conventionally end in "d" and are all-lowercase ("locationd"), unlike
        // app names ("Discord"), so only treat the lowercase form as a daemon.
        if raw == lower, lower.hasSuffix("d"), lower.count > 4, !lower.contains(" ") {
            return "System background service"
        }
        return nil
    }
}
