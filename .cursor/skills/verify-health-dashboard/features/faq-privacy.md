# FAQ and privacy

The Privacy section states on-device, no-upload claims. The Questions section uses `<details>` disclosures for download status, Watch support, medical-score limits, coverage limits, and missing-data behavior.

## Sub-features

- `privacy-claims` shows the on-device / no-backend messaging.
- `faq-open` expands a disclosure and shows its answer text.

## How to get to it (user POV)

- Jump to `#privacy` or `#questions`.
- Choose a FAQ summary to expand or collapse it.

## Driving it with verify_site

Preconditions:

- Doctor is green.
- Evidence under `$EVIDENCE/faq-privacy/`.

- **Privacy copy.** Run `python3 .cursor/skills/verify-health-dashboard/scripts/verify_site.py http --run-id $RUN_ID --path / --out $EVIDENCE/faq-privacy/privacy-http --expect-status 200 --expect-contains "no health upload service" --expect-contains "PERSONAL BY DESIGN"`.
- **FAQ toggle.** Run `python3 .../verify_site.py browser --run-id $RUN_ID --path /#questions --toggle-faq "Is this a medical or recovery score?" --out $EVIDENCE/faq-privacy/faq --expect-title-contains "Health Dashboard"`. Screenshot shows the medical-score answer open.
- **Proof.** Body text and browser artifacts retain the privacy and FAQ wording.

## Gotchas

- The first FAQ item ships with `open` already set; toggling another item is a clearer mutation proof.
- Do not claim App Store availability — the FAQ states the opposite.
