import Foundation

/// Opt-in tracing for when a screenshot doesn't reach the clipboard. Launch the
/// executable straight from Terminal with SSC_DEBUG=1 and watch
/// ~/Library/Logs/ScreenShotClipboard.log:
///
///   SSC_DEBUG=1 ScreenShotClipboard.app/Contents/MacOS/ScreenShotClipboard
///
/// It writes to a file rather than stderr so the trace survives any launch method.
enum Log {
    private static let enabled = ProcessInfo.processInfo.environment["SSC_DEBUG"] == "1"
    private static let queue = DispatchQueue(label: "se.mediaempire.screenshotclipboard.log")
    private static let fileURL = FileManager.default
        .urls(for: .libraryDirectory, in: .userDomainMask).first?
        .appendingPathComponent("Logs/ScreenShotClipboard.log")

    private static let timestamps: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    static func debug(_ message: @autoclosure () -> String) {
        guard enabled, let fileURL else { return }
        let line = "[" + timestamps.string(from: Date()) + "] " + message() + "\n"
        queue.async {
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: fileURL)
            }
        }
    }
}
