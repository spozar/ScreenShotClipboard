import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var watcher: ScreenshotWatcher?
    private var thumbnail: ThumbnailPanel?
    private var activity: NSObjectProtocol?
    private let launchAtLoginItem = NSMenuItem(title: "Open at Login",
                                               action: #selector(toggleLaunchAtLogin(_:)),
                                               keyEquivalent: "")

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

        guard let image = NSImage(contentsOf: url) else { return }
        thumbnail?.dismiss()
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
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit ScreenShotClipboard",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    func menuWillOpen(_ menu: NSMenu) {
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
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
