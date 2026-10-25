# Health Dashboard

Personal, iPhone-first SwiftUI and HealthKit prototype. Apple Watch supplies health data through HealthKit; no separate Watch app is planned. The repository now contains a SwiftUI iPhone prototype and an Xcode project. iOS compilation and real-device validation are pending full Xcode installation.

## Agreed scope

- Sleep, resting heart rate, and heart rate variability, with 7-day and 30-day trends.
- Show measurement timestamps and missing/stale data explicitly; missing data is not zero.
- Editable sleep goal, initially 8 hours.
- Editable REM range, initially 20–25% of total sleep. Below/above flags use the user's non-diagnostic threshold, not a medical target. Watch sleep stages are estimates.
- Optional local phone notifications after permission, with once-per-night intent, preferred morning time, and mute controls. Local notifications are separate from APNs.
- Foreground HealthKit sync first. Verify background observers/delivery on a real device later; instant background refresh is not guaranteed. Overnight alerts cannot be fully validated in a same-day setup session.
- No server or cloud health uploads. Never commit real health records, exports, credentials, or secrets. Future demo/test fixtures must be synthetic.

## Current prototype status — 2026-10-25

- Re-inspection: macOS **27.0.1 (26A434)**, approximately **169 GiB free**. Full Xcode is still absent; command-line tools are selected. Earlier macOS findings below are historical.
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

Project/entitlement plist syntax, shared-scheme XML, source-file references, and git whitespace checks passed. Swift test execution was attempted but blocked before tests ran: the installed command-line toolchain reports a compiler/SDK version mismatch, duplicate SwiftBridging modules, and a PackageDescription manifest linker failure even with writable caches. A direct core compilation attempt was also blocked by the same toolchain. No executable tests passed yet. Six core XCTest cases cover interval overlap, missing data, REM thresholds, source selection, unstaged sleep, noon clipping, and synthetic gaps. Run `swift test` after installing a matching toolchain. iOS UI/HealthKit/notification type-checking, simulator launch, signing, and real-device tests remain pending full Xcode; no device validation is claimed.

**Next single user action:** approve/install the free official Xcode app. Current macOS meets the documented Xcode 27 requirement. Apple sign-in, agreements, device pairing, Developer Mode, and Health/notification permission prompts remain user steps. The phone OS version alone does not prove an older Xcode cannot pair; SDK and device-support columns differ.

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
