import Foundation

/// Owns the two `com.apple.screencapture` preferences the app depends on, and puts
/// them back the way it found them on quit.
enum ScreenshotSettings {
    private static let domain = "com.apple.screencapture"
    private static let backupKey = "originalScreencapturePrefs"

    private static var systemDefaults: UserDefaults? { UserDefaults(suiteName: domain) }

    private static var desktop: URL {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop")
    }

    /// Where the system writes screenshots. Unset means ~/Desktop.
    static var saveLocation: URL {
        let raw = systemDefaults?.string(forKey: "location") ?? ""
        guard !raw.isEmpty else { return desktop }
        return URL(fileURLWithPath: (raw as NSString).expandingTildeInPath)
    }

    /// The floating thumbnail is what delays the file write, and we can only reach a
    /// screenshot once it exists on disk — so it has to go. The destination has to stay
    /// "file" for the same reason: a clipboard-only capture leaves nothing to save or drag.
    static func apply() {
        guard let defaults = systemDefaults else { return }

        // Record the originals once, so a relaunch doesn't back up our own values.
        if UserDefaults.standard.object(forKey: backupKey) == nil {
            var backup: [String: Any] = [:]
            for key in ["show-thumbnail", "target"] {
                if let value = defaults.object(forKey: key) { backup[key] = value }
            }
            UserDefaults.standard.set(backup, forKey: backupKey)
        }

        defaults.set(false, forKey: "show-thumbnail")
        if let target = defaults.string(forKey: "target"), target != "file" {
            defaults.set("file", forKey: "target")
        }
        reloadScreenshotUI()
    }

    static func restore() {
        guard let defaults = systemDefaults else { return }
        let backup = UserDefaults.standard.dictionary(forKey: backupKey) ?? [:]
        for key in ["show-thumbnail", "target"] {
            if let value = backup[key] {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        UserDefaults.standard.removeObject(forKey: backupKey)
        reloadScreenshotUI()
    }

    /// screencaptureui caches these prefs at launch and relaunches on demand, so a kill
    /// is the cheapest way to make a change take effect on the very next screenshot.
    private static func reloadScreenshotUI() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task.arguments = ["screencaptureui"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
    }
}
