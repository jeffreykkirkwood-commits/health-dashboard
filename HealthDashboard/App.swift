import SwiftUI
import Charts

@main struct HealthDashboardApp: App {
    var body: some Scene { WindowGroup { DashboardView() } }
}
struct DashboardView: View {
    @StateObject private var store = DashboardStore()
    @StateObject private var reminders = ReminderManager()
    @Environment(\.scenePhase) private var phase
    @AppStorage("sleepGoal") private var goal = 8.0
    @AppStorage("remLow") private var low = 20.0
    @AppStorage("remHigh") private var high = 25.0
    @AppStorage("remindersEnabled") private var enabled = false
    @AppStorage("morningHour") private var hour = 8
    @AppStorage("morningMinute") private var minute = 0
    @State private var range = 7
    @State private var settings = false
    private var visible: [DailyHealth] { Array(store.rows.suffix(range)) }
    private var latest: DailyHealth? { store.rows.last }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Label(store.demo ? "SYNTHETIC DEMO" : "ON-DEVICE HEALTH", systemImage: store.demo ? "sparkles" : "heart.fill")
                            .font(.caption.bold()).foregroundStyle(.teal)
                        Spacer()
                        if store.busy { ProgressView() }
                    }
                    Text("Your daily rhythm").font(.largeTitle.bold())
                    Text("A personal view of rest and recovery. Watch sleep stages are estimates.")
                        .foregroundStyle(.secondary)
                    Toggle("Use synthetic demo data", isOn: Binding(get: { store.demo }, set: { store.setDemo($0) }))
                    if !store.demo {
                        Button("Connect Health & sync") { Task { await store.connect() } }.buttonStyle(.borderedProminent).disabled(store.busy)
                    }
                    if let message = store.message { Text(message).font(.callout).foregroundStyle(.secondary) }
                    Text(store.demo ? "Demo values only — no Health records accessed." : "Last successful sync: \(store.lastSync?.formatted(date: .abbreviated, time: .shortened) ?? "Not yet")")
                        .font(.caption).foregroundStyle(.secondary)
                    if let measured = latest?.measuredAt {
                        Text("Latest measurement today: \(measured.formatted(date: .abbreviated, time: .shortened))").font(.caption)
                        if Date().timeIntervalSince(measured) > 12 * 3600 { Text("Today's data is over 12 hours old.").font(.caption).foregroundStyle(.orange) }
                    } else { Text("No measurements for today. Earlier days may still have data.").font(.caption) }
                    HStack(alignment: .top) {
                        metric("Sleep", latest?.sleepHours, unit: "h", detail: "Goal \(goal.formatted()) h")
                        metric("REM", latest?.remPercent, unit: "%", detail: HealthMath.remFlag(latest?.remPercent, low: low, high: high))
                    }
                    HStack(alignment: .top) {
                        metric("Resting HR", latest?.restingHR, unit: "bpm", detail: "Daily sample mean")
                        metric("HRV", latest?.hrv, unit: "ms", detail: "SDNN · daily mean")
                    }
                    Text("REM flags reflect your chosen range (\(Int(low))–\(Int(high))%), not a diagnosis or medical recommendation.").font(.caption).foregroundStyle(.secondary)
                    Picker("Trend period", selection: $range) { Text("7 days").tag(7); Text("30 days").tag(30) }.pickerStyle(.segmented)
                    trend("Sleep hours", key: \.sleepHours, color: .indigo)
                    trend("Resting heart rate · bpm", key: \.restingHR, color: .pink)
                    trend("HRV · milliseconds", key: \.hrv, color: .teal)
                    Text("Daily detail").font(.title2.bold())
                    ForEach(visible.reversed()) { row in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(row.date, format: .dateTime.month().day()).font(.headline)
                            Text("Sleep \(value(row.sleepHours)) h · REM \(value(row.remPercent))% · RHR \(value(row.restingHR)) bpm · HRV \(value(row.hrv)) ms").font(.caption)
                            Text(row.measuredAt.map { "Measured \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "No readable measurements").font(.caption).foregroundStyle(.secondary)
                            if let source = row.sleepSource { Text("Sleep source: \(source)").font(.caption2).foregroundStyle(.secondary) }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
                    }
                    Text("Missing values remain blank. Sleep uses noon-to-noon windows and one source per night, preferring staged data. Heart metrics average available samples and may differ from Apple Health. No cloud upload or safety monitoring.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding()
            }
            .navigationTitle("Health Dashboard").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Settings", systemImage: "slider.horizontal.3") { settings = true } }
            .refreshable { await store.refresh() }
            .task { store.setDemo(true) }
            .onChange(of: phase) { _, new in if new == .active { Task { await store.refresh() } } }
            .sheet(isPresented: $settings) { settingsView }
        }.tint(.teal)
    }
    private func value(_ number: Double?) -> String { number.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—" }
    private func metric(_ title: String, _ number: Double?, unit: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text("\(value(number)) \(unit)").font(.title2.bold()).minimumScaleFactor(0.65).lineLimit(1)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, minHeight: 110, alignment: .leading).padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 20))
    }
    private func trend(_ title: String, key: KeyPath<DailyHealth, Double?>, color: Color) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.headline)
            if visible.contains(where: { $0[keyPath: key] != nil }) {
                Chart(visible) { row in
                    if let number = row[keyPath: key] { BarMark(x: .value("Day", row.date, unit: .day), y: .value(title, number)).foregroundStyle(color) }
                }.chartXScale(domain: (visible.first?.date ?? Date())...(Calendar.current.date(byAdding: .day, value: 1, to: visible.last?.date ?? Date())!)).frame(height: 150)
            } else { Text("No readable data for this period").foregroundStyle(.secondary).frame(height: 100) }
        }.accessibilityElement(children: .contain)
    }
    private var settingsView: some View {
        NavigationStack {
            Form {
                Section("Your preferences") {
                    Stepper("Sleep goal: \(goal.formatted()) hours", value: $goal, in: 1...16, step: 0.5)
                    Stepper("REM lower bound: \(Int(low))%", value: $low, in: 0...high, step: 1)
                    Stepper("REM upper bound: \(Int(high))%", value: $high, in: low...100, step: 1)
                    Text("These are personal, non-diagnostic thresholds. Sleep stages are Watch estimates.").font(.caption)
                }
                Section("Local morning reminder") {
                    Toggle("Enable reminders (off = muted)", isOn: $enabled)
                        .onChange(of: enabled) { _, flag in if !flag { Task { await reminders.update(enabled: false, hour: hour, minute: minute) } } }
                    DatePicker("Morning time", selection: Binding(get: { Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())! }, set: { hour = Calendar.current.component(.hour, from: $0); minute = Calendar.current.component(.minute, from: $0) }), displayedComponents: .hourAndMinute)
                    Button("Save reminder & request permission") { Task { await reminders.update(enabled: enabled, hour: hour, minute: minute) } }
                    Button("Test demo notification in 5 seconds") { Task { await reminders.test(muted: !enabled) } }
                    Text(reminders.message).font(.caption)
                    Text("One daily review reminder, not a threshold-triggered overnight alert. Foreground sync is required. Background HealthKit delivery is deferred until entitlement and device testing.").font(.caption)
                }
            }.navigationTitle("Settings").toolbar { Button("Done") { settings = false } }
        }
    }
}
