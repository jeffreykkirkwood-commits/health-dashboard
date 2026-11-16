---
name: verify-health-dashboard
description: "Drive the health-dashboard promotional website the way a visitor does — launch an isolated python3 http.server on website/, prove hero, preview tabs, library search, FAQ, and privacy. Use when verifying health-dashboard website UI or static assets."
---

# Verify health-dashboard

Project-local verification for Jeffrey's Health Dashboard repo. The **product** is an iPhone SwiftUI app (HealthKit); this Linux-friendly skill drives the **promotional website** in `website/` (static HTML/CSS/JS), which is the surface agents can launch and prove here. Core sleep math still lives under `swift test` on a Mac — that path is noted in Gotchas, not substituted by this skill.

Agents read this cold mid-task. Follow Launch → Doctor → Drive → Evidence → Cleanup. Never drive an instance you did not start.

## Launch

Each run picks a unique `RUN_ID` (e.g. `date +%s`-pid). State lives under `/tmp/health-dashboard-verify/$RUN_ID/` (override with `HEALTH_VERIFY_STATE_ROOT`). Evidence lives under a path **outside** that tree (recommended: `/tmp/health-dashboard-verify-artifacts/$RUN_ID/`) so cleanup cannot delete proofs.

```bash
RUN_ID="verify-$(date +%s)-$$"
HELPER=".cursor/skills/verify-health-dashboard/scripts/verify_site.py"
EVIDENCE="/tmp/health-dashboard-verify-artifacts/$RUN_ID"
mkdir -p "$EVIDENCE"
python3 "$HELPER" launch --run-id "$RUN_ID"
```

What launch does:

- Serves `website/` with `python3 -m http.server` bound to `127.0.0.1` on a free port (or `--port`).
- Waits until `GET /` returns HTML containing `Health Dashboard`.

Ready means doctor can fetch `/`, `/style.css`, and `/app.js` with HTTP 200. A listening socket alone is not enough.

Teardown: `python3 "$HELPER" cleanup --run-id "$RUN_ID"` (see Cleanup).

**Isolate:** each `RUN_ID` gets its own port and pid file. Do not share one instance across agents.

## Doctor

```bash
python3 "$HELPER" doctor --run-id "$RUN_ID"
```

Read-only. Passes only when: recorded pid is alive, `GET /` shows the brand and hero copy, and `/style.css` + `/app.js` return 200. Run doctor first whenever anything looks off.

## Drive

Helper entry points (literal invocations):

```bash
# HTTP asset / HTML checks
python3 "$HELPER" http --run-id "$RUN_ID" --path / \
  --out "$EVIDENCE/home-http" --expect-status 200 \
  --expect-contains 'Health Dashboard' --expect-contains 'Your health'

# Browser (Playwright Chromium)
python3 "$HELPER" browser --run-id "$RUN_ID" --path / \
  --out "$EVIDENCE/home" --expect-title-contains 'Health Dashboard'

python3 "$HELPER" browser --run-id "$RUN_ID" --path /#explore \
  --click-tab Trends --out "$EVIDENCE/trends-tab" \
  --expect-tab Trends --expect-preview-contains 'seven days'

python3 "$HELPER" browser --run-id "$RUN_ID" --path /#explore \
  --click-tab Library --search Sleep \
  --out "$EVIDENCE/library-search" --expect-tab Library \
  --expect-preview-contains 'Sleep duration'
```

Prefer ARIA roles from `website/index.html` / `website/app.js`: preview `role="tablist"` with tabs `Today` / `Trends` / `Library`, searchbox `Search sample health metrics`, FAQ `<details>`/`<summary>`, header brand `Health Dashboard`.

Use the feature map under `features/` for journey recipes. Drive the visitor path; do not invent test-only endpoints.

Requires Playwright + Chromium for browser drives (`pip install playwright && python3 -m playwright install chromium` if missing). HTTP-only proofs can skip browser when the feature file says so.

## Evidence

Proof standards:

- Exercise the real visitor path (page load + tab / search / FAQ), not only `GET /`.
- Capture the action and the resulting state (ARIA snapshot + screenshot with title containing `Health Dashboard` and header brand visible).
- For API/asset proofs, keep status, headers, and body; assert brand strings and fictional-preview disclaimers.
- Side effects: this site is static — no writes. Search filters the in-page sample list only.
- Mocks: none required. All preview values are fictional by design; never treat them as HealthKit data.

Artifacts for a run stay in `$EVIDENCE` (outside the state dir). Name subfolders by feature id (`preview-tabs/`, `library-search/`, `hero-nav/`).

## Cleanup

```bash
python3 "$HELPER" cleanup --run-id "$RUN_ID"
```

Sends SIGTERM (then SIGKILL if needed) **only** to the pid recorded for this `RUN_ID`. Removes that run's `meta.json`, `server.pid`, and `server.log`. Does **not** delete `$EVIDENCE` or anything under `/tmp/health-dashboard-verify-artifacts/`.

After cleanup, confirm evidence still exists at the path you named before teardown.

## Helpers

| Command | Purpose |
|---|---|
| `python3 .../verify_site.py launch --run-id ID` | Start isolated website server |
| `python3 .../verify_site.py doctor --run-id ID` | Read-only instance check |
| `python3 .../verify_site.py http --run-id ID --path PATH --out DIR` | GET with status/body capture |
| `python3 .../verify_site.py browser --run-id ID --out DIR [...]` | Playwright visitor drive |
| `python3 .../verify_site.py cleanup --run-id ID` | Stop only this run's pid |

Script path: `.cursor/skills/verify-health-dashboard/scripts/verify_site.py` (executable).

## Feature map

See [`features/README.md`](features/README.md). Keep the map honest with `/maintain-verification-skill` when routes or UI handles change.
