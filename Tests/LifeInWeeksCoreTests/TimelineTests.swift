import Testing
@testable import LifeInWeeksCore

/// The worked example from PRD §4.1, used verbatim as a fixture.
private let workedBirth = CalendarDate(year: 1994, month: 1, day: 15)
private let worked = Timeline(birthDate: workedBirth, endAge: 90)

@Suite("Timeline")
struct TimelineTests {

    // MARK: - The worked example (PRD §9.1, bullets 2 and 3)

    @Test("week[0] and week[1] match the PRD's worked values exactly")
    func birthWeekAndSecondWeek() {
        #expect(worked.birthWeekMonday == CalendarDate(year: 1994, month: 1, day: 10))
        #expect(worked.monday(of: 0) == CalendarDate(year: 1994, month: 1, day: 10))
        #expect(worked.monday(of: 1) == CalendarDate(year: 1994, month: 1, day: 17))
    }

    @Test("Week 1 starts five days before the birth, as PRD §4.1 accepts")
    func weekOneStartsBeforeBirth() {
        #expect(worked.birthWeekMonday < workedBirth)
        #expect(CalendarDate.daysBetween(worked.birthWeekMonday, workedBirth) == 5)
    }

    @Test("end_week_monday is 2084-01-10 and N is 4696")
    func endWeekAndN() {
        #expect(workedBirth.adding(years: 90) == CalendarDate(year: 2084, month: 1, day: 15))
        #expect(worked.endWeekMonday == CalendarDate(year: 2084, month: 1, day: 10))
        #expect(worked.lastWeekIndex == 4696)
        #expect(worked.weekCount == 4697)
    }

    @Test("Every week in the sequence is a Monday")
    func everyWeekIsAMonday() {
        for index in stride(from: 0, through: worked.lastWeekIndex, by: 37) {
            #expect(worked.monday(of: index).isoWeekday == 1)
        }
        #expect(worked.monday(of: worked.lastWeekIndex) == worked.endWeekMonday)
    }

    @Test("A Feb 29 birth produces a valid timeline")
    func leapDayBirthTimeline() {
        let timeline = Timeline(birthDate: CalendarDate(year: 2004, month: 2, day: 29), endAge: 90)
        #expect(timeline.birthWeekMonday == CalendarDate(year: 2004, month: 2, day: 23))
        // The 90th "birthday" clamps to Feb 28 2094, a Sunday → Monday 2094-02-22.
        #expect(timeline.endWeekMonday == CalendarDate(year: 2094, month: 2, day: 22))
        #expect(timeline.weekCount > 4600)
    }

    // MARK: - Week lookup

    @Test("Dates map to the week containing them")
    func weekIndexLookup() {
        #expect(worked.weekIndex(containing: CalendarDate(year: 1994, month: 1, day: 15)) == 0)
        #expect(worked.weekIndex(containing: CalendarDate(year: 1994, month: 1, day: 16)) == 0)
        #expect(worked.weekIndex(containing: CalendarDate(year: 1994, month: 1, day: 17)) == 1)
        #expect(worked.weekIndex(containing: CalendarDate(year: 1993, month: 12, day: 1)) == nil)
        #expect(worked.weekIndex(containing: CalendarDate(year: 2085, month: 1, day: 1)) == nil)
    }

    @Test("Clamped lookup never leaves the grid")
    func clampedWeekIndex() {
        #expect(worked.clampedWeekIndex(containing: CalendarDate(year: 1900, month: 1, day: 1)) == 0)
        #expect(worked.clampedWeekIndex(containing: CalendarDate(year: 2200, month: 1, day: 1))
                == worked.lastWeekIndex)
    }

    // MARK: - Life Year rows (PRD §9.1, bullet 5)

    @Test("Life Year rows are exactly 52 cells except the last, which is 17")
    func lifeYearRowWidths() {
        let layout = worked.layout(mode: .life)
        #expect(layout.rows.count == 91)
        #expect(layout.rows[0].count == 52, "row 1 is full, unlike Calendar Year")
        for row in layout.rows.dropLast() {
            #expect(row.count == 52, "row \(row.index + 1)")
        }
        #expect(layout.rows.last?.count == 17)
        #expect(layout.rows.map(\.count).reduce(0, +) == 4697)
        #expect(layout.widestRow == 52)
    }

    @Test("Life Year rows cover every week exactly once, in order")
    func lifeYearRowsAreContiguous() {
        let layout = worked.layout(mode: .life)
        var expected = 0
        for row in layout.rows {
            #expect(row.firstWeek == expected)
            expected += row.count
        }
        #expect(expected == 4697)
    }

    @Test("Life Year labels pair the row's calendar year with its life-year index")
    func lifeYearLabels() {
        let layout = worked.layout(mode: .life)
        #expect(layout.rows[0].age == 0)
        #expect(layout.rows[0].calendarYear == 1994)
        #expect(layout.rows[18].age == 18)
        #expect(layout.rows[0].label == "1994 · 0")
        #expect(layout.rows[10].isDecade)
    }

    @Test("Life Year positions agree with the rows")
    func lifeYearPositions() {
        let layout = worked.layout(mode: .life)
        #expect(layout.position(of: 0).map { [$0.row, $0.column] } == [0, 0])
        #expect(layout.position(of: 51).map { [$0.row, $0.column] } == [0, 51])
        #expect(layout.position(of: 52).map { [$0.row, $0.column] } == [1, 0])
        #expect(layout.position(of: 4696).map { [$0.row, $0.column] } == [90, 16])
        #expect(layout.position(of: 4697) == nil)
    }

    // MARK: - Calendar Year rows (PRD §9.1, bullets 6 and 7)

    @Test("Calendar Year first and last rows are partial")
    func calendarYearPartialEnds() {
        let layout = worked.layout(mode: .calendar)

        let first = layout.rows[0]
        #expect(first.calendarYear == 1994)
        #expect(worked.monday(of: first.firstWeek) == worked.birthWeekMonday)
        #expect(first.count < 52, "birth-year row starts at the birth week, not Jan 1")
        #expect(worked.monday(of: first.lastWeek).year == 1994)

        let last = layout.rows[layout.rows.count - 1]
        #expect(last.calendarYear == 2084)
        #expect(worked.monday(of: last.lastWeek) == worked.endWeekMonday)
        #expect(last.count < 52, "final row ends at the 90th-birthday week, not Dec 31")
    }

    @Test("Calendar Year middle rows are 52 or 53 cells")
    func calendarYearMiddleRows() {
        let layout = worked.layout(mode: .calendar)
        let middle = layout.rows.dropFirst().dropLast()
        #expect(!middle.isEmpty)
        for row in middle {
            #expect(row.count == 52 || row.count == 53, "\(row.calendarYear) had \(row.count)")
        }
        #expect(middle.contains { $0.count == 53 }, "53-week years should occur")
        #expect(layout.widestRow == 53)
    }

    @Test("A Dec 31 Monday groups by its plain calendar year, not its ISO week-year")
    func calendarYearIgnoresISOWeekYear() throws {
        // The specific bug PRD §4.2 rejects: 2018-12-31 is a Monday whose ISO
        // week-year is 2019. It must land in the 2018 row.
        let boundaryMonday = CalendarDate(year: 2018, month: 12, day: 31)
        #expect(boundaryMonday.isoWeekday == 1)
        #expect(boundaryMonday.isoWeekLabel == "2019-W01")

        let layout = worked.layout(mode: .calendar)
        let week = try #require(worked.weekIndex(containing: boundaryMonday))
        let position = try #require(layout.position(of: week))
        #expect(layout.rows[position.row].calendarYear == 2018)

        // And the following Monday opens the 2019 row.
        let nextRow = layout.rows[position.row + 1]
        #expect(nextRow.calendarYear == 2019)
        #expect(worked.monday(of: nextRow.firstWeek) == CalendarDate(year: 2019, month: 1, day: 7))
    }

    @Test("Calendar Year rows are contiguous, one per year, covering every week")
    func calendarYearRowsAreContiguous() {
        let layout = worked.layout(mode: .calendar)
        var expected = 0
        for (offset, row) in layout.rows.enumerated() {
            #expect(row.firstWeek == expected)
            if offset > 0 {
                #expect(row.calendarYear == layout.rows[offset - 1].calendarYear + 1)
            }
            expected += row.count
        }
        #expect(expected == 4697)
        #expect(layout.rows.count == 91)
    }

    @Test("Both modes render the same week sequence, only regrouped")
    func modesShareTheSameWeeks() {
        let life = worked.layout(mode: .life)
        let calendar = worked.layout(mode: .calendar)
        #expect(life.positions.count == calendar.positions.count)
        #expect(life.rows.map(\.count).reduce(0, +) == calendar.rows.map(\.count).reduce(0, +))
    }
}
