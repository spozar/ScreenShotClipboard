import AppKit

enum PreviewCorner: String, CaseIterable {
    case bottomRight, bottomLeft, topRight, topLeft

    var title: String {
        switch self {
        case .bottomRight: return "Bottom Right"
        case .bottomLeft: return "Bottom Left"
        case .topRight: return "Top Right"
        case .topLeft: return "Top Left"
        }
    }
}

/// The app's own settings, edited from the status item menu.
enum Preferences {
    private static let defaults = UserDefaults.standard

    /// The durations offered in the menu, in seconds.
    static let durationChoices: [TimeInterval] = [3, 5, 10, 30]

    /// Whether a preview appears after each screenshot at all.
    static var showPreview: Bool {
        get { defaults.object(forKey: "showPreview") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showPreview") }
    }

    static var previewCorner: PreviewCorner {
        get { PreviewCorner(rawValue: defaults.string(forKey: "previewCorner") ?? "") ?? .bottomRight }
        set { defaults.set(newValue.rawValue, forKey: "previewCorner") }
    }

    /// How long the preview stays up when the pointer isn't over it.
    static var previewDuration: TimeInterval {
        get {
            let value = defaults.double(forKey: "previewDuration")
            return value > 0 ? value : 5
        }
        set { defaults.set(newValue, forKey: "previewDuration") }
    }

    /// Whether dragging the preview out, or closing it with its button, sends the
    /// screenshot file to the Trash. Off keeps every file where macOS saved it.
    static var trashAfterUse: Bool {
        get { defaults.object(forKey: "trashAfterUse") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "trashAfterUse") }
    }
}
