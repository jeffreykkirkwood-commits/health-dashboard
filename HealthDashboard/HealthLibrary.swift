// PURPOSE: Let the user search supported health types, choose one, and read its recent on-device samples without bulk authorization.
// READING GUIDE: Follow the numbered FEATURE sections below; see docs/START-HERE.md for the whole app.

import SwiftUI
import HealthKit
import Charts

// FEATURE 01 — Describe one row in a metric's history
// Keep sample identity, times, display text and source. value is optional
// because a category such as a symptom need not be a numeric chart point.
struct HealthReading: Identifiable {
    let id: UUID
    let date: Date
    let end: Date
    let value: Double?
    let display: String
    let source: String
}

// FEATURE 02 — Hold the selected metric's reading state
// Published fields update the detail screen as reading begins, succeeds or
// fails. This reader has no upload or database-writing path.
@MainActor final class HealthLibraryReader: ObservableObject {
    @Published var readings: [HealthReading] = []
    @Published var busy = false
    @Published var message: String?
    @Published var unit = ""
    private let health = HKHealthStore()

    // Request only the selected type and show its newest 100 samples in 30 days.
    // These are individual observations, not daily aggregates. Unit compatibility
    // is checked before conversion; a failed or empty read is never fabricated data.
    // FEATURE 03 — Connect and read the selected metric
    // The user presses Connect & refresh. Avoid duplicate reads, clear previous
    // rows, then ask read permission for this one type. Choose the user's Health
    // unit for a quantity and refuse an incompatible unit instead of converting
    // incorrectly. Read at most 100 records from 30 days, newest first.
    func load(_ metric: HealthMetricDefinition) async {
        guard !busy, HKHealthStore.isHealthDataAvailable(), let type = metric.sampleType else { return }
        busy = true; readings = []; message = nil
        defer { busy = false }
        do {
            try await health.requestAuthorization(toShare: [], read: [type])
            var preferredUnit: HKUnit?
            if let quantityType = type as? HKQuantityType {
                preferredUnit = try await health.preferredUnits(for: [quantityType])[quantityType]
                guard let candidate = preferredUnit, quantityType.is(compatibleWith: candidate) else {
                    message = "This metric's display unit is unavailable. No values were converted."; return
                }
                unit = preferredUnit!.unitString
            }
            let from = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            let samples: [HKSample] = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(sampleType: type,
                    predicate: HKQuery.predicateForSamples(withStart: from, end: Date(), options: []),
                    limit: 100, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: samples ?? []) }
                }
                health.execute(query)
            }
            // FEATURE 04 — Turn raw samples into understandable rows
            // Quantities become unit-labelled numbers; fractions displayed as percentages
            // are multiplied by 100. Categories use known labels or retain the original
            // code. Workouts show minutes and activity. These are individual samples,
            // not daily totals; a single step sample may represent only part of a day.
            readings = samples.map { sample in
                var value: Double?; var display: String
                if let quantity = sample as? HKQuantitySample, let preferredUnit {
                    let raw = quantity.quantity.doubleValue(for: preferredUnit)
                    value = unit == "%" ? raw * 100 : raw
                    display = "\(value!.formatted(.number.precision(.fractionLength(0...2)))) \(unit)"
                } else if let category = sample as? HKCategorySample {
                    display = metric.categoryLabels[category.value] ?? "Recorded category code \(category.value)"
                } else if let workout = sample as? HKWorkout {
                    value = workout.duration / 60; unit = "min"
                    display = "\(workoutName(workout.workoutActivityType)) · \(Int(workout.duration / 60)) min"
                } else { display = "Recorded event" }
                return HealthReading(id: sample.uuid, date: sample.startDate, end: sample.endDate, value: value,
                                     display: display, source: sample.sourceRevision.source.name)
            }
            // FEATURE 05 — Explain absent or failed readings
            // No samples may mean missing data, restricted history or read access being
            // off; Apple hides read denial. A thrown error asks the user to unlock/check
            // access and retry. Neither case substitutes synthetic measurements.
            if readings.isEmpty { message = "No readable records in the last 30 days. Data may be missing, outside your allowed history, or access may be off. Apple does not disclose denied read permissions." }
        } catch {
            message = "Could not read this metric. Unlock your iPhone, check this app's access in Apple Health, and try again."
        }
    }
    // FEATURE 06 — Name common workouts without guessing others
    // Known activity codes receive friendly names. Unlisted types keep their
    // numeric code in the label instead of being misidentified as another sport.
    private func workoutName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .walking: return "Walking"
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength training"
        case .yoga: return "Yoga"
        case .hiking: return "Hiking"
        case .highIntensityIntervalTraining: return "HIIT"
        default: return "Workout (activity \(type.rawValue))"
        }
    }
}

// FEATURE 07 — Search the catalog before connecting data
// Search filters titles and group names already held in HealthCatalog. Group
// headings organize the matching definitions. Browsing these names does not
// read every metric; each detail owns the explicit Connect action.
struct HealthLibraryView: View {
    let demo: Bool
    @State private var search = ""
    private var metrics: [HealthMetricDefinition] {
        HealthCatalog.available.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.group.localizedCaseInsensitiveContains(search) }
    }
    private var groups: [String] { Set(metrics.map(\.group)).sorted() }
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your health, connected.").font(.title.bold())
                    Text("Explore \(HealthCatalog.available.count) supported data types. Open a metric to choose read access and see its recent records.").foregroundStyle(.secondary)
                    Label(demo ? "Demo mode · live reads paused" : "Read only · stays on your iPhone", systemImage: demo ? "sparkles" : "lock.shield")
                        .font(.caption).foregroundStyle(Palette.mint)
                }.padding(.vertical, 8)
            }.listRowBackground(Palette.card)
            Section("Coverage") {
                NavigationLink { coverage } label: { Label("What can this prototype read?", systemImage: "checklist") }
                Text("Permission is requested per metric. No bulk collection or health uploads.").font(.caption).foregroundStyle(.secondary)
            }.listRowBackground(Palette.card)
            ForEach(groups, id: \.self) { group in
                Section(group) {
                    ForEach(metrics.filter { $0.group == group }) { metric in
                        NavigationLink { HealthMetricDetail(metric: metric, demo: demo) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: metric.kind == "quantity" ? "waveform.path" : metric.kind == "workout" ? "figure.run" : "list.bullet.clipboard")
                                    .foregroundStyle(Palette.mint).frame(width: 24)
                                Text(metric.title)
                            }.padding(.vertical, 4)
                        }
                    }
                }.listRowBackground(Palette.card)
            }
            if metrics.isEmpty { ContentUnavailableView.search(text: search).listRowBackground(Palette.card) }
        }
        .scrollContentBackground(.hidden).background(Palette.background)
        .navigationTitle("Health Library").searchable(text: $search, prompt: "Search metrics or categories")
    }
    // FEATURE 08 — Explain what this release can and cannot read
    // The coverage page distinguishes supported sample types from specialized
    // records that need another reader. Catalog size is not the number of types
    // tested on a real device or the number of records the user has.
    private var coverage: some View {
        List {
            Section("Available now") {
                Text("All public quantity and category identifiers listed in the iOS 27.1 SDK, filtered for your iOS version, plus workouts.")
                Text("Includes activity, heart, sleep, body measurements, nutrition, respiratory health, mobility, hearing exposure, reproductive health, symptoms, and mindful sessions.")
                Text("Each detail shows the newest 100 records within 30 days, their timestamps, sources, and values in your preferred Health units. Category values retain their recorded meaning; unknown values keep their original code.")
            }
            Section("Not connected in this release") {
                Text("Clinical/FHIR records and clinical lab imports require separate Health Records capability, permissions, and an importer. The lab demonstration remains fictional.")
                Text("ECG waveforms, audiograms, vision prescriptions, medications, state-of-mind records, scored assessments, activity-ring summaries, profile characteristics, workout routes, and heartbeat series need specialized readers and screens. They are not included in the catalog count.")
            }
            Section("Understanding the data") {
                Text("Library charts plot individual samples, not daily totals. A step sample may cover only part of a day. The Today dashboard uses HealthKit statistics for activity totals.")
                Text("No readable records does not prove permission was denied. Apple protects that information. Availability depends on your devices, apps, permissions, and saved history.")
            }
        }.navigationTitle("Data coverage").navigationBarTitleDisplayMode(.inline)
    }
}

// FEATURE 09 — Display one chosen metric and its history
// In demo mode this screen explains that live reads are paused. Otherwise
// the user explicitly starts a read; the latest returned sample is highlighted,
// known numeric samples receive chart points and every row keeps its source.
// A sample history is not a diagnosis or a calculation of daily totals.
struct HealthMetricDetail: View {
    let metric: HealthMetricDefinition
    let demo: Bool
    @StateObject private var reader = HealthLibraryReader()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(metric.group.uppercased()).font(.caption.bold()).tracking(2).foregroundStyle(Palette.mint)
                Text(metric.title).font(.largeTitle.bold())
                if demo {
                    Label("Live reads are paused in demo mode", systemImage: "sparkles").foregroundStyle(Palette.mint)
                    Text("Turn off synthetic demo data in Settings to connect this metric. No real health readings are shown here.").foregroundStyle(.secondary)
                } else {
                    Button { Task { await reader.load(metric) } } label: {
                        Label(reader.busy ? "Reading…" : "Connect & refresh this metric", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                    }.buttonStyle(.borderedProminent).disabled(reader.busy)
                    if reader.busy { ProgressView() }
                    if let message = reader.message { Text(message).foregroundStyle(.secondary) }
                    if let latest = reader.readings.first {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("LATEST RECORDED SAMPLE").font(.caption.bold()).foregroundStyle(.secondary)
                            Text(latest.display).font(.largeTitle.bold()).foregroundStyle(Palette.mint)
                            Text(latest.date, format: .dateTime.month().day().hour().minute()).foregroundStyle(.secondary)
                        }.panel()
                    }
                    if reader.readings.contains(where: { $0.value != nil }) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent samples · \(reader.unit)").font(.headline)
                            Chart(reader.readings.reversed()) { reading in
                                if let value = reading.value {
                                    PointMark(x: .value("Date", reading.date), y: .value(reader.unit, value)).foregroundStyle(Palette.mint)
                                }
                            }.frame(height: 190)
                            Text("Individual readings, not daily totals. Newest 100 records within 30 days.").font(.caption).foregroundStyle(.secondary)
                        }.panel()
                    }
                    ForEach(reader.readings) { reading in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(reading.display).font(.headline)
                            Text(reading.date.formatted(date: .abbreviated, time: .shortened)).font(.subheadline)
                            Text("Source: \(reading.source)").font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading).panel()
                    }
                }
            }.padding(20)
        }.background(Palette.background).navigationBarTitleDisplayMode(.inline)
    }
}
