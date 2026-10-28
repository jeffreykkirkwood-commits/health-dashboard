// PURPOSE: Check the shape and value ranges of the fictional 35-day Apple Health-shaped data set. No HealthKit, no real person's data.

import XCTest
@testable import HealthCore
final class SyntheticHealthTests: XCTestCase {
    // FEATURE 01 — Load the shipped fixture and read dates in its own timezone
    // Days are calendar days in the fixture's timeZone (America/New_York), so the
    // same answers come out on any computer.
    func fixture() throws -> SyntheticHealthSet { try SyntheticHealth.loadBundled() }
    func calendar(_ set: SyntheticHealthSet) throws -> Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = try XCTUnwrap(TimeZone(identifier: set.timeZone)); return c
    }
    func dayKey(_ date: Date, _ cal: Calendar) -> String {
        let p = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", p.year!, p.month!, p.day!)
    }
    func date(_ key: String, _ cal: Calendar) throws -> Date {
        let p = key.split(separator: "-").compactMap { Int($0) }
        return try XCTUnwrap(cal.date(from: DateComponents(year: p[0], month: p[1], day: p[2])))
    }
    // FEATURE 02 — Fictional marker, 35 full days plus a partial today
    func testFixtureIsSyntheticAndCoversThirtyFiveFullDays() throws {
        let set = try fixture(), cal = try calendar(set)
        XCTAssertTrue(set.syntheticOnly)
        XCTAssertTrue(set.subjectID.hasPrefix("SYNTHETIC"))
        XCTAssertTrue(set.note.hasPrefix("SYNTHETIC"))
        let first = try date(set.firstDay, cal), today = cal.startOfDay(for: set.referenceNow)
        XCTAssertEqual(cal.dateComponents([.day], from: first, to: today).day, 35)
        XCTAssertEqual(dayKey(today, cal), set.cases.partialToday)
        let activityDays = Set(set.dailyActivity.map { dayKey($0.start, cal) })
        XCTAssertEqual(activityDays.count, set.dailyActivity.count, "one activity row per day")
        XCTAssertEqual(activityDays.count, 35 + 1 - set.cases.missingDays.count)
        let all = set.hrvReadings.map(\.start) + set.restingHeartRate.map(\.start) + set.dailyActivity.map(\.start) + set.sleepSegments.map(\.end)
        XCTAssertTrue(all.allSatisfy { $0 >= cal.date(byAdding: .day, value: -1, to: first)! && $0 <= set.referenceNow })
    }
    // FEATURE 03 — Values stay in plausible, made-up ranges
    func testValueRanges() throws {
        let set = try fixture(), cal = try calendar(set)
        XCTAssertTrue(set.hrvReadings.allSatisfy { (15...120).contains($0.valueMs) && $0.end > $0.start })
        XCTAssertTrue(set.restingHeartRate.allSatisfy { (40...80).contains($0.bpm) && $0.end > $0.start })
        XCTAssertTrue(set.dailyActivity.allSatisfy { (0...1500).contains($0.activeEnergyKcal) && (0...180).contains($0.exerciseMinutes) && $0.end > $0.start })
        XCTAssertTrue(set.sleepSegments.allSatisfy { [1, 2, 3, 4, 5].contains($0.stage) && $0.end > $0.start && $0.end.timeIntervalSince($0.start) < 12 * 3600 })
        let perDay = Dictionary(grouping: set.hrvReadings) { dayKey($0.start, cal) }
        XCTAssertTrue(perDay.values.allSatisfy { (1...6).contains($0.count) }, "0 to 6 HRV readings a day")
        XCTAssertEqual(Set(set.restingHeartRate.map { dayKey($0.start, cal) }).count, set.restingHeartRate.count, "one resting HR a day")
        for night in Set(set.sleepSegments.map { dayKey($0.end, cal) }) {
            guard let hours = HealthMath.sleep(for: try date(night, cal), segments: set.sleepSegments, calendar: cal).hours else { continue }
            XCTAssertTrue((5...9).contains(hours), "\(night): \(hours) h")
        }
        XCTAssertTrue(set.sleepSegments.contains { $0.stage == 2 }, "some nights record awake time")
    }
    // FEATURE 04 — Every named no-data and edge case is really in the data
    func testNamedCasesMatchTheData() throws {
        let set = try fixture(), cal = try calendar(set), c = set.cases
        let hrvDays = Dictionary(grouping: set.hrvReadings) { dayKey($0.start, cal) }
        func asleep(_ r: HRVReading) -> Bool { set.sleepSegments.contains { $0.stage != 2 && $0.start <= r.start && r.start < $0.end } }
        for day in c.missingDays {
            XCTAssertNil(hrvDays[day]); XCTAssertFalse(set.restingHeartRate.contains { dayKey($0.start, cal) == day })
            XCTAssertFalse(set.dailyActivity.contains { dayKey($0.start, cal) == day }, "missing day has no row, not a 0")
            XCTAssertNil(HealthMath.sleep(for: try date(day, cal), segments: set.sleepSegments, calendar: cal).hours)
        }
        XCTAssertNil(hrvDays[c.noHRVDay])
        XCTAssertEqual(hrvDays[c.singleHRVReadingNight]?.count, 1)
        XCTAssertTrue(hrvDays[c.singleHRVReadingNight]!.allSatisfy(asleep))
        XCTAssertFalse(try XCTUnwrap(hrvDays[c.daytimeOnlyHRVDay]).contains(where: asleep))
        let mixed = try XCTUnwrap(hrvDays[c.sleepAndDaytimeHRVDay])
        XCTAssertTrue(mixed.contains(where: asleep) && mixed.contains { !asleep($0) })
        XCTAssertFalse(set.restingHeartRate.contains { dayKey($0.start, cal) == c.noRestingHRDay })
        XCTAssertNil(HealthMath.sleep(for: try date(c.noSleepNight, cal), segments: set.sleepSegments, calendar: cal).hours)
        let zero = try XCTUnwrap(set.dailyActivity.first { dayKey($0.start, cal) == c.zeroActivityDay })
        XCTAssertEqual(zero.activeEnergyKcal, 0); XCTAssertEqual(zero.exerciseMinutes, 0)
        // A night is noon-to-noon, keyed by the morning date (same as HealthMath.sleep).
        func segments(_ night: String) throws -> [SleepSegment] {
            let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: try date(night, cal))!
            return set.sleepSegments.filter { $0.end > cal.date(byAdding: .day, value: -1, to: noon)! && $0.start < noon }
        }
        func bedtime(_ night: String) throws -> Date { try XCTUnwrap(try segments(night).map(\.start).min()) }
        for night in c.bedtimeAfterMidnightNights { XCTAssertEqual(dayKey(try bedtime(night), cal), night, "bedtime after midnight") }
        let before = try bedtime(c.bedtimeBeforeMidnightNextToAfter)
        XCTAssertNotEqual(dayKey(before, cal), c.bedtimeBeforeMidnightNextToAfter, "bedtime before midnight")
        XCTAssertEqual(cal.component(.hour, from: before), 23)
        let noAwake = try segments(c.noAwakeDataNight)
        XCTAssertFalse(noAwake.isEmpty); XCTAssertTrue(noAwake.allSatisfy { $0.stage == 1 })
        XCTAssertEqual(HealthMath.sleep(for: try date(c.noAwakeDataNight, cal), segments: set.sleepSegments, calendar: cal).source, "SYNTHETIC Phone")
        let partial = try XCTUnwrap(set.dailyActivity.first { dayKey($0.start, cal) == c.partialToday })
        XCTAssertLessThan(partial.end, cal.date(byAdding: .day, value: 1, to: partial.start)!, "today is a partial day")
        let earlier = Set(set.hrvReadings.map { dayKey($0.start, cal) }.filter { $0 < c.shortHistoryAsOf })
        XCTAssertEqual(earlier.count, 9, "fewer than 14 days of HRV history as of shortHistoryAsOf")
    }
    // FEATURE 05 — Refuse a file that is not marked synthetic or has another version
    func testRejectsNonSyntheticOrUnknownVersion() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "health.synthetic.v1", withExtension: "json"))
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertThrowsError(try SyntheticHealth.decode(Data(text.replacingOccurrences(of: "\"syntheticOnly\": true", with: "\"syntheticOnly\": false").utf8))) {
            XCTAssertEqual($0 as? SyntheticHealthError, .syntheticOnlyRequired)
        }
        XCTAssertThrowsError(try SyntheticHealth.decode(Data(text.replacingOccurrences(of: "\"schemaVersion\": 1", with: "\"schemaVersion\": 2").utf8))) {
            XCTAssertEqual($0 as? SyntheticHealthError, .unsupportedSchema)
        }
    }
}
