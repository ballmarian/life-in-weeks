import Foundation

/// Splits and rejoins the `---`-delimited YAML block at the top of a week file.
///
/// The format is fixed and small enough to hand-roll rather than take a
/// dependency for (PRD §5.5). The one subtlety worth stating: the closing
/// delimiter is the *first* `---` line after the opening one, and everything
/// past it is body text handed back verbatim — so a `---` inside a code fence
/// further down can never be mistaken for a delimiter.
public enum Frontmatter {
    public struct Parts: Equatable, Sendable {
        /// The YAML between the delimiters, including its trailing newline.
        /// `nil` when the file has no frontmatter block at all — an ordinary
        /// vault note, which per PRD §5.1 simply isn't one of our weeks.
        public var yaml: String?
        public var body: String

        public init(yaml: String?, body: String) {
            self.yaml = yaml
            self.body = body
        }
    }

    private static let openDelimiter = "---"

    public static func split(_ text: String) -> Parts {
        var lines = text.components(separatedBy: "\n")
        guard let first = lines.first, isDelimiter(first, allowEllipsis: false) else {
            return Parts(yaml: nil, body: text)
        }

        // Find the closing delimiter. Without one there is no frontmatter —
        // the leading "---" is just a horizontal rule.
        guard let closingIndex = lines.dropFirst().firstIndex(where: {
            isDelimiter($0, allowEllipsis: true)
        }) else {
            return Parts(yaml: nil, body: text)
        }

        let yamlLines = lines[1 ..< closingIndex]
        let yaml = yamlLines.isEmpty ? "" : yamlLines.joined(separator: "\n") + "\n"

        lines.removeSubrange(0 ... closingIndex)
        return Parts(yaml: yaml, body: lines.joined(separator: "\n"))
    }

    public static func join(_ parts: Parts) -> String {
        guard let yaml = parts.yaml else { return parts.body }
        var block = yaml
        if !block.isEmpty, !block.hasSuffix("\n") { block += "\n" }
        return "\(openDelimiter)\n\(block)\(openDelimiter)\n\(parts.body)"
    }

    /// A delimiter line is exactly `---` (or `...` for the close), ignoring a
    /// trailing carriage return from a CRLF file.
    private static func isDelimiter(_ line: String, allowEllipsis: Bool) -> Bool {
        let trimmed = line.hasSuffix("\r") ? String(line.dropLast()) : line
        return trimmed == openDelimiter || (allowEllipsis && trimmed == "...")
    }
}
