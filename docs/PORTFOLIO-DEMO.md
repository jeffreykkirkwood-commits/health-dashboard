# Health Dashboard: technical walkthrough

Use synthetic mode for a portfolio presentation. Never project a personal Health Library or export real records for screenshots.

## Five-minute walkthrough

1. Open `HealthDashboard.xcodeproj` in Xcode, select the HealthDashboard scheme and an iPhone simulator, then Run. Start in demo mode; if settings persisted from another session, explicitly select demo before presenting.
2. On Today, explain sleep duration versus the editable sleep goal and REM percentage versus a personal range. Change the goal: the ring changes its comparison, not the underlying night.
3. Switch to Trends and compare 7 and 30 days. Point out missing fixture days: unknown is not a zero measurement.
4. Search the Health Library. Its 193 catalog definitions are an inventory, not evidence that all 193 types have been read. Live detail access is per metric, foreground and read-only. Do not authorize personal Health data during the portfolio demo.
5. Open the synthetic biomarker demonstration. Explain that the app-owned JSON fixture is not a clinical/FHIR importer.
6. Show notification settings and explain mute and generic daily reminders. Delivery is system-controlled; no background threshold monitor is implemented.

## Explain the data flow

`App.swift` owns presentation and persisted preferences. `DashboardStore` in `HealthStore.swift` requests HealthKit reads and publishes daily rows. `HealthCore.swift` merges overlapping sleep intervals within local noon-to-noon windows and selects one source per night, preferring staged sleep. REM is a proportion of asleep time; missing staging remains unknown. Daily heart/HRV means are descriptive sample means, not validated clinical baselines.

`HealthCatalog.swift` supplies availability-gated definitions; `HealthLibrary.swift` requests a selected type and reads at most 100 samples from 30 days with preferred units. The library's individual sample chart differs from dashboard cumulative activity statistics. `Biomarkers.swift` validates synthetic interchange records. `Notifications.swift` schedules generic local reminders without placing health values in notifications.

## Reproduce checks

```sh
swift test
xcodebuild -project HealthDashboard.xcodeproj -scheme HealthDashboard -destination 'generic/platform=iOS' -derivedDataPath /tmp/health-portfolio-build CODE_SIGNING_ALLOWED=NO build
```

Swift Package tests cover calculation and biomarker logic; they exclude SwiftUI, HealthKit and notifications. An unsigned build checks compilation only. Real-device permission handling, missing records, new catalog types, accessibility, relaunch and notification delivery need separate acceptance.

There is no web deployment, backend, upload pipeline or Watch app. Preferences persist in UserDefaults; live records remain in Apple Health. Reinstalling/resetting this app is not a way to erase Apple Health records. Demo mode replaces displayed data with fixtures, without changing HealthKit. No clinical interpretation, continuous monitoring or production medical claim is supported.
