# Planet Edit Rebuild Avalanche

## Problem

Saving changes in `Edit Planet` currently tends to trigger broad downstream work even when the edited field only affects a narrow slice of output. This is a long-standing behavior: the edit flow saves the planet model, often kicks off a full public rebuild, and some field changes can also cause every article to be saved or reindexed. The result is an avalanche effect where small settings edits can create unnecessary disk writes, search updates, template rendering, and background publish-adjacent work.

This became visible again while adding planet slugs and article references. A slug change must update derived references in public/API/search output, but the current safe implementation resaves all articles from `MyPlanetEditView` so their persisted/search snapshots refresh. That solves correctness but inherits the older broad-rebuild cost.

## Current Shape

- `Planet/Views/My/MyPlanetEditView.swift` applies the edited snapshot, saves the planet, and schedules a background `planet.rebuild()`.
- `MyArticleModel.save()` persists article JSON and queues search snapshot/index work.
- Some planet-level metadata changes only need planet JSON, search metadata, or template context refresh, but the current API surface does not express those narrower invalidation scopes.
- Derived data, persisted data, public site output, search snapshots, and Spotlight updates are coupled through save/rebuild entry points.

## Impact

- Editing simple planet settings can feel slow for planets with many articles.
- Rebuild work may compete with user-initiated writing, publishing, aggregation, or search indexing.
- New derived fields, like `articleReference`, are easy to implement correctly by resaving broadly, but that makes the existing cost easier to hit.
- It is difficult to reason about what actually needs to be invalidated for a given planet property change.

## Future Direction

- Introduce explicit invalidation scopes for planet edits, for example: planet metadata only, public planet JSON, article public JSON, search snapshots, Spotlight items, template render, and full rebuild.
- Keep derived values like `articleReference` out of private article persistence where possible, and update API/public/search projections from the owning planet/article models instead of forcing article JSON rewrites.
- Add targeted refresh helpers, such as reindexing all articles for one planet without rewriting article files, or regenerating `planet.json` without re-rendering every article page.
- Make `Edit Planet` compute a change set from the previous and desired snapshots, then invoke the smallest required set of operations.
- Add logging around rebuild triggers so future regressions show which edit caused which invalidation path.

## Status

Recorded as tech debt in May 2026. The article reference work keeps the conservative broad refresh behavior for correctness, and this note exists so the rebuild/invalidation model can be cleaned up separately.
