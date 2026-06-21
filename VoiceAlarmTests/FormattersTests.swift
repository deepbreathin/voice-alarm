import XCTest
@testable import VoiceAlarm

final class FormattersTests: XCTestCase {
    private let cal = TestSupport.utcCalendar()
    private let locale = Locale(identifier: "en_US")

    func testDurationUnderAnHour() {
        XCTAssertEqual(Formatters.duration(0), "0:00")
        XCTAssertEqual(Formatters.duration(5), "0:05")
        XCTAssertEqual(Formatters.duration(65), "1:05")
        XCTAssertEqual(Formatters.duration(599), "9:59")
    }

    func testDurationOverAnHour() {
        XCTAssertEqual(Formatters.duration(3661), "1:01:01")
    }

    func testDurationNegativeClampsToZero() {
        XCTAssertEqual(Formatters.duration(-10), "0:00")
    }

    func testRecurrenceDescriptionOneOff() {
        var c = cal; c.locale = locale
        let day = TestSupport.date(2026, 6, 24, calendar: cal)
        let desc = Formatters.recurrenceDescription(.oneOff(day: day), locale: locale, calendar: c)
        XCTAssertTrue(desc.hasPrefix("Once on"), desc)
        XCTAssertTrue(desc.contains("24"), desc)
    }

    func testRecurrenceDescriptionPresetSets() {
        XCTAssertEqual(Formatters.recurrenceDescription(.weekly(days: Weekday.everyDay), locale: locale, calendar: cal), "Every day")
        XCTAssertEqual(Formatters.recurrenceDescription(.weekly(days: Weekday.weekdays), locale: locale, calendar: cal), "Weekdays")
        XCTAssertEqual(Formatters.recurrenceDescription(.weekly(days: Weekday.weekend), locale: locale, calendar: cal), "Weekends")
        XCTAssertEqual(Formatters.recurrenceDescription(.weekly(days: []), locale: locale, calendar: cal), "Never")
    }

    func testRecurrenceDescriptionCustomDaysAreMondayFirst() {
        var c = cal; c.locale = locale
        let desc = Formatters.recurrenceDescription(.weekly(days: [.friday, .monday, .wednesday]), locale: locale, calendar: c)
        // Should list Mon before Wed before Fri.
        let monIndex = desc.range(of: c.shortStandaloneWeekdaySymbols[1])
        let friIndex = desc.range(of: c.shortStandaloneWeekdaySymbols[5])
        XCTAssertNotNil(monIndex)
        XCTAssertNotNil(friIndex)
        XCTAssertLessThan(monIndex!.lowerBound, friIndex!.lowerBound)
    }

    func testRecurrenceDescriptionEveryNDays() {
        let day = TestSupport.date(2026, 6, 21, calendar: cal)
        XCTAssertEqual(Formatters.recurrenceDescription(.everyNDays(interval: 3, anchorDay: day), locale: locale, calendar: cal), "Every 3 days")
        XCTAssertEqual(Formatters.recurrenceDescription(.everyNDays(interval: 1, anchorDay: day), locale: locale, calendar: cal), "Every day")
    }

    func testNextFireDescriptionToday() {
        let now = TestSupport.date(2026, 6, 21, 8, 0, calendar: cal)
        let fire = TestSupport.date(2026, 6, 21, 9, 0, calendar: cal)
        let desc = Formatters.nextFireDescription(fire, now: now, locale: locale, calendar: cal)
        XCTAssertTrue(desc.hasPrefix("Today at"), desc)
    }

    func testNextFireDescriptionTomorrow() {
        let now = TestSupport.date(2026, 6, 21, 8, 0, calendar: cal)
        let fire = TestSupport.date(2026, 6, 22, 7, 0, calendar: cal)
        let desc = Formatters.nextFireDescription(fire, now: now, locale: locale, calendar: cal)
        XCTAssertTrue(desc.hasPrefix("Tomorrow at"), desc)
    }

    func testNextFireDescriptionFutureDate() {
        let now = TestSupport.date(2026, 6, 21, 8, 0, calendar: cal)
        let fire = TestSupport.date(2026, 6, 26, 7, 0, calendar: cal)
        let desc = Formatters.nextFireDescription(fire, now: now, locale: locale, calendar: cal)
        XCTAssertFalse(desc.hasPrefix("Today"), desc)
        XCTAssertFalse(desc.hasPrefix("Tomorrow"), desc)
        XCTAssertTrue(desc.contains("at"), desc)
    }
}
