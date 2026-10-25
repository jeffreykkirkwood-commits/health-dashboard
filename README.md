# Health Dashboard

Personal, iPhone-first SwiftUI and HealthKit prototype. Apple Watch supplies health data through HealthKit; no separate Watch app is planned. This repository is at the initial setup/documentation milestone, with no app target or executable implementation yet.

## Agreed scope

- Sleep, resting heart rate, and heart rate variability, with 7-day and 30-day trends.
- Show measurement timestamps and missing/stale data explicitly; missing data is not zero.
- Editable sleep goal, initially 8 hours.
- Editable REM range, initially 20–25% of total sleep. Below/above flags use the user's non-diagnostic threshold, not a medical target. Watch sleep stages are estimates.
- Optional local phone notifications after permission, with once-per-night intent, preferred morning time, and mute controls. Local notifications are separate from APNs.
- Foreground HealthKit sync first. Verify background observers/delivery on a real device later; instant background refresh is not guaranteed. Overnight alerts cannot be fully validated in a same-day setup session.
- No server or cloud health uploads. Never commit real health records, exports, credentials, or secrets. Future demo/test fixtures must be synthetic.

## Setup inspection — 2026-10-25

- Apple silicon (arm64); macOS 15.1.1, build 24B91.
- Active developer directory: /Library/Developer/CommandLineTools. Full Xcode was not found in /Applications, the user's Applications folder, or Spotlight's Xcode bundle search. xcodebuild cannot run with this command-line-tools-only setup.
- Approximately 152 GiB available on the system volume at inspection; space must be rechecked before downloading Xcode and simulator runtimes.
- Apple's compatibility table lists Xcode 16.2 for macOS Sonoma 14.5 through Sequoia 15.x, with the iOS 18.2 SDK. Xcode 16.3 needs macOS 15.2; Xcode 16.4 needs macOS 15.3; Xcode 26 through 26.3 need macOS 15.6 or later within their listed ranges. Therefore Xcode 16.2 is the newest listed release compatible with the installed macOS 15.1.1. Device compatibility still needs verification against the actual iPhone/iOS version.
- Git 2.39.5 is available and an existing author identity is configured. GitHub CLI was not found on PATH or at the standard Homebrew locations. GitHub Desktop is installed; authenticated GitHub ownership has not been verified.
- No software installs/updates, agreements, account sign-ins, device pairing, or security changes performed.

## Cost and next step

The planned route is free direct device testing with an Xcode Personal Team and HealthKit; no paid membership or TestFlight is planned. Personal Team provisioning expires after seven days and requires rebuild/reinstall. Signing and HealthKit capability must still be verified during device setup.

Smallest next user step: report the iPhone's iOS version from Settings > General > About > iOS Version. Then choose the compatible Xcode path before requesting approval for an install or macOS update. Installation today is not yet promised.

Remote repository creation/push is pending confirmation of exact GitHub owner and privacy. Suggested repository name: health-dashboard, private. No remote is configured. A local folder/repo does not automatically register a Codex sidebar project; add this folder through the app's project UI if desired.

## Official references

- [Xcode system requirements](https://developer.apple.com/xcode/system-requirements)
- [Supported iOS capabilities](https://developer.apple.com/help/account/reference/supported-capabilities-ios/)
- [Developer account / Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account/)
