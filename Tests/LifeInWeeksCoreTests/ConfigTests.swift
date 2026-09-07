import Testing
@testable import LifeInWeeksCore

@Suite("config.yaml and blocks.yaml")
struct ConfigTests {

    // MARK: - config.yaml, exactly as PRD §5.3 prints it

    @Test("Decodes the PRD's config example")
    func decodesPRDConfig() throws {
        let yaml = """
        name: "MBM"
        birth_date: 1994-01-15
        end_age: 90
        """
        let config = try LifeConfig.parse(yaml: yaml)
        #expect(config.name == "MBM")
        #expect(config.birthDate == CalendarDate(year: 1994, month: 1, day: 15))
        #expect(config.endAge == 90)
    }

    @Test("config.yaml round-trips, dates unquoted")
    func configRoundTrip() throws {
        let config = LifeConfig(name: "MBM", birthDate: CalendarDate(year: 1994, month: 1, day: 15))
        let text = config.serialized()
        #expect(text == "name: \"MBM\"\nbirth_date: 1994-01-15\nend_age: 90\n")
        #expect(try LifeConfig.parse(yaml: text) == config)
    }

    @Test("A quoted birth_date also decodes, and end_age defaults")
    func quotedBirthDate() throws {
        // Unquoted YAML tags this a timestamp, quoted a string; a hand-edited
        // file can contain either.
        let config = try LifeConfig.parse(yaml: "name: X\nbirth_date: \"1994-01-15\"\n")
        #expect(config.birthDate == CalendarDate(year: 1994, month: 1, day: 15))
        #expect(config.endAge == 90)
    }

    @Test("A name containing quotes and backslashes round-trips")
    func awkwardName() throws {
        let config = LifeConfig(name: #"O"Brien \ "the kid""#,
                                birthDate: CalendarDate(year: 1994, month: 1, day: 15))
        #expect(try LifeConfig.parse(yaml: config.serialized()) == config)
    }

    @Test("A malformed birth_date is an error, not a silent default")
    func malformedBirthDate() {
        #expect(throws: (any Error).self) {
            try LifeConfig.parse(yaml: "name: X\nbirth_date: 1994-13-45\n")
        }
    }

    // MARK: - blocks.yaml, exactly as PRD §5.4 prints it

    @Test("Decodes the PRD's blocks example")
    func decodesPRDBlocks() throws {
        let yaml = """
        blocks:
          - id: b1
            start: 2010-01-04
            end: 2014-05-05
            color: "#4A90D9"
            title: "College"
          - id: b2
            start: 2014-06-02
            end: 2016-03-14
            color: "#E8A33D"
            title: "First job at Acme"
        """
        let file = try BlocksFile.parse(yaml: yaml)
        #expect(file.blocks.count == 2)
        #expect(file.blocks[0].id == "b1")
        #expect(file.blocks[0].start == CalendarDate(year: 2010, month: 1, day: 4))
        #expect(file.blocks[0].end == CalendarDate(year: 2014, month: 5, day: 5))
        #expect(file.blocks[0].color == "#4A90D9")
        #expect(file.blocks[0].title == "College")
        #expect(file.blocks[1].title == "First job at Acme")
    }

    @Test("blocks.yaml round-trips; an ongoing chapter omits end")
    func blocksRoundTrip() throws {
        let blocks = [
            Chapter(id: "b1", start: CalendarDate(year: 2010, month: 1, day: 4),
                    end: CalendarDate(year: 2014, month: 5, day: 5),
                    color: "#4A90D9", title: "College"),
            Chapter(id: "b2", start: CalendarDate(year: 2014, month: 6, day: 2),
                    end: nil, color: "#E8A33D", title: "First job at Acme"),
        ]
        let text = BlocksFile(blocks: blocks).serialized()
        #expect(!text.contains("end:\n"))
        #expect(try BlocksFile.parse(yaml: text).blocks == blocks)
    }

    @Test("An empty or missing blocks file is a valid empty archive")
    func emptyBlocks() throws {
        #expect(try BlocksFile.parse(yaml: "").blocks == [])
        #expect(try BlocksFile.parse(yaml: "\n  \n").blocks == [])
        #expect(try BlocksFile.parse(yaml: "blocks: []\n").blocks == [])
        #expect(BlocksFile().serialized() == "blocks: []\n")
    }

    @Test("Chapter ranges display as the sidebar shows them")
    func rangeDisplay() {
        let closed = Chapter(id: "b1", start: CalendarDate(year: 1996, month: 9, day: 2),
                             end: CalendarDate(year: 2000, month: 5, day: 15), color: "#fff", title: "T")
        #expect(closed.rangeDisplay == "Sep 2, 1996 → May 15, 2000")

        let ongoing = Chapter(id: "b2", start: CalendarDate(year: 1996, month: 9, day: 2),
                              end: nil, color: "#fff", title: "T")
        #expect(ongoing.rangeDisplay == "Sep 2, 1996 → now")
    }

    @Test("Hand-edited mid-week chapter dates snap to Mondays")
    func chapterDatesSnap() {
        let chapter = Chapter(id: "b1", start: CalendarDate(year: 2011, month: 6, day: 16),
                              end: CalendarDate(year: 2011, month: 6, day: 19), color: "#fff", title: "T")
        #expect(chapter.startMonday == CalendarDate(year: 2011, month: 6, day: 13))
        #expect(chapter.endMonday == CalendarDate(year: 2011, month: 6, day: 13))
    }

    @Test("Generated chapter IDs avoid collisions")
    func idsAvoidCollisions() {
        var seen: Set<String> = []
        for _ in 0 ..< 200 {
            let id = Chapter.makeID(avoiding: seen)
            #expect(!seen.contains(id))
            seen.insert(id)
        }
    }

    @Test("The palette is ten hues at three depths, no duplicates")
    func paletteShape() {
        #expect(ChapterPalette.rows.count == 3)
        #expect(ChapterPalette.rows.allSatisfy { $0.count == 10 })
        #expect(ChapterPalette.all.count == 30)
        #expect(Set(ChapterPalette.all).count == 30)
        #expect(ChapterPalette.all.contains(ChapterPalette.defaultColor))
    }
}
