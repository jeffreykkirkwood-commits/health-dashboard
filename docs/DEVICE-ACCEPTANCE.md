# Device acceptance checklist (0.2.0 / build 2)

Status: **not yet run.** This checklist turns the README's "Device acceptance after approval" paragraph into steps you can tick off on a real iPhone. Automated tests and CI cannot cover these: they need HealthKit permissions, real (personal) Health data and notification delivery on a device.

Use your own iPhone with the build installed from Xcode. Do not export or commit any real Health records; write only pass/fail and short notes below.

Run date: ____  ·  iPhone model / iOS: ____  ·  App commit: ____

| # | Area | Steps | Expected | Result | Notes |
| --- | --- | --- | --- | --- | --- |
| 1 | Health permissions | Today or Settings → **Connect / update Health access**; accept the expanded set. | System sheet lists the dashboard metrics; read only, no write. | ☐ | |
| 2 | Missing data | Look at a metric you have never recorded (e.g. blood oxygen without a capable Watch). | Card stays blank/unknown, not zero, and is not labeled "denied". | ☐ | |
| 3 | Added dashboard metrics | Compare steps, active energy, exercise minutes, respiratory rate and blood oxygen with Apple Health for today. | Values match Health's totals/averages within rounding. | ☐ | |
| 4 | Health Library | Search for one quantity type, one category type and Workouts; tap **Connect** in each detail screen. | Per-type permission prompt; newest samples (up to 100, 30 days) with dates, sources and units. | ☐ | |
| 5 | Sleep and REM targets | Settings → change sleep goal and REM band. | Ring, below/within/above labels and chart target lines update. | ☐ | |
| 6 | Personal vital ranges | Enable resting HR and HRV ranges; set bounds. | Indicators and chart lines appear only when enabled. | ☐ | |
| 7 | Trends | Switch 7 / 30 days. | Charts redraw; dated night label stays correct. | ☐ | |
| 8 | Relaunch and refresh | Force-quit, reopen; pull to refresh / return to foreground. | Demo/live mode and settings persist; values refresh. | ☐ | |
| 9 | Notifications | Save a reminder time; send the 5-second test; then mute. | Test arrives with no health values; mute cancels pending reminders immediately. | ☐ | |
| 10 | Larger text | Settings → Accessibility → Larger Text at a large size. | Cards and charts stay readable; nothing clipped off-screen. | ☐ | |

When all rows pass, update the "Historical validation" paragraph in the README with the run date and device, and change the status at the top of this file.
