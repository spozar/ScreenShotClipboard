import AppKit

/// Stands in for the system's floating thumbnail, which had to be switched off to get
/// the file — and therefore the clipboard — written immediately.
///
/// Ignore it and the screenshot stays on the Desktop. Drag it out and the receiver gets a
/// copy staged in our Caches folder (see DragCache), as a file and as image data. With
/// "trash after use" on, a drop or the close button then sends the Desktop original to the
/// Trash; with it off, nothing is trashed and the close button just closes. The clipboard
/// keeps the image either way. Corner and duration are read from Preferences at creation.
final class ThumbnailPanel: NSPanel {
    private let fileURL: URL
    private let visibleDuration = Preferences.previewDuration
    private var autoDismiss: DispatchWorkItem?

    init(fileURL: URL, image: NSImage) {
        self.fileURL = fileURL
        let trashAfterUse = Preferences.trashAfterUse
        let size = ThumbnailPanel.fittedSize(for: image)
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovable = false
        hidesOnDeactivate = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let view = ThumbnailView(fileURL: fileURL, image: image, trashAfterUse: trashAfterUse,
                                 frame: NSRect(origin: .zero, size: size))
        view.onDiscard = { [weak self] in
            trashAfterUse ? self?.discard() : self?.dismiss()
        }
        view.onDismiss = { [weak self] in self?.dismiss() }
        view.onHoverChanged = { [weak self] hovering in
            hovering ? self?.cancelAutoDismiss() : self?.scheduleAutoDismiss()
        }
        contentView = view
        positionInCorner(Preferences.previewCorner)
    }

    override var canBecomeKey: Bool { false }

    func present() {
        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            animator().alphaValue = 1
        }
        scheduleAutoDismiss()
    }

    /// Leaves the screenshot where it is.
    func dismiss() {
        cancelAutoDismiss()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
        })
    }

    /// The Trash rather than an unlink: a mis-click stays recoverable.
    private func discard() {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            NSWorkspace.shared.recycle([fileURL], completionHandler: nil)
        }
        dismiss()
    }

    private func scheduleAutoDismiss() {
        cancelAutoDismiss()
        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        autoDismiss = work
        DispatchQueue.main.asyncAfter(deadline: .now() + visibleDuration, execute: work)
    }

    private func cancelAutoDismiss() {
        autoDismiss?.cancel()
        autoDismiss = nil
    }

    private func positionInCorner(_ corner: PreviewCorner) {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(pointer, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let margin: CGFloat = 20
        let left = visible.minX + margin
        let right = visible.maxX - frame.width - margin
        let bottom = visible.minY + margin
        let top = visible.maxY - frame.height - margin
        switch corner {
        case .bottomRight: setFrameOrigin(NSPoint(x: right, y: bottom))
        case .bottomLeft: setFrameOrigin(NSPoint(x: left, y: bottom))
        case .topRight: setFrameOrigin(NSPoint(x: right, y: top))
        case .topLeft: setFrameOrigin(NSPoint(x: left, y: top))
        }
    }

    private static func fittedSize(for image: NSImage) -> NSSize {
        let bounds = NSSize(width: 260, height: 180)
        let size = image.size
        guard size.width > 0, size.height > 0 else { return bounds }
        let scale = min(bounds.width / size.width, bounds.height / size.height, 1)
        // Extreme aspect ratios still need to stay big enough to grab.
        return NSSize(width: max(90, size.width * scale),
                      height: max(64, size.height * scale))
    }
}

private final class ThumbnailView: NSView {
    var onDiscard: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onHoverChanged: ((Bool) -> Void)?

    private let fileURL: URL
    private let image: NSImage
    private let closeButton = NSButton()
    private var dragOrigin: NSPoint?
    private var isDragging = false
    /// Staged on the first drag, then reused: one copy per screenshot is enough.
    private var dragURL: URL?

    init(fileURL: URL, image: NSImage, trashAfterUse: Bool, frame: NSRect) {
        self.fileURL = fileURL
        self.image = image
        super.init(frame: frame)

        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor

        let imageView = NSImageView(frame: bounds.insetBy(dx: 5, dy: 5))
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width, .height]
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 6
        imageView.layer?.masksToBounds = true
        // The image must not swallow the clicks and drags aimed at this view.
        imageView.isEditable = false
        addSubview(imageView)

        closeButton.frame = NSRect(x: 4, y: bounds.height - 22, width: 18, height: 18)
        closeButton.autoresizingMask = [.minYMargin]
        let closeLabel = trashAfterUse ? "Move screenshot to Trash" : "Close preview"
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill",
                                    accessibilityDescription: closeLabel)
        closeButton.toolTip = closeLabel
        closeButton.isBordered = false
        closeButton.bezelStyle = .inline
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.target = self
        closeButton.action = #selector(discard)
        closeButton.alphaValue = 0
        addSubview(closeButton)

        addTrackingArea(NSTrackingArea(rect: .zero,
                                       options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self))
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    @objc private func discard() { onDiscard?() }

    override func mouseEntered(with event: NSEvent) {
        closeButton.animator().alphaValue = 1
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        closeButton.animator().alphaValue = 0
        onHoverChanged?(false)
    }

    override func mouseDown(with event: NSEvent) {
        dragOrigin = event.locationInWindow
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let origin = dragOrigin, !isDragging else { return }
        let travelled = hypot(event.locationInWindow.x - origin.x,
                              event.locationInWindow.y - origin.y)
        guard travelled > 4 else { return }
        isDragging = true

        if dragURL == nil {
            dragURL = DragCache.stage(fileURL) ?? fileURL
        }

        // A file for apps that take attachments, image data for those that only take
        // pictures. Both up front: a receiver may ask after this preview is long gone.
        let source = dragURL ?? fileURL
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(source.absoluteString, forType: .fileURL)
        if let data = ThumbnailView.pngData(of: source, image: image) {
            pasteboardItem.setData(data, forType: .png)
        }

        let item = NSDraggingItem(pasteboardWriter: pasteboardItem)
        item.setDraggingFrame(bounds, contents: image)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        defer { dragOrigin = nil }
        guard !isDragging else { return }
        // A plain click opens the file that is still sitting on the Desktop, so it stays.
        NSWorkspace.shared.open(fileURL)
        onDismiss?()
    }
}

extension ThumbnailView: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        [.copy, .move]
    }

    func draggingSession(_ session: NSDraggingSession,
                         endedAt point: NSPoint,
                         operation: NSDragOperation) {
        isDragging = false
        dragOrigin = nil
        // Dropping it somewhere is "doing something with it": don't leave a copy behind.
        // That's safe now the receiver reads the staged copy, not the Desktop file.
        // An empty operation means it went nowhere, so the Desktop copy is all they have.
        if operation.isEmpty {
            onDismiss?()
        } else {
            onDiscard?()
        }
    }
}

extension ThumbnailView {
    /// The file's own bytes when it already is a PNG — no re-encode, no quality change.
    static func pngData(of url: URL, image: NSImage) -> Data? {
        if url.pathExtension.lowercased() == "png", let data = try? Data(contentsOf: url) {
            return data
        }
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
