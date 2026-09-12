import Testing
@testable import LifeInWeeksCore

private let birth = CalendarDate(year: 1994, month: 1, day: 15)
private let timeline = Timeline(birthDate: birth, endAge: 90)
private let openEnd = CalendarDate(year: 2026, month: 9, day: 7)

private func chapter(_ id: String, _ start: String, _ end: String?, _ title: String) -> Chapter {
    Chapter(id: id,
            start: CalendarDate(iso: start)!,
            end: end.flatMap { CalendarDate(iso: $0) },
            color: "#C6E8C6",
            title: title)
}

private func resolve(_ chapters: [Chapter]) -> ChapterResolution {
    ChapterResolution(chapters: chapters, timeline: timeline, openEnd: openEnd)
}

private func week(_ iso: String) -> Int {
    timeline.weekIndex(containing: CalendarDate(iso: iso)!)!
}

@Suite("Chapter overlap resolution")
struct ChapterResolverTests {

    // MARK: - The four-deep overlap cap

    @Test("Covering chapters come back earliest start first — the order a split cell paints")
    func coveringChaptersAreInStartOrder() {
        let outer = chapter("b1", "2012-01-02", "2016-05-30", "College")
        let middle = chapter("b2", "2014-01-06", "2014-12-29", "Study Abroad")
        let inner = chapter("b3", "2014-03-03", "2014-04-28", "Thesis")
        let resolution = resolve([inner, outer, middle])

        #expect(resolution.coveringChapters(week: week("2014-03-10")).map(\.title)
                == ["College", "Study Abroad", "Thesis"])
        #expect(resolution.coveringChapters(week: week("2014-07-07")).map(\.title)
                == ["College", "Study Abroad"])
        #expect(resolution.coveringChapters(week: week("2020-01-06")).isEmpty)
    }

    @Test("Overlap depth counts the deepest week, which is what the cap is applied to")
    func deepestOverlapIsTheDeepestWeek() {
        let stacked = (1 ... 4).map {
            chapter("b\($0)", "201\($0)-01-05", "2016-05-30", "Chapter \($0)")
        }
        #expect(resolve(stacked).deepestOverlap == 4)
        #expect(resolve(stacked).deepestOverlap <= ChapterResolution.maxOverlap)

        let fifth = chapter("b5", "2015-06-01", "2015-08-31", "Summer")
        #expect(resolve(stacked + [fifth]).deepestOverlap == 5)
    }

    @Test("Chapters that never share a week don't stack")
    func disjointChaptersDontStack() {
        let first = chapter("b1", "2012-01-02", "2013-12-30", "School")
        let second = chapter("b2", "2014-01-06", "2015-12-28", "Work")
        #expect(resolve([first, second]).deepestOverlap == 1)
        #expect(resolve([]).deepestOverlap == 0)
    }

    // MARK: - PRD §9.1: earliest start paints, latest start is revealed

    @Test("The earlier-starting chapter paints; the later-starting one is revealed on hover")
    func nestedChapterResolution() {
        // "College" 2012–2016 with "Study Abroad" 2014 nested inside it.
        let college = chapter("b1", "2012-01-02", "2016-05-30", "College")
        let abroad = chapter("b2", "2014-01-06", "2014-06-30", "Study Abroad")
        let resolution = resolve([abroad, college]) // deliberately out of order

        let inside = week("2014-03-03")
        #expect(resolution.coveringCount(week: inside) == 2)
        #expect(resolution.backgroundChapter(week: inside)?.title == "College")
        #expect(resolution.hoverChapter(week: inside)?.title == "Study Abroad")
        #expect(resolution.revealsNestedChapter(week: inside))
    }

    @Test("Hover exposes the nested chapter's full extent, not just the hovered cell")
    func nestedChapterExtent() throws {
        let college = chapter("b1", "2012-01-02", "2016-05-30", "College")
        let abroad = chapter("b2", "2014-01-06", "2014-06-30", "Study Abroad")
        let resolution = resolve([college, abroad])

        let span = try #require(resolution.span(of: "b2"))
        #expect(timeline.monday(of: span.lowerBound) == CalendarDate(year: 2014, month: 1, day: 6))
        #expect(timeline.monday(of: span.upperBound) == CalendarDate(year: 2014, month: 6, day: 30))
        #expect(span.count == 26)
    }

    // MARK: - PRD §9.1: one covering chapter means no extent highlight

    @Test("A single covering chapter shows its title with nothing to reveal")
    func singleChapterHasNoReveal() {
        let resolution = resolve([chapter("b1", "2012-01-02", "2016-05-30", "College")])

        let inside = week("2013-04-08")
        #expect(resolution.coveringCount(week: inside) == 1)
        #expect(resolution.backgroundChapter(week: inside)?.title == "College")
        #expect(resolution.hoverChapter(week: inside)?.title == "College")
        #expect(resolution.revealsNestedChapter(week: inside) == false)
    }

    @Test("A week outside every chapter has none")
    func uncoveredWeek() {
        let resolution = resolve([chapter("b1", "2012-01-02", "2016-05-30", "College")])
        let outside = week("2020-01-06")
        #expect(resolution.coveringCount(week: outside) == 0)
        #expect(resolution.backgroundChapter(week: outside) == nil)
        #expect(resolution.hoverChapter(week: outside) == nil)
    }

    // MARK: - PRD §9.1: three overlapping still surface only the newest

    @Test("Three overlapping chapters surface only the single newest")
    func threeOverlapping() {
        let broad = chapter("b1", "2012-01-02", "2018-12-31", "Twenties")
        let middle = chapter("b2", "2014-01-06", "2016-12-26", "College")
        let narrow = chapter("b3", "2015-01-05", "2015-06-29", "Study Abroad")
        let resolution = resolve([narrow, broad, middle])

        let inside = week("2015-03-02")
        #expect(resolution.coveringCount(week: inside) == 3)
        #expect(resolution.backgroundChapter(week: inside)?.title == "Twenties")
        #expect(resolution.hoverChapter(week: inside)?.title == "Study Abroad",
                "the single newest, not a stepped reveal")
        #expect(resolution.revealsNestedChapter(week: inside))
    }

    // MARK: - Boundaries, ordering, ongoing chapters

    @Test("Both range ends are inclusive")
    func inclusiveRange() {
        let resolution = resolve([chapter("b1", "2012-01-02", "2012-01-16", "Short")])
        #expect(resolution.coveringCount(week: week("2011-12-26")) == 0)
        #expect(resolution.coveringCount(week: week("2012-01-02")) == 1)
        #expect(resolution.coveringCount(week: week("2012-01-16")) == 1)
        #expect(resolution.coveringCount(week: week("2012-01-23")) == 0)
        #expect(resolution.span(of: "b1")?.count == 3)
    }

    @Test("An ongoing chapter stops at the current week, not the end of the grid")
    func ongoingChapterStopsAtNow() throws {
        let resolution = resolve([chapter("b1", "2020-01-06", nil, "Now")])
        #expect(resolution.coveringCount(week: week("2026-09-07")) == 1)
        #expect(resolution.coveringCount(week: week("2026-09-14")) == 0, "no painting into the future")
        let span = try #require(resolution.span(of: "b1"))
        #expect(timeline.monday(of: span.upperBound) == CalendarDate(year: 2026, month: 9, day: 7))
    }

    @Test("Chapters sort ascending by start; the sidebar reads newest first")
    func ordering() {
        let a = chapter("b1", "2016-01-04", "2018-01-01", "Later")
        let b = chapter("b2", "2012-01-02", "2014-01-06", "Earlier")
        let resolution = resolve([a, b])
        #expect(resolution.chapters.map(\.title) == ["Earlier", "Later"])
        #expect(resolution.newestFirst.map(\.title) == ["Later", "Earlier"])
    }

    @Test("Equal start dates resolve the same way whatever the file order")
    func equalStartsAreDeterministic() {
        let a = chapter("b1", "2012-01-02", "2013-01-07", "A")
        let b = chapter("b2", "2012-01-02", "2013-01-07", "B")
        let forward = resolve([a, b])
        let reversed = resolve([b, a])
        let inside = week("2012-06-04")
        #expect(forward.backgroundChapter(week: inside)?.title
                == reversed.backgroundChapter(week: inside)?.title)
        #expect(forward.hoverChapter(week: inside)?.title
                == reversed.hoverChapter(week: inside)?.title)
    }

    @Test("A chapter starting before the grid is clamped, not dropped")
    func clampedToGridStart() throws {
        let resolution = resolve([chapter("b1", "1980-01-07", "1995-01-02", "Before")])
        let span = try #require(resolution.span(of: "b1"))
        #expect(span.lowerBound == 0)
        #expect(resolution.coveringCount(week: 0) == 1)
    }

    @Test("A chapter entirely outside the grid has no span")
    func entirelyOutside() {
        let resolution = resolve([chapter("b1", "1980-01-07", "1985-01-07", "Way before")])
        #expect(resolution.span(of: "b1") == nil)
        #expect(resolution.coveringCount(week: 0) == 0)
    }

    @Test("An inverted range is ignored rather than crashing")
    func invertedRange() {
        let resolution = resolve([chapter("b1", "2016-01-04", "2012-01-02", "Backwards")])
        #expect(resolution.span(of: "b1") == nil)
        #expect(resolution.coveringCount(week: week("2014-01-06")) == 0)
    }
}

@Suite("Chapter lookups the grid uses per cell")
struct ChapterIndexTests {

    @Test("backgroundChapterIndex agrees with backgroundChapter")
    func indexMatchesChapter() {
        let broad = chapter("b1", "2012-01-02", "2018-12-31", "Twenties")
        let narrow = chapter("b2", "2015-01-05", "2015-06-29", "Study Abroad")
        let resolution = resolve([narrow, broad])

        for iso in ["2011-12-26", "2013-01-07", "2015-03-02", "2020-01-06"] {
            let index = week(iso)
            let byIndex = resolution.backgroundChapterIndex(week: index)
                .map { resolution.chapters[$0] }
            #expect(byIndex == resolution.backgroundChapter(week: index), "\(iso)")
        }
    }

    @Test("Out-of-range weeks return nothing rather than trapping")
    func outOfRange() {
        let resolution = resolve([chapter("b1", "2012-01-02", "2018-12-31", "Twenties")])
        #expect(resolution.backgroundChapterIndex(week: -1) == nil)
        #expect(resolution.backgroundChapterIndex(week: 999_999) == nil)
        #expect(resolution.hoverChapter(week: -1) == nil)
        #expect(resolution.coveringCount(week: 999_999) == 0)
    }
}
