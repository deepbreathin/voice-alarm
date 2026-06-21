import Foundation
import XCTest
@testable import VoiceAlarm

/// Shared helpers for deterministic date math in tests.
enum TestSupport {

    /// A fixed UTC Gregorian calendar so weekday/date arithmetic is independent
    /// of the machine running the tests.
    static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    /// A calendar in a DST-observing zone for transition tests.
    static func newYorkCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    static func date(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int = 0, _ minute: Int = 0,
        calendar: Calendar
    ) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        guard let result = calendar.date(from: comps) else {
            fatalError("Invalid date components \(year)-\(month)-\(day) \(hour):\(minute)")
        }
        return result
    }

    /// Creates a unique temporary directory for file-based tests.
    static func makeTempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceAlarmTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

extension XCTestCase {
    /// Asserts two dates are equal to the second.
    func assertSameInstant(
        _ lhs: Date?, _ rhs: Date?,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        guard let lhs, let rhs else {
            XCTFail("Expected both dates non-nil, got \(String(describing: lhs)) and \(String(describing: rhs))",
                    file: file, line: line)
            return
        }
        XCTAssertEqual(lhs.timeIntervalSince1970, rhs.timeIntervalSince1970, accuracy: 0.5,
                       file: file, line: line)
    }
}
