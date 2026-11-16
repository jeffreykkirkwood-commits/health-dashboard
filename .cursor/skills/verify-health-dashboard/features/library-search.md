# Library search

On the Library preview tab, visitors filter the sample metric list with the search box labeled `Search sample health metrics`. Matching rows stay; empty queries show all samples; non-matches show `No sample metrics match.`

## Sub-features

- `search-match` filters to metrics whose names contain the query.
- `search-empty` restores the full sample list when the query is cleared.
- `search-miss` shows the no-match message.

## How to get to it (user POV)

- Open `#explore`, choose `Library`, then type in the search field.
- Clear the field to reset.

## Driving it with verify_site

Preconditions:

- Doctor is green.
- Evidence under `$EVIDENCE/library-search/`.

- **Match Sleep.** Run `python3 .cursor/skills/verify-health-dashboard/scripts/verify_site.py browser --run-id $RUN_ID --path /#explore --click-tab Library --search Sleep --out $EVIDENCE/library-search/match --expect-tab Library --expect-preview-contains "Sleep duration"`. Preview lists Sleep duration.
- **Miss.** Run `python3 .../verify_site.py browser --run-id $RUN_ID --path /#explore --click-tab Library --search zzzz --out $EVIDENCE/library-search/miss --expect-preview-contains "No sample metrics match."`.
- **Proof.** `aria.txt` / `screenshot.png` / `summary.json` under each subfolder.

## Gotchas

- The searchbox exists only after Library is selected; the helper clicks Library when `--search` is set if needed.
- Matching is case-insensitive substring on the fixed sample list in `website/app.js`.
