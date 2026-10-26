# How this app works (Health Dashboard)

## What it does

Health Dashboard is a personal iPhone app that shows your Apple Health data in a calmer,
more focused way. The **Today** screen shows last night's sleep against your sleep goal,
your REM sleep share against a range you choose, today's steps/energy/exercise, and heart
and breathing readings. **Trends** shows the same numbers over 7 or 30 days. **Health
Library** lets you search ~200 Apple Health data types and read the recent history of any
one of them. **Settings** holds your goals, optional personal ranges, a daily reminder,
and a switch between **demo mode** (made-up data, the default) and **live mode** (your real
Apple Health data, read only on the phone). A separate demo screen shows fictional lab
results. Nothing is uploaded anywhere; there is no server.

## Main user flows

**1. First launch (demo mode)**
1. `App.swift` starts the app and builds `DashboardView`.
2. `DashboardStore` (`HealthStore.swift`) sees demo mode is on and fills 30 days of
   fictional rows from `HealthMath.demo()` (`HealthCore.swift`), with two days missing on
   purpose so the "no data" display can be seen.
3. The Today cards and Trends charts read those rows.

**2. Switch to live Apple Health data**
1. In Settings, turn off demo mode → `setDemo(false)` clears the screen.
2. Tap **Connect** → `connect()` asks iOS for *read-only* permission for sleep, heart and
   activity types.
3. `refresh()` reads 30 days of samples, then `HealthMath.sleep(...)` turns overlapping
   sleep records into one number per night (noon-to-noon, one source per night, overlaps
   counted once), heart readings are averaged per day, and today's totals are fetched.
4. Pull-to-refresh or reopening the app repeats step 3. If you switch back to demo mid-read,
   the late live result is thrown away (the "generation" counter).

**3. Compare against your goals** — Goals and ranges are saved on the phone. Cards label
values as below / within / above your range. These are your own targets, not medical advice.

**4. Explore the Health Library** (`HealthLibrary.swift`, `HealthCatalog.swift`)
1. Search the catalog of supported types (types too new for your iOS are hidden).
2. Open one → tap **Connect & refresh** → permission is asked for that one type only.
3. Up to 100 samples from the last 30 days are shown, newest first, with a chart for numbers.

**5. Daily reminder** (`Notifications.swift`) — Pick a time, tap Save; iOS shows a generic
morning reminder. Turning it off cancels it. "Test" shows one in 5 seconds. No health
data is in the reminder.

**6. Fictional lab results** (demo mode only; `Biomarkers.swift`, `BiomarkerDemoView.swift`)
— Loads `Fixtures/biomarkers.synthetic.v1.json`, rejects it unless every record is marked
synthetic and consistent, then shows a comparable glucose history and the original reports,
including corrected versions.

## Key files

| File | What it does |
| --- | --- |
| `HealthDashboard/App.swift` | App entry point and all main screens (Today, Trends, Settings). |
| `HealthDashboard/HealthStore.swift` | Reads Apple Health (or demo data) and hands rows to the screens. |
| `HealthDashboard/HealthCore.swift` | Pure sleep math and the demo data generator (tested on a Mac). |
| `HealthDashboard/HealthCatalog.swift` | The list of Apple Health types the library can show. |
| `HealthDashboard/HealthLibrary.swift` | Library search screen and one-metric history screen. |
| `HealthDashboard/Notifications.swift` | Daily reminder scheduling. |
| `HealthDashboard/Biomarkers.swift` | Data model and safety checks for the fictional lab file. |
| `HealthDashboard/BiomarkerDemoView.swift` | Screen that displays the fictional lab results. |
| `HealthDashboard/Fixtures/biomarkers.synthetic.v1.json` | The fictional lab data. |
| `HealthDashboard/HealthDashboard.entitlements` | Tells iOS this app uses HealthKit. |
| `HealthDashboard.xcodeproj/` | Xcode project (build settings, permission text shown to users). |
| `Package.swift` + `Tests/HealthCoreTests/` | Mac-runnable tests for the sleep math and lab rules. |
| `website/` | The separate promotional website (static HTML/CSS/JS). |

## Where data lives

- **Apple Health (HealthKit)** on the phone: the source of live readings. The app only reads.
- **On-device settings** (`UserDefaults` / `@AppStorage`): demo/live choice, sleep goal,
  REM range, heart-rate and HRV ranges, which cards to show, reminder on/off and time.
- **App bundle**: the fictional lab JSON file.
- **iOS notification scheduler**: the pending reminder.
- No databases, servers, external APIs, API keys or environment variables.

## Run it and test it

- **App**: needs a Mac with Xcode (the README says Xcode 27.1 / iOS 27.1 SDK). Open
  `HealthDashboard.xcodeproj`, pick the HealthDashboard scheme and your iPhone, set your
  Personal Team for signing, press Run. Live mode needs a real iPhone.
- **Tests** (on a Mac): `swift test` — runs the 12 sleep-math and lab-rule tests. They don't
  cover HealthKit reading or the screens.
- **Compile check without signing**: `xcodebuild -project HealthDashboard.xcodeproj -scheme HealthDashboard -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`
- **Website**: `python3 -m http.server 8000 --directory website`, then open http://localhost:8000.

## Glossary

- **HealthKit** — Apple's system for apps to read/write Apple Health data on the iPhone.
- **Sample** — one Apple Health record (e.g. one sleep stretch, one heart-rate reading).
- **Sleep stage** — Apple's estimate of core, deep or REM sleep within a night.
- **REM** — "rapid eye movement", one sleep stage; shown as a percentage of time asleep.
- **HRV** — heart rate variability, a measure of variation between heartbeats (in ms).
- **SwiftUI / View** — Apple's way of building screens; a *view* is one piece of screen.
- **Store** — an object that holds data the screens show and tells them when it changes.
- **`nil` / optional** — "unknown / no value", deliberately different from zero.
- **Demo / synthetic data** — made-up numbers, never from a person.
- **Fixture** — a prepared file of example data used by the app demo and tests.
- **Generation** — a counter used to ignore results from an older, outdated request.
- **Entitlement** — a permission flag built into the app (here: "uses HealthKit").
- **FHIR** — a standard format for medical records; the lab model is FHIR-*like*, not FHIR.
- **XCTest / `swift test`** — Apple's testing tool and the command that runs the tests.
