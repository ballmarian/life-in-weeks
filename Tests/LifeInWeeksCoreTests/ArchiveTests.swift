import Foundation
import Testing
@testable import LifeInWeeksCore

/// Each test gets its own throwaway storage root.
private func withArchive(_ body: (Archive) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("LifeInWeeksTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(Archive(paths: ArchivePaths(root: root)))
}

private let seedConfig = LifeConfig(name: "MBM", birthDate: CalendarDate(year: 1994, month: 1, day: 15))

private func withSeededArchive(_ body: (Archive) throws -> Void) throws {
    try withArchive { archive in
        try archive.createIfNeeded(config: seedConfig)
        try body(archive)
    }
}

@Suite("Archive")
struct ArchiveTests {

    // MARK: - The filename is the sole source of truth (PRD §5.1)

    @Test("Only Monday-named markdown files are weeks")
    func filenameRules() {
        #expect(Archive.mondayForFilename("1994-01-10.md") == CalendarDate(year: 1994, month: 1, day: 10))
        #expect(Archive.mondayForFilename("1994-01-15.md") == nil, "a Saturday is not a week Monday")
        #expect(Archive.mondayForFilename("1994-01-10.txt") == nil)
        #expect(Archive.mondayForFilename("Meeting notes.md") == nil)
        #expect(Archive.mondayForFilename("2011-02-30.md") == nil)
        #expect(Archive.mondayForFilename(".md") == nil)
    }

    @Test("Scanning weeks/ ignores files the app doesn't own")
    func scanIgnoresForeignFiles() throws {
        try withSeededArchive { archive in
            let weeks = archive.paths.weeksURL
            try "---\ntags: [lifeinweeks]\n---\n\nReal.\n"
                .write(to: weeks.appendingPathComponent("2011-06-13.md"), atomically: true, encoding: .utf8)
            try "An ordinary note.\n"
                .write(to: weeks.appendingPathComponent("Shopping list.md"), atomically: true, encoding: .utf8)
            try "Not a Monday.\n"
                .write(to: weeks.appendingPathComponent("2011-06-16.md"), atomically: true, encoding: .utf8)

            let notes = archive.loadNotes()
            #expect(notes.count == 1)
            #expect(notes[CalendarDate(year: 2011, month: 6, day: 13)]?.firstLine == "Real.")
        }
    }

    // MARK: - Layout and round-trips on disk

    @Test("createIfNeeded writes config.yaml, blocks.yaml and weeks/")
    func createsLayout() throws {
        try withSeededArchive { archive in
            let fm = FileManager.default
            #expect(fm.fileExists(atPath: archive.paths.configURL.path))
            #expect(fm.fileExists(atPath: archive.paths.blocksURL.path))
            var isDirectory: ObjCBool = false
            #expect(fm.fileExists(atPath: archive.paths.weeksURL.path, isDirectory: &isDirectory))
            #expect(isDirectory.boolValue)
            let config = try archive.loadConfig()
            #expect(config == seedConfig)
            let chapters = try archive.loadChapters()
            #expect(chapters.isEmpty)
        }
    }

    @Test("createIfNeeded never clobbers an existing config")
    func doesNotClobber() throws {
        try withSeededArchive { archive in
            try archive.createIfNeeded(config: LifeConfig(
                name: "Someone else", birthDate: CalendarDate(year: 1980, month: 1, day: 1)))
            let reloaded = try archive.loadConfig()
            #expect(reloaded.name == "MBM")
        }
    }

    @Test("A note written and read back is byte-for-byte what the format specifies")
    func noteRoundTrip() throws {
        try withSeededArchive { archive in
            let monday = CalendarDate(year: 2011, month: 6, day: 13)
            let note = WeekNote.newNote(body: "Fly fishing with Sam.\n", emoji: "🏔️")
            try archive.save(note: note, monday: monday)

            let onDisk = try String(contentsOf: archive.paths.weekURL(monday: monday), encoding: .utf8)
            #expect(onDisk == "---\ntags: [lifeinweeks]\nemoji: \"🏔️\"\n---\n\nFly fishing with Sam.\n")
            #expect(archive.loadNote(monday: monday) == note)
        }
    }

    @Test("Saving an empty note deletes the file (PRD §5.1: no empty week files)")
    func emptySaveDeletes() throws {
        try withSeededArchive { archive in
            let monday = CalendarDate(year: 2011, month: 6, day: 13)
            let url = archive.paths.weekURL(monday: monday)
            try archive.save(note: WeekNote.newNote(body: "Something", emoji: nil), monday: monday)
            #expect(FileManager.default.fileExists(atPath: url.path))

            let result = try archive.save(note: WeekNote(emoji: "", body: "  \n"), monday: monday)
            #expect(result == nil)
            #expect(FileManager.default.fileExists(atPath: url.path) == false)
            #expect(archive.loadNote(monday: monday) == nil)
        }
    }

    @Test("Clearing a week that has no file is not an error")
    func deletingAbsentFile() throws {
        try withSeededArchive { archive in
            try archive.save(note: WeekNote(body: ""), monday: CalendarDate(year: 2011, month: 6, day: 13))
        }
    }

    @Test("Chapters round-trip through blocks.yaml on disk")
    func chaptersRoundTrip() throws {
        try withSeededArchive { archive in
            let chapters = [Chapter(id: "b1", start: CalendarDate(year: 2010, month: 1, day: 4),
                                    end: CalendarDate(year: 2014, month: 5, day: 5),
                                    color: "#4A90D9", title: "College")]
            try archive.save(chapters: chapters)
            let reloaded = try archive.loadChapters()
            #expect(reloaded == chapters)
        }
    }

    // MARK: - Quick note (PRD §6.4)

    @Test("Quick note creates the week's file when it doesn't exist")
    func quickNoteCreates() throws {
        try withSeededArchive { archive in
            let monday = CalendarDate(year: 2011, month: 6, day: 13)
            let note = try archive.appendQuickNote("Started the garden", monday: monday, stamp: "Thu 09:14")
            #expect(note.body.contains("Thu 09:14 — Started the garden"))
            #expect(note.tags == ["lifeinweeks"])
            #expect(archive.loadNote(monday: monday)?.body == note.body)
        }
    }

    @Test("Quick note appends below existing content and leaves the emoji alone")
    func quickNoteAppends() throws {
        try withSeededArchive { archive in
            let monday = CalendarDate(year: 2011, month: 6, day: 13)
            try archive.save(note: WeekNote.newNote(body: "First thought.\n", emoji: "🙂"), monday: monday)
            let note = try archive.appendQuickNote("Second thought.", monday: monday, stamp: "Fri 18:02")

            #expect(note.emoji == "🙂")
            let body = note.body
            let first = try #require(body.range(of: "First thought."))
            let second = try #require(body.range(of: "Second thought."))
            #expect(first.lowerBound < second.lowerBound)
        }
    }

    // MARK: - Errors

    @Test("A missing config.yaml is a clear, typed error")
    func missingConfig() throws {
        try withArchive { archive in
            do {
                _ = try archive.loadConfig()
                Issue.record("expected .missingConfig")
            } catch ArchiveError.missingConfig {
                // expected
            }
        }
    }

    @Test("A missing weeks/ folder scans to nothing rather than throwing")
    func missingWeeksFolder() throws {
        try withArchive { archive in
            #expect(archive.loadNotes().isEmpty)
        }
    }

    @Test("A malformed blocks.yaml surfaces as an error, not silently empty")
    func malformedBlocks() throws {
        try withSeededArchive { archive in
            try "blocks:\n  - id: b1\n    start: nope\n"
                .write(to: archive.paths.blocksURL, atomically: true, encoding: .utf8)
            do {
                _ = try archive.loadChapters()
                Issue.record("expected .unreadableBlocks")
            } catch ArchiveError.unreadableBlocks {
                // expected
            }
        }
    }

    @Test("Paths render the way the inspector and status bar show them")
    func pathDisplay() throws {
        try withArchive { archive in
            #expect(archive.paths.relativeWeekPath(monday: CalendarDate(year: 2011, month: 6, day: 13))
                    == "weeks/2011-06-13.md")
            #expect(archive.paths.displayWeeksPath.hasSuffix("/weeks"))
        }
    }
}
