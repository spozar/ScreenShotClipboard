import AppKit

enum Clipboard {
    /// Writes the image in its native flavour plus TIFF, the way a native ⌘⇧⌃4 does,
    /// so both modern and older apps can paste it.
    static func copyImage(at url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: pasteboardType(for: url))
        if let tiff = NSBitmapImageRep(data: data)?.tiffRepresentation {
            pasteboard.setData(tiff, forType: .tiff)
        }
    }

    private static func pasteboardType(for url: URL) -> NSPasteboard.PasteboardType {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg": return NSPasteboard.PasteboardType("public.jpeg")
        case "pdf": return .pdf
        case "tiff": return .tiff
        case "heic": return NSPasteboard.PasteboardType("public.heic")
        default: return .png
        }
    }
}
