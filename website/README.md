# Health Dashboard website

This folder is the single source of truth for the Health Dashboard promotional website. Make all website changes here in the health-dashboard GitHub repository.

## Files

- `index.html`: page content and illustrative phone preview.
- `style.css`: responsive layout, colors, and typography.
- `app.js`: Today/Trends/Library preview tabs and sample metric search.

No package installation or build step is required. Fonts load from Google Fonts, with local fallback fonts.

## Local preview

From the repository root:

```sh
python3 -m http.server 8000 --directory website
```

Open http://localhost:8000. Stop the server with Ctrl+C.

Optional JavaScript syntax check, if Node.js is installed:

```sh
node --check website/app.js
```

Check narrow and wide screens, preview tabs, library search, navigation links, and FAQ disclosures after editing.

## Publishing

Hosted site: https://health-dashboard-jeff-kirkwood.toastypin7.chatgpt.site

The site is currently owner-private. GitHub commits alone do not automatically deploy it.

When publishing with Sites:
1. Read the latest committed files from this folder.
2. Copy `index.html`, `style.css`, and `app.js` unchanged into the existing Site's static `dist/` directory.
3. Publish to existing Site project `appgprj_6adf94e2a53c819193a781fba9beb94f`, preserving its access settings.
4. Verify successful deployment.

Sites requires a separate internal publishing repository. Treat it only as generated deployment output: do not make independent source edits there. No second user-maintained repository is needed. Do not copy publishing credentials or checkout-local state into GitHub.

## Content constraints

The page introduces the iPhone prototype; it does not connect to HealthKit, collect health records, or offer an App Store download. All displayed health values are fictional illustrations. Keep claims aligned with the app's documented capabilities and limitations.
