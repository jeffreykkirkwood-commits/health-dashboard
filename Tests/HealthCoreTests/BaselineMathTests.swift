// PURPOSE: Check the baseline, sleep and activity math for #28's first cards against the fictional fixture. Expected numbers were worked out independently from the JSON. No HealthKit, no real person's data.

import XCTest
@testable import HealthCore
final class BaselineMathTests: XCTestCase {
    // FEATURE 01 — Same fixture and calendar as SyntheticHealthTests
    var set: SyntheticHealthSet!
    var cal: Calendar!
    override func setUpWithError() throws {
        set = try SyntheticHealth.loadBundled()
        cal = Calendar(identifier: .gregorian); cal.timeZone = try XCTUnwrap(TimeZone(identifier: set.timeZone))
    }
    func day(_ key: String) -> Date {
        let p = key.split(separator: "-").compactMap { Int($0) }
        return cal.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))!
    }
    func hrv(_ key: String) -> BaselineStatus { HealthMath.hrvBaseline(on: day(key), readings: set.hrvReadings, segments: set.sleepSegments, calendar: cal) }
    func rhr(_ key: String) -> BaselineStatus { HealthMath.restingHRBaseline(on: day(key), readings: set.restingHeartRate, calendar: cal) }
    func assertCompared(_ status: BaselineStatus, value: Double, usual: Double, p25: Double, p75: Double, days: Int, label: BaselineLabel, line: UInt = #line) {
        guard case let .compared(v, b, l) = status else { return XCTFail("expected compared, got \(status)", line: line) }
        XCTAssertEqual(v, value, accuracy: 1e-9, line: line); XCTAssertEqual(b.usual, usual, accuracy: 1e-9, line: line)
        XCTAssertEqual(b.p25, p25, accuracy: 1e-9, line: line); XCTAssertEqual(b.p75, p75, accuracy: 1e-9, line: line)
        XCTAssertEqual(b.days, days, line: line); XCTAssertEqual(l, label, line: line)
    }
    // FEATURE 02 — One percentile method: linear interpolation (PERCENTILE.INC)
    func testPercentileMatchesPercentileInc() {
        XCTAssertEqual(HealthMath.percentile([4, 1, 3, 2], 0.25), 1.75)
        XCTAssertEqual(HealthMath.percentile([4, 1, 3, 2], 0.75), 3.25)
        XCTAssertEqual(HealthMath.median([4, 1, 3, 2]), 2.5)
        XCTAssertEqual(HealthMath.median([1, 9, 2]), 2)
        XCTAssertEqual(HealthMath.percentile([7], 0.25), 7)
        XCTAssertNil(HealthMath.median([]))
    }
    // FEATURE 03 — Last night's HRV: sleep readings first, then the whole day
    func testNightlyHRVCases() {
        let c = set.cases
        func night(_ key: String) -> NightlyHRV? { HealthMath.nightlyHRV(for: day(key), readings: set.hrvReadings, segments: set.sleepSegments, calendar: cal) }
        XCTAssertEqual(night(c.singleHRVReadingNight), NightlyHRV(value: 41.1, count: 1, fromSleep: true), "one reading counts, value is that reading")
        XCTAssertEqual(night(c.sleepAndDaytimeHRVDay), NightlyHRV(value: 51.35, count: 2, fromSleep: true), "sleep readings only, daytime ignored")
        XCTAssertEqual(night(c.daytimeOnlyHRVDay), NightlyHRV(value: 39.15, count: 2, fromSleep: false), "whole-day fallback")
        XCTAssertEqual(night(c.noSleepNight), NightlyHRV(value: 34.3, count: 5, fromSleep: false), "no sleep: whole-day fallback")
        XCTAssertEqual(night(c.partialToday), NightlyHRV(value: 42.2, count: 3, fromSleep: true))
        XCTAssertNil(night(c.noHRVDay), "zero readings: no value, nothing carried over")
        for missing in c.missingDays { XCTAssertNil(night(missing)) }
    }
    // FEATURE 04 — Your usual and the band, from your own last 30 days
    func testHRVBaseline() {
        let c = set.cases
        assertCompared(hrv(c.partialToday), value: 42.2, usual: 42.175, p25: 39.4, p75: 47.275, days: 26, label: .within)
        assertCompared(hrv(c.singleHRVReadingNight), value: 41.1, usual: 41.875, p25: 39.1125, p75: 45.325, days: 24, label: .within)
        assertCompared(hrv(c.daytimeOnlyHRVDay), value: 39.15, usual: 43.2, p25: 39.0, p75: 46.0, days: 21, label: .within)
        XCTAssertEqual(hrv(c.noHRVDay), .noReading)
        XCTAssertEqual(hrv(c.shortHistoryAsOf), .building(value: 39.0, days: 10), "under 14 days: building, with the day count")
    }
    func testRestingHRBaseline() {
        let c = set.cases
        assertCompared(rhr(c.partialToday), value: 54, usual: 56, p25: 55, p75: 58, days: 26, label: .below)
        assertCompared(rhr(c.singleHRVReadingNight), value: 55, usual: 57, p25: 55, p75: 58, days: 25, label: .within) // exactly on p25
        XCTAssertEqual(rhr(c.noRestingHRDay), .noReading)
        XCTAssertEqual(rhr(c.shortHistoryAsOf), .building(value: 56, days: 10))
    }
    // FEATURE 05 — Band edges, missing days and the 30-day limit
    func testBandEdgesAreWithinAndAboveBelowOutside() {
        let daily: (Date) -> Double? = { HealthMath.restingHR(for: $0, readings: self.set.restingHeartRate, calendar: self.cal) }
        let today = day(set.cases.partialToday)
        func label(_ v: Double) -> BaselineLabel? {
            if case let .compared(_, _, l) = HealthMath.baseline(on: today, value: v, daily: daily, calendar: cal) { return l }; return nil
        }
        XCTAssertEqual(label(55), .within); XCTAssertEqual(label(58), .within)
        XCTAssertEqual(label(54.99), .below); XCTAssertEqual(label(58.01), .above)
    }
    func testMissingDaysAreLeftOutAndOnlyLast30DaysCount() {
        // 30-day window Sep 29 – Oct 28: 3 missing days and the no-HRV day are skipped, not 0.
        guard case let .compared(_, b, _) = hrv(set.cases.partialToday) else { return XCTFail() }
        XCTAssertEqual(b.days, 30 - set.cases.missingDays.count - 1)
        // Dropping days 31+ (Sep 23 – 28) changes nothing.
        let cutoff = day("2026-09-29")
        let recent = HealthMath.hrvBaseline(on: day(set.cases.partialToday), readings: set.hrvReadings.filter { $0.start >= cutoff },
                                            segments: set.sleepSegments.filter { $0.start >= cutoff.addingTimeInterval(-12 * 3600) }, calendar: cal)
        XCTAssertEqual(recent, hrv(set.cases.partialToday))
        XCTAssertEqual(HealthMath.restingHRBaseline(on: day(set.cases.partialToday), readings: set.restingHeartRate.filter { $0.start >= cutoff }, calendar: cal), rhr(set.cases.partialToday))
    }
    // FEATURE 06 — Bedtime consistency, with bedtimes after midnight
    func testBedtimesAfterMidnight() {
        func bed(_ key: String) -> Double? { HealthMath.bedtimeMinutesAfterNoon(for: day(key), segments: set.sleepSegments, calendar: cal) }
        XCTAssertEqual(bed(set.cases.bedtimeBeforeMidnightNextToAfter), 710) // 11:50 PM
        for key in set.cases.bedtimeAfterMidnightNights { XCTAssertEqual(bed(key), 740) } // 12:20 AM, 30 min later, not 23 h earlier
        XCTAssertNil(bed(set.cases.noSleepNight))
        // Two nights 30 minutes apart either side of midnight are both within 30 minutes of their median.
        let noon = day("2026-01-02").addingTimeInterval(-12 * 3600)
        let nights = (0..<7).flatMap { i -> [SleepSegment] in
            let start = noon.addingTimeInterval(Double(i) * 86400 + (i % 2 == 0 ? 710 : 740) * 60)
            return [SleepSegment(start: start, end: start.addingTimeInterval(7 * 3600), stage: 3, source: "Test")]
        }
        XCTAssertEqual(HealthMath.bedtimeConsistency(on: day("2026-01-08"), segments: nights, calendar: cal), .measured(withinUsual: 7, recorded: 7, usualMinutesAfterNoon: 710))
    }
    func testBedtimeConsistency() {
        XCTAssertEqual(HealthMath.bedtimeConsistency(on: day(set.cases.partialToday), segments: set.sleepSegments, calendar: cal), .measured(withinUsual: 13, recorded: 14, usualMinutesAfterNoon: 647.5))
        XCTAssertEqual(HealthMath.bedtimeConsistency(on: day("2026-10-10"), segments: set.sleepSegments, calendar: cal), .measured(withinUsual: 9, recorded: 11, usualMinutesAfterNoon: 660))
        XCTAssertEqual(HealthMath.bedtimeConsistency(on: day("2026-09-28"), segments: set.sleepSegments, calendar: cal), .notEnoughNights(recorded: 6))
    }
    // FEATURE 07 — Time awake: only when the source records it
    func testAwakeMinutes() {
        func awake(_ key: String) -> Double? { HealthMath.awakeMinutes(for: day(key), segments: set.sleepSegments, calendar: cal) }
        XCTAssertEqual(awake(set.cases.partialToday), 15)
        XCTAssertEqual(awake("2026-10-09"), 20)
        XCTAssertEqual(awake("2026-10-20"), 0, "staged night with no awake segment")
        XCTAssertNil(awake(set.cases.noAwakeDataNight), "unstaged source: awake time not recorded")
        XCTAssertNil(awake(set.cases.noSleepNight))
    }
    // FEATURE 08 — Activity: last 7 full days vs the previous 28, today left out
    func testEffortTrend() throws {
        guard case let .compared(energy, exercise, overall) = HealthMath.effortTrend(today: day(set.cases.partialToday), activity: set.dailyActivity, calendar: cal) else { return XCTFail() }
        XCTAssertEqual(energy.recentPerDay, 4275.0 / 7, accuracy: 1e-9); XCTAssertEqual(energy.previousPerDay, 449.56, accuracy: 1e-9)
        XCTAssertEqual(exercise.recentPerDay, 265.0 / 7, accuracy: 1e-9); XCTAssertEqual(exercise.previousPerDay, 28.56, accuracy: 1e-9)
        XCTAssertEqual(energy.label, .more); XCTAssertEqual(exercise.label, .more); XCTAssertEqual(overall, .more)
        // Oct 21: exercise up 9.3% is "about the same"; energy up 31.8% is "more"; overall (mean 20.6%) "more".
        guard case let .compared(e2, x2, o2) = HealthMath.effortTrend(today: day("2026-10-21"), activity: set.dailyActivity, calendar: cal) else { return XCTFail() }
        XCTAssertEqual(x2.label, .aboutTheSame); XCTAssertEqual(e2.label, .more); XCTAssertEqual(o2, .more)
        XCTAssertEqual(x2.previousPerDay, 501.0 / 18, accuracy: 1e-9, "missing days skipped, the zero day counted as 0")
        XCTAssertEqual(HealthMath.effortTrend(today: day("2026-10-03"), activity: set.dailyActivity, calendar: cal), .notEnoughHistory(previousDays: 3))
        XCTAssertEqual(HealthMath.effortTrend(today: day(set.firstDay), activity: set.dailyActivity, calendar: cal), .noActivityThisWeek)
        XCTAssertEqual(HealthMath.effortLabel(recent: 110, previous: 100), .aboutTheSame)
        XCTAssertEqual(HealthMath.effortLabel(recent: 90, previous: 100), .aboutTheSame)
        XCTAssertEqual(HealthMath.effortLabel(recent: 111, previous: 100), .more)
        XCTAssertEqual(HealthMath.effortLabel(recent: 89, previous: 100), .less)
    }
}
