import Foundation
import Yams

/// One week's file: `weeks/1994-01-10.md` (PRD §5.1, §5.2).
///
/// ```markdown
/// ---
/// tags: [lifeinweeks]
/// emoji: "🏔️"
/// ---
///
/// Drove up to the cabin with the kids.
/// ```
public struct WeekNote: Equatable, Sendable {
    public var emoji: String?
    public var tags: [String]
    public var body: String

    /// Frontmatter keys this app doesn't own, kept verbatim so editing a note
    /// here doesn't strip whatever Obsidian or the user added to it.
    ///
    /// Line-based rather than a full YAML round-trip: enough for the realistic
    /// case (`aliases:`, `cssclass:`, a nested list), and it can't reorder or
    /// reformat anything it doesn't understand.
    public var extraFrontmatterLines: [String]

    public static let tag = "lifeinweeks"

    public init(
        emoji: String? = nil,
        tags: [String] = [WeekNote.tag],
        body: String = "",
        extraFrontmatterLines: [String] = []
    ) {
        self.emoji = emoji
        self.tags = tags
        self.body = body
        self.extraFrontmatterLines = extraFrontmatterLines
    }

    /// True when the week has nothing worth a file. Saving in this state deletes
    /// the file instead of writing an empty one (README §Interactions, PRD §5.1).
    public var isEmpty: Bool {
        body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (emoji?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            && extraFrontmatterLines.isEmpty
    }

    /// First non-empty line of the body — the tooltip's summary line (README §6).
    public var firstLine: String? {
        body.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
    }

    // MARK: - Parsing

    public static func parse(_ text: String) -> WeekNote {
        let parts = Frontmatter.split(text)
        guard let yaml = parts.yaml else {
            return WeekNote(emoji: nil, tags: [], body: parts.body, extraFrontmatterLines: [])
        }

        var emoji: String?
        var tags: [String] = []
        if let mapping = try? Yams.load(yaml: yaml) as? [String: Any] {
            if let raw = mapping["emoji"] as? String, !raw.isEmpty { emoji = raw }
            if let list = mapping["tags"] as? [Any] {
                tags = list.compactMap { $0 as? String }
            } else if let single = mapping["tags"] as? String {
                tags = [single]
            }
        }

        return WeekNote(
            emoji: emoji,
            tags: tags,
            body: parts.body,
            extraFrontmatterLines: unknownLines(in: yaml)
        )
    }

    /// Top-level frontmatter lines whose key is neither `tags` nor `emoji`,
    /// together with any indented continuation lines under them.
    private static func unknownLines(in yaml: String) -> [String] {
        var kept: [String] = []
        var keepingBlock = false
        for line in yaml.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if keepingBlock { kept.append(line) }
                continue
            }
            let isContinuation = line.first == " " || line.first == "\t" || line.hasPrefix("-")
            if isContinuation {
                if keepingBlock { kept.append(line) }
                continue
            }
            let key = String(line.prefix(while: { $0 != ":" })).trimmingCharacters(in: .whitespaces)
            keepingBlock = (key != "tags" && key != "emoji")
            if keepingBlock { kept.append(line) }
        }
        // Don't carry trailing blank lines into the rewritten block.
        while let last = kept.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            kept.removeLast()
        }
        return kept
    }

    // MARK: - Serializing

    public func serialized() -> String {
        var yaml = ""
        let effectiveTags = tags.isEmpty ? [WeekNote.tag] : tags
        yaml += "tags: [\(effectiveTags.joined(separator: ", "))]\n"
        if let emoji, !emoji.isEmpty {
            yaml += "emoji: \(YAMLEmit.quoted(emoji))\n"
        }
        for line in extraFrontmatterLines {
            yaml += line + "\n"
        }
        return Frontmatter.join(Frontmatter.Parts(yaml: yaml, body: body))
    }

    /// A fresh file for a week with content: frontmatter, a blank line, the note.
    public static func newNote(body: String, emoji: String?) -> WeekNote {
        let normalized = body.hasPrefix("\n") ? body : "\n" + body
        return WeekNote(emoji: emoji, tags: [WeekNote.tag], body: normalized)
    }
}
