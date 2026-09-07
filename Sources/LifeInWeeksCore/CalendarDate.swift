import Foundation

/// A proleptic-Gregorian calendar date with no time, no time zone, and no locale.
///
/// The whole app keys off week-Monday dates that appear in filenames and YAML
/// (PRD §5.1), so dates need to mean exactly one thing regardless of where the
/// machine is or what `TimeZone.current` happens to be. `Foundation.Date` is a
/// point in time and drags DST and zone offsets in with it; this is a civil date.
///
/// Arithmetic goes through a day serial number (days since 1970-01-01) using
/// Howard Hinnant's `days_from_civil` / `civil_from_days`, which is exact for
/// every year we care about and needs no `Calendar` lookups.
public struct CalendarDate: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Fails on anything that isn't a real date, so `2011-02-30` never becomes a week.
    public init?(validating year: Int, _ month: Int, _ day: Int) {
        guard month >= 1, month <= 12, day >= 1 else { return nil }
        guard day <= CalendarDate.daysInMonth(year: year, month: month) else { return nil }
        self.init(year: year, month: month, day: day)
    }

    // MARK: - Serial conversion

    /// Days since 1970-01-01. Negative before the epoch.
    public var serial: Int {
        let y = year - (month <= 2 ? 1 : 0)
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = month + (month > 2 ? -3 : 9)
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    public init(serial: Int) {
        let z = serial + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp + (mp < 10 ? 3 : -9)
        self.init(year: y + (m <= 2 ? 1 : 0), month: m, day: d)
    }

    // MARK: - Arithmetic

    public func adding(days: Int) -> CalendarDate {
        CalendarDate(serial: serial + days)
    }

    /// Whole calendar years forward, clamping Feb 29 to Feb 28 in a non-leap
    /// target year (PRD §4.1's leap-day rule).
    public func adding(years: Int) -> CalendarDate {
        let targetYear = year + years
        let clampedDay = min(day, CalendarDate.daysInMonth(year: targetYear, month: month))
        return CalendarDate(year: targetYear, month: month, day: clampedDay)
    }

    /// Whole years elapsed from `self` to `other`, i.e. age on that date.
    public func completedYears(until other: CalendarDate) -> Int {
        var age = other.year - year
        if (other.month, other.day) < (month, day) { age -= 1 }
        return age
    }

    public static func daysBetween(_ a: CalendarDate, _ b: CalendarDate) -> Int {
        b.serial - a.serial
    }

    // MARK: - Weekdays and ISO weeks

    /// ISO weekday: Monday = 1 … Sunday = 7.
    public var isoWeekday: Int {
        // Serial 0 (1970-01-01) was a Thursday, ISO weekday 4.
        (((serial + 3) % 7) + 7) % 7 + 1
    }

    /// The Monday on or before this date — PRD §4.1's `isoWeekMonday`.
    public var isoWeekMonday: CalendarDate {
        adding(days: -(isoWeekday - 1))
    }

    /// ISO 8601 week-numbering year and week, e.g. `2011-W24`.
    ///
    /// Defined by the Thursday of this date's week: the week belongs to whichever
    /// calendar year that Thursday falls in. Note this is deliberately *not* what
    /// Calendar Year row grouping uses (PRD §4.2 groups by the Monday's plain
    /// calendar year); this is display metadata only, for tooltips and the inspector.
    public var isoWeekYearAndWeek: (year: Int, week: Int) {
        let thursday = isoWeekMonday.adding(days: 3)
        let jan1 = CalendarDate(year: thursday.year, month: 1, day: 1)
        let ordinal = thursday.serial - jan1.serial + 1
        return (thursday.year, (ordinal - 1) / 7 + 1)
    }

    // MARK: - Calendar facts

    public static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    public static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        case 2: return isLeapYear(year) ? 29 : 28
        default: return 0
        }
    }

    // MARK: - Comparable

    public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

// MARK: - ISO string form

extension CalendarDate: CustomStringConvertible {
    /// `YYYY-MM-DD` — the form used in filenames and YAML.
    public var iso: String {
        let y = year < 0
            ? "-" + String(format: "%04d", -year)
            : String(format: "%04d", year)
        return "\(y)-\(String(format: "%02d", month))-\(String(format: "%02d", day))"
    }

    public var description: String { iso }

    /// Strict `YYYY-MM-DD`. Rejects anything else, including real-looking dates
    /// that don't exist — this is what decides whether a file in `weeks/` is a
    /// week at all (PRD §5.1).
    public init?(iso: String) {
        let parts = iso.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              parts[0].allSatisfy(\.isNumber),
              parts[1].allSatisfy(\.isNumber),
              parts[2].allSatisfy(\.isNumber)
        else { return nil }
        self.init(validating: y, m, d)
    }
}

// MARK: - Display formatting

extension CalendarDate {
    private static let shortMonths = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ]

    /// `Jun 13, 2011` — the inspector date and sidebar range format.
    public var mediumDisplay: String {
        guard month >= 1, month <= 12 else { return iso }
        return "\(CalendarDate.shortMonths[month - 1]) \(day), \(year)"
    }

    /// `2011-W24`.
    public var isoWeekLabel: String {
        let (y, w) = isoWeekYearAndWeek
        return "\(y)-W\(String(format: "%02d", w))"
    }
}

// MARK: - Bridging to Foundation (for "what is today")

extension CalendarDate {
    /// Today in a given time zone. The only place the app asks the system what
    /// day it is; everything downstream is pure civil arithmetic.
    public static func today(in timeZone: TimeZone = .current, now: Date = Date()) -> CalendarDate {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        return CalendarDate(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
    }
}
