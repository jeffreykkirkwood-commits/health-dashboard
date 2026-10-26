# Health Dashboard

A personal, iPhone-first SwiftUI app that reads Apple Health data on-device. Apple Watch is a data source through HealthKit; there is no separate Watch app, backend, analytics, or health upload service.

The **0.2.0 / build 2** redesign is present on `main` (baseline `4d8714e`). It includes Today, Trends and Health Library. Repository availability does not establish which version is installed on a device; expanded permissions and live readings still require device acceptance. Start with the [synthetic portfolio walkthrough](docs/PORTFOLIO-DEMO.md).

## What changed in 0.2.0

- Dark Today, Trends, and Health Library tabs, stronger visual hierarchy, colored cards, and a sleep-goal ring. The ring represents completion of the user's hours goal, not a sleep quality or recovery score.
- Visible sleep duration versus editable goal (initially 8 hours); REM percentage, calculated REM duration, editable target band (initially 20–25%), and below/within/above indicators. The displayed night is dated; fallback to an older night is labeled.
- Optional resting-heart-rate and HRV personal range indicators. They start disabled; example bounds are not medical recommendations. Chart target lines show enabled personal ranges and the sleep/REM targets.
- Added steps, active energy, exercise minutes, respiratory rate, and blood oxygen. Activity uses today's cumulative HealthKit statistics; respiration and oxygen use today's sample means. Missing/unreadable values stay blank.
- Demo/live mode and personal settings persist across launches. Demo fixtures remain fictional.
- Searchable Health Library with **193 entries: 121 quantity types, 71 category types, and workouts** from the public iOS 27.1 SDK. Availability is filtered by OS version, using Apple's actual identifier constants. Categories include activity, body measurements, heart, hearing exposure, nutrition, sleep, respiratory health, mobility, symptoms, reproductive health, and mindful sessions.

## Apple Health access and coverage

Use **Connect / update Health access** on Today or in Settings to authorize the dashboard's expanded metric set. The Health Library requests read permission for a selected metric only when the user taps Connect in its detail screen. No write permission is requested.

Library details show the newest 100 samples within 30 days, their dates, sources, preferred units, and individual-sample charts. These charts are not daily totals; a step sample may cover only part of a day. Category values use SDK labels when available; unknown values retain their original code. Percent quantities are displayed on the 0–100 scale.

**This release does not read every record Apple Health can hold.** Clinical/FHIR records and clinical lab imports require a dedicated capability, permissions, and importer. ECG waveforms, audiograms, vision prescriptions, medications, state of mind, scored assessments, activity-ring summaries, profile characteristics, workout routes, and heartbeat series require specialized readers/screens. These are excluded from the catalog count, and the same limits appear in the app's Data coverage screen. The biomarker demo remains synthetic.

HealthKit does not reveal whether read access was denied. Empty results may mean no saved data, missing permission, limited allowed history, or no samples in the selected period. The app does not label empty results as proven denial.

## Calculation and notification behavior

- Sleep is grouped into local noon-to-noon windows. Overlapping intervals are merged, and one source is selected per night, preferring staged data. This may differ from Apple Health's prioritization. In-bed and awake time do not count as asleep.
- REM share is REM time divided by total asleep time. Missing stage data remains unknown; it is not zero. Displayed REM duration is derived from total sleep and that share. Watch sleep stages are estimates.
- Resting heart rate and HRV are daily arithmetic sample means, not clinical baselines. User-defined indicators are comparisons with personal targets, not diagnoses or validated recovery scores.
- Notifications remain one generic daily morning review reminder and a synthetic five-second test. Mute cancels pending reminders/tests. Reminder content contains no health values. Changing schedule/enabling requires Save; mute applies immediately.
- Threshold indicators are visual only. Data-triggered overnight alerts and background HealthKit delivery are not implemented. Exact-time monitoring is not promised.

## Repository map

| Path | Responsibility |
| --- | --- |
| `HealthDashboard/App.swift` | Dashboard, trends, target controls, and settings |
| `HealthDashboard/HealthStore.swift` | Dashboard permissions, foreground reads, daily summaries |
| `HealthDashboard/HealthCore.swift` | Sleep aggregation, daily models, synthetic dashboard data |
| `HealthDashboard/HealthCatalog.swift` | OS-aware public quantity/category/workout inventory |
| `HealthDashboard/HealthLibrary.swift` | Search, per-metric permissions, records, sample charts, coverage |
| `HealthDashboard/Notifications.swift` | Local reminders and mute |
| `HealthDashboard/Biomarkers.swift` | App-owned synthetic lab interchange and validation |
| `HealthDashboard/BiomarkerDemoView.swift` | Fictional lab-results demonstration |
| `Tests/HealthCoreTests/` | Calculation and biomarker tests |
| `docs/BIOMARKER_IMPORT.md` | Lab import contract and limitations |

## Build and validation

The catalog was authored against the iOS 27.1 SDK; use Xcode 27.1 or a compatible newer SDK to compile it. Open `HealthDashboard.xcodeproj`, choose the HealthDashboard scheme and iPhone, and select the user's Personal Team for signing. The target supports iOS 17+; newer catalog types are gated by availability. No signing credentials or real health data belong in Git.

For core tests: `swift test`. For an unsigned compile: `xcodebuild -project HealthDashboard.xcodeproj -scheme HealthDashboard -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`.

Historical validation of the redesign (not a guarantee of a new checkout): all 12 existing automated calculation/biomarker tests pass; iPhone and simulator builds succeeded; a signed iPhone build was prepared; the synthetic Today screen was visually inspected in a simulator. Plist syntax and Git whitespace checks pass. New live Health categories, full interaction/accessibility checks, and the updated iPhone installation are pending. Existing tests do not cover the new HealthKit integration or all UI behavior.

Device acceptance after approval: update Health permissions; check actual data/missing-data behavior for added dashboard metrics; connect representative quantity/category/workout records from the library; edit sleep and REM bounds and verify indicators/chart lines; enable and set personal vital ranges; exercise 7/30-day switching, app relaunch, refresh, notification mute/rescheduling, and larger text. No real records should be exported for testing.

## Design research

- [WHOOP app navigation and dashboard](https://support.whoop.com/s/article/Navigating-the-WHOOP-Mobile-App?language=en_US): prominent primary metrics and deeper metric exploration.
- [Oura Today, Vitals, and My Health](https://support.ouraring.com/hc/en-us/articles/42987005571859-How-to-Use-the-Oura-App): daily focus separated from deeper trends.
- [Garmin focus and glance cards](https://support.garmin.com/en-AU/?faq=35qboQSvKC2WpKkTaDaRP7): layered cards and personal focus controls.

This app uses its own layout and native shapes, without copied brand artwork or proprietary scoring algorithms.

## Apple references

- [Per-type authorization and read privacy](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
- [Quantity aggregation](https://developer.apple.com/documentation/healthkit/hkquantityaggregationstyle)
- [Preferred units](https://developer.apple.com/documentation/healthkit/hkhealthstore/preferredunits(for:completion:))
- [Clinical records](https://developer.apple.com/documentation/healthkit/accessing-health-records)
- [Xcode requirements](https://developer.apple.com/xcode/system-requirements)
- [Account and signing limits](https://developer.apple.com/help/account/basics/about-your-developer-account/)
