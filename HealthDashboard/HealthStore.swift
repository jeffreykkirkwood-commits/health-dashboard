// PURPOSE: Bring Apple Health readings into the dashboard while keeping demo values separate. HealthKit is Apple's on-device health-data interface.

import Foundation
import HealthKit
import SwiftUI

// FEATURE 01 — Own the values the screen observes
// @Published values make the screen redraw when they change. @MainActor makes
// these updates run on the main thread, the only one allowed to touch the screen.
// UserDefaults (simple on-device settings storage) remembers only the demo/live
// choice here; this class never uploads readings.
@MainActor final class DashboardStore: ObservableObject {
    @Published var rows: [DailyHealth] = []
    @Published var lastSync: Date?
    @Published var busy = false
    @Published var message: String?
    @Published var demo = UserDefaults.standard.object(forKey: "demoMode") == nil ? true : UserDefaults.standard.bool(forKey: "demoMode")
    @Published var extraValues: [String: Double] = [:]
    @Published var extraSync: Date?
    // FEATURE 02 — Choose how each extra metric is summarized
    // The true/false flag chooses a total for steps/energy/exercise and an average
    // for respiration/oxygen. Adding a metric here affects permissions and today's
    // read; it does not automatically create a new screen card.
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

    // FEATURE 03 — Switch sources without mixing their values
    // When you toggle synthetic data, immediately replace the rows, clear previous
    // sync information and save the choice. generation is a changing request number:
    // a read that started under the old choice must not overwrite the new display.
    func setDemo(_ enabled: Bool) {
        generation += 1; busy = false; demo = enabled; lastSync = nil; message = nil
        UserDefaults.standard.set(enabled, forKey: "demoMode")
        rows = enabled ? HealthMath.demo() : []
        extraValues = enabled ? ["HKQuantityTypeIdentifierStepCount": 6840, "HKQuantityTypeIdentifierActiveEnergyBurned": 412,
                                 "HKQuantityTypeIdentifierAppleExerciseTime": 38, "HKQuantityTypeIdentifierRespiratoryRate": 14.2,
                                 "HKQuantityTypeIdentifierOxygenSaturation": 0.98] : [:]
        extraSync = nil
    }
    // FEATURE 04 — Ask permission only when the user connects
    // Check that HealthKit exists, request read access for the dashboard metrics,
    // then refresh. toShare is empty: no write permission is requested. A failed
    // prompt sets a readable message. Apple does not disclose which read types
    // were denied, so permission completion alone cannot mean all data is available.
    func connect() async {
        guard HKHealthStore.isHealthDataAvailable() else { message = "HealthKit is unavailable on this device. Try synthetic demo mode."; return }
        do {
            try await health.requestAuthorization(toShare: [], read: Set<HKObjectType>([sleep, rhr, hrv] + extras.compactMap { HKObjectType.quantityType(forIdentifier: $0.0) }))
            await refresh()
        } catch { message = "Health access request failed. You can review access in the Health app and retry." }
    }
    // FEATURE 05 — Read data and publish a new dashboard
    // A busy flag prevents overlapping refreshes. Demo mode regenerates fictional
    // rows instead of querying HealthKit. Live mode remembers the current request
    // number, reads 30 days of sleep/heart samples, and groups them into daily rows.
    // This only runs when the app asks to refresh; nothing monitors in the background.
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
            // FEATURE 06 — Convert Apple samples into the app's daily model
            // Sleep goes through HealthMath's one-source/night calculation. Heart readings
            // are grouped by their start date and averaged, not added. The newest relevant
            // sample timestamp accompanies each row so the UI can explain its freshness.
            let segments = sleepSamples.map { SleepSegment(start: $0.startDate, end: $0.endDate, stage: $0.value, source: $0.sourceRevision.source.name + " · " + $0.sourceRevision.source.bundleIdentifier) }
            let calendar = Calendar.current
            rows = days.map { day in
                let s = HealthMath.sleep(for: day, segments: segments)
                let heart = heartSamples.filter { calendar.isDate($0.startDate, inSameDayAs: day) }
                let variability = variabilitySamples.filter { calendar.isDate($0.startDate, inSameDayAs: day) }
                // FEATURE 07 — Keep empty heart days unknown
                // No samples returns nil. Otherwise take the arithmetic mean: add the values
                // and divide by the number of samples. This is descriptive, not a medical baseline.
                func mean(_ values: [HKQuantitySample], unit: HKUnit) -> Double? {
                    values.isEmpty ? nil : values.map { $0.quantity.doubleValue(for: unit) }.reduce(0,+) / Double(values.count)
                }
                return DailyHealth(date: day, sleepHours: s.hours, remPercent: s.rem,
                    restingHR: mean(heart, unit: HKUnit.count().unitDivided(by: .minute())),
                    hrv: mean(variability, unit: .secondUnit(with: .milli)),
                    measuredAt: ([s.timestamp].compactMap { $0 } + heart.map(\.endDate) + variability.map(\.endDate)).max(), sleepSource: s.source)
            }
            // FEATURE 08 — Read today's movement and breathing cards
            // Ask for each extra statistic separately. A failed extra read is omitted rather
            // than blocking all extras. Before publishing, check that the source choice is
            // still current; a late live response must not replace the new demo display.
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
        // FEATURE 09 — Handle failed refresh honestly
        // Discard this attempt's visible rows and timestamps and show a retry message.
        // If the user already switched sources, ignore the outdated failure too. An
        // empty successful result is described as unreadable/missing, not proven denial.
        } catch {
            guard generation == token else { return }
            rows = []; extraValues = [:]; extraSync = nil; lastSync = nil; message = "Sync failed. Unlock your iPhone, review Health access, and retry."
        }
    }
    // FEATURE 10 — Ask Apple for today's total or average
    // Restrict samples to those starting today, request the appropriate statistic
    // and convert it to the requested unit. Apple answers later via a callback;
    // withCheckedThrowingContinuation lets this function simply wait for that answer
    // without freezing the screen. Errors are passed back; no fallback value is made up.
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
    // FEATURE 11 — Retrieve dated records for the daily calculations
    // Ask HealthKit for this type from the requested start until now. Return its
    // samples or propagate its error. The caller decides how to group them; this
    // helper does not interpret stages, choose sources or change health records.
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
