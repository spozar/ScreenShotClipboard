import Foundation

/// Watches the screenshot folder and reports each new file macOS tagged as a screen
/// capture. The tag is what keeps everything else that lands on the Desktop out of it.
final class ScreenshotWatcher {
    private static let captureAttribute = "com.apple.metadata:kMDItemIsScreenCapture"

    private let directory: URL
    private let onCapture: (URL) -> Void
    private let queue = DispatchQueue(label: "se.mediaempire.screenshotclipboard.watcher")
    private var source: DispatchSourceFileSystemObject?
    private var descriptor: CInt = -1
    private var known: Set<String> = []

    init(directory: URL, onCapture: @escaping (URL) -> Void) {
        self.directory = directory
        self.onCapture = onCapture
    }

    func start() {
        known = Set(names())
        Log.debug("watching \(directory.path), \(known.count) existing entries")
        descriptor = open(directory.path, O_EVTONLY)
        guard descriptor >= 0 else {
            Log.debug("open() failed: \(String(cString: strerror(errno)))")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor, eventMask: [.write, .rename], queue: queue)
        source.setEventHandler { [weak self] in self?.scan() }
        source.setCancelHandler { [weak self] in
            guard let self, self.descriptor >= 0 else { return }
            close(self.descriptor)
            self.descriptor = -1
        }
        self.source = source
        source.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func names() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    }

    private func scan() {
        let current = names()
        let added = current.filter { !known.contains($0) && !$0.hasPrefix(".") }
        known = Set(current)
        let removed = known.subtracting(current)
        Log.debug("directory event: \(current.count) entries, new \(added), gone \(Array(removed))")
        for name in added {
            let url = directory.appendingPathComponent(name)
            // Off the watcher queue: a file that never proves itself would otherwise
            // hold up the screenshot arriving behind it.
            DispatchQueue.global(qos: .userInitiated).async { self.settle(url) }
        }
    }

    /// The capture tag and the last of the pixel data can both land a beat after the
    /// directory event, so give every new file a short window to prove itself.
    private func settle(_ url: URL) {
        let deadline = Date().addingTimeInterval(2)
        var previousSize = -1
        while Date() < deadline {
            if isScreenCapture(url) {
                let size = fileSize(url)
                if size > 0, size == previousSize {
                    Log.debug("settled \(url.lastPathComponent) at \(size) bytes")
                    DispatchQueue.main.async { self.onCapture(url) }
                    return
                }
                previousSize = size
            }
            usleep(10_000)
        }
        Log.debug("gave up on \(url.lastPathComponent) (tagged: \(isScreenCapture(url)))")
    }

    private func isScreenCapture(_ url: URL) -> Bool {
        getxattr(url.path, ScreenshotWatcher.captureAttribute, nil, 0, 0, 0) > 0
    }

    private func fileSize(_ url: URL) -> Int {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? Int) ?? -1
    }
}
