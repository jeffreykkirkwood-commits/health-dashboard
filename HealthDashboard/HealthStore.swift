import Foundation
import HealthKit
import SwiftUI

@MainActor final class DashboardStore: ObservableObject {
    @Published var rows: [DailyHealth] = []
    @Published var lastSync: Date?
    @Published var busy = false
    @Published var message: String?
    @Published var demo = true
    private let health = HKHealthStore()
    private var generation = 0
    private let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    private let rhr = HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
    private let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!

    func setDemo(_ enabled: Bool) {
        generation += 1; busy = false; demo = enabled; lastSync = nil; message = nil
        rows = enabled ? HealthMath.demo() : []
    }
    func connect() async {
        guard HKHealthStore.isHealthDataAvailable() else { message = "HealthKit is unavailable on this device. Try synthetic demo mode."; return }
        do {
            try await health.requestAuthorization(toShare: [], read: Set<HKObjectType>([sleep, rhr, hrv]))
            await refresh()
        } catch { message = "Health access request failed. You can review access in the Health app and retry." }
    }
    func refresh() async {
        guard !busy else { return }
        if demo { rows = HealthMath.demo(); return }
        busy = true; message = nil
        let token = generation
        defer { if token == generation { busy = false } }
        do {
            let days = HealthMath.days(count: 30)
            let from = Calendar.current.date(byAdding: .day, value: -1, to: days[0])!
            let sleepSamples = (try await samples(sleep, from: from)).compactMap { $0 as? HKCategorySample }
            let heartSamples = (try await samples(rhr, from: days[0])).compactMap { $0 as? HKQuantitySample }
            let variabilitySamples = (try await samples(hrv, from: days[0])).compactMap { $0 as? HKQuantitySample }
            guard generation == token, !demo else { return }
            let segments = sleepSamples.map { SleepSegment(start: $0.startDate, end: $0.endDate, stage: $0.value, source: $0.sourceRevision.source.name + " · " + $0.sourceRevision.source.bundleIdentifier) }
            let calendar = Calendar.current
            rows = days.map { day in
                let s = HealthMath.sleep(for: day, segments: segments)
                let heart = heartSamples.filter { calendar.isDate($0.startDate, inSameDayAs: day) }
                let variability = variabilitySamples.filter { calendar.isDate($0.startDate, inSameDayAs: day) }
                func mean(_ values: [HKQuantitySample], unit: HKUnit) -> Double? {
                    values.isEmpty ? nil : values.map { $0.quantity.doubleValue(for: unit) }.reduce(0,+) / Double(values.count)
                }
                return DailyHealth(date: day, sleepHours: s.hours, remPercent: s.rem,
                    restingHR: mean(heart, unit: HKUnit.count().unitDivided(by: .minute())),
                    hrv: mean(variability, unit: .secondUnit(with: .milli)),
                    measuredAt: ([s.timestamp].compactMap { $0 } + heart.map(\.endDate) + variability.map(\.endDate)).max(), sleepSource: s.source)
            }
            lastSync = Date()
            if rows.allSatisfy({ $0.measuredAt == nil }) { message = "No readable samples. Data may be missing or Health access may be off. HealthKit does not reveal whether read permission was denied." }
        } catch {
            guard generation == token else { return }
            rows = []; message = "Sync failed. Unlock your iPhone, review Health access, and retry."
        }
    }
    private func samples(_ type: HKSampleType, from: Date) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: HKQuery.predicateForSamples(withStart: from, end: Date(), options: []), limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: samples ?? []) }
            }
            health.execute(query)
        }
    }
}
