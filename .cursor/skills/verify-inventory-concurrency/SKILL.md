---
name: verify-inventory-concurrency
description: "Formally check health-dashboard Inventory updated workflow concurrency so issue_comment runs are never cancelled (#239). Use when changing .github/workflows/inventory-updated.yml concurrency, cancel-in-progress, or inventory gate grouping."
---

# Verify inventory concurrency

## Property (plain words)

**Promise:** An Inventory updated `issue_comment` run is never cancelled by a later run — each comment run keeps its own concurrency group, and `cancel-in-progress` is true only for `pull_request` events.

**Harm if broken:** Comment runs are filed against `main`'s newest commit; a cancelled comment check stays red there and can block Render "deploy after checks pass" (#239).

## Tool and why

**TLA+ / TLC** over a small model of the workflow concurrency expressions. Ordering of overlapping PR syncs and comment events is the question; a model checker fits better than tests that only sample a few event pairs (those live in `tests/test_inventory_concurrency.py`). Bounds: 2 PR numbers, 4 run ids.

Read every TLC result with `/statechart` so invariant breaks show as shortest paths in plain words. Do not copy statechart CLI flags from memory — use that skill’s current command.

## Coverage (keep in sync)

| Model name | Code |
|---|---|
| `GroupToken` / `SafeGrouping` | `concurrency.group` in `.github/workflows/inventory-updated.yml` |
| `CancelsOthers` | `concurrency.cancel-in-progress` |
| `Start` victims | GitHub cancelling in-progress jobs that share the group |
| `Inv_CommentNeverCancelled` | #239 promise: comment runs never enter the cancelled set |

Files: `.github/workflows/inventory-updated.yml` (top-level `concurrency:`), mirrored by `tests/test_inventory_concurrency.py`.

**Last sync commit:** `0573870cfa69829e5a0eb83d247f27f55546b405` (confirm before trusting after later edits). Move this forward only after you confirm the model still describes those expressions.

## When to run

Run before merging any change that touches the rows above, or when `/maintain-formal-verification-skill` says this check is stale.

## How to run

Needs Java 11+ and `tla2tools.jar` (TLC). One-time:

```bash
mkdir -p /tmp/tla
curl -fsSL -o /tmp/tla/tla2tools.jar \
  https://github.com/tlaplus/tlaplus/releases/download/v1.8.0/tla2tools.jar
export TLA2TOOLS=/tmp/tla/tla2tools.jar
export JAVA="$(command -v java)"
```

From the repo root:

```bash
chmod +x .cursor/skills/verify-inventory-concurrency/scripts/run_check.sh
HEALTH_FORMAL_OUT=/tmp/health-dashboard-formal-inventory \
  TLA2TOOLS=/tmp/tla/tla2tools.jar JAVA="$(command -v java)" \
  .cursor/skills/verify-inventory-concurrency/scripts/run_check.sh
```

That script:

1. **Structural sync** — fails if `concurrency.group` no longer includes `github.run_id` for comment isolation, or if `cancel-in-progress` no longer depends on `pull_request`.
2. **TLC** on `model/InventoryConcurrency.cfg` with `SafeGrouping = TRUE` (current workflow). Expect **no** `Inv_CommentNeverCancelled` violation.

Optional proof that the property can fail (broken design):

```bash
HEALTH_FORMAL_OUT=/tmp/health-dashboard-formal-inventory \
  TLA2TOOLS=/tmp/tla/tla2tools.jar JAVA="$(command -v java)" \
  .cursor/skills/verify-inventory-concurrency/scripts/run_check.sh --expect-fail-broken
```

Uses `model/InventoryConcurrencyBroken.cfg` (`SafeGrouping = FALSE`). Expect a violation of `Inv_CommentNeverCancelled`. Read the counterexample with `/statechart`.

To catch a **workflow** break the way the next agent should: scratch-edit `concurrency` so comment runs share the PR group or set `cancel-in-progress: true`, re-run `run_check.sh` (structural and/or TLC must fail). Restore the workflow afterward. Do not leave the scratch change in the branch.

## Pass vs modeling error vs bug

- **Pass:** structural OK + safe TLC finds no `Inv_CommentNeverCancelled` break.
- **Modeling error:** TLC fails on `TypeOK`, deadlock you did not mean, or a break that cannot happen in the workflow YAML because the model step is coarser/finer than GitHub Actions. Fix the model; do not weaken `Inv_CommentNeverCancelled`.
- **Real bug:** structural check fails, or a revised model that still matches the YAML violates the promise. Report the counterexample in workflow words (comment run shares `inventory-N-pr`, a later PR sync cancels it). Do not change product workflow unless the user asks.

## Scope and limits

- Models only the concurrency group / cancel-in-progress shape, not the inventory status Python logic.
- Does not model GitHub queueing delay, runner capacity, or Dependabot `if:` skips.
- Run id cardinality is 4 — the race shape is what is checked.
- Unit tests in `tests/test_inventory_concurrency.py` remain the fast regression net; this skill checks every interleaving in the bound.

## Maintain

After intentional concurrency changes, update the model and bump **Last sync commit**. Use `/maintain-formal-verification-skill` when coverage drifts.
