import Testing
@testable import LifeInWeeksCore

@Suite("Frontmatter and week files")
struct FrontmatterTests {

    // MARK: - PRD §9.1: round-trip a file with tags and emoji

    @Test("tags + emoji round-trip byte-identically")
    func tagsAndEmojiRoundTrip() {
        let source = """
        ---
        tags: [lifeinweeks]
        emoji: "🏔️"
        ---

        Drove up to the cabin with the kids. First time Sam tried fly fishing.

        """
        let parts = Frontmatter.split(source)
        #expect(parts.yaml == "tags: [lifeinweeks]\nemoji: \"🏔️\"\n")
        #expect(parts.body == "\nDrove up to the cabin with the kids. First time Sam tried fly fishing.\n")
        #expect(Frontmatter.join(parts) == source)

        let note = WeekNote.parse(source)
        #expect(note.emoji == "🏔️")
        #expect(note.tags == ["lifeinweeks"])
        #expect(note.serialized() == source)
    }

    // MARK: - PRD §9.1: a `---` inside a code fence is not a delimiter

    @Test("A --- inside a code fence is body text, not a second delimiter")
    func tripleDashInsideACodeFence() {
        let source = """
        ---
        tags: [lifeinweeks]
        ---

        Wrote up the config format:

        ```yaml
        ---
        name: "MBM"
        ---
        ```

        Then went for a walk.

        """
        let parts = Frontmatter.split(source)
        #expect(parts.yaml == "tags: [lifeinweeks]\n")
        #expect(parts.body.contains("```yaml"))
        #expect(parts.body.contains("name: \"MBM\""))
        #expect(Frontmatter.join(parts) == source, "the fenced --- must survive untouched")

        let note = WeekNote.parse(source)
        #expect(note.emoji == nil)
        #expect(note.serialized() == source)
    }

    // MARK: - PRD §9.1: a file with no frontmatter at all

    @Test("A file with no frontmatter is handed back unchanged")
    func noFrontmatterAtAll() {
        let source = "Just an ordinary vault note.\n\nNo YAML anywhere.\n"
        let parts = Frontmatter.split(source)
        #expect(parts.yaml == nil)
        #expect(parts.body == source)
        #expect(Frontmatter.join(parts) == source)

        // Parsed as a week it carries no tags — per PRD §5.1 nothing in the
        // content places a note; only its filename does.
        let note = WeekNote.parse(source)
        #expect(note.tags.isEmpty)
        #expect(note.emoji == nil)
        #expect(note.body == source)
    }

    @Test("A leading --- with no close is a horizontal rule, not frontmatter")
    func unclosedDelimiter() {
        let source = "---\nAn em-rule opening, never closed.\n"
        let parts = Frontmatter.split(source)
        #expect(parts.yaml == nil)
        #expect(parts.body == source)
    }

    @Test("An empty frontmatter block round-trips")
    func emptyFrontmatter() {
        let source = "---\n---\nBody.\n"
        let parts = Frontmatter.split(source)
        #expect(parts.yaml == "")
        #expect(parts.body == "Body.\n")
        #expect(Frontmatter.join(parts) == source)
    }

    @Test("... also closes the block")
    func ellipsisCloses() {
        let parts = Frontmatter.split("---\ntags: [lifeinweeks]\n...\nBody.\n")
        #expect(parts.yaml == "tags: [lifeinweeks]\n")
        #expect(parts.body == "Body.\n")
    }

    // MARK: - Foreign frontmatter keys

    @Test("Frontmatter keys this app doesn't own survive a rewrite")
    func unknownKeysSurvive() {
        let source = """
        ---
        tags: [lifeinweeks, travel]
        aliases:
          - cabin trip
        emoji: "🏔️"
        cssclass: wide
        ---

        Body.

        """
        let note = WeekNote.parse(source)
        #expect(note.tags == ["lifeinweeks", "travel"])
        #expect(note.emoji == "🏔️")
        #expect(note.extraFrontmatterLines == ["aliases:", "  - cabin trip", "cssclass: wide"])

        let rewritten = note.serialized()
        #expect(rewritten.contains("aliases:"))
        #expect(rewritten.contains("  - cabin trip"))
        #expect(rewritten.contains("cssclass: wide"))
        #expect(WeekNote.parse(rewritten) == note, "a second round-trip is stable")
    }

    // MARK: - Emptiness and body helpers

    @Test("Emptiness is what drives file deletion on save")
    func emptinessRules() {
        #expect(WeekNote(emoji: nil, body: "   \n\n").isEmpty)
        #expect(WeekNote(emoji: "", body: "").isEmpty)
        #expect(WeekNote(emoji: "🙂", body: "").isEmpty == false)
        #expect(WeekNote(emoji: nil, body: "something").isEmpty == false)
    }

    @Test("firstLine skips leading blank lines")
    func firstLineSkipsBlanks() {
        #expect(WeekNote(body: "\n\n  Hello there\nmore").firstLine == "Hello there")
        #expect(WeekNote(body: "\n \n").firstLine == nil)
    }

    @Test("Quotes and backslashes in the emoji field are escaped safely")
    func emojiEscaping() {
        let note = WeekNote(emoji: "\"\\", body: "x")
        #expect(note.serialized().contains(#"emoji: "\"\\""#))
        #expect(WeekNote.parse(note.serialized()).emoji == "\"\\")
    }
}
