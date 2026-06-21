import XCTest
@testable import VoiceAlarm

final class AlarmTriggerPlannerTests: XCTestCase {

    private let cal = TestSupport.utcCalendar()
    private let planner = AlarmTriggerPlanner(windowSizePerIntervalAlarm: 8)
    private var now: Date { TestSupport.date(2026, 6, 21, 8, 0, calendar: cal) }

    private func makeAlarm(
        recurrence: Recurrence,
        time: TimeOfDay = TimeOfDay(hour: 7, minute: 0),
        enabled: Bool = true,
        hasRecording: Bool = true
    ) -> Alarm {
        Alarm(
            recordingID: hasRecording ? UUID() : nil,
            time: time,
            recurrence: recurrence,
            isEnabled: enabled
        )
    }

    func testDisabledAlarmProducesNoTriggers() {
        let alarm = makeAlarm(recurrence: .weekly(days: [.monday]), enabled: false)
        XCTAssertTrue(planner.triggers(for: alarm, now: now, calendar: cal).isEmpty)
    }

    func testAlarmWithoutRecordingProducesNoTriggers() {
        let alarm = makeAlarm(recurrence: .weekly(days: [.monday]), hasRecording: false)
        XCTAssertTrue(planner.triggers(for: alarm, now: now, calendar: cal).isEmpty)
    }

    func testWeeklyEmptyDaysProducesNoTriggers() {
        let alarm = makeAlarm(recurrence: .weekly(days: []))
        XCTAssertTrue(planner.triggers(for: alarm, now: now, calendar: cal).isEmpty)
    }

    func testOneOffProducesSingleNonRepeatingTriggerWithFullComponents() {
        let alarm = makeAlarm(
            recurrence: .oneOff(day: TestSupport.date(2026, 6, 25, calendar: cal)),
            time: TimeOfDay(hour: 9, minute: 15)
        )
        let triggers = planner.triggers(for: alarm, now: now, calendar: cal)
        XCTAssertEqual(triggers.count, 1)
        let trigger = triggers[0]
        XCTAssertFalse(trigger.repeats)
        XCTAssertEqual(trigger.id, alarm.id.uuidString)
        XCTAssertEqual(trigger.dateComponents.year, 2026)
        XCTAssertEqual(trigger.dateComponents.month, 6)
        XCTAssertEqual(trigger.dateComponents.day, 25)
        XCTAssertEqual(trigger.dateComponents.hour, 9)
        XCTAssertEqual(trigger.dateComponents.minute, 15)
    }

    func testPastOneOffProducesNoTriggers() {
        let alarm = makeAlarm(recurrence: .oneOff(day: TestSupport.date(2026, 6, 1, calendar: cal)))
        XCTAssertTrue(planner.triggers(for: alarm, now: now, calendar: cal).isEmpty)
    }

    func testWeeklyProducesOneRepeatingTriggerPerDay() {
        let alarm = makeAlarm(recurrence: .weekly(days: [.monday, .wednesday, .friday]))
        let triggers = planner.triggers(for: alarm, now: now, calendar: cal)
        XCTAssertEqual(triggers.count, 3)
        XCTAssertTrue(triggers.allSatisfy { $0.repeats })
        let weekdays = Set(triggers.compactMap { $0.dateComponents.weekday })
        XCTAssertEqual(weekdays, [Weekday.monday.rawValue, Weekday.wednesday.rawValue, Weekday.friday.rawValue])
        // Each repeating trigger carries only recurring components, not a date.
        XCTAssertTrue(triggers.allSatisfy { $0.dateComponents.year == nil })
        XCTAssertTrue(triggers.allSatisfy { $0.dateComponents.hour == 7 })
        // Identifiers are unique.
        XCTAssertEqual(Set(triggers.map { $0.id }).count, 3)
    }

    func testEveryNDaysProducesWindowOfNonRepeatingTriggers() {
        let alarm = makeAlarm(recurrence: .everyNDays(interval: 2, anchorDay: TestSupport.date(2026, 6, 21, calendar: cal)))
        let triggers = planner.triggers(for: alarm, now: now, calendar: cal)
        XCTAssertEqual(triggers.count, 8) // windowSizePerIntervalAlarm
        XCTAssertTrue(triggers.allSatisfy { !$0.repeats })
        XCTAssertEqual(Set(triggers.map { $0.id }).count, 8)
        // Sorted ascending by fire date and 2 days apart.
        let fires = triggers.compactMap { $0.fireDate }.sorted()
        for i in 1..<fires.count {
            let days = cal.dateComponents([.day], from: fires[i - 1], to: fires[i]).day
            XCTAssertEqual(days, 2)
        }
    }

    func testBudgetKeepsAllRepeatingAndSoonestNonRepeating() {
        // 3 weekly (repeating) + many one-offs; limit forces trimming.
        var alarms: [Alarm] = [makeAlarm(recurrence: .weekly(days: [.monday, .wednesday, .friday]))]
        for dayOffset in 1...40 {
            let day = cal.date(byAdding: .day, value: dayOffset, to: now)!
            alarms.append(makeAlarm(recurrence: .oneOff(day: day), time: TimeOfDay(hour: 10, minute: 0)))
        }
        let limit = 10
        let triggers = planner.triggers(for: alarms, now: now, calendar: cal, limit: limit)
        XCTAssertEqual(triggers.count, limit)
        let repeating = triggers.filter { $0.repeats }
        XCTAssertEqual(repeating.count, 3, "All weekly repeating triggers retained")
        // The kept one-offs are the soonest ones.
        let keptFires = triggers.filter { !$0.repeats }.compactMap { $0.fireDate }.sorted()
        XCTAssertEqual(keptFires.count, limit - 3)
        let earliestPossible = cal.date(byAdding: .day, value: 1, to: now)!
        assertSameInstant(keptFires.first, TestSupport.date(
            cal.component(.year, from: earliestPossible),
            cal.component(.month, from: earliestPossible),
            cal.component(.day, from: earliestPossible),
            10, 0, calendar: cal
        ))
    }

    func testUnderBudgetReturnsEverything() {
        let alarms = [
            makeAlarm(recurrence: .weekly(days: [.monday])),
            makeAlarm(recurrence: .oneOff(day: TestSupport.date(2026, 6, 25, calendar: cal))),
        ]
        let triggers = planner.triggers(for: alarms, now: now, calendar: cal)
        XCTAssertEqual(triggers.count, 2)
    }
}
