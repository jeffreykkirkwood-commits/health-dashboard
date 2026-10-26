import Foundation
import HealthKit
import SwiftUI

@MainActor final class DashboardStore: ObservableObject {
    @Published var rows: [DailyHealth] = []
    @Published var lastSync: Date?
    @Published var busy = false
    @Published var message: String?
    @Published var demo = UserDefaults.standard.object(forKey: "demoMode") == nil ? true : UserDefaults.standard.bool(forKey: "demoMode")
    @Published var extraValues: [String: Double] = [:]
    @Published var extraSync: Date?
    private let extras: [(HKQuantityTypeIdentifier, HKUnit, Bool)] = [
        (.stepCount, .count(), true), (.activeEnergyBurned, .kilocalorie(), true),
        (.appleExerciseTime, .minute(), true), (.respiratoryRate, HKUnit.count().unitDivided(by: .minute()), false),
        (.oxygenSaturation, .percent(), false)
    ]
    private let health = HKHealthStore()
    private var generation = 0
    private let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    private let rhr = HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
    private let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!

    // Changing mode invalidates in-flight foreground reads. A late HealthKit result
    // must not replace synthetic rows or reveal old live values after switching modes.
    func setDemo(_ enabled: Bool) {
        generation += 1; busy = false; demo = enabled; lastSync = nil; message = nil
        UserDefaults.standard.set(enabled, forKey: "demoMode")
        rows = enabled ? HealthMath.demo() : []
        extraValues = enabled ? ["HKQuantityTypeIdentifierStepCount": 6840, "HKQuantityTypeIdentifierActiveEnergyBurned": 412,
                                 "HKQuantityTypeIdentifierAppleExerciseTime": 38, "HKQuantityTypeIdentifierRespiratoryRate": 14.2,
                                 "HKQuantityTypeIdentifierOxygenSaturation": 0.98] : [:]
        extraSync = nil
    }
    func connect() async {
        guard HKHealthStore.isHealthDataAvailable() else { message = "HealthKit is unavailable on this device. Try synthetic demo mode."; return }
        do {
            try await health.requestAuthorization(toShare: [], read: Set<HKObjectType>([sleep, rhr, hrv] + extras.compactMap { HKObjectType.quantityType(forIdentifier: $0.0) }))
            await refresh()
        } catch { message = "Health access request failed. You can review access in the Health app and retry." }
    }
    // Fetch a 30-day window, reduce samples into dated rows, then publish on the main
    // actor. Empty sample sets stay nil: HealthKit does not disclose read denial.
    // This is a foreground refresh, not observer delivery or overnight monitoring.
    func refresh() async {
        guard !busy else { return }
        if demo { setDemo(true); return }
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
            var updatedExtras: [String: Double] = [:]
            for (identifier, unit, cumulative) in extras {
                if let type = HKObjectType.quantityType(forIdentifier: identifier),
                   let value = try? await todayStatistic(type, unit: unit, cumulative: cumulative) {
                    updatedExtras[identifier.rawValue] = value
                }
            }
            guard generation == token, !demo else { return }
            extraValues = updatedExtras; extraSync = Date()
            lastSync = Date()
            if rows.allSatisfy({ $0.measuredAt == nil }) { message = "No readable samples. Data may be missing or Health access may be off. HealthKit does not reveal whether read permission was denied." }
        } catch {
            guard generation == token else { return }
            rows = []; extraValues = [:]; extraSync = nil; lastSync = nil; message = "Sync failed. Unlock your iPhone, review Health access, and retry."
        }
    }
    private func todayStatistic(_ type: HKQuantityType, unit: HKUnit, cumulative: Bool) async throws -> Double? {
        try await withCheckedThrowingContinuation { continuation in
            let start = Calendar.current.startOfDay(for: Date())
            let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate,
                                          options: cumulative ? .cumulativeSum : .discreteAverage) { _, result, error in
                if let error { continuation.resume(throwing: error); return }
                let quantity = cumulative ? result?.sumQuantity() : result?.averageQuantity()
                continuation.resume(returning: quantity?.doubleValue(for: unit))
            }
            health.execute(query)
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
