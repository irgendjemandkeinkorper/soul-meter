# Pandora Stability Assessment

## Decision

Soul Meter will remain pinned to Pandora commit `d78b99e`, whose plugin identifies itself as
`1.0-alpha10-dev`. Pandora is suitable as the project's canonical game-data editor and database
at that exact revision, but its pre-1.0 status makes unreviewed upgrades too risky. The pin is a
compatibility boundary, not evidence that the dependency has a stable public API.

## Current risk surface

- `data.pandora` is canonical for items, combatants, encounters, spells, effects, factions,
  NPCs, and lore-facing IDs. A serialization or schema change can affect most runtime content.
- Project seed and generator tools use Pandora's entity/property API. API changes can break
  migrations or silently alter committed outputs under `data/generated/`.
- Runtime registries and combat/inventory paths consume generated identifiers and JSON. Drift
  may therefore appear well after a successful editor import.
- Release builds deliberately include raw `data.pandora` and use Godot recovery mode because
  Pandora's editor release hook ASCII-compresses JSON and loses canonical Unicode content.
  Changes to that hook or export behavior are release-blocking risks.
- The vendored addon does not retain verifiable upstream commit metadata. The documented pin
  and committed tree must be reviewed together; neither independently proves provenance.

These risks are balanced by a narrow ownership rule: Pandora owns game data, generated files
are one-way outputs, and lore prose remains in the Dramgid vault. Game code must not write back
to Pandora at runtime.

## Upgrade policy

Upgrade only in a dedicated dependency branch. Record the new commit in `DEPENDENCIES.md` in
the same commit as the vendored snapshot. Review upstream changes from `d78b99e` through the
candidate revision, with particular attention to database serialization, entity/property APIs,
editor import hooks, and export hooks.

Before merging an upgrade:

1. Back up `data.pandora` and confirm it opens without an automatic destructive migration.
2. Run a Godot headless import and inspect parse, resource, and autoload errors.
3. Run `scripts/check_generated_data.sh`, then review every generated diff rather than accepting
   regeneration mechanically.
4. Run the full gdUnit4 suite and exercise a release export containing Unicode Pandora data.
5. Run `scripts/verify_addon_pins.sh` and review its findings.
6. Keep the previous vendored snapshot and database backup available as the rollback path.

Do not combine a Pandora upgrade with content, schema, or gameplay changes. Any required data
migration must be explicit, repeatable, reviewed, and validated before the old snapshot is
discarded.

## Existing drift-check coverage

`scripts/check_generated_data.sh` runs the GLoot and isometric-sprite generators in drift mode
and requires their explicit no-drift completion messages. This catches differences between the
canonical database and those committed projections. `scripts/verify_addon_pins.sh` reports a
missing documented pin, tracked edits, missing addon directories, and untracked files relative
to the committed vendored snapshot.

The checks do not validate every Pandora entity or property, prove the vendored snapshot came
from the documented upstream commit, detect upstream changes, test editor-only workflows, or
guarantee database migration compatibility. Full-suite, import, manual editor, and release-export
verification therefore remain mandatory for upgrades.
