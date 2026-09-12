import Foundation

/// One note that matched a search, as the results list draws it (PRD §6.2).
public struct NoteSearchResult: Equatable, Sendable, Identifiable {
    /// Week index into the timeline — the row's identity and what opening it
    /// selects.
    public let week: Int
    public let emoji: String?
    /// The matching line of the note, elided at either end when it's longer
    /// than a result row can show.
    public let snippet: String
    /// Where the query landed inside `snippet`, as character offsets, so the
    /// row can bold it without searching the text a second time.
    public let matchRange: Range<Int>

    public var id: Int { week }

    public init(week: Int, emoji: String?, snippet: String, matchRange: Range<Int>) {
        self.week = week
        self.emoji = emoji
        self.snippet = snippet
        self.matchRange = matchRange
    }
}

/// Plain substring search across every week's note body.
///
/// Deliberately not an index: at ~4,700 weeks — of which only the written ones
/// hold a file at all (PRD §5.1) — scanning the already-loaded notes costs less
/// than keeping an index honest against edits made outside the app.
public enum NoteSearch {

    /// How much of a long line a result row shows, in characters, before it's
    /// windowed around the match.
    public static let snippetLength = 110

    /// Characters of lead-in kept before the match when a line is windowed.
    private static let leadIn = 28

    /// Matches for `query`, most recent week first. `notes` is indexed by week,
    /// with `nil` for weeks that have no file.
    public static func run(query: String, notes: [WeekNote?]) -> [NoteSearchResult] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }

        var results: [NoteSearchResult] = []
        for week in notes.indices.reversed() {
            guard let note = notes[week],
                  let hit = firstMatch(of: needle, in: note.body) else { continue }
            results.append(NoteSearchResult(week: week, emoji: note.emoji,
                                            snippet: hit.snippet, matchRange: hit.range))
        }
        return results
    }

    /// The first hit in a body, as the line it fell on plus the match's place
    /// in that line. Case- and diacritic-insensitive, so "cafe" finds "Café".
    static func firstMatch(of needle: String, in body: String)
        -> (snippet: String, range: Range<Int>)? {
        guard let found = body.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive])
        else { return nil }

        // The line the match sits on. A match that spans a line break keeps
        // whatever follows it on the same snippet row.
        let lineStart = body[..<found.lowerBound].lastIndex(of: "\n")
            .map { body.index(after: $0) } ?? body.startIndex
        let lineEnd = body[found.upperBound...].firstIndex(of: "\n") ?? body.endIndex

        // Newlines become spaces rather than being collapsed: one character in,
        // one character out, so the match offsets survive the substitution.
        var line = Array(body[lineStart ..< lineEnd].map { $0 == "\n" ? " " : $0 })
        var start = body.distance(from: lineStart, to: found.lowerBound)
        var end = start + body.distance(from: found.lowerBound, to: found.upperBound)

        trimWhitespace(&line, &start, &end)
        return window(line, start, end)
    }

    /// Drops surrounding whitespace from the line, moving the match with it.
    /// The needle is trimmed before searching, so the match itself can never be
    /// inside what this removes.
    private static func trimWhitespace(_ line: inout [Character], _ start: inout Int,
                                       _ end: inout Int) {
        var lead = 0
        while lead < line.count, line[lead].isWhitespace { lead += 1 }
        var tail = line.count
        while tail > lead, line[tail - 1].isWhitespace { tail -= 1 }
        line = Array(line[lead ..< tail])
        start -= lead
        end = min(end - lead, line.count)
    }

    /// A line short enough to show as it is, or a window around the match with
    /// an ellipsis on whichever side was cut.
    private static func window(_ line: [Character], _ start: Int, _ end: Int)
        -> (snippet: String, range: Range<Int>) {
        guard line.count > snippetLength else {
            return (String(line), start ..< end)
        }
        // A match late in a long line pulls the window back so it stays full.
        var from = min(max(0, start - leadIn), max(0, line.count - snippetLength))
        let to = min(line.count, max(from + snippetLength, end))
        from = min(from, start)

        let leadingEllipsis = from > 0
        var snippet = leadingEllipsis ? "…" : ""
        snippet += String(line[from ..< to])
        if to < line.count { snippet += "…" }

        let shift = (leadingEllipsis ? 1 : 0) - from
        let length = snippet.count - (to < line.count ? 1 : 0)
        return (snippet, min(start + shift, length) ..< min(end + shift, length))
    }
}
