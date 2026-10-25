import Foundation

struct SleepSegment {
    let start: Date
    let end: Date
    let stage: Int // HealthKit: 1 unspecified, 3 core, 4 deep, 5 REM
    let source: String
}
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
enum HealthMath {
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
    // Noon-to-noon window assigned to its morning date. Split at boundaries,
    // avoiding midnight double counting and retaining timezone/DST semantics.
    static func sleep(for day: Date, segments: [SleepSegment], calendar: Calendar = .current) -> (hours: Double?, rem: Double?, source: String?, timestamp: Date?) {
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day)!
        let previous = calendar.date(byAdding: .day, value: -1, to: noon)!
        let candidates = segments.filter { [1,3,4,5].contains($0.stage) && $0.end > previous && $0.start < noon }
        let groups = Dictionary(grouping: candidates, by: \.source)
        func clipped(_ items: [SleepSegment]) -> [DateInterval] {
            items.map { DateInterval(start: max(previous, $0.start), end: min(noon, $0.end)) }
        }
        // Prefer a source with staging; never combine overlapping sources.
        let selected = groups.keys.sorted().max { a, b in
            let aa = groups[a]!, bb = groups[b]!
            let aStaged = aa.contains { $0.stage >= 3 }, bStaged = bb.contains { $0.stage >= 3 }
            if aStaged != bStaged { return !aStaged }
            return unionSeconds(clipped(aa)) < unionSeconds(clipped(bb))
        }
        guard let source = selected, let items = groups[source] else { return (nil,nil,nil,nil) }
        let seconds = unionSeconds(clipped(items))
        guard seconds > 0 else { return (nil,nil,nil,nil) }
        let staged = items.contains { $0.stage >= 3 }
        let rem = unionSeconds(clipped(items.filter { $0.stage == 5 }))
        return (seconds / 3600, staged ? rem / seconds * 100 : nil, source, items.map(\.end).max())
    }
    static func remFlag(_ percent: Double?, low: Double, high: Double) -> String {
        guard let percent else { return "No stage data" }
        if percent < low { return "Below your range" }
        if percent > high { return "Above your range" }
        return "Within your range"
    }
    static func days(count: Int, now: Date = Date(), calendar: Calendar = .current) -> [Date] {
        (0..<count).reversed().map { calendar.date(byAdding: .day, value: -$0, to: calendar.startOfDay(for: now))! }
    }
    static func demo(now: Date = Date()) -> [DailyHealth] {
        days(count: 30, now: now).enumerated().map { index, date in
            let missing = index == 9 || index == 22
            return DailyHealth(date: date, sleepHours: missing ? nil : 6.8 + Double(index % 5) * 0.35,
                remPercent: missing ? nil : 18 + Double(index % 9), restingHR: missing ? nil : 55 + Double(index % 7),
                hrv: missing ? nil : 38 + Double(index % 13), measuredAt: missing ? nil : min(now, date.addingTimeInterval(7 * 3600)), sleepSource: "Synthetic fixture")
        }
    }
}
