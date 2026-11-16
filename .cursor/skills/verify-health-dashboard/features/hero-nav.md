# Hero and navigation

The first screen introduces Health Dashboard with brand, headline, supporting copy, and in-page links to Experience, Privacy, Questions, and Explore.

## Sub-features

- `hero-brand` shows the header brand `Health Dashboard`.
- `hero-copy` shows the headline `Your health.` / `In perspective.`
- `nav-links` jumps to `#experience`, `#privacy`, `#questions`, and `#explore`.

## How to get to it (user POV)

- Open the site root `/`.
- Choose header links `Experience`, `Privacy`, or `Questions`.
- Choose `Explore the app` or `Take a closer look` to reach `#explore`.

## Driving it with verify_site

Preconditions:

- Doctor reports the expected base URL and healthy `/`.
- Evidence directory exists under `/tmp/health-dashboard-verify-artifacts/$RUN_ID/hero-nav/`.

- **Load home.** Open `/`. Run `python3 .cursor/skills/verify-health-dashboard/scripts/verify_site.py browser --run-id $RUN_ID --path / --out $EVIDENCE/hero-nav --expect-title-contains "Health Dashboard"`. The ARIA snapshot and screenshot show header brand `Health Dashboard` and hero copy.
- **HTTP brand check.** Run `python3 .../verify_site.py http --run-id $RUN_ID --path / --out $EVIDENCE/hero-nav/http --expect-status 200 --expect-contains "Health Dashboard" --expect-contains "Your health"`. Body includes the brand and headline.
- **Proof.** Artifacts under `$EVIDENCE/hero-nav/` show title containing `Health Dashboard` and brand text.

## Gotchas

- Google Fonts may fail offline; layout still proves with local fallback fonts — do not fail the journey for missing remote fonts.
- The hero phone preview is static illustration, not the interactive `#explore` panel.
