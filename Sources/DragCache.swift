import Foundation

/// Private copies of screenshots for dragging out of the preview.
///
/// A drop hands the receiver a file URL that it reads whenever it likes — often after
/// the drag has ended and the Desktop original is already in the Trash. ~/Desktop is
/// also privacy-protected, so some receivers can't open it at all. A copy in our own
/// Caches folder outlives the original and is readable by anyone.
enum DragCache {
    /// Long enough for any receiver to finish reading; short enough not to pile up.
    private static let maxAge: TimeInterval = 60 * 60

    private static let directory: URL? = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask).first?
        .appendingPathComponent("se.mediaempire.screenshotclipboard/Drag", isDirectory: true)

    /// Copies `url` into the cache under the same name, so the receiver shows the
    /// familiar file name. Returns nil if it couldn't.
    static func stage(_ url: URL) -> URL? {
        guard let directory else { return nil }
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            purge(directory)

            let staged = directory.appendingPathComponent(url.lastPathComponent)
            if fileManager.fileExists(atPath: staged.path) {
                try fileManager.removeItem(at: staged)
            }
            try fileManager.copyItem(at: url, to: staged)
            // A copy keeps the original's dates; age it from now so purge doesn't take it early.
            try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: staged.path)
            Log.debug("staged \(url.lastPathComponent) for dragging")
            return staged
        } catch {
            Log.debug("couldn't stage \(url.lastPathComponent) for dragging: \(error)")
            return nil
        }
    }

    private static func purge(_ directory: URL) {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let cutoff = Date().addingTimeInterval(-maxAge)
        for file in files {
            let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            if let modified, modified < cutoff {
                try? fileManager.removeItem(at: file)
            }
        }
    }
}
