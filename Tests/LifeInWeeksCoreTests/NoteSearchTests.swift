import Testing
@testable import LifeInWeeksCore

private func note(_ body: String, emoji: String? = nil) -> WeekNote {
    WeekNote(emoji: emoji, body: body)
}

/// `notes[week]`, the shape the app hands the search: one slot per week, most
/// of them empty.
private func notes(_ pairs: [Int: String], count: Int = 12) -> [WeekNote?] {
    var indexed = [WeekNote?](repeating: nil, count: count)
    for (week, body) in pairs { indexed[week] = note(body) }
    return indexed
}

private func matched(_ result: NoteSearchResult) -> String {
    let characters = Array(result.snippet)
    return String(characters[result.matchRange])
}

@Suite("Note search")
struct NoteSearchTests {

    // MARK: - What matches

    @Test("Matches are case- and diacritic-insensitive")
    func matchingIgnoresCaseAndAccents() {
        let indexed = notes([2: "Coffee at the Café", 5: "CABIN weekend", 8: "nothing here"])
        #expect(NoteSearch.run(query: "cafe", notes: indexed).map(\.week) == [2])
        #expect(NoteSearch.run(query: "cabin", notes: indexed).map(\.week) == [5])
        #expect(NoteSearch.run(query: "CoFfEe", notes: indexed).map(\.week) == [2])
    }

    @Test("Results run newest week first, one row per note")
    func resultsAreNewestFirst() {
        let indexed = notes([1: "hike", 4: "a hike and a swim", 9: "hiked all day"])
        #expect(NoteSearch.run(query: "hike", notes: indexed).map(\.week) == [9, 4, 1])
    }

    @Test("An empty or whitespace-only query matches nothing")
    func emptyQueryMatchesNothing() {
        let indexed = notes([3: "something"])
        #expect(NoteSearch.run(query: "", notes: indexed).isEmpty)
        #expect(NoteSearch.run(query: "   \n", notes: indexed).isEmpty)
    }

    @Test("The query is trimmed before it's matched")
    func queryIsTrimmed() {
        #expect(NoteSearch.run(query: "  cabin ", notes: notes([3: "the cabin"])).map(\.week) == [3])
    }

    @Test("The emoji rides along for the result row")
    func resultCarriesEmoji() {
        var indexed = [WeekNote?](repeating: nil, count: 4)
        indexed[1] = note("Drove up to the cabin", emoji: "🏔️")
        #expect(NoteSearch.run(query: "cabin", notes: indexed).first?.emoji == "🏔️")
    }

    // MARK: - The snippet

    @Test("The snippet is the matching line, not the whole note")
    func snippetIsTheMatchingLine() {
        let body = "\nFirst line about nothing.\nDrove up to the cabin.\nThen home.\n"
        let result = NoteSearch.run(query: "cabin", notes: [note(body)])[0]
        #expect(result.snippet == "Drove up to the cabin.")
        #expect(matched(result) == "cabin")
    }

    @Test("Leading whitespace is trimmed with the match moving to match")
    func indentedLineTrimsWithoutLosingTheMatch() {
        let result = NoteSearch.run(query: "cabin", notes: [note("\n  - up to the cabin  \n")])[0]
        #expect(result.snippet == "- up to the cabin")
        #expect(matched(result) == "cabin")
    }

    @Test("A long line is windowed around the match, elided on the cut sides")
    func longLineIsWindowed() {
        let filler = String(repeating: "word ", count: 60)
        let result = NoteSearch.run(query: "cabin", notes: [note(filler + "cabin " + filler)])[0]
        #expect(result.snippet.count <= NoteSearch.snippetLength + 2)
        #expect(result.snippet.hasPrefix("…"))
        #expect(result.snippet.hasSuffix("…"))
        #expect(matched(result) == "cabin")
    }

    @Test("A match at the end of a long line still fills the window")
    func matchAtTheEndKeepsAFullWindow() {
        let filler = String(repeating: "word ", count: 60)
        let result = NoteSearch.run(query: "cabin", notes: [note(filler + "cabin")])[0]
        #expect(result.snippet.hasPrefix("…"))
        #expect(!result.snippet.hasSuffix("…"))
        #expect(matched(result) == "cabin")
    }

    @Test("A match in the opening of a long line keeps its lead-in unelided")
    func matchAtTheStartHasNoLeadingEllipsis() {
        let filler = String(repeating: "word ", count: 60)
        let result = NoteSearch.run(query: "cabin", notes: [note("cabin " + filler)])[0]
        #expect(!result.snippet.hasPrefix("…"))
        #expect(result.snippet.hasSuffix("…"))
        #expect(result.matchRange == 0 ..< 5)
    }

    @Test("A match longer than the window is never cut mid-highlight")
    func matchRangeStaysInsideTheSnippet() {
        let needle = String(repeating: "long ", count: 40)
        let result = NoteSearch.run(query: needle, notes: [note("before " + needle + "after")])[0]
        #expect(result.matchRange.upperBound <= result.snippet.count)
        #expect(result.matchRange.lowerBound < result.matchRange.upperBound)
    }
}
