# Static assets

The site is three static files with no build step. Visitors (and agents) must receive `index.html`, `style.css`, and `app.js` with HTTP 200 from the same origin.

## Sub-features

- `asset-html` serves `/` with brand markup.
- `asset-css` serves `/style.css`.
- `asset-js` serves `/app.js` with the preview tab logic.

## How to get to it (user POV)

- Load the site; the browser requests the three files automatically.
- Optional: `node --check website/app.js` for syntax (no server required).

## Driving it with verify_site

Preconditions:

- A launched instance for `$RUN_ID`.
- Evidence under `$EVIDENCE/static-assets/`.

- **HTML.** `python3 .cursor/skills/verify-health-dashboard/scripts/verify_site.py http --run-id $RUN_ID --path / --out $EVIDENCE/static-assets/html --expect-status 200 --expect-contains "Health Dashboard"`.
- **CSS.** `python3 .../verify_site.py http --run-id $RUN_ID --path /style.css --out $EVIDENCE/static-assets/css --expect-status 200`.
- **JS.** `python3 .../verify_site.py http --run-id $RUN_ID --path /app.js --out $EVIDENCE/static-assets/js --expect-status 200 --expect-contains "data-tab"`.
- **Proof.** Status files and bodies under each subfolder.

## Gotchas

- Doctor already covers these three GETs; this feature is for artifacted proof of each file.
- `node --check` is optional and does not replace an HTTP proof of the served file.
