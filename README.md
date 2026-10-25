# Health Dashboard

Personal, iPhone-first SwiftUI and HealthKit prototype. Apple Watch supplies health data through HealthKit; no separate Watch app is planned. The repository now contains a SwiftUI iPhone prototype and an Xcode project. The iOS simulator build and 12 core tests pass with Xcode 27.1. Simulator interaction and real-device validation remain pending.

## Agreed scope

- Sleep, resting heart rate, and heart rate variability, with 7-day and 30-day trends.
- Show measurement timestamps and missing/stale data explicitly; missing data is not zero.
- Editable sleep goal, initially 8 hours.
- Editable REM range, initially 20–25% of total sleep. Below/above flags use the user's non-diagnostic threshold, not a medical target. Watch sleep stages are estimates.
- Optional local phone notifications after permission, with once-per-night intent, preferred morning time, and mute controls. Local notifications are separate from APNs.
- Foreground HealthKit sync first. Verify background observers/delivery on a real device later; instant background refresh is not guaranteed. Overnight alerts cannot be fully validated in a same-day setup session.
- No server or cloud health uploads. Never commit real health records, exports, credentials, or secrets. Future demo/test fixtures must be synthetic.

## Current prototype status — 2026-10-25

- Latest inspection: macOS **27.0.1 (26A434)**; Xcode **27.1 (27A9275)** is installed, selected, and usable. Earlier missing-Xcode and license messages below are historical. No software installation, agreement acceptance, account sign-in, or security change was performed by this agent.
- Existing origin: https://github.com/jeffreykkirkwood-commits/health-dashboard.git. Parent verified private repository ownership/access. No push performed in this implementation task.
- Open `HealthDashboard.xcodeproj` in full Xcode after installation. The shared HealthDashboard scheme targets iPhone / iOS 17+. Set your Personal Team in Signing & Capabilities and use a unique bundle identifier if required. No team ID or signing credentials are committed.
- Starts in clearly labeled synthetic demo mode. Turn demo off and use Connect Health & sync for read-only HealthKit access. Pull to refresh; foreground activation also refreshes. Data is held in memory; only preferences are saved locally.
- Sleep is assigned to noon-to-noon windows in the current timezone, clipped at boundaries, with overlapping intervals merged. Per night, staged sources are preferred, then the longest available sleep source. Source selection is shown; it may differ from Apple Health's prioritization. Only asleep values contribute; in-bed and awake do not. REM is unknown when no staged data exists.
- Heart metrics are arithmetic daily means of readable samples, not clinical baselines. Charts use bars so missing days are not interpolated. Daily details include measurement timestamps. Today's data older than 12 hours is labeled stale; historical measurements remain dated.
- REM flags use editable personal thresholds. Watch stages are estimates; no diagnosis, emergency detection, or guaranteed overnight monitoring.
- Notifications implement one generic daily morning review reminder and a separately labeled synthetic five-second test. Mute cancels pending reminders/tests. Reminder content contains no health values. Settings require Save to apply time/enable changes; mute applies immediately. These are **not yet data-triggered once-per-night alerts**.
- HealthKit capability is declared in the entitlement file and project. Background delivery is deliberately not enabled: verify signed entitlements, observer completion handling, protected-data behavior, and delivery on device before adding it. Exact delivery times cannot be guaranteed.
- No backend, analytics, paid service, dependency downloads, or cloud health upload code.

### Validation and next action

Project/entitlement syntax, scheme XML, source references, JSON fixture integrity, and whitespace checks passed. **All 12 XCTest cases pass** (six sleep/core and six biomarker tests). The entire app **builds successfully for arm64 iOS Simulator** using Xcode 27.1 and the iOS 27.1 simulator SDK, deployment target iOS 17, with code signing disabled. An initial restricted-sandbox attempt failed to communicate with compiler plugins; the authorized local build succeeded outside that sandbox.

Validation commands:

```sh
CLANG_MODULE_CACHE_PATH=/tmp/health-clang-27 SWIFTPM_MODULECACHE_OVERRIDE=/tmp/health-swift-27 swift test --scratch-path /tmp/health-tests-27 --cache-path /tmp/health-spm-27 --disable-sandbox
xcodebuild -project HealthDashboard.xcodeproj -scheme HealthDashboard -sdk iphonesimulator -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/health-dashboard-derived-27 CODE_SIGNING_ALLOWED=NO ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build
```

No physical-device installation, signed entitlement check, Health permission flow, real measurements, notification-delivery check, or overnight validation has occurred. **Next device step:** open `HealthDashboard.xcodeproj` in Xcode and select your Apple Account Personal Team in Signing & Capabilities; account sign-in, agreements and security/device prompts remain user actions. Coordinate with the parent task one action at a time.

After Xcode installation, build with `xcodebuild -project HealthDashboard.xcodeproj -scheme HealthDashboard -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build`, then test demo UI and denied/missing Health access before real data. Verify notification mute/rescheduling and locked-device behavior on the iPhone. Overnight behavior needs an overnight test.

## Historical setup inspection — 2026-10-25

- Apple silicon (arm64); macOS 15.1.1, build 24B91.
- Active developer directory: /Library/Developer/CommandLineTools. Full Xcode was not found in /Applications, the user's Applications folder, or Spotlight's Xcode bundle search. xcodebuild cannot run with this command-line-tools-only setup.
- Approximately 152 GiB available on the system volume at inspection; space must be rechecked before downloading Xcode and simulator runtimes.
- Apple's compatibility table lists Xcode 16.2 for macOS Sonoma 14.5 through Sequoia 15.x, with the iOS 18.2 SDK. Xcode 16.3 needs macOS 15.2; Xcode 16.4 needs macOS 15.3; Xcode 26 through 26.3 need macOS 15.6 or later within their listed ranges. Therefore Xcode 16.2 is the newest listed release compatible with the installed macOS 15.1.1. Device compatibility still needs verification against the actual iPhone/iOS version.
- Git 2.39.5 is available and an existing author identity is configured. GitHub CLI was not found on PATH or at the standard Homebrew locations. GitHub Desktop is installed; authenticated GitHub ownership has not been verified.
- No software installs/updates, agreements, account sign-ins, device pairing, or security changes performed.

## Cost and next step

The planned route is free direct device testing with an Xcode Personal Team and HealthKit; no paid membership or TestFlight is planned. Personal Team provisioning expires after seven days and requires rebuild/reinstall. Signing and HealthKit capability must still be verified during device setup.

The user reports iOS 27.0.1. See the current-status section for the next action. Installation today is not yet promised.

The existing private GitHub repository is configured as origin; pushing remains pending explicit authorization. A local folder/repo does not automatically register a Codex sidebar project; add this folder through the app's project UI if desired.

## Official references

- [Xcode system requirements](https://developer.apple.com/xcode/system-requirements)
- [Supported iOS capabilities](https://developer.apple.com/help/account/reference/supported-capabilities-ios/)
- [Developer account / Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account/)

## Synthetic biomarkers extension

In synthetic demo mode, choose **Explore synthetic biomarkers**. This isolated screen reads a bundled app-owned JSON fixture; no Labcorp account, provider API, real file import, or clinical HealthKit integration is enabled. Seven familiar biomarkers span three fictional draws, with source ranges/flags, missing results, a qualitative screen, comparator values, incompatible units, cancellation and amendment history. Original report versions are preserved. No medical recommendations or inferred flags are generated.

See [biomarker import research and contract](docs/BIOMARKER_IMPORT.md) and [synthetic JSON](HealthDashboard/Fixtures/biomarkers.synthetic.v1.json). The Swift domain model retains coded analytes, raw units and decimal text, qualitative/text/missing values, specimen/timestamps, provenance, source ranges, statuses, notes and revisions. It supports idempotent repeated demo imports and conservative trend selection. Six additional XCTest cases pass alongside the original six. The full simulator build passes; interactive UI and physical-device checks remain pending.

Latest setup: Xcode 27.1 is present, selected and usable. Earlier license/missing-toolchain messages were superseded by successful tests and an unsigned simulator build; this agent did not install software or accept agreements.
