import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSMenuItemValidation {
    private var statusItem: NSStatusItem?
    private var watcher: ScreenshotWatcher?
    private var thumbnail: ThumbnailPanel?
    private var activity: NSObjectProtocol?
    private let launchAtLoginItem = NSMenuItem(title: "Open at Login",
                                               action: #selector(toggleLaunchAtLogin(_:)),
                                               keyEquivalent: "")
    private let showPreviewItem = NSMenuItem(title: "Show Preview",
                                             action: #selector(toggleShowPreview(_:)),
                                             keyEquivalent: "")
    private let trashAfterUseItem = NSMenuItem(title: "Trash File After Drag or Close",
                                               action: #selector(toggleTrashAfterUse(_:)),
                                               keyEquivalent: "")
    private var cornerItems: [NSMenuItem] = []
    private var durationItems: [NSMenuItem] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A menu bar app with no windows is a prime App Nap candidate, and napping
        // throttles exactly what this app depends on: prompt delivery of directory
        // events. Idle system sleep stays allowed — the Mac should still doze off.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Watching for new screenshots")

        ScreenshotSettings.apply()
        setUpStatusItem()

        let watcher = ScreenshotWatcher(directory: ScreenshotSettings.saveLocation) { [weak self] url in
            self?.handle(url)
        }
        watcher.start()
        self.watcher = watcher
    }

    func applicationWillTerminate(_ notification: Notification) {
        watcher?.stop()
        ScreenshotSettings.restore()
    }

    private func handle(_ url: URL) {
        // Clipboard first — everything else can wait a frame.
        Clipboard.copyImage(at: url)
        Log.debug("copied \(url.lastPathComponent) to the clipboard")

        // A new screenshot replaces the old preview even when no new one will show.
        thumbnail?.dismiss()
        thumbnail = nil
        guard Preferences.showPreview, let image = NSImage(contentsOf: url) else { return }
        let panel = ThumbnailPanel(fileURL: url, image: image)
        panel.present()
        thumbnail = panel
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "camera.on.rectangle",
                                     accessibilityDescription: "ScreenShotClipboard")
        item.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.delegate = self
        for (index, line) in AppDelegate.aboutLines.enumerated() {
            menu.addItem(AppDelegate.captionItem(line, heading: index == 0))
        }
        menu.addItem(.separator())

        showPreviewItem.target = self
        menu.addItem(showPreviewItem)

        cornerItems = PreviewCorner.allCases.map { corner in
            let item = NSMenuItem(title: corner.title, action: #selector(chooseCorner(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = corner.rawValue
            return item
        }
        menu.addItem(AppDelegate.submenuItem("Preview Position", items: cornerItems))

        durationItems = Preferences.durationChoices.map { seconds in
            let item = NSMenuItem(title: "\(Int(seconds)) seconds", action: #selector(chooseDuration(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = seconds
            return item
        }
        menu.addItem(AppDelegate.submenuItem("Preview Duration", items: durationItems))

        trashAfterUseItem.target = self
        menu.addItem(trashAfterUseItem)
        menu.addItem(.separator())
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit ScreenShotClipboard",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    /// The status item is the only place to explain what the app does, since it has
    /// no window. Plain unclickable text, read once and ignored after.
    private static var aboutLines: [String] {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return [
            "ScreenShotClipboard \(version)",
            "Screenshots copy to your clipboard instantly",
            "and still save to your Desktop.",
            "Drag the preview into any app to use it.",
        ]
    }

    /// An item with no action is disabled by the menu's own auto-enabling, which is
    /// exactly what a caption should be.
    private static func captionItem(_ text: String, heading: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        let size = NSFont.smallSystemFontSize
        item.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: heading ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size),
            .foregroundColor: heading ? NSColor.labelColor : NSColor.secondaryLabelColor,
        ])
        return item
    }

    private static func submenuItem(_ title: String, items: [NSMenuItem]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: title)
        items.forEach(submenu.addItem)
        item.submenu = submenu
        return item
    }

    // Submenus are only reachable through the main menu, so refreshing everything
    // here covers them too.
    func menuWillOpen(_ menu: NSMenu) {
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        showPreviewItem.state = Preferences.showPreview ? .on : .off
        trashAfterUseItem.state = Preferences.trashAfterUse ? .on : .off
        let corner = Preferences.previewCorner.rawValue
        for item in cornerItems {
            item.state = item.representedObject as? String == corner ? .on : .off
        }
        let duration = Preferences.previewDuration
        for item in durationItems {
            item.state = item.representedObject as? TimeInterval == duration ? .on : .off
        }
    }

    /// Auto-enabling asks here; the preview settings mean nothing without a preview.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(chooseCorner(_:)), #selector(chooseDuration(_:)), #selector(toggleTrashAfterUse(_:)):
            return Preferences.showPreview
        default:
            return true
        }
    }

    @objc private func toggleShowPreview(_ sender: NSMenuItem) {
        Preferences.showPreview.toggle()
        if !Preferences.showPreview {
            thumbnail?.dismiss()
            thumbnail = nil
        }
    }

    @objc private func chooseCorner(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let corner = PreviewCorner(rawValue: raw) else { return }
        Preferences.previewCorner = corner
    }

    @objc private func chooseDuration(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? TimeInterval else { return }
        Preferences.previewDuration = seconds
    }

    @objc private func toggleTrashAfterUse(_ sender: NSMenuItem) {
        Preferences.trashAfterUse.toggle()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSSound.beep()
        }
        sender.state = service.status == .enabled ? .on : .off
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.setActivationPolicy(.accessory)
application.delegate = delegate
application.run()
