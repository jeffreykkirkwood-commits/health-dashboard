import XCTest
@testable import HealthCore
final class HealthCoreTests: XCTestCase {
    var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    let day = Date(timeIntervalSince1970: 1_728_864_000)
    func testOverlapsAreNotDoubleCounted() {
        let a = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(HealthMath.unionSeconds([DateInterval(start: a, duration: 100), DateInterval(start: a.addingTimeInterval(50), duration: 100)]), 150)
    }
    func testMissingAndThresholdBoundaries() {
        XCTAssertNil(HealthMath.sleep(for: day, segments: [], calendar: cal).hours)
        XCTAssertEqual(HealthMath.remFlag(nil, low: 20, high: 25), "No stage data")
        XCTAssertEqual(HealthMath.remFlag(20, low: 20, high: 25), "Within your range")
        XCTAssertEqual(HealthMath.remFlag(25, low: 20, high: 25), "Within your range")
        XCTAssertEqual(HealthMath.remFlag(19, low: 20, high: 25), "Below your range")
        XCTAssertEqual(HealthMath.remFlag(26, low: 20, high: 25), "Above your range")
    }
    func testSourceSelectionAndREM() {
        let start = cal.startOfDay(for: day)
        let segments = [SleepSegment(start: start, end: start.addingTimeInterval(3600), stage: 5, source: "Watch"), SleepSegment(start: start.addingTimeInterval(3600), end: start.addingTimeInterval(4*3600), stage: 3, source: "Watch"), SleepSegment(start: start, end: start.addingTimeInterval(8*3600), stage: 1, source: "Other")]
        let result = HealthMath.sleep(for: day, segments: segments, calendar: cal)
        XCTAssertEqual(result.hours, 4)
        XCTAssertEqual(result.rem, 25)
        XCTAssertEqual(result.source, "Watch")
    }
    func testUnstagedSleepHasUnknownREM() {
        let start = cal.startOfDay(for: day)
        let result = HealthMath.sleep(for: day, segments: [SleepSegment(start: start, end: start.addingTimeInterval(3600), stage: 1, source: "Phone")], calendar: cal)
        XCTAssertEqual(result.hours, 1); XCTAssertNil(result.rem)
    }
    func testNoonBoundaryClipping() {
        let noon = cal.startOfDay(for: day).addingTimeInterval(12*3600)
        let result = HealthMath.sleep(for: day, segments: [SleepSegment(start: noon.addingTimeInterval(-3600), end: noon.addingTimeInterval(3600), stage: 3, source: "Watch")], calendar: cal)
        XCTAssertEqual(result.hours, 1)
    }
    func testDemoIsThirtyDaysWithGaps() {
        let rows = HealthMath.demo(now: day)
        XCTAssertEqual(rows.count, 30)
        XCTAssertEqual(rows.filter { $0.sleepHours == nil }.count, 2)
    }
}
