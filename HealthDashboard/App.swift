import SwiftUI
import Charts

@main struct HealthDashboardApp: App {
    var body: some Scene { WindowGroup { DashboardView().preferredColorScheme(.dark) } }
}

enum Palette {
    static let background = Color(red: 0.035, green: 0.055, blue: 0.075)
    static let card = Color(red: 0.075, green: 0.105, blue: 0.13)
    static let mint = Color(red: 0.69, green: 0.94, blue: 0.61)
    static let lavender = Color(red: 0.72, green: 0.68, blue: 1)
    static let coral = Color(red: 1, green: 0.62, blue: 0.48)
    static let blue = Color(red: 0.43, green: 0.77, blue: 1)
}
extension View {
    func panel() -> some View {
        padding(20).background(Palette.card, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.055), lineWidth: 1))
    }
}

struct DashboardView: View {
    @StateObject private var store = DashboardStore()
    @StateObject private var reminders = ReminderManager()
    @Environment(\.scenePhase) private var phase
    @AppStorage("sleepGoal") private var goal = 8.0
    @AppStorage("remLow") private var low = 20.0
    @AppStorage("remHigh") private var high = 25.0
    @AppStorage("rhrRangeEnabled") private var rhrRangeEnabled = false
    @AppStorage("rhrLow") private var rhrLow = 45.0
    @AppStorage("rhrHigh") private var rhrHigh = 75.0
    @AppStorage("hrvRangeEnabled") private var hrvRangeEnabled = false
    @AppStorage("hrvLow") private var hrvLow = 20.0
    @AppStorage("hrvHigh") private var hrvHigh = 80.0
    @AppStorage("showBreathing") private var showBreathing = true
    @AppStorage("showOxygen") private var showOxygen = true
    @AppStorage("remindersEnabled") private var enabled = false
    @AppStorage("morningHour") private var hour = 8
    @AppStorage("morningMinute") private var minute = 0
    @State private var range = 7
    @State private var settings = false
    private var visible: [DailyHealth] { Array(store.rows.suffix(range)) }
    private var today: DailyHealth? { store.rows.last }
    private var night: DailyHealth? { store.rows.last(where: { $0.sleepHours != nil }) }
    private var nightIsToday: Bool { night.map { Calendar.current.isDateInToday($0.date) } ?? false }

    var body: some View {
        TabView {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        connectionBanner
                        sleepHero
                        remCard
                        sectionTitle("YOUR VITALS", subtitle: "Today's available readings")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            vitalCard("Resting heart rate", value: today?.restingHR, unit: "bpm", icon: "heart.fill", color: Palette.coral,
                                      status: personalFlag(today?.restingHR, enabled: rhrRangeEnabled, lower: rhrLow, upper: rhrHigh),
                                      caption: rhrRangeEnabled ? "Your range \(Int(rhrLow))–\(Int(rhrHigh)) bpm" : "Daily mean · range off")
                            vitalCard("Heart rate variability", value: today?.hrv, unit: "ms", icon: "waveform.path.ecg", color: Palette.mint,
                                      status: personalFlag(today?.hrv, enabled: hrvRangeEnabled, lower: hrvLow, upper: hrvHigh),
                                      caption: hrvRangeEnabled ? "Your range \(Int(hrvLow))–\(Int(hrvHigh)) ms" : "SDNN daily mean · range off")
                            if showBreathing {
                                vitalCard("Respiratory rate", value: store.extraValues["HKQuantityTypeIdentifierRespiratoryRate"], unit: "/min", icon: "lungs.fill", color: Palette.blue, status: nil, caption: "Today's sample mean")
                            }
                            if showOxygen {
                                vitalCard("Blood oxygen", value: store.extraValues["HKQuantityTypeIdentifierOxygenSaturation"].map { $0 * 100 }, unit: "%", icon: "drop.fill", color: Palette.lavender, status: nil, caption: "Today's sample mean")
                            }
                        }
                        activityCard
                        NavigationLink { HealthLibraryView(demo: store.demo) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "square.grid.2x2.fill").font(.title2).foregroundStyle(Palette.mint)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Go beyond the dashboard").font(.headline)
                                    Text("Explore \(HealthCatalog.available.count) health data types").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(); Image(systemName: "arrow.up.right")
                            }.foregroundStyle(.white).panel()
                        }.buttonStyle(.plain)
                        Text("Indicators compare readings with your personal targets. They are not medical assessments. Watch sleep stages are estimates.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(20)
                }.background(Palette.background)
                    .refreshable { await store.refresh() }
                    .toolbar { settingsButton }
                    .navigationBarTitleDisplayMode(.inline)
            }.tabItem { Label("Today", systemImage: "circle.grid.2x2.fill") }
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        sectionTitle("YOUR TRENDS", subtitle: "The bigger picture")
                        Picker("Trend period", selection: $range) { Text("7 days").tag(7); Text("30 days").tag(30) }.pickerStyle(.segmented)
                        trend("Sleep duration", key: \.sleepHours, unit: "hours", color: Palette.lavender, lower: goal, upper: nil)
                        trend("REM share of sleep", key: \.remPercent, unit: "%", color: Palette.blue, lower: low, upper: high)
                        trend("Resting heart rate", key: \.restingHR, unit: "bpm", color: Palette.coral, lower: rhrRangeEnabled ? rhrLow : nil, upper: rhrRangeEnabled ? rhrHigh : nil)
                        trend("Heart rate variability", key: \.hrv, unit: "ms", color: Palette.mint, lower: hrvRangeEnabled ? hrvLow : nil, upper: hrvRangeEnabled ? hrvHigh : nil)
                        sectionTitle("DAILY RECORD", subtitle: "Sources and timestamps")
                        ForEach(visible.reversed()) { row in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(row.date, format: .dateTime.weekday().month().day()).font(.headline)
                                Text("Sleep \(value(row.sleepHours)) h  ·  REM \(value(row.remPercent))%")
                                Text("RHR \(value(row.restingHR)) bpm  ·  HRV \(value(row.hrv)) ms").font(.subheadline)
                                Text(row.measuredAt.map { "Latest sample \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "No readable measurements").font(.caption).foregroundStyle(.secondary)
                                if let source = row.sleepSource { Text("Sleep: \(source)").font(.caption2).foregroundStyle(.secondary) }
                            }.frame(maxWidth: .infinity, alignment: .leading).panel()
                        }
                        Text("Gaps stay empty. Sleep uses noon-to-noon windows and one source per night. Heart metrics are daily sample means and may differ from Apple Health.").font(.caption).foregroundStyle(.secondary)
                    }.padding(20)
                }.background(Palette.background).navigationTitle("Trends").toolbar { settingsButton }
                    .refreshable { await store.refresh() }
            }.tabItem { Label("Trends", systemImage: "chart.xyaxis.line") }
            NavigationStack { HealthLibraryView(demo: store.demo).toolbar { settingsButton } }
                .tabItem { Label("Health Library", systemImage: "square.stack.3d.up") }
        }
        .tint(Palette.mint)
        .sheet(isPresented: $settings) { settingsView }
        .task { store.setDemo(store.demo); if !store.demo { await store.refresh() } }
        .onChange(of: phase) { _, new in if new == .active { Task { await store.refresh() } } }
    }
    private var settingsButton: some View {
        Button { settings = true } label: { Image(systemName: "slider.horizontal.3").foregroundStyle(.white).padding(6) }
            .accessibilityLabel("Settings and targets")
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Date(), format: .dateTime.weekday(.wide).month().day()).font(.caption.bold()).textCase(.uppercase).tracking(2).foregroundStyle(.secondary)
                Spacer()
                Circle().fill(store.demo ? Palette.lavender : Palette.mint).frame(width: 6, height: 6)
                Text(store.demo ? "DEMO" : "APPLE HEALTH").font(.caption2.bold()).tracking(1).foregroundStyle(store.demo ? Palette.lavender : Palette.mint)
            }
            Text("Your daily rhythm.").font(.system(size: 34, weight: .bold, design: .rounded)).tracking(-1)
            Text("Rest. Move. Find your balance.").font(.subheadline).foregroundStyle(.secondary)
        }
    }
    private var connectionBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: store.demo ? "sparkles" : "lock.shield").foregroundStyle(Palette.mint)
                Text(store.demo ? "Fictional data · explore the experience" : "On-device · \(store.lastSync.map { "synced \($0.formatted(date: .omitted, time: .shortened))" } ?? "not synced yet")")
                    .font(.caption)
                Spacer()
                if store.busy { ProgressView() }
            }
            if !store.demo {
                Button("Connect / update Health access") { Task { await store.connect() } }.font(.caption.bold()).disabled(store.busy)
            }
            if let message = store.message { Text(message).font(.caption).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
    }
    private var sleepHero: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("SLEEP", systemImage: "moon.stars.fill").font(.caption.bold()).tracking(2).foregroundStyle(Palette.lavender)
                Spacer()
                Text(nightIsToday ? "LAST NIGHT" : "LATEST AVAILABLE NIGHT").font(.caption2.bold()).foregroundStyle(.secondary)
            }
            HStack(spacing: 24) {
                ZStack {
                    Circle().stroke(Palette.lavender.opacity(0.14), lineWidth: 11)
                    Circle().trim(from: 0, to: CGFloat(min(max((night?.sleepHours ?? 0) / max(goal, 1), 0), 1)))
                        .stroke(AngularGradient(colors: [Palette.lavender.opacity(0.5), Palette.lavender, .white], center: .center), style: StrokeStyle(lineWidth: 11, lineCap: .round)).rotationEffect(.degrees(-90))
                    VStack(spacing: 4) {
                        Text(night?.sleepHours.map { "\(Int($0 / max(goal, 1) * 100))%" } ?? "—").font(.system(size: 30, weight: .bold, design: .rounded)).minimumScaleFactor(0.7)
                        Text("OF GOAL").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.secondary)
                    }
                }.frame(width: 112, height: 112).accessibilityElement(children: .combine)
                VStack(alignment: .leading, spacing: 9) {
                    Text(duration(night?.sleepHours)).font(.system(size: 32, weight: .semibold, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
                    Text("Your goal · \(duration(goal))").font(.subheadline).foregroundStyle(.secondary)
                    badge(night?.sleepHours.map { $0 >= goal ? "Goal reached" : "\(duration(goal - $0)) below goal" } ?? "No sleep data", color: night?.sleepHours.map { $0 >= goal ? Palette.mint : Palette.coral } ?? .secondary)
                }
            }
            if let night {
                Text("Night ending \(night.date.formatted(.dateTime.month().day()))\(nightIsToday ? "" : " · not today's sleep")").font(.caption).foregroundStyle(.secondary)
            } else { Text("Sync Apple Health to see your latest recorded night.").font(.caption).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading).panel()
    }
    private var remCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Label("REM SLEEP", systemImage: "brain.head.profile").font(.caption.bold()).tracking(1.5).foregroundStyle(Palette.blue)
                Spacer()
                badge(HealthMath.remFlag(night?.remPercent, low: low, high: high), color: rangeColor(night?.remPercent, lower: low, upper: high))
            }
            HStack(alignment: .firstTextBaseline) {
                Text(night?.remPercent.map { "\(value($0))%" } ?? "—").font(.system(size: 42, weight: .semibold, design: .rounded))
                Text("of total sleep").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.06))
                    RoundedRectangle(cornerRadius: 4).fill(Palette.blue.opacity(0.45))
                        .frame(width: max(2, geometry.size.width * (high - low) / 100)).offset(x: geometry.size.width * low / 100)
                    if let rem = night?.remPercent {
                        Circle().fill(.white).frame(width: 12, height: 12)
                            .offset(x: min(max(0, geometry.size.width * rem / 100 - 6), geometry.size.width - 12))
                    }
                }
            }.frame(height: 10).accessibilityLabel("REM target \(Int(low)) to \(Int(high)) percent")
            HStack {
                Text("Your target · \(Int(low))–\(Int(high))%")
                Spacer()
                Text(duration(night.flatMap { row in row.remPercent.flatMap { rem in row.sleepHours.map { $0 * rem / 100 } } }))
            }.font(.caption).foregroundStyle(.secondary)
            Text("REM % = REM time ÷ total asleep time × 100.\(night?.remPercent == nil ? " Sleep-stage data is needed." : " Calculated for the night shown above.")")
                .font(.caption).foregroundStyle(.secondary)
            Button("Edit sleep & REM targets") { settings = true }.font(.caption.bold())
        }.panel()
    }
    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("TODAY'S MOVEMENT", subtitle: "Everyday activity")
            activityRow("Steps", icon: "figure.walk", value: store.extraValues["HKQuantityTypeIdentifierStepCount"], unit: "steps", color: Palette.mint)
            Divider().overlay(.white.opacity(0.06))
            activityRow("Active energy", icon: "flame.fill", value: store.extraValues["HKQuantityTypeIdentifierActiveEnergyBurned"], unit: "kcal", color: Palette.coral)
            activityRow("Exercise", icon: "figure.run", value: store.extraValues["HKQuantityTypeIdentifierAppleExerciseTime"], unit: "min", color: Palette.blue)
            Text("Today's HealthKit totals. Missing or unreadable records stay blank.").font(.caption).foregroundStyle(.secondary)
        }.panel()
    }
    private func activityRow(_ title: String, icon: String, value: Double?, unit: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 26)
            Text(title).font(.subheadline)
            Spacer()
            Text(value.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "—").font(.title3.bold()).monospacedDigit()
            Text(unit).font(.caption).foregroundStyle(.secondary)
        }
    }
    private func vitalCard(_ title: String, value number: Double?, unit: String, icon: String, color: Color, status: String?, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(title).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value(number)).font(.system(size: 29, weight: .semibold, design: .rounded)).minimumScaleFactor(0.6)
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }.lineLimit(1)
            if let status { badge(status, color: status == "Within your range" ? Palette.mint : status == "No data" ? .secondary : Palette.coral) }
            Text(caption).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading).panel()
    }
    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption.bold()).tracking(2).foregroundStyle(Palette.mint)
            Text(subtitle).font(.title2.bold())
        }
    }
    private func badge(_ text: String, color: Color) -> some View {
        Text(text).font(.system(size: 10, weight: .semibold)).foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 6).background(color.opacity(0.1), in: Capsule())
    }
    private func personalFlag(_ number: Double?, enabled: Bool, lower: Double, upper: Double) -> String? {
        guard enabled else { return nil }
        guard let number else { return "No data" }
        return number < lower ? "Below your range" : number > upper ? "Above your range" : "Within your range"
    }
    private func rangeColor(_ number: Double?, lower: Double, upper: Double) -> Color {
        guard let number else { return .secondary }
        return (lower...upper).contains(number) ? Palette.mint : Palette.coral
    }
    private func value(_ number: Double?) -> String { number.map { $0.formatted(.number.precision(.fractionLength(0...1))) } ?? "—" }
    private func duration(_ hours: Double?) -> String {
        guard let hours else { return "—" }
        let minutes = max(0, Int((hours * 60).rounded()))
        return "\(minutes / 60)h \(minutes % 60)m"
    }
    private func trend(_ title: String, key: KeyPath<DailyHealth, Double?>, unit: String, color: Color, lower: Double?, upper: Double?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }
            if visible.contains(where: { $0[keyPath: key] != nil }) {
                Chart {
                    ForEach(visible) { row in
                        if let number = row[keyPath: key] {
                            BarMark(x: .value("Day", row.date, unit: .day), y: .value(title, number)).foregroundStyle(color.gradient).cornerRadius(3)
                        }
                    }
                    if let lower { RuleMark(y: .value("Your target", lower)).foregroundStyle(.white.opacity(0.65)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4])) }
                    if let upper { RuleMark(y: .value("Your upper target", upper)).foregroundStyle(.white.opacity(0.65)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4])) }
                }.chartXScale(domain: (visible.first?.date ?? Date())...(Calendar.current.date(byAdding: .day, value: 1, to: visible.last?.date ?? Date())!)).frame(height: 170)
                if let lower { Text(upper.map { "Dashed lines: your range \(Int(lower))–\(Int($0)) \(unit)" } ?? "Dashed line: your goal \(value(lower)) \(unit)").font(.caption).foregroundStyle(.secondary) }
            } else { Text("No readable data for this period").foregroundStyle(.secondary).frame(height: 130) }
        }.panel()
    }
    private var settingsView: some View {
        NavigationStack {
            Form {
                Section("Data source") {
                    Toggle("Use synthetic demo data", isOn: Binding(get: { store.demo }, set: { store.setDemo($0) }))
                    Text(store.demo ? "All dashboard values are fictional." : "Health data is read on-device and stays on your iPhone.").font(.caption)
                    if !store.demo { Button("Connect / update dashboard Health access") { Task { await store.connect() } }.disabled(store.busy) }
                    if store.demo { NavigationLink("Explore synthetic biomarkers") { BiomarkerDemoView() } }
                }
                Section("Sleep & REM targets") {
                    Stepper("Sleep goal: \(duration(goal))", value: $goal, in: 1...16, step: 0.5)
                    Stepper("REM lower bound: \(Int(low))%", value: $low, in: 0...high, step: 1)
                    Stepper("REM upper bound: \(Int(high))%", value: $high, in: low...100, step: 1)
                    Text("The initial REM range is 20–25%. This is an editable personal target, not a medical recommendation.").font(.caption)
                }
                Section("Optional personal vital ranges") {
                    Toggle("Resting heart rate indicators", isOn: $rhrRangeEnabled)
                    if rhrRangeEnabled {
                        Stepper("Lower: \(Int(rhrLow)) bpm", value: $rhrLow, in: 1...rhrHigh)
                        Stepper("Upper: \(Int(rhrHigh)) bpm", value: $rhrHigh, in: rhrLow...220)
                    }
                    Toggle("HRV indicators", isOn: $hrvRangeEnabled)
                    if hrvRangeEnabled {
                        Stepper("Lower: \(Int(hrvLow)) ms", value: $hrvLow, in: 0...hrvHigh)
                        Stepper("Upper: \(Int(hrvHigh)) ms", value: $hrvHigh, in: hrvLow...500)
                    }
                    Text("These ranges start off. If enabled, replace the example bounds with your own targets. Indicators do not diagnose illness or provide recovery scores.").font(.caption)
                }
                Section("Customize your focus cards") {
                    Toggle("Show respiratory rate", isOn: $showBreathing)
                    Toggle("Show blood oxygen", isOn: $showOxygen)
                }
                Section("Local morning reminder") {
                    Toggle("Enable reminders (off = muted)", isOn: $enabled)
                        .onChange(of: enabled) { _, flag in if !flag { Task { await reminders.update(enabled: false, hour: hour, minute: minute) } } }
                    DatePicker("Morning time", selection: Binding(get: { Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())! }, set: { hour = Calendar.current.component(.hour, from: $0); minute = Calendar.current.component(.minute, from: $0) }), displayedComponents: .hourAndMinute)
                    Button("Save reminder & request permission") { Task { await reminders.update(enabled: enabled, hour: hour, minute: minute) } }
                    Button("Test demo notification in 5 seconds") { Task { await reminders.test(muted: !enabled) } }
                    Text(reminders.message).font(.caption)
                    Text("A daily reminder, not a threshold-triggered background alert. Your new threshold indicators appear when the app syncs; they do not monitor overnight.").font(.caption)
                }
            }.navigationTitle("Settings & targets").toolbar { Button("Done") { settings = false } }
        }.tint(Palette.mint).preferredColorScheme(.dark)
    }
}
