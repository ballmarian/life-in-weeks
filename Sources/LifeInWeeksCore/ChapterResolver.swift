import Foundation

/// Which chapter paints a week, and which one a hover should reveal.
///
/// Both answers come from the same pass (PRD §6.6):
/// - the **earliest** `start` paints the background, so a broad chapter shows
///   through and a nested one doesn't hide it;
/// - the **latest** `start` is what hover surfaces, but only where two or more
///   chapters overlap — that's the thing not already visible.
///
/// With three or more overlapping, hover still surfaces just the newest; there
/// is no stepped reveal in v1.
public struct ChapterResolution: Sendable {
    /// Chapters sorted ascending by `start` — the order the grid and sidebar
    /// both reason about. Ties break on `id` so the result is deterministic.
    public let chapters: [Chapter]

    /// Per week: index into `chapters` of the background-painting chapter.
    private let oldestIndex: [Int32]
    /// Per week: index into `chapters` of the chapter hover reveals.
    private let newestIndex: [Int32]
    /// Per week: how many chapters cover it.
    private let coverCount: [Int32]

    /// Per chapter: the inclusive week-index span it covers, clamped to the grid.
    /// `nil` when the chapter falls entirely outside it.
    public let weekSpans: [ClosedRange<Int>?]

    public init(chapters: [Chapter], timeline: Timeline, openEnd: CalendarDate) {
        let sorted = chapters.sorted {
            ($0.startMonday, $0.id) < ($1.startMonday, $1.id)
        }
        self.chapters = sorted

        let count = timeline.weekCount
        var oldest = [Int32](repeating: -1, count: count)
        var newest = [Int32](repeating: -1, count: count)
        var covers = [Int32](repeating: 0, count: count)
        var spans = [ClosedRange<Int>?](repeating: nil, count: sorted.count)

        for (position, chapter) in sorted.enumerated() {
            let lastMonday = chapter.endMonday ?? openEnd.isoWeekMonday
            guard lastMonday >= chapter.startMonday else { continue }

            // Convert the date range to week indices once, then fill.
            let rawFirst = (chapter.startMonday.serial - timeline.birthWeekMonday.serial) / 7
            let rawLast = (lastMonday.serial - timeline.birthWeekMonday.serial) / 7
            let first = max(0, rawFirst)
            let last = min(timeline.lastWeekIndex, rawLast)
            guard first <= last else { continue }
            spans[position] = first ... last

            for week in first ... last {
                covers[week] += 1
                // Ascending by start: the first writer is the oldest, the last
                // writer is the newest (README §"State Management").
                if oldest[week] < 0 { oldest[week] = Int32(position) }
                newest[week] = Int32(position)
            }
        }

        self.oldestIndex = oldest
        self.newestIndex = newest
        self.coverCount = covers
        self.weekSpans = spans
    }

    public var isEmpty: Bool { chapters.isEmpty }

    public func coveringCount(week: Int) -> Int {
        guard week >= 0, week < coverCount.count else { return 0 }
        return Int(coverCount[week])
    }

    /// Index into `chapters` of the chapter whose colour fills this cell.
    /// The grid asks this per cell, so it's a table lookup rather than a search.
    public func backgroundChapterIndex(week: Int) -> Int? {
        guard week >= 0, week < oldestIndex.count else { return nil }
        let index = oldestIndex[week]
        return index < 0 ? nil : Int(index)
    }

    /// The chapter whose color fills this cell.
    public func backgroundChapter(week: Int) -> Chapter? {
        guard week >= 0, week < oldestIndex.count else { return nil }
        let index = oldestIndex[week]
        return index < 0 ? nil : chapters[Int(index)]
    }

    /// The chapter hover reveals: the newest one where several overlap,
    /// otherwise the sole covering chapter.
    public func hoverChapter(week: Int) -> Chapter? {
        guard week >= 0, week < newestIndex.count else { return nil }
        let index = newestIndex[week]
        return index < 0 ? nil : chapters[Int(index)]
    }

    /// True only when hover has something *hidden* to reveal — with a single
    /// covering chapter there is no extent-highlight (PRD §6.6).
    public func revealsNestedChapter(week: Int) -> Bool {
        coveringCount(week: week) >= 2
    }

    public func span(of chapterID: String) -> ClosedRange<Int>? {
        guard let position = chapters.firstIndex(where: { $0.id == chapterID }) else { return nil }
        return weekSpans[position]
    }

    public func chapter(id: String) -> Chapter? {
        chapters.first { $0.id == id }
    }

    /// Newest first — the sidebar's order (README §3).
    public var newestFirst: [Chapter] { chapters.reversed() }
}
