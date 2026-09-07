import Foundation
import LifeInWeeksCore

/// Lightweight app preferences, deliberately kept out of `config.yaml` so the
/// archive stays layout-agnostic (PRD §4.2, §5.3).
///
/// The storage-root pointer lives here too: the app has to know which folder to
/// open before it can read anything inside it.
enum Preferences {
    private enum Key {
        static let storageRoot = "storageRootPath"
        static let rowMode = "rowMode"
        static let zoom = "zoom"
    }

    private static var defaults: UserDefaults { .standard }

    static var storageRoot: URL? {
        get {
            guard let path = defaults.string(forKey: Key.storageRoot), !path.isEmpty else { return nil }
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        set { defaults.set(newValue?.path, forKey: Key.storageRoot) }
    }

    static var rowMode: RowMode {
        get { RowMode(rawValue: defaults.string(forKey: Key.rowMode) ?? "") ?? .life }
        set { defaults.set(newValue.rawValue, forKey: Key.rowMode) }
    }

    static var zoom: ZoomLevel {
        get { ZoomLevel(rawValue: defaults.string(forKey: Key.zoom) ?? "") ?? .medium }
        set { defaults.set(newValue.rawValue, forKey: Key.zoom) }
    }

    /// Where the first-run setup screen points by default.
    static var suggestedStorageRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/LifeInWeeks", isDirectory: true)
    }
}
