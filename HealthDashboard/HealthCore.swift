// PURPOSE: Calculate daily sleep summaries and provide fictional dashboard data without needing Apple Health or a screen.

import Foundation

// FEATURE 01 — Describe one recorded sleep interval
// Each segment carries start/end times, a recorded stage and the source app or
// device. One night may have overlapping segments from several sources.
struct SleepSegment: Codable {
    let start: Date
    let end: Date
    let stage: Int // HealthKit: 1 unspecified, 2 awake, 3 core, 4 deep, 5 REM
    let source: String
}
// FEATURE 02 — Describe one day for the dashboard
// This row combines optional sleep and heart readings with their dates/source.
// Optional means the value may be unknown; nil means no readable value, not zero.
struct DailyHealth: Identifiable {
    var id: Date { date }
    let date: Date
    var sleepHours: Double?
    var remPercent: Double?
    var restingHR: Double?
    var hrv: Double?
    var measuredAt: Date?
    var sleepSource: String?
}
// The sleep math, kept free of Apple Health and screens so the Mac tests can check it.
enum HealthMath {
    // FEATURE 03 — Count overlapping time only once
    // Sort valid time intervals and join those that overlap or touch. Summing
    // the joined durations prevents duplicate segments from inflating sleep time.
    // An empty set contributes zero seconds to this intermediate calculation.
    static func unionSeconds(_ intervals: [DateInterval]) -> Double {
        let sorted = intervals.filter { $0.duration > 0 }.sorted { $0.start < $1.start }
        guard var current = sorted.first else { return 0 }
        var total = 0.0
        for next in sorted.dropFirst() {
            if next.start <= current.end { current = DateInterval(start: current.start, end: max(current.end, next.end)) }
            else { total += current.duration; current = next }
        }
        return total + current.duration
    }
    // FEATURE 04 — Assign sleep to a night and choose one source
    // A "night" is yesterday's noon to this day's noon, so sleep that crosses
    // midnight counts once, under the morning's date. Keep only
    // asleep stages. Group by source, prefer a source with stage detail, then use
    // the longest covered duration. Never add two devices' overlapping nights.
    // This is this app's source-selection rule, not Apple Health's prioritization.
    static func sleep(for day: Date, segments: [SleepSegment], calendar: Calendar = .current) -> (hours: Double?, rem: Double?, source: String?, timestamp: Date?) {
        guard let night = night(for: day, segments: segments, calendar: calendar) else { return (nil,nil,nil,nil) }
        // FEATURE 06 — Return unknown when there is no usable night
        // No source or no positive duration returns nil fields. With a usable night,
        // unionSeconds prevents overlap inflation. REM share is REM seconds divided
        // by all asleep seconds; without stage detail, REM stays unknown.
        let items = night.asleep
        let seconds = unionSeconds(night.clipped(items))
        guard seconds > 0 else { return (nil,nil,nil,nil) }
        let staged = items.contains { $0.stage >= 3 }
        let rem = unionSeconds(night.clipped(items.filter { $0.stage == 5 }))
        return (seconds / 3600, staged ? rem / seconds * 100 : nil, night.source, items.map(\.end).max())
    }
    // FEATURE 04b — The chosen source's segments for one noon-to-noon night
    // Shared by sleep hours, bedtime, time awake and the HRV sleep window, so all
    // of them use the same night and the same single source. Awake segments (2)
    // are kept separately; they never decide which source wins.
    struct Night {
        let start: Date, end: Date, source: String
        let asleep: [SleepSegment], awake: [SleepSegment]
        // FEATURE 05 — Keep only the part inside this night
        // An interval can cross noon. Trim its edges to the selected night before
        // counting, so time outside this window does not inflate this night's hours.
        func clipped(_ items: [SleepSegment]) -> [DateInterval] {
            items.map { DateInterval(start: max(start, $0.start), end: min(end, $0.end)) }
        }
    }
    static func night(for day: Date, segments: [SleepSegment], calendar: Calendar = .current) -> Night? {
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day)!
        let previous = calendar.date(byAdding: .day, value: -1, to: noon)!
        let inWindow = segments.filter { $0.end > previous && $0.start < noon }
        let candidates = inWindow.filter { [1,3,4,5].contains($0.stage) }
        let groups = Dictionary(grouping: candidates, by: \.source)
        func span(_ items: [SleepSegment]) -> Double {
            unionSeconds(items.map { DateInterval(start: max(previous, $0.start), end: min(noon, $0.end)) })
        }
        let selected = groups.keys.sorted().max { a, b in
            let aa = groups[a]!, bb = groups[b]!
            let aStaged = aa.contains { $0.stage >= 3 }, bStaged = bb.contains { $0.stage >= 3 }
            if aStaged != bStaged { return !aStaged }
            return span(aa) < span(bb)
        }
        guard let source = selected, let items = groups[source] else { return nil }
        return Night(start: previous, end: noon, source: source, asleep: items, awake: inWindow.filter { $0.stage == 2 && $0.source == source })
    }
    // FEATURE 07 — Translate a personal range into a label
    // Both endpoints count as within your range. Missing staging says No stage
    // data. The label compares numbers only; it is not a clinical interpretation.
    static func remFlag(_ percent: Double?, low: Double, high: Double) -> String {
        guard let percent else { return "No stage data" }
        if percent < low { return "Below your range" }
        if percent > high { return "Above your range" }
        return "Within your range"
    }
    // FEATURE 08 — Create calendar dates for charts
    // Build consecutive local start-of-day dates ending today. Calendar arithmetic
    // handles day boundaries rather than assuming every day lasts exactly 24 hours.
    static func days(count: Int, now: Date = Date(), calendar: Calendar = .current) -> [Date] {
        (0..<count).reversed().map { calendar.date(byAdding: .day, value: -$0, to: calendar.startOfDay(for: now))! }
    }
    // FEATURE 09 — Generate a safe fictional 30-day history
    // Create repeatable-looking sleep/heart values with two intentional missing
    // days. Dates move with now so the demo stays usable. These values never come
    // from a person and are never written into Apple Health.
    static func demo(now: Date = Date()) -> [DailyHealth] {
        days(count: 30, now: now).enumerated().map { index, date in
            let missing = index == 9 || index == 22
            return DailyHealth(date: date, sleepHours: missing ? nil : 6.8 + Double(index % 5) * 0.35,
                remPercent: missing ? nil : 18 + Double(index % 9), restingHR: missing ? nil : 55 + Double(index % 7),
                hrv: missing ? nil : 38 + Double(index % 13), measuredAt: missing ? nil : min(now, date.addingTimeInterval(7 * 3600)), sleepSource: "Synthetic fixture")
        }
    }
}

// FEATURE 10 — Describe the fictional 35-day Apple Health-shaped data set
// health.synthetic.v1.json holds made-up samples shaped like what the app reads:
// sleep segments (awake included), single HRV readings, daily resting heart rate
// and daily activity totals. A day with no record has no row; a zero day has a
// row with 0. `cases` names the dates of each no-data and edge case, as
// yyyy-MM-dd in `timeZone`, so later math and card tests can point at them.
struct HRVReading: Codable, Equatable {
    let start: Date
    let end: Date
    let valueMs: Double // SDNN, milliseconds
}
struct RestingHRReading: Codable, Equatable {
    let start: Date
    let end: Date
    let bpm: Double
}
struct DailyActivity: Codable, Equatable {
    let start: Date
    let end: Date
    let activeEnergyKcal: Double
    let exerciseMinutes: Double
}
struct SyntheticCases: Codable, Equatable {
    let missingDays: [String]
    let noHRVDay: String
    let singleHRVReadingNight: String
    let daytimeOnlyHRVDay: String
    let sleepAndDaytimeHRVDay: String
    let noRestingHRDay: String
    let noSleepNight: String
    let zeroActivityDay: String
    let bedtimeAfterMidnightNights: [String]
    let bedtimeBeforeMidnightNextToAfter: String
    let noAwakeDataNight: String
    let partialToday: String
    let shortHistoryAsOf: String
}
struct SyntheticHealthSet: Codable {
    let schemaVersion: Int
    let syntheticOnly: Bool
    let subjectID: String
    let subjectDisplay: String
    let note: String
    let timeZone: String
    let firstDay: String
    let referenceNow: Date
    let cases: SyntheticCases
    let sleepSegments: [SleepSegment]
    let hrvReadings: [HRVReading]
    let restingHeartRate: [RestingHRReading]
    let dailyActivity: [DailyActivity]
}
// FEATURE 11 — Load the fictional data set, parsing only
// Same bundle choice as the biomarker fixture. Dates are ISO 8601 with an offset.
// Reject anything not marked synthetic or not version 1; no math happens here.
enum SyntheticHealthError: Error, Equatable { case unsupportedSchema, syntheticOnlyRequired }
enum SyntheticHealth {
    static func loadBundled() throws -> SyntheticHealthSet {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "health.synthetic.v1", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try decode(Data(contentsOf: url))
    }
    static func decode(_ data: Data) throws -> SyntheticHealthSet {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let set = try decoder.decode(SyntheticHealthSet.self, from: data)
        guard set.schemaVersion == 1 else { throw SyntheticHealthError.unsupportedSchema }
        guard set.syntheticOnly, set.subjectID.hasPrefix("SYNTHETIC") else { throw SyntheticHealthError.syntheticOnlyRequired }
        return set
    }
}

// FEATURE 12 — Personal baseline: your usual and the middle half of your own days
// Pure math for the "Heart rate & HRV vs your usual" card (#28). Compares a value
// only with the same person's last 30 days. Missing days are left out, never 0.
struct PersonalBaseline: Equatable {
    let usual: Double // median of the daily values in the window
    let p25: Double
    let p75: Double
    let days: Int // days in the window that have a value
}
enum BaselineLabel: String, Equatable { case above, within, below }
enum BaselineStatus: Equatable {
    case noReading // no value for this day: nothing guessed or carried over
    case building(value: Double, days: Int) // under 14 days of readings in the 30
    case compared(value: Double, baseline: PersonalBaseline, label: BaselineLabel)
}
struct NightlyHRV: Equatable {
    let value: Double // median of the readings used
    let count: Int // readings the median used
    let fromSleep: Bool // false when it fell back to the whole day's readings
}
extension HealthMath {
    static let baselineWindowDays = 30
    static let baselineMinimumDays = 14
    // FEATURE 13 — One percentile method everywhere
    // Linear interpolation between closest ranks, the same as PERCENTILE.INC:
    // rank h = (n - 1) × p on the sorted values. Empty input has no value.
    static func percentile(_ values: [Double], _ p: Double) -> Double? {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return nil }
        let h = Double(sorted.count - 1) * min(max(p, 0), 1)
        let lower = Int(h.rounded(.down)), upper = Int(h.rounded(.up))
        return sorted[lower] + (h - Double(lower)) * (sorted[upper] - sorted[lower])
    }
    static func median(_ values: [Double]) -> Double? { percentile(values, 0.5) }
    // FEATURE 14 — Last night's HRV
    // Median of the readings inside last night's sleep window (first asleep
    // segment start to last asleep segment end of the chosen source, same
    // noon-to-noon night as the sleep card). If none, the median of that whole
    // calendar day's readings. One reading counts; zero readings gives nil.
    static func nightlyHRV(for day: Date, readings: [HRVReading], segments: [SleepSegment], calendar: Calendar = .current) -> NightlyHRV? {
        if let night = night(for: day, segments: segments, calendar: calendar),
           let start = night.clipped(night.asleep).map(\.start).min(), let end = night.clipped(night.asleep).map(\.end).max() {
            let asleep = readings.filter { $0.start >= start && $0.start <= end }.map(\.valueMs)
            if let value = median(asleep) { return NightlyHRV(value: value, count: asleep.count, fromSleep: true) }
        }
        let dayValues = readings.filter { calendar.isDate($0.start, inSameDayAs: day) }.map(\.valueMs)
        guard let value = median(dayValues) else { return nil }
        return NightlyHRV(value: value, count: dayValues.count, fromSleep: false)
    }
    // FEATURE 15 — Today's resting heart rate
    // The day's reading; if a source wrote more than one, their median. None is nil.
    static func restingHR(for day: Date, readings: [RestingHRReading], calendar: Calendar = .current) -> Double? {
        median(readings.filter { calendar.isDate($0.start, inSameDayAs: day) }.map(\.bpm))
    }
    // FEATURE 16 — Your usual and the band from your own last 30 days
    // The window is the 30 calendar days ending on `day`, that day included.
    // Days with no value are skipped. Under 14 days with a value: building.
    // "Within" includes both ends of the band (p25 ≤ value ≤ p75).
    static func baseline(on day: Date, value: Double?, daily: (Date) -> Double?, calendar: Calendar = .current) -> BaselineStatus {
        guard let value else { return .noReading }
        let start = calendar.startOfDay(for: day)
        let values = (0..<baselineWindowDays).compactMap { daily(calendar.date(byAdding: .day, value: -$0, to: start)!) }
        guard values.count >= baselineMinimumDays, let usual = median(values),
              let p25 = percentile(values, 0.25), let p75 = percentile(values, 0.75) else { return .building(value: value, days: values.count) }
        let label: BaselineLabel = value < p25 ? .below : value > p75 ? .above : .within
        return .compared(value: value, baseline: PersonalBaseline(usual: usual, p25: p25, p75: p75, days: values.count), label: label)
    }
    static func hrvBaseline(on day: Date, readings: [HRVReading], segments: [SleepSegment], calendar: Calendar = .current) -> BaselineStatus {
        baseline(on: day, value: nightlyHRV(for: day, readings: readings, segments: segments, calendar: calendar)?.value,
                 daily: { nightlyHRV(for: $0, readings: readings, segments: segments, calendar: calendar)?.value }, calendar: calendar)
    }
    static func restingHRBaseline(on day: Date, readings: [RestingHRReading], calendar: Calendar = .current) -> BaselineStatus {
        baseline(on: day, value: restingHR(for: day, readings: readings, calendar: calendar),
                 daily: { restingHR(for: $0, readings: readings, calendar: calendar) }, calendar: calendar)
    }
}

// FEATURE 17 — Sleep extras: bedtime consistency and time awake
// Bedtime is the start of the chosen source's first asleep segment in the
// noon-to-noon night. It is measured as minutes after the previous noon, so
// 11:50 PM is 710 and 12:20 AM is 740: 30 minutes apart, not 23 hours.
enum BedtimeConsistency: Equatable {
    case notEnoughNights(recorded: Int) // under 7 recorded nights in the 14
    case measured(withinUsual: Int, recorded: Int, usualMinutesAfterNoon: Double)
}
extension HealthMath {
    static let bedtimeNights = 14
    static let bedtimeMinimumNights = 7
    static let bedtimeToleranceMinutes = 30.0
    static func bedtimeMinutesAfterNoon(for day: Date, segments: [SleepSegment], calendar: Calendar = .current) -> Double? {
        guard let night = night(for: day, segments: segments, calendar: calendar),
              let first = night.clipped(night.asleep).map(\.start).min() else { return nil }
        return first.timeIntervalSince(night.start) / 60
    }
    // The 14 nights ending on `day` (its morning included). "Usual" is the median
    // bedtime of the recorded nights; a night counts when it is within 30 minutes
    // of it, both ends included.
    static func bedtimeConsistency(on day: Date, segments: [SleepSegment], calendar: Calendar = .current) -> BedtimeConsistency {
        let start = calendar.startOfDay(for: day)
        let bedtimes = (0..<bedtimeNights).compactMap { bedtimeMinutesAfterNoon(for: calendar.date(byAdding: .day, value: -$0, to: start)!, segments: segments, calendar: calendar) }
        guard bedtimes.count >= bedtimeMinimumNights, let usual = median(bedtimes) else { return .notEnoughNights(recorded: bedtimes.count) }
        let within = bedtimes.filter { abs($0 - usual) <= bedtimeToleranceMinutes }.count
        return .measured(withinUsual: within, recorded: bedtimes.count, usualMinutesAfterNoon: usual)
    }
    // Minutes awake during the night from the chosen source, overlaps counted once.
    // Only a source with stage detail records awake time: an unstaged source gives
    // nil ("Awake time not recorded"); a staged night with no awake segment gives 0.
    // No recorded night is nil too.
    static func awakeMinutes(for day: Date, segments: [SleepSegment], calendar: Calendar = .current) -> Double? {
        guard let night = night(for: day, segments: segments, calendar: calendar), night.asleep.contains(where: { $0.stage >= 3 }) else { return nil }
        return unionSeconds(night.clipped(night.awake)) / 60
    }
}

// FEATURE 18 — Activity this week vs your previous 4 weeks
// Daily average of the last 7 full days against the 28 full days before them;
// today is a partial day and is left out. A day with no row is skipped; a row
// with 0 counts as 0. "About the same" is within 10% either way.
enum EffortLabel: String, Equatable { case more, aboutTheSame, less }
struct EffortComparison: Equatable {
    let recentPerDay: Double, previousPerDay: Double, label: EffortLabel
}
enum EffortTrend: Equatable {
    case noActivityThisWeek // no activity row in the last 7 full days
    case notEnoughHistory(previousDays: Int) // under 7 days with a row in the previous 28
    case compared(energy: EffortComparison, exercise: EffortComparison, overall: EffortLabel)
}
extension HealthMath {
    static let effortSameBand = 0.10
    static func effortLabel(recent: Double, previous: Double) -> EffortLabel {
        if previous == 0 { return recent == 0 ? .aboutTheSame : .more }
        let change = (recent - previous) / previous
        return change > effortSameBand ? .more : change < -effortSameBand ? .less : .aboutTheSame
    }
    // `today` is the partial day; the windows are the 7 days before it and the 28 before those.
    // Overall label: the mean of the two relative changes, with the same 10% band.
    static func effortTrend(today: Date, activity: [DailyActivity], calendar: Calendar = .current) -> EffortTrend {
        let todayStart = calendar.startOfDay(for: today)
        let byDay = Dictionary(grouping: activity) { calendar.startOfDay(for: $0.start) }
        func rows(_ offsets: ClosedRange<Int>) -> [DailyActivity] {
            offsets.flatMap { byDay[calendar.date(byAdding: .day, value: -$0, to: todayStart)!] ?? [] }
        }
        let recent = rows(1...7), previous = rows(8...35)
        guard !recent.isEmpty else { return .noActivityThisWeek }
        let previousDays = Set(previous.map { calendar.startOfDay(for: $0.start) }).count
        guard previousDays >= 7 else { return .notEnoughHistory(previousDays: previousDays) }
        func perDay(_ items: [DailyActivity], _ value: (DailyActivity) -> Double) -> Double {
            items.map(value).reduce(0, +) / Double(Set(items.map { calendar.startOfDay(for: $0.start) }).count)
        }
        func compare(_ value: (DailyActivity) -> Double) -> EffortComparison {
            let r = perDay(recent, value), p = perDay(previous, value)
            return EffortComparison(recentPerDay: r, previousPerDay: p, label: effortLabel(recent: r, previous: p))
        }
        let energy = compare(\.activeEnergyKcal), exercise = compare(\.exerciseMinutes)
        func change(_ c: EffortComparison) -> Double { c.previousPerDay == 0 ? (c.recentPerDay == 0 ? 0 : 1) : (c.recentPerDay - c.previousPerDay) / c.previousPerDay }
        let mean = (change(energy) + change(exercise)) / 2
        return .compared(energy: energy, exercise: exercise, overall: mean > effortSameBand ? .more : mean < -effortSameBand ? .less : .aboutTheSame)
    }
}
