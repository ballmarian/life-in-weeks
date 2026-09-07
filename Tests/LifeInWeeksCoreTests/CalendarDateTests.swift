import Testing
@testable import LifeInWeeksCore

@Suite("CalendarDate")
struct CalendarDateTests {

    // MARK: - isoWeekMonday (PRD §9.1, first bullet)

    @Test("A Monday is its own week Monday")
    func isoWeekMondayOnAMonday() {
        let monday = CalendarDate(year: 2011, month: 6, day: 13)
        #expect(monday.isoWeekday == 1)
        #expect(monday.isoWeekMonday == monday)
    }

    @Test("A mid-week date resolves back to its Monday")
    func isoWeekMondayMidWeek() {
        let thursday = CalendarDate(year: 2011, month: 6, day: 16)
        #expect(thursday.isoWeekday == 4)
        #expect(thursday.isoWeekMonday == CalendarDate(year: 2011, month: 6, day: 13))
    }

    @Test("A Sunday belongs to the week that started six days earlier")
    func isoWeekMondayOnSunday() {
        // The off-by-one most likely to break.
        let sunday = CalendarDate(year: 2011, month: 6, day: 19)
        #expect(sunday.isoWeekday == 7)
        #expect(sunday.isoWeekMonday == CalendarDate(year: 2011, month: 6, day: 13))
    }

    @Test("Week Mondays cross month and year boundaries")
    func isoWeekMondayAcrossBoundaries() {
        // 2019-01-01 is a Tuesday; its Monday is in the previous year.
        let newYear = CalendarDate(year: 2019, month: 1, day: 1)
        #expect(newYear.isoWeekMonday == CalendarDate(year: 2018, month: 12, day: 31))
    }

    // MARK: - Serial arithmetic

    @Test("Serial conversion round-trips", arguments: [
        CalendarDate(year: 1900, month: 1, day: 1),
        CalendarDate(year: 1970, month: 1, day: 1),
        CalendarDate(year: 2000, month: 2, day: 29),
        CalendarDate(year: 2084, month: 1, day: 10),
        CalendarDate(year: 2100, month: 3, day: 1),
    ])
    func serialRoundTrip(date: CalendarDate) {
        #expect(CalendarDate(serial: date.serial) == date)
    }

    @Test("The Unix epoch is serial 0 and a Thursday")
    func epochIsAThursday() {
        let epoch = CalendarDate(year: 1970, month: 1, day: 1)
        #expect(epoch.serial == 0)
        #expect(epoch.isoWeekday == 4)
    }

    @Test("Day counts are right across 1900 (not a leap year) and 2000 (leap)")
    func daysAcrossACentury() {
        let a = CalendarDate(year: 1899, month: 12, day: 31)
        let b = CalendarDate(year: 2000, month: 12, day: 31)
        #expect(CalendarDate.daysBetween(a, b) == 36_890)
    }

    // MARK: - Leap-day handling (PRD §9.1, fourth bullet)

    @Test("Feb 29 advanced into a non-leap year clamps to Feb 28")
    func leapDayClampsForward() {
        let leapBirth = CalendarDate(year: 2004, month: 2, day: 29)
        #expect(CalendarDate.isLeapYear(2094) == false)
        #expect(leapBirth.adding(years: 90) == CalendarDate(year: 2094, month: 2, day: 28))
    }

    @Test("Feb 29 advanced into a leap year keeps Feb 29")
    func leapDayKeptWhenTargetIsLeap() {
        let leapBirth = CalendarDate(year: 2000, month: 2, day: 29)
        #expect(CalendarDate.isLeapYear(2080))
        #expect(leapBirth.adding(years: 80) == CalendarDate(year: 2080, month: 2, day: 29))
    }

    // MARK: - Parsing and formatting

    @Test("Strict YYYY-MM-DD parsing accepts only real dates")
    func strictISOParsing() {
        #expect(CalendarDate(iso: "1994-01-10") == CalendarDate(year: 1994, month: 1, day: 10))
        // Real-looking but nonexistent dates are rejected, not clamped.
        #expect(CalendarDate(iso: "2011-02-30") == nil)
        #expect(CalendarDate(iso: "2011-13-01") == nil)
        #expect(CalendarDate(iso: "1994-1-10") == nil)
        #expect(CalendarDate(iso: "19940110") == nil)
        #expect(CalendarDate(iso: "not-a-date") == nil)
        #expect(CalendarDate(iso: "1994-01-10.md") == nil)
    }

    @Test("ISO output pads to four- and two-digit fields")
    func isoStringPadding() {
        #expect(CalendarDate(year: 2011, month: 6, day: 3).iso == "2011-06-03")
    }

    @Test("Display formats match the inspector and tooltip")
    func displayFormats() {
        let date = CalendarDate(year: 2011, month: 6, day: 13)
        #expect(date.mediumDisplay == "Jun 13, 2011")
        #expect(date.isoWeekLabel == "2011-W24")
    }

    @Test("ISO week numbering at year boundaries")
    func isoWeekNumberBoundaries() {
        // Dec 31 2018 falls in ISO week 1 of 2019 — the case PRD §4.2 calls out.
        #expect(CalendarDate(year: 2018, month: 12, day: 31).isoWeekLabel == "2019-W01")
        // 2020 was a 53-week ISO year.
        #expect(CalendarDate(year: 2020, month: 12, day: 28).isoWeekLabel == "2020-W53")
    }

    @Test("Completed years flip on the birthday, not before it")
    func completedYears() {
        let birth = CalendarDate(year: 1994, month: 1, day: 15)
        #expect(birth.completedYears(until: CalendarDate(year: 2011, month: 1, day: 14)) == 16)
        #expect(birth.completedYears(until: CalendarDate(year: 2011, month: 1, day: 15)) == 17)
    }
}
