import Foundation
import Testing
import LifeInWeeksCore
@testable import LifeInWeeksApp

@MainActor
@Suite("AppModel today")
struct AppModelTodayTests {

    /// A throwaway archive plus a model reading a clock the test controls.
    private func makeModel(start: CalendarDate) throws -> (AppModel, Clock) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lifeinweeks-\(UUID().uuidString)", isDirectory: true)
        let config = LifeConfig(name: "Test", birthDate: CalendarDate(year: 1994, month: 1, day: 15))
        try Archive(paths: ArchivePaths(root: root)).createIfNeeded(config: config)
        let clock = Clock(now: start)
        return (AppModel(root: root, clock: { clock.now }), clock)
    }

    final class Clock {
        var now: CalendarDate
        init(now: CalendarDate) { self.now = now }
    }

    @Test("a long-running model moves to the next week once the date passes a Monday")
    func advancesAcrossWeeks() throws {
        let (model, clock) = try makeModel(start: CalendarDate(year: 2026, month: 9, day: 28))
        let first = model.currentWeek
        #expect(model.today == CalendarDate(year: 2026, month: 9, day: 28))

        clock.now = CalendarDate(year: 2026, month: 10, day: 5)
        model.refreshToday()

        #expect(model.today == CalendarDate(year: 2026, month: 10, day: 5))
        #expect(model.currentWeek == first + 1)
    }

    @Test("a day inside the same week changes today but not the week")
    func sameWeek() throws {
        let (model, clock) = try makeModel(start: CalendarDate(year: 2026, month: 9, day: 28))
        let first = model.currentWeek

        clock.now = CalendarDate(year: 2026, month: 10, day: 4)
        model.refreshToday()

        #expect(model.today == CalendarDate(year: 2026, month: 10, day: 4))
        #expect(model.currentWeek == first)
    }
}
