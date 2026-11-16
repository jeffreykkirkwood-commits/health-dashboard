# Preview tabs

Visitors switch the interactive product preview among Today, Trends, and Library. Each tab updates the `#preview` panel and marks the chosen tab `aria-selected="true"`.

## Sub-features

- `tab-today` shows the default Today sample snapshot.
- `tab-trends` shows the fictional seven-day sleep chart copy.
- `tab-library` shows the Health Library preview shell.
- `tab-keyboard` moves selection with ArrowLeft / ArrowRight / Home / End.

## How to get to it (user POV)

- Scroll or jump to `#explore`.
- Choose the `Today`, `Trends`, or `Library` tab buttons in the preview switcher.
- Use arrow keys while a tab is focused.

## Driving it with verify_site

Preconditions:

- Doctor is green.
- Evidence under `$EVIDENCE/preview-tabs/`.

- **Default Today.** Run `python3 .cursor/skills/verify-health-dashboard/scripts/verify_site.py browser --run-id $RUN_ID --path /#explore --out $EVIDENCE/preview-tabs/today --expect-tab Today --expect-preview-contains "7h 24m"`. Selected tab is Today; preview shows sleep duration sample.
- **Switch Trends.** Run `python3 .../verify_site.py browser --run-id $RUN_ID --path /#explore --click-tab Trends --out $EVIDENCE/preview-tabs/trends --expect-tab Trends --expect-preview-contains "seven days"`. Selected tab is Trends; preview mentions the seven-day illustration.
- **Switch Library.** Run `python3 .../verify_site.py browser --run-id $RUN_ID --path /#explore --click-tab Library --out $EVIDENCE/preview-tabs/library --expect-tab Library --expect-preview-contains "sample metrics"`. Selected tab is Library.
- **Proof.** Screenshots and `summary.json` record the selected tab and preview excerpt for each drive.

## Gotchas

- Tab accessible names are the button text (`Today`, `Trends`, `Library`), not the `data-tab` values alone.
- Preview values are fictional; assert the disclaimer copy when the journey mentions HealthKit.
- Keyboard navigation is not wrapped by the helper yet — prove it with Playwright `keyboard.press` in an ad-hoc drive if needed, and record that entry point separately.
