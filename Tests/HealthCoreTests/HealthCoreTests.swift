// PURPOSE: Check sleep calculations with invented timestamps. These tests do not request HealthKit permission or read a person's data.
// READING GUIDE: Follow the numbered FEATURE sections below; see docs/START-HERE.md for the whole app.

import XCTest
@testable import HealthCore
final class HealthCoreTests: XCTestCase {
    // FEATURE 01 — Keep test dates independent of the Mac's timezone
    // Use a fixed UTC calendar/date so the same intervals give the same expected
    // answer on different developers' computers.
    var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    let day = Date(timeIntervalSince1970: 1_728_864_000)
    // FEATURE 02 — Overlapping samples must not inflate sleep
    // Two 100-second records overlap by 50 seconds. Expect 150, not 200; failure
    // would mean the dashboard double-counts overlapping coverage.
    func testOverlapsAreNotDoubleCounted() {
        let a = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(HealthMath.unionSeconds([DateInterval(start: a, duration: 100), DateInterval(start: a.addingTimeInterval(50), duration: 100)]), 150)
    }
    // FEATURE 03 — Missing data and exact target bounds must stay honest
    // No segments must mean unknown sleep. No staging must say so. A value exactly
    // at either range endpoint belongs within it; nearby outside values do not.
    func testMissingAndThresholdBoundaries() {
        XCTAssertNil(HealthMath.sleep(for: day, segments: [], calendar: cal).hours)
        XCTAssertEqual(HealthMath.remFlag(nil, low: 20, high: 25), "No stage data")
        XCTAssertEqual(HealthMath.remFlag(20, low: 20, high: 25), "Within your range")
        XCTAssertEqual(HealthMath.remFlag(25, low: 20, high: 25), "Within your range")
        XCTAssertEqual(HealthMath.remFlag(19, low: 20, high: 25), "Below your range")
        XCTAssertEqual(HealthMath.remFlag(26, low: 20, high: 25), "Above your range")
    }
    // FEATURE 04 — Prefer a staged source without adding a second device
    // The invented Watch has four staged hours, including one REM hour; another
    // source has eight unstaged hours. Expect four hours and 25% REM from Watch,
    // protecting against combining sources or losing the stage-based preference.
    func testSourceSelectionAndREM() {
        let start = cal.startOfDay(for: day)
        let segments = [SleepSegment(start: start, end: start.addingTimeInterval(3600), stage: 5, source: "Watch"), SleepSegment(start: start.addingTimeInterval(3600), end: start.addingTimeInterval(4*3600), stage: 3, source: "Watch"), SleepSegment(start: start, end: start.addingTimeInterval(8*3600), stage: 1, source: "Other")]
        let result = HealthMath.sleep(for: day, segments: segments, calendar: cal)
        XCTAssertEqual(result.hours, 4)
        XCTAssertEqual(result.rem, 25)
        XCTAssertEqual(result.source, "Watch")
    }
    // FEATURE 05 — Unstaged sleep must not imply zero REM
    // One hour of unstaged sleep is known duration with unknown REM. Failure
    // would turn missing stage information into a misleading measurement.
    func testUnstagedSleepHasUnknownREM() {
        let start = cal.startOfDay(for: day)
        let result = HealthMath.sleep(for: day, segments: [SleepSegment(start: start, end: start.addingTimeInterval(3600), stage: 1, source: "Phone")], calendar: cal)
        XCTAssertEqual(result.hours, 1); XCTAssertNil(result.rem)
    }
    // FEATURE 06 — A sample crossing noon must be trimmed
    // Only the hour before noon belongs to the selected night. This protects
    // against carrying the next window's hour into this night's total.
    func testNoonBoundaryClipping() {
        let noon = cal.startOfDay(for: day).addingTimeInterval(12*3600)
        let result = HealthMath.sleep(for: day, segments: [SleepSegment(start: noon.addingTimeInterval(-3600), end: noon.addingTimeInterval(3600), stage: 3, source: "Watch")], calendar: cal)
        XCTAssertEqual(result.hours, 1)
    }
    // FEATURE 07 — Keep the fictional demonstration realistic about gaps
    // Expect 30 dated rows and two missing days. This protects the demo's ability
    // to show missing-data UI as well as successful measurements.
    func testDemoIsThirtyDaysWithGaps() {
        let rows = HealthMath.demo(now: day)
        XCTAssertEqual(rows.count, 30)
        XCTAssertEqual(rows.filter { $0.sleepHours == nil }.count, 2)
    }
}
