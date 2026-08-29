import AppKit

/// Stands in for the system's floating thumbnail, which had to be switched off to get
/// the file — and therefore the clipboard — written immediately.
///
/// Ignore it and the screenshot stays on the Desktop. Drag it out or press the close
/// button and the Desktop copy goes to the Trash; the clipboard keeps the image either way.
final class ThumbnailPanel: NSPanel {
    private static let visibleDuration: TimeInterval = 5

    private let fileURL: URL
    private var autoDismiss: DispatchWorkItem?

    init(fileURL: URL, image: NSImage) {
        self.fileURL = fileURL
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

        let view = ThumbnailView(fileURL: fileURL, image: image,
                                 frame: NSRect(origin: .zero, size: size))
        view.onDiscard = { [weak self] in self?.discard() }
        view.onDismiss = { [weak self] in self?.dismiss() }
        view.onHoverChanged = { [weak self] hovering in
            hovering ? self?.cancelAutoDismiss() : self?.scheduleAutoDismiss()
        }
        contentView = view
        positionInCorner()
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
        DispatchQueue.main.asyncAfter(deadline: .now() + ThumbnailPanel.visibleDuration, execute: work)
    }

    private func cancelAutoDismiss() {
        autoDismiss?.cancel()
        autoDismiss = nil
    }

    private func positionInCorner() {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(pointer, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let margin: CGFloat = 20
        setFrameOrigin(NSPoint(x: visible.maxX - frame.width - margin,
                               y: visible.minY + margin))
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

    init(fileURL: URL, image: NSImage, frame: NSRect) {
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
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill",
                                    accessibilityDescription: "Discard screenshot")
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

        let item = NSDraggingItem(pasteboardWriter: fileURL as NSURL)
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
        // An empty operation means it went nowhere, so the Desktop copy is all they have.
        if operation.isEmpty {
            onDismiss?()
        } else {
            onDiscard?()
        }
    }
}
