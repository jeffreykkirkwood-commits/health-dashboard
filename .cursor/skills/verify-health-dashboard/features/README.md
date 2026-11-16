# Health Dashboard website verification map

This directory is the maintained source for verifying the visitor-facing promotional website in `website/`. Read the index before driving the site, then use the matching feature file as the recipe.

The iPhone app (SwiftUI / HealthKit) is out of scope for these Linux drives. Mac-only `swift test` covers sleep math separately; do not report an iPhone journey as verified through this map.

## Baseline preconditions

- Launch the site with `python3 .cursor/skills/verify-health-dashboard/scripts/verify_site.py launch --run-id $RUN_ID`.
- State under `/tmp/health-dashboard-verify/$RUN_ID/`; evidence under `/tmp/health-dashboard-verify-artifacts/$RUN_ID/`.
- Run `doctor` and require HTTP 200 for `/`, `/style.css`, and `/app.js`, with brand text in `/`.
- Never drive an instance that was not started by this verification run.

## Driving conventions

- Start every recipe from the baseline home page unless its preconditions say otherwise.
- Prefer ARIA roles and accessible names (`tab`, `searchbox`, `link`) over CSS selectors.
- Treat every command as literal. Keep quoted names and flags unchanged.
- Run browser actions through `verify_site.py browser`.
- Run static checks through `verify_site.py http`.
- Cleanup removes the server process and scratch state, never proof artifacts.

## Proof and skip reporting

- Capture the visitor action and the resulting state, not only the final screen.
- UI proof includes an ARIA snapshot and a screenshot with the brand / page title visible.
- HTTP proof includes status, headers, and body text assertions.
- Record the feature ID and entry point used with every artifact.
- Report an unreachable path with the attempted command and the unmet precondition.
- Do not report a skipped entry point as verified through a different path.

## Feature entry contract

Each feature file starts with an H1 title and one paragraph describing the visitor-visible behavior. It then uses exactly four H2 sections in this order.

1. `Sub-features` lists short IDs with one line for each behavior.
2. `How to get to it (user POV)` lists every visitor entry point.
3. `Driving it with verify_site` starts with `Preconditions:` and uses labeled bullets that pair each visitor action with an exact command and observable result.
4. `Gotchas` lists traps that can waste or invalidate a verification run.

## Features

- [Hero and navigation](./hero-nav.md) covers brand, hero copy, and in-page nav links.
- [Preview tabs](./preview-tabs.md) covers Today / Trends / Library switcher and selected ARIA state.
- [Library search](./library-search.md) covers sample metric filtering in the Library preview.
- [FAQ and privacy](./faq-privacy.md) covers disclosures and the privacy section claims.
- [Static assets](./static-assets.md) covers HTML/CSS/JS delivery without a browser.
