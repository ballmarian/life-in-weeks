import Foundation
import Yams

/// One entry in `blocks.yaml`: a date range painted as a background band
/// behind the grid (PRD §5.4).
///
/// Chapters live in config, never in `weeks/` — the vault-note logic never
/// sees them.
public struct Chapter: Codable, Equatable, Identifiable, Sendable {
    /// Short stable identifier, so edits and deletes don't depend on the title
    /// (which changes) or grid position (which moves with the row mode).
    public var id: String
    public var start: CalendarDate
    /// `nil` means ongoing — rendered "→ now" and painted through the current
    /// week rather than off into the unlived future.
    public var end: CalendarDate?
    public var color: String
    public var title: String

    public static let untitled = "Untitled chapter"

    public init(id: String, start: CalendarDate, end: CalendarDate?, color: String, title: String) {
        self.id = id
        self.start = start
        self.end = end
        self.color = color
        self.title = title
    }

    /// `start`/`end` are Mondays by convention; snap anything else so a
    /// hand-edited `blocks.yaml` still lines up with cell boundaries.
    public var startMonday: CalendarDate { start.isoWeekMonday }
    public var endMonday: CalendarDate? { end?.isoWeekMonday }

    /// Inclusive of both ends. `openEnd` supplies the effective last Monday for
    /// an ongoing chapter.
    public func covers(monday: CalendarDate, openEnd: CalendarDate) -> Bool {
        let last = endMonday ?? openEnd
        return monday >= startMonday && monday <= last
    }

    /// `Sep 2, 1996 → May 15, 2000`, or `→ now` when ongoing (README §3).
    public var rangeDisplay: String {
        "\(startMonday.mediumDisplay) → \(endMonday?.mediumDisplay ?? "now")"
    }

    // MARK: - ID generation

    private static let idAlphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")

    /// A short id that doesn't collide with anything already in the file.
    public static func makeID(avoiding existing: Set<String>) -> String {
        for _ in 0 ..< 1000 {
            let suffix = String((0 ..< 6).map { _ in idAlphabet.randomElement() ?? "x" })
            let candidate = "b\(suffix)"
            if !existing.contains(candidate) { return candidate }
        }
        return "b\(UUID().uuidString.prefix(8).lowercased())"
    }
}

/// The whole `blocks.yaml` document.
public struct BlocksFile: Codable, Equatable, Sendable {
    public var blocks: [Chapter]

    public init(blocks: [Chapter] = []) {
        self.blocks = blocks
    }

    public static func parse(yaml: String) throws -> BlocksFile {
        let trimmed = yaml.trimmingCharacters(in: .whitespacesAndNewlines)
        // An empty or brand-new file is a valid empty archive, not an error.
        if trimmed.isEmpty { return BlocksFile() }
        return try YAMLDecoder().decode(BlocksFile.self, from: yaml)
    }

    public func serialized() -> String {
        guard !blocks.isEmpty else { return "blocks: []\n" }
        var out = "blocks:\n"
        for block in blocks {
            out += "  - id: \(block.id)\n"
            out += "    start: \(block.start.iso)\n"
            if let end = block.end {
                out += "    end: \(end.iso)\n"
            }
            out += "    color: \(YAMLEmit.quoted(block.color))\n"
            out += "    title: \(YAMLEmit.quoted(block.title))\n"
        }
        return out
    }
}
