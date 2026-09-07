import Foundation

/// How weeks are chunked into visual rows. Display-only — it never changes which
/// file a week lives in (PRD §4.2).
public enum RowMode: String, Codable, Sendable, CaseIterable {
    /// Uniform rows of exactly 52 weeks. Drifts from the real birthday by ~1.25
    /// days a year; that is accepted, not a bug (PRD §4.2).
    case life
    /// Rows follow the Gregorian calendar year of each week's *Monday* — not the
    /// ISO week-year, which would push a Dec 30/31 week into the next row.
    case calendar
}

/// One visual row of the grid.
public struct GridRow: Equatable, Sendable {
    /// 0-based row position.
    public let index: Int
    /// Week index of the row's first cell.
    public let firstWeek: Int
    /// Number of cells. 52 everywhere in `.life` except the last row; 52 or 53
    /// in `.calendar`, with partial first and last rows.
    public let count: Int
    /// Calendar year of the row's first week's Monday — the left half of the
    /// `1996 · 18` row label.
    public let calendarYear: Int
    /// Life-year index — the right half of the label.
    public let age: Int

    public var weekRange: Range<Int> { firstWeek ..< (firstWeek + count) }
    public var lastWeek: Int { firstWeek + count - 1 }

    /// `1996 · 18`
    public var label: String { "\(calendarYear) · \(age)" }

    /// Decade rows are drawn heavier (README §4).
    public var isDecade: Bool {
        age % 10 == 0 || calendarYear % 10 == 0
    }
}

/// The grouping of every week into rows, plus the reverse map needed for
/// hit-testing and highlight geometry.
public struct RowLayout: Sendable {
    public let mode: RowMode
    public let rows: [GridRow]
    /// `positions[weekIndex] == (row, column)`.
    public let positions: [(row: Int, column: Int)]
    /// Widest row, in cells — drives canvas width.
    public let widestRow: Int

    public func position(of week: Int) -> (row: Int, column: Int)? {
        guard week >= 0, week < positions.count else { return nil }
        return positions[week]
    }
}

/// Every week from the birth week to the week of the `end_age` birthday,
/// per PRD §4.1's normative algorithm.
public struct Timeline: Sendable {
    public let birthDate: CalendarDate
    public let endAge: Int

    /// `week[0]` — the ISO Monday on or before `birthDate`. May precede the
    /// birth by up to six days; PRD §4.1 accepts this to keep one week rule.
    public let birthWeekMonday: CalendarDate
    /// `week[N]` — the Monday of the ISO week containing the `end_age` birthday.
    public let endWeekMonday: CalendarDate
    /// `N` in the PRD's terms: the last week's index.
    public let lastWeekIndex: Int

    public init(birthDate: CalendarDate, endAge: Int) {
        self.birthDate = birthDate
        self.endAge = max(0, endAge)
        let start = birthDate.isoWeekMonday
        let end = birthDate.adding(years: self.endAge).isoWeekMonday
        self.birthWeekMonday = start
        self.endWeekMonday = end
        self.lastWeekIndex = max(0, (end.serial - start.serial) / 7)
    }

    public init(config: LifeConfig) {
        self.init(birthDate: config.birthDate, endAge: config.endAge)
    }

    /// `N + 1` — 4697 for the PRD's worked example.
    public var weekCount: Int { lastWeekIndex + 1 }

    /// The Monday of week `index`. Defined outside the grid too, so callers can
    /// ask about a week beyond age 90 without a crash.
    public func monday(of index: Int) -> CalendarDate {
        birthWeekMonday.adding(days: 7 * index)
    }

    /// The Sunday that closes week `index`.
    public func sunday(of index: Int) -> CalendarDate {
        monday(of: index).adding(days: 6)
    }

    /// Week index containing `date`, or `nil` if it falls outside the grid.
    public func weekIndex(containing date: CalendarDate) -> Int? {
        let i = rawWeekIndex(containing: date)
        return (i >= 0 && i <= lastWeekIndex) ? i : nil
    }

    /// Same, but clamped into range — used for "which week is today" when the
    /// user is younger than the birth week or older than `end_age`.
    public func clampedWeekIndex(containing date: CalendarDate) -> Int {
        min(max(rawWeekIndex(containing: date), 0), lastWeekIndex)
    }

    private func rawWeekIndex(containing date: CalendarDate) -> Int {
        (date.isoWeekMonday.serial - birthWeekMonday.serial) / 7
    }

    /// Completed years of life at the start of week `index`, floored at 0 —
    /// week 0 can begin before the birth date (PRD §4.1).
    public func age(atWeek index: Int) -> Int {
        max(0, birthDate.completedYears(until: monday(of: index)))
    }

    // MARK: - Row grouping

    public func layout(mode: RowMode) -> RowLayout {
        switch mode {
        case .life: return lifeYearLayout()
        case .calendar: return calendarYearLayout()
        }
    }

    /// Fixed 52-cell rows. Row 1 is full, unlike Calendar Year; only the last
    /// row is short (PRD §9.1).
    private func lifeYearLayout() -> RowLayout {
        var rows: [GridRow] = []
        var positions = [(row: Int, column: Int)](repeating: (0, 0), count: weekCount)

        var week = 0
        var rowIndex = 0
        while week < weekCount {
            let count = min(52, weekCount - week)
            for column in 0 ..< count {
                positions[week + column] = (rowIndex, column)
            }
            rows.append(GridRow(
                index: rowIndex,
                firstWeek: week,
                count: count,
                calendarYear: monday(of: week).year,
                age: rowIndex
            ))
            week += count
            rowIndex += 1
        }
        return RowLayout(mode: .life, rows: rows, positions: positions,
                         widestRow: rows.map(\.count).max() ?? 0)
    }

    /// Rows follow the Monday's plain calendar year. Deliberately not the ISO
    /// week-year: the week containing Dec 31 2018 is ISO 2019-W01, but belongs
    /// in the 2018 row of a view whose whole point is "what happened in 2018"
    /// (PRD §4.2).
    private func calendarYearLayout() -> RowLayout {
        var rows: [GridRow] = []
        var positions = [(row: Int, column: Int)](repeating: (0, 0), count: weekCount)

        var week = 0
        var rowIndex = 0
        while week < weekCount {
            let year = monday(of: week).year
            var count = 0
            while week + count <= lastWeekIndex, monday(of: week + count).year == year {
                positions[week + count] = (rowIndex, count)
                count += 1
            }
            rows.append(GridRow(
                index: rowIndex,
                firstWeek: week,
                count: count,
                calendarYear: year,
                age: age(atWeek: week)
            ))
            week += count
            rowIndex += 1
        }
        return RowLayout(mode: .calendar, rows: rows, positions: positions,
                         widestRow: rows.map(\.count).max() ?? 0)
    }
}
