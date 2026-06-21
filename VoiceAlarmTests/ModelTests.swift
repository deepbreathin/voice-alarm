import XCTest
@testable import VoiceAlarm

final class WeekdayTests: XCTestCase {
    func testRawValuesMatchCalendarNumbering() {
        XCTAssertEqual(Weekday.sunday.rawValue, 1)
        XCTAssertEqual(Weekday.saturday.rawValue, 7)
    }

    func testMondayFirstOrder() {
        XCTAssertEqual(Weekday.mondayFirstOrder.first, .monday)
        XCTAssertEqual(Weekday.mondayFirstOrder.last, .sunday)
        XCTAssertEqual(Weekday.mondayFirstOrder.count, 7)
    }

    func testPresetSets() {
        XCTAssertEqual(Weekday.weekdays, [.monday, .tuesday, .wednesday, .thursday, .friday])
        XCTAssertEqual(Weekday.weekend, [.saturday, .sunday])
        XCTAssertEqual(Weekday.everyDay.count, 7)
    }

    func testComparable() {
        XCTAssertTrue(Weekday.monday < Weekday.tuesday)
        XCTAssertEqual([Weekday.friday, .monday, .wednesday].sorted(), [.monday, .wednesday, .friday])
    }

    func testCodableRoundTrip() throws {
        let original: Set<Weekday> = [.monday, .friday]
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Set<Weekday>.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

final class TimeOfDayTests: XCTestCase {
    func testClampsOutOfRangeValues() {
        XCTAssertEqual(TimeOfDay(hour: 30, minute: 99).hour, 23)
        XCTAssertEqual(TimeOfDay(hour: 30, minute: 99).minute, 59)
        XCTAssertEqual(TimeOfDay(hour: -5, minute: -1).hour, 0)
        XCTAssertEqual(TimeOfDay(hour: -5, minute: -1).minute, 0)
    }

    func testMinutesSinceMidnight() {
        XCTAssertEqual(TimeOfDay(hour: 7, minute: 30).minutesSinceMidnight, 450)
    }

    func testComparable() {
        XCTAssertTrue(TimeOfDay(hour: 6, minute: 0) < TimeOfDay(hour: 6, minute: 1))
        XCTAssertTrue(TimeOfDay(hour: 5, minute: 59) < TimeOfDay(hour: 6, minute: 0))
    }

    func testInitFromDate() {
        let cal = TestSupport.utcCalendar()
        let date = TestSupport.date(2026, 6, 21, 14, 45, calendar: cal)
        let tod = TimeOfDay(date: date, calendar: cal)
        XCTAssertEqual(tod.hour, 14)
        XCTAssertEqual(tod.minute, 45)
    }

    func testAppliedToDay() {
        let cal = TestSupport.utcCalendar()
        let day = TestSupport.date(2026, 6, 21, 3, 3, calendar: cal)
        let applied = TimeOfDay(hour: 9, minute: 5).applied(to: day, calendar: cal)
        XCTAssertEqual(cal.component(.hour, from: applied), 9)
        XCTAssertEqual(cal.component(.minute, from: applied), 5)
        XCTAssertEqual(cal.component(.day, from: applied), 21)
    }
}

final class AlarmModelTests: XCTestCase {
    private let cal = TestSupport.utcCalendar()
    private var now: Date { TestSupport.date(2026, 6, 21, 8, 0, calendar: cal) }

    func testSchedulableRequiresEnabledAndRecording() {
        let base = Alarm(recordingID: UUID(), time: TimeOfDay(hour: 7, minute: 0), recurrence: .weekly(days: [.monday]))
        XCTAssertTrue(base.isSchedulable)

        var disabled = base; disabled.isEnabled = false
        XCTAssertFalse(disabled.isSchedulable)

        var noRecording = base; noRecording.recordingID = nil
        XCTAssertFalse(noRecording.isSchedulable)
    }

    func testWeeklyEmptyNotSchedulable() {
        let alarm = Alarm(recordingID: UUID(), time: TimeOfDay(hour: 7, minute: 0), recurrence: .weekly(days: []))
        XCTAssertFalse(alarm.isSchedulable)
    }

    func testNextFireDateNilWhenDisabled() {
        var alarm = Alarm(recordingID: UUID(), time: TimeOfDay(hour: 7, minute: 0), recurrence: .weekly(days: [.monday]))
        alarm.isEnabled = false
        XCTAssertNil(alarm.nextFireDate(after: now, calendar: cal))
    }

    func testNextFireDateComputed() {
        let alarm = Alarm(recordingID: UUID(), time: TimeOfDay(hour: 7, minute: 0), recurrence: .weekly(days: [.monday]))
        assertSameInstant(alarm.nextFireDate(after: now, calendar: cal), TestSupport.date(2026, 6, 22, 7, 0, calendar: cal))
    }

    func testCodableRoundTripAllRecurrenceKinds() throws {
        let alarms = [
            Alarm(label: "A", recordingID: UUID(), time: TimeOfDay(hour: 6, minute: 0), recurrence: .oneOff(day: now)),
            Alarm(label: "B", recordingID: UUID(), time: TimeOfDay(hour: 7, minute: 0), recurrence: .weekly(days: [.monday, .friday])),
            Alarm(label: "C", recordingID: nil, time: TimeOfDay(hour: 8, minute: 0), recurrence: .everyNDays(interval: 3, anchorDay: now)),
        ]
        let data = try JSONEncoder().encode(alarms)
        let decoded = try JSONDecoder().decode([Alarm].self, from: data)
        XCTAssertEqual(decoded, alarms)
    }
}

final class RecurrenceModelTests: XCTestCase {
    func testIsRepeating() {
        XCTAssertFalse(Recurrence.oneOff(day: Date()).isRepeating)
        XCTAssertFalse(Recurrence.weekly(days: []).isRepeating)
        XCTAssertTrue(Recurrence.weekly(days: [.monday]).isRepeating)
        XCTAssertTrue(Recurrence.everyNDays(interval: 2, anchorDay: Date()).isRepeating)
    }
}
