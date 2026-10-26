# Start here: how Health Dashboard works

Health Dashboard is a personal iPhone app that shows Apple Health data, such as sleep, heart, activity and breathing,
in a calmer, more focused way. It only **reads** Apple Health, everything stays on the phone, and
there is no server. Setup and build steps are in the [README](../README.md). Every file is listed in
[CODE-COVERAGE](CODE-COVERAGE.md). You don't need to know Swift: read the numbered `FEATURE` comments
above each block.

## The rules the code protects

- **An empty result doesn't mean permission was denied.** Apple doesn't tell apps which read permissions
  were refused, so "no readable records" might mean missing data or access turned off.
- **Switching between demo and live clears the old data.** Rows, sync times and messages reset straight
  away, and a read still running from before the switch is ignored (`generation`).
- **Goals and ranges are personal preferences, not medical thresholds.** Colors and labels compare a reading
  with your own target. They are not health advice.

## Main flows (read the files in this order)

1. [App.swift](../HealthDashboard/App.swift) contains the launch, the Today cards, Trends (7 or 30 days) and
   Settings. Start with FEATURE 03–05 to see where your choices and the readings meet.
2. [HealthStore.swift](../HealthDashboard/HealthStore.swift) handles the demo/live switch, the **Connect**
   permission request (read-only), and the refresh that reads 30 days of sleep, resting heart rate and HRV
   plus today's steps, energy, exercise, breathing rate and oxygen. Refresh happens only on screen (pull to refresh or reopening the app),
   not in the background. Demo mode, which is the default, fills in fictional rows instead.
3. [HealthCore.swift](../HealthDashboard/HealthCore.swift) turns sleep records that overlap into one value
   per night. Each night runs noon to noon, uses one source, and counts overlaps only once. Missing days stay empty
   rather than showing zero. This file also generates the demo data.
4. [HealthCatalog.swift](../HealthDashboard/HealthCatalog.swift), then
   [HealthLibrary.swift](../HealthDashboard/HealthLibrary.swift): search about 190 Apple Health types, ask
   permission for one type at a time, and see up to 100 records from the last 30 days.
5. [Notifications.swift](../HealthDashboard/Notifications.swift): save, mute or test a daily reminder.
   The reminder is generic, contains no health data, and does not monitor your health.
6. [Biomarkers.swift](../HealthDashboard/Biomarkers.swift), then
   [BiomarkerDemoView.swift](../HealthDashboard/BiomarkerDemoView.swift) load the fictional lab file. It is shown
   in demo mode only, and the app refuses the file unless every record is marked synthetic. The screen shows the
   glucose history and any corrected reports. See also [BIOMARKER_IMPORT](BIOMARKER_IMPORT.md).
7. The [calculation tests](../Tests/HealthCoreTests/HealthCoreTests.swift) and
   [lab tests](../Tests/HealthCoreTests/BiomarkerTests.swift) describe each made-up scenario and the mistake it
   guards against.
8. `website/` is the separate promotional website (plain HTML, CSS and JS) and is not part of the app.

## Where data lives

- **Apple Health (HealthKit)** on the phone holds the live readings. The app never writes to it.
- **On-device settings** (`@AppStorage` / `UserDefaults`) store the demo/live choice, sleep goal, REM range,
  heart-rate and HRV ranges, which cards are shown, and the reminder's on/off setting and time.
- **App bundle**: `HealthDashboard/Fixtures/biomarkers.synthetic.v1.json` holds the fictional lab data.
- The app has no database, server, API keys or environment variables.

## Run and test

- App: on a Mac with Xcode, open `HealthDashboard.xcodeproj`, pick the HealthDashboard scheme and press Run.
  Live data needs a real iPhone. The README covers signing and SDK versions.
- Tests (on a Mac): `swift test` runs the 12 sleep-math and lab-rule tests. They don't cover reading
  from HealthKit or the screens.
- Website: `python3 -m http.server 8000 --directory website`.

## Words used in the code

- **View**: one piece of screen.
- **Store**: holds the readings the screens show.
- **Sample**: one Apple Health record.
- **`nil`**: unknown, which is not the same as zero.
- **REM**: a sleep stage, shown as a share of sleep time.
- **HRV**: heart rate variability.
- **Generation**: a counter used to ignore results from older requests.
- **Entitlement**: an app permission flag, here "uses HealthKit".
- **FHIR-like**: shaped like a medical-records standard, but not actual FHIR.

## Known gaps between docs and code (2026-10-26)

- The `#L` line links in CODE-COVERAGE.md are now a few lines off, because comments were
  cleaned up. The FEATURE titles they point to still exist.
- CODE-COVERAGE.md doesn't list the `website/` files (README.md, app.js, index.html, style.css).
