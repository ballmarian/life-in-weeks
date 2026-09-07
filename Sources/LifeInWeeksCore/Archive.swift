import Foundation

/// Where everything lives under the storage root (PRD §5.3).
///
/// ```
/// LifeInWeeks/
/// ├── config.yaml
/// ├── blocks.yaml
/// └── weeks/
/// ```
///
/// Only `weeks/` is ever scanned or watched — never the rest of a vault.
public struct ArchivePaths: Equatable, Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public static let weeksFolderName = "weeks"

    public var configURL: URL { root.appendingPathComponent("config.yaml") }
    public var blocksURL: URL { root.appendingPathComponent("blocks.yaml") }
    public var weeksURL: URL { root.appendingPathComponent(ArchivePaths.weeksFolderName, isDirectory: true) }

    public func weekURL(monday: CalendarDate) -> URL {
        weeksURL.appendingPathComponent("\(monday.iso).md")
    }

    /// `weeks/2011-06-13.md` — what the inspector footer shows.
    public func relativeWeekPath(monday: CalendarDate) -> String {
        "\(ArchivePaths.weeksFolderName)/\(monday.iso).md"
    }

    /// `~/Vault/LifeInWeeks/weeks` — the status bar's left half.
    public var displayWeeksPath: String {
        let path = weeksURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}

/// Everything read off disk in one pass.
public struct ArchiveSnapshot: Sendable {
    public var config: LifeConfig
    public var chapters: [Chapter]
    /// Keyed by week-Monday. The filename is the sole source of truth for
    /// placement (PRD §5.1) — nothing in the content or the file's timestamps
    /// is consulted.
    public var notes: [CalendarDate: WeekNote]

    public init(config: LifeConfig, chapters: [Chapter], notes: [CalendarDate: WeekNote]) {
        self.config = config
        self.chapters = chapters
        self.notes = notes
    }

    public var noteCount: Int { notes.count }
}

public enum ArchiveError: LocalizedError {
    case missingConfig(URL)
    case unreadableConfig(URL, underlying: Error)
    case unreadableBlocks(URL, underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .missingConfig(let url):
            return "No config.yaml at \(url.path)."
        case .unreadableConfig(let url, let error):
            return "Couldn't read \(url.lastPathComponent): \(error.localizedDescription)"
        case .unreadableBlocks(let url, let error):
            return "Couldn't read \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }
}

/// Plain file reads and writes. No database, no persisted index — at a few
/// thousand small files a directory listing per launch is cheap (PRD §5.3).
public struct Archive {
    public let paths: ArchivePaths
    private let fileManager: FileManager

    public init(paths: ArchivePaths, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    // MARK: - Reading

    public func load() throws -> ArchiveSnapshot {
        ArchiveSnapshot(
            config: try loadConfig(),
            chapters: try loadChapters(),
            notes: loadNotes()
        )
    }

    public func loadConfig() throws -> LifeConfig {
        guard let text = try? String(contentsOf: paths.configURL, encoding: .utf8) else {
            throw ArchiveError.missingConfig(paths.configURL)
        }
        do {
            return try LifeConfig.parse(yaml: text)
        } catch {
            throw ArchiveError.unreadableConfig(paths.configURL, underlying: error)
        }
    }

    public func loadChapters() throws -> [Chapter] {
        guard let text = try? String(contentsOf: paths.blocksURL, encoding: .utf8) else {
            return [] // A missing blocks.yaml just means no chapters yet.
        }
        do {
            return try BlocksFile.parse(yaml: text).blocks
        } catch {
            throw ArchiveError.unreadableBlocks(paths.blocksURL, underlying: error)
        }
    }

    /// Scans `weeks/` only. A file whose name isn't a valid `YYYY-MM-DD.md`
    /// Monday isn't part of the archive — it stays an ordinary note in the
    /// vault, invisible to the grid (PRD §5.1).
    public func loadNotes() -> [CalendarDate: WeekNote] {
        guard let names = try? fileManager.contentsOfDirectory(atPath: paths.weeksURL.path) else {
            return [:]
        }

        var notes: [CalendarDate: WeekNote] = [:]
        notes.reserveCapacity(names.count)
        for name in names {
            guard let monday = Archive.mondayForFilename(name) else { continue }
            guard let text = try? String(
                contentsOf: paths.weeksURL.appendingPathComponent(name), encoding: .utf8
            ) else { continue }
            notes[monday] = WeekNote.parse(text)
        }
        return notes
    }

    public func loadNote(monday: CalendarDate) -> WeekNote? {
        guard let text = try? String(contentsOf: paths.weekURL(monday: monday), encoding: .utf8) else {
            return nil
        }
        return WeekNote.parse(text)
    }

    /// `2011-06-13.md` → that Monday. Rejects a non-Monday date: the filename
    /// convention is week-Mondays, and anything else can't be placed.
    public static func mondayForFilename(_ name: String) -> CalendarDate? {
        guard name.hasSuffix(".md") else { return nil }
        let stem = String(name.dropLast(3))
        guard let date = CalendarDate(iso: stem), date.isoWeekday == 1 else { return nil }
        return date
    }

    // MARK: - Writing

    /// Creates the storage root, `weeks/`, and both config files if absent.
    public func createIfNeeded(config: LifeConfig) throws {
        try fileManager.createDirectory(at: paths.weeksURL, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: paths.configURL.path) {
            try atomicWrite(config.serialized(), to: paths.configURL)
        }
        if !fileManager.fileExists(atPath: paths.blocksURL.path) {
            try atomicWrite(BlocksFile().serialized(), to: paths.blocksURL)
        }
    }

    public func save(config: LifeConfig) throws {
        try atomicWrite(config.serialized(), to: paths.configURL)
    }

    public func save(chapters: [Chapter]) throws {
        try atomicWrite(BlocksFile(blocks: chapters).serialized(), to: paths.blocksURL)
    }

    /// Writes the week's file, or deletes it when the note has no content —
    /// files exist only for weeks that have something in them (PRD §5.1).
    /// Returns the note that is now on disk, `nil` if the file was removed.
    @discardableResult
    public func save(note: WeekNote, monday: CalendarDate) throws -> WeekNote? {
        let url = paths.weekURL(monday: monday)
        if note.isEmpty {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            return nil
        }
        try fileManager.createDirectory(at: paths.weeksURL, withIntermediateDirectories: true)
        try atomicWrite(note.serialized(), to: url)
        return note
    }

    /// Appends a timestamped line to a week's file, creating it if needed —
    /// the menu bar's quick note (PRD §6.4).
    @discardableResult
    public func appendQuickNote(
        _ text: String,
        monday: CalendarDate,
        stamp: String
    ) throws -> WeekNote {
        var note = loadNote(monday: monday) ?? WeekNote(body: "\n")
        if note.tags.isEmpty { note.tags = [WeekNote.tag] }

        var body = note.body
        if !body.isEmpty, !body.hasSuffix("\n") { body += "\n" }
        if !body.hasSuffix("\n\n"), !body.isEmpty { body += "\n" }
        if body.isEmpty { body = "\n" }
        body += "\(stamp) — \(text)\n"
        note.body = body

        try save(note: note, monday: monday)
        return note
    }

    /// Temp file plus rename, so a note can't be truncated by the app dying
    /// mid-write (PRD §6.5). `Data.write(options: .atomic)` is exactly that.
    private func atomicWrite(_ text: String, to url: URL) throws {
        guard let data = text.data(using: .utf8) else { return }
        try data.write(to: url, options: .atomic)
    }
}
