import XCTest
@testable import VoiceAlarm

final class RecurrenceEngineTests: XCTestCase {

    private let cal = TestSupport.utcCalendar()

    /// 2026-06-21 is a Sunday; used as the reference "now" (08:00 UTC).
    private var now: Date { TestSupport.date(2026, 6, 21, 8, 0, calendar: cal) }

    // MARK: - One-off

    func testOneOffFutureReturnsThatDateTime() {
        let recurrence = Recurrence.oneOff(day: TestSupport.date(2026, 6, 25, calendar: cal))
        let result = recurrence.nextOccurrence(after: now, at: TimeOfDay(hour: 10, minute: 30), calendar: cal)
        assertSameInstant(result, TestSupport.date(2026, 6, 25, 10, 30, calendar: cal))
    }

    func testOneOffInPastReturnsNil() {
        let recurrence = Recurrence.oneOff(day: TestSupport.date(2026, 6, 20, calendar: cal))
        let result = recurrence.nextOccurrence(after: now, at: TimeOfDay(hour: 10, minute: 30), calendar: cal)
        XCTAssertNil(result)
    }

    func testOneOffTodayBeforeNowReturnsNil() {
        let recurrence = Recurrence.oneOff(day: TestSupport.date(2026, 6, 21, calendar: cal))
        let result = recurrence.nextOccurrence(after: now, at: TimeOfDay(hour: 7, minute: 0), calendar: cal)
        XCTAssertNil(result, "07:00 today has already passed relative to 08:00 now")
    }

    func testOneOffTodayAfterNowReturnsToday() {
        let recurrence = Recurrence.oneOff(day: TestSupport.date(2026, 6, 21, calendar: cal))
        let result = recurrence.nextOccurrence(after: now, at: TimeOfDay(hour: 9, minute: 0), calendar: cal)
        assertSameInstant(result, TestSupport.date(2026, 6, 21, 9, 0, calendar: cal))
    }

    // MARK: - Weekly

    func testWeeklyEmptyReturnsNil() {
        let recurrence = Recurrence.weekly(days: [])
        XCTAssertNil(recurrence.nextOccurrence(after: now, at: TimeOfDay(hour: 7, minute: 0), calendar: cal))
    }

    func testWeeklyNextMonday() {
        let recurrence = Recurrence.weekly(days: [.monday])
        let result = recurrence.nextOccurrence(after: now, at: TimeOfDay(hour: 7, minute: 0), calendar: cal)
        // Next Monday after Sunday 06-21 is 06-22.
        assertSameInstant(result, TestSupport.date(2026, 6, 22, 7, 0, calendar: cal))
    }

    func testWeeklyTodaySundayLaterTimeReturnsToday() {
        let recurrence = Recurrence.weekly(days: [.sunday])
        let result = recurrence.nextOccurrence(after: now, at: TimeOfDay(hour: 9, minute: 0), calendar: cal)
        assertSameInstant(result, TestSupport.date(2026, 6, 21, 9, 0, calendar: cal))
    }

    func testWeeklyTodaySundayEarlierTimeReturnsNextWeek() {
        let recurrence = Recurrence.weekly(days: [.sunday])
        let result = recurrence.nextOccurrence(after: now, at: TimeOfDay(hour: 7, minute: 0), calendar: cal)
        assertSameInstant(result, TestSupport.date(2026, 6, 28, 7, 0, calendar: cal))
    }

    func testWeeklyPicksEarliestOfMultipleDays() {
        let recurrence = Recurrence.weekly(days: [.monday, .wednesday, .friday])
        let result = recurrence.nextOccurrence(after: now, at: TimeOfDay(hour: 7, minute: 0), calendar: cal)
        // Earliest after Sunday is Monday 06-22.
        assertSameInstant(result, TestSupport.date(2026, 6, 22, 7, 0, calendar: cal))
    }

    // MARK: - Every N days

    func testEveryNDaysAnchorTodayLaterTimeReturnsToday() {
        let recurrence = Recurrence.everyNDays(interval: 3, anchorDay: TestSupport.date(2026, 6, 21, calendar: cal))
        let result = recurrence.nextOccurrence(after: now, at: TimeOfDay(hour: 9, minute: 0), calendar: cal)
        assertSameInstant(result, TestSupport.date(2026, 6, 21, 9, 0, calendar: cal))
    }

    func testEveryNDaysAnchorTodayEarlierTimeAdvancesOneInterval() {
        let recurrence = Recurrence.everyNDays(interval: 3, anchorDay: TestSupport.date(2026, 6, 21, calendar: cal))
        let result = recurrence.nextOccurrence(after: now, at: TimeOfDay(hour: 6, minute: 0), calendar: cal)
        assertSameInstant(result, TestSupport.date(2026, 6, 24, 6, 0, calendar: cal))
    }

    func testEveryNDaysAnchorInPastJumpsToNextOccurrence() {
        let recurrence = Recurrence.everyNDays(interval: 7, anchorDay: TestSupport.date(2026, 6, 1, calendar: cal))
        let result = recurrence.nextOccurrence(after: now, at: TimeOfDay(hour: 6, minute: 0), calendar: cal)
        // Occurrences: 06-01, 06-08, 06-15, 06-22 → first after 06-21 is 06-22.
        assertSameInstant(result, TestSupport.date(2026, 6, 22, 6, 0, calendar: cal))
    }

    func testEveryNDaysIntervalClampedToAtLeastOne() {
        let recurrence = Recurrence.everyNDays(interval: 0, anchorDay: TestSupport.date(2026, 6, 21, calendar: cal))
        let result = recurrence.nextOccurrence(after: now, at: TimeOfDay(hour: 6, minute: 0), calendar: cal)
        // Treated as every 1 day → tomorrow at 06:00.
        assertSameInstant(result, TestSupport.date(2026, 6, 22, 6, 0, calendar: cal))
    }

    // MARK: - Upcoming occurrences

    func testUpcomingWeeklyMultipleDays() {
        let recurrence = Recurrence.weekly(days: [.monday, .wednesday, .friday])
        let dates = recurrence.upcomingOccurrences(after: now, at: TimeOfDay(hour: 7, minute: 0), calendar: cal, count: 4)
        XCTAssertEqual(dates.count, 4)
        assertSameInstant(dates[0], TestSupport.date(2026, 6, 22, 7, 0, calendar: cal)) // Mon
        assertSameInstant(dates[1], TestSupport.date(2026, 6, 24, 7, 0, calendar: cal)) // Wed
        assertSameInstant(dates[2], TestSupport.date(2026, 6, 26, 7, 0, calendar: cal)) // Fri
        assertSameInstant(dates[3], TestSupport.date(2026, 6, 29, 7, 0, calendar: cal)) // Mon
    }

    func testUpcomingEveryNDays() {
        let recurrence = Recurrence.everyNDays(interval: 3, anchorDay: TestSupport.date(2026, 6, 21, calendar: cal))
        let dates = recurrence.upcomingOccurrences(after: now, at: TimeOfDay(hour: 6, minute: 0), calendar: cal, count: 3)
        XCTAssertEqual(dates.count, 3)
        assertSameInstant(dates[0], TestSupport.date(2026, 6, 24, 6, 0, calendar: cal))
        assertSameInstant(dates[1], TestSupport.date(2026, 6, 27, 6, 0, calendar: cal))
        assertSameInstant(dates[2], TestSupport.date(2026, 6, 30, 6, 0, calendar: cal))
    }

    func testUpcomingOneOffReturnsAtMostOne() {
        let recurrence = Recurrence.oneOff(day: TestSupport.date(2026, 6, 25, calendar: cal))
        let dates = recurrence.upcomingOccurrences(after: now, at: TimeOfDay(hour: 10, minute: 0), calendar: cal, count: 5)
        XCTAssertEqual(dates.count, 1)
    }

    func testUpcomingResultsAreStrictlyIncreasing() {
        let recurrence = Recurrence.weekly(days: Set(Weekday.allCases))
        let dates = recurrence.upcomingOccurrences(after: now, at: TimeOfDay(hour: 7, minute: 0), calendar: cal, count: 10)
        XCTAssertEqual(dates.count, 10)
        for i in 1..<dates.count {
            XCTAssertGreaterThan(dates[i], dates[i - 1])
        }
    }

    // MARK: - DST

    func testEveryNDaysPreservesWallClockAcrossSpringForward() {
        let ny = TestSupport.newYorkCalendar()
        // US DST 2026 begins Sunday 2026-03-08. Anchor the day before.
        let recurrence = Recurrence.everyNDays(interval: 1, anchorDay: TestSupport.date(2026, 3, 7, calendar: ny))
        let reference = TestSupport.date(2026, 3, 8, 12, 0, calendar: ny)
        let result = recurrence.nextOccurrence(after: reference, at: TimeOfDay(hour: 7, minute: 0), calendar: ny)
        XCTAssertNotNil(result)
        // Despite the clocks jumping forward, the alarm should still read 07:00.
        XCTAssertEqual(ny.component(.hour, from: result!), 7)
        XCTAssertEqual(ny.component(.day, from: result!), 9)
    }

    func testWeeklyPreservesWallClockAcrossFallBack() {
        let ny = TestSupport.newYorkCalendar()
        // US DST 2026 ends Sunday 2026-11-01.
        let recurrence = Recurrence.weekly(days: [.sunday])
        let reference = TestSupport.date(2026, 10, 26, 12, 0, calendar: ny) // a Monday before
        let result = recurrence.nextOccurrence(after: reference, at: TimeOfDay(hour: 7, minute: 0), calendar: ny)
        XCTAssertNotNil(result)
        XCTAssertEqual(ny.component(.hour, from: result!), 7)
        XCTAssertEqual(ny.component(.month, from: result!), 11)
        XCTAssertEqual(ny.component(.day, from: result!), 1)
    }
}
