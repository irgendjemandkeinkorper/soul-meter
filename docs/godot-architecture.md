# Project context — Godot RPG architecture and plugin stack

Handoff document (the standing architecture spec; `CLAUDE.md` summarizes it — this is the
full text). Game shape: lore-heavy RPG with faction/reputation consequence tracking and an
open magic system built on combinable spell effects.

> Status note (2026-07-31): stack installed & pinned — see `DEPENDENCIES.md`. Done: root
> state chart (`ui/flow/game_flow.tscn`), Pandora trees seeded (`tools/seed_pandora.gd`),
> Pandora→GLoot generator + ItemIds + items.pot (`tools/generate_gloot.gd`, drift-check
> mode), reputation ledger (`globals/reputation.gd`), and PO item fallback/merge support.
> Still to do: Maaack's setup wizard (editor, Windows), GodotGAS (store download) + its
> generator, and CI hook for the drift check.

---

## Stack

- **Engine:** Godot 4.6 floor (project runs 4.7.1; several addons require 4.4+/4.6+)
- **Language:** GDScript
- **Dimension:** 2D — isometric, rendered from 3D models (per human answer)

---

## Layered architecture

Five layers. Dependencies point downward only. If you find yourself wanting an upward
reference, that's a design smell — raise it rather than adding one.

```
Flow          State charts — what the game is currently doing
Presentation  Themes, Phantom Camera, Anima, Juicee, shaders
Systems       GodotGAS (abilities/effects), GLoot (inventory), reputation ledger
Narrative     Dialogue Manager, QuestSystem
Data          Pandora — single source of truth
```

### The one-way data rule

**Pandora is canonical. Everything else consumes from it. Nothing writes back.**

This is the most important constraint in the project. Items, spells, effects, factions, NPCs,
and lore entries are Pandora entities. GLoot's prototype JSON, GodotGAS effect resources, and
any lookup tables are *generated artifacts*, committed to the repo but never hand-edited.
If a generated file needs to change, change the Pandora entity and regenerate.

---

## Confirmed plugin stack

**Foundation:** Maaack's Godot Game Template (menus, options, pause, credits, scene loader,
input remapping, save/load — MIT, assets 2703/2709) · Godot State Charts (game & menu flow —
asset 1778; compound/parallel/history states, guards, debug view).

**Data:** Pandora (`bitbrain/pandora`) — canonical items/spells/abilities/factions/NPCs/lore.
Verify release stability before deep dependence (pre-1.0 heritage).

**Narrative:** Dialogue Manager (`nathanhoad/godot_dialogue_manager`, v4 needs 4.6+; text
format chosen because it diffs cleanly in git) · QuestSystem (`shomykohai/quest-system`,
asset 3809 for 4.4+; CSV+POT localization, unit-tested API).

**Systems:** GodotGAS (abilities/attributes/effects/tags/stacking/durations — 100% GDScript;
**read the source before depending on it**) · GLoot (`peter-kish/gloot`, asset 1368 —
inventory/equipment/stacking/constraints; consumes JSON prototypes — see sync spec).

**Presentation:** Phantom Camera (`ramokz/phantom-camera`, asset 1822) · Anima (UI motion) ·
Juicee (screen shake/hit stop, visual graph editor) · Godot Shaders (a copy-from collection,
NOT a plugin — check each shader's license before shipping).

**Authoring (editor-only):** PixelPen (pixel art in-editor) · SmartShape2D (2D organic
terrain).

---

## Install order (matters for 1–8)

1. **Maaack's template** — the project skeleton. ✅ installed as plugin into existing project
2. **Run the setup wizard** (`Project > Tools > Run Maaack's Game Template Setup...`), verify
   the copied menus run end-to-end, **commit — clean baseline**. ⬜ (editor-interactive; run on
   the Windows machine)
3. **Godot State Charts** — root chart, states empty, menu buttons send events. ✅ chart live
   at `ui/flow/game_flow.tscn`
4. **Pandora** — define category trees first (`Items`, `Spells`, `Effects`, `Factions`,
   `NPCs`, `Lore`) with a handful of real entities each. ✅ installed / ⬜ trees
5. **Localization / POT** — before content exists, not after. ✅ PO/gettext pipeline enabled
6. **Dialogue Manager** ✅ installed
7. **QuestSystem** ✅ installed
8. **GodotGAS + GLoot + the Pandora sync tool.** GLoot must not be used until the sync tool
   exists. ⬜ GAS awaiting store download; GLoot installed but unused by design
9. Phantom Camera, Anima, Juicee ✅ · 10. Godot Shaders per-need ⬜ · 11. PixelPen ✅ (parked
   on Linux), SmartShape2D ✅

---

## Pandora → GLoot sync spec

GLoot wants a JSON prototree. Pandora owns the data. Bridge with a one-way generator:

- An `@tool` script exposed via `Project > Tools > Regenerate GLoot prototypes`
- Walks the Pandora `Items` category tree
- Emits `res://data/generated/gloot_prototree.json`
- Emits `res://data/generated/item_ids.gd` — constants class; no literal item path strings

**Mapping contract:** Pandora category path → GLoot prototype path
(`Items/Weapons/Melee/Knife` → `weapons/melee/knife`). Reserved properties on the `Items`
root (propagate to every child): `Max Stack Size` (stack constraint) · `Weight` (weight
constraint) · `Grid Size` (grid constraint, if grid inventories) · `Equip Slot` (slot filter;
empty = non-equipment) · `Display Name` / `Description` (translation pipeline source strings).

**Rules:** generated files are committed with a generated-file header; never hand-edited.
Never `create_and_add_item()` with a literal — use `ItemIds.WEAPONS_MELEE_KNIFE`. If generator
and Pandora disagree, Pandora wins; regenerate. Add a CI/pre-commit check that regenerates and
fails on diff — without it the two silently drift.

**The same one-way pattern applies to GodotGAS:** spells are Pandora entities referencing GAS
effect resources by ID. Pandora holds design data (name, cost, tags, description, lore); GAS
holds runtime effect definitions. Generate the linkage.

---

## Localization / POT setup (step 5 — before content)

- Godot 4.7 has no separate enable switch for POT generation. The
  `internationalization/locale/translations_pot_files` project setting is the source list;
  use `Project Settings > Localization > Template Generation > Generate` to write the
  engine-owned template. This project keeps that output at `locale/project.pot` and lists
  Dialogue Manager `.dialogue` files plus QuestSystem quest resources as its sources.
- The generated item template is intentionally separate at `data/generated/items.pot`.
  Pandora owns item source text and `tools/generate_gloot.gd` owns those entries; Godot's
  scanner owns dialogue/quest/script strings. Do not merge the two templates.
- `locale/es.po` is a checked-in non-English scaffold loaded through
  `internationalization/locale/translations`. It is updated by the Pandora generator and
  keeps existing `msgstr` values. When an English source comment changes, the row is retained
  and marked `#, fuzzy` for translator review.

**Where strings live — decided:** English source strings live in Pandora (`Display Name`,
`Description` as authoring fields). Localized strings do NOT — they live downstream in the
normal Godot translation pipeline (translators work in PO/CSV in parallel; keeping them out of
Pandora avoids merge collisions between translation batches and balance passes).

**Mechanism:** the same generator that emits GLoot prototypes extracts the English strings
into translation source files. Keys are *derived*, never stored: `ITEM_` + entity id,
uppercased. Runtime resolves via `tr(derived_key)` in `globals/item_localization.gd`, then
falls back to the raw Pandora string when no translation exists. The generator merges the
locale scaffold instead of overwriting it: it preserves translated rows and flags rows whose
English source comment changed as stale (`fuzzy`).

Format: **PO/gettext**. The engine-owned `locale/project.pot` and Pandora-owned
`data/generated/items.pot` are separate by design.

**Parser audit (2026-07-31):** the installed addon set has one parser for each relevant
extension: Dialogue Manager registers `.dialogue`, and QuestSystem registers `.tres`.
Pandora and GLoot do not register an `EditorTranslationParserPlugin`, so the known first-parser
collision is not active in this checkout. Re-audit if another addon adds a `.tres` or
`.dialogue` parser.

---

## Reputation and consequence tracking (in-house, no plugin)

> Status: ✅ implemented — `globals/reputation.gd` (autoload `Reputation`, single append API
> `record()`, derived standings + bands, `why()` query, serialize round-trip) with standings
> mirrored into statechart expression properties (`rep_<faction>`) for guards. Smoke-tested.

**Model reputation as an append-only event log, not a bag of mutable integers.**

```
{ actor, faction, delta, cause, scene, timestamp }
```

Derive standings from the log: (1) you can show the player *why* a faction feels how it does;
(2) rebalance by changing the derivation without invalidating saves; (3) "why is this NPC
hostile" is a query, not archaeology. Statechart guards and Dialogue Manager conditions read
the derived state. Nothing writes to the log except a single append API.

---

## Combat

No framework. GodotGAS covers the stats half. The collision half — hitbox/hurtbox — is
in-house (~50 lines), modelled on GDQuest's hitbox/hurtbox demo: both are `Area2D`; hitbox on
the attacker's weapon/projectile, hurtbox on anything damageable. `collision_layer` = what you
are, `collision_mask` = what you scan for. Hurtbox `monitorable=true, monitoring=false`;
hitbox the reverse — that split prevents friendly fire and self-damage without code.

Rejected: Combat Collider, Saltmire Hitbox, Acro's Hitboxes — viable but not enough adoption
to be a safe dependency for something this small and this frequently tuned.

---

## Conventions and guardrails

**Data** — Pandora is the source of truth; generated artifacts never hand-edited; no literal
string IDs in code (use generated constants).

**Flow** — no `change_scene_to_file()` in game code; all flow through the state chart. UI
sends events (`send_event("options_pressed")`), never names a destination. Transition
conditions live in guards, not `if` blocks in button handlers. Every state pairs enter with
exit: if enter allocates/connects, exit releases.

**Template** — never edit anything under `addons/`; extend the inherited copies of the
template's example scenes so upstream updates still apply.

**Theming** — theme *type variations* (`DangerButton`, `HUDLabel`), not per-node overrides.
`StyleBoxTexture` nine-patches for anything that must survive resolution changes (4k →
640x360).

**Focus & input** — set `focus_mode` deliberately on every interactive control;
`grab_focus()` on menu entry, restore on pop; test every menu gamepad-only.

---

## Deferred — install when the need is real

- **LimboAI** — behavior trees for enemy/NPC AI; nothing to drive one yet. Choose the
  **GDExtension build** (drop-in) over the C++ module unless a missing feature forces it.
- **Terrain3D / TerraBrush** — only if 3D and only when terrain matters.
- **Talo** — self-hostable backend; only if anything goes online.
- **Panku Console** — in-game console; valuable once reputation/spell state needs live poking.

## Testing

**gdUnit4** — chosen over GUT 2026-07-26; see `docs/testing.md` for the full rationale, how to
run/write tests, and the manual-test checklist convention. Installed and pinned
(`DEPENDENCIES.md`); example suites exist for the reputation ledger (unit) and the field room
(integration, via `SceneRunner`). What's still missing: property-based tests over the
reputation derivation and the (future) combinatorial magic-system effect matrix — this was the
reason testing was flagged as the riskiest omission in the first place, and still is until
those exist.

## Dependency risk

~13 addons must survive each Godot upgrade, and minor releases do break addons. The failure
mode is four needing patches from four maintainers simultaneously. Mitigations: pin versions
(`DEPENDENCIES.md`), upgrade Godot deliberately, record what breaks if each is removed.

## Open questions for the human

1. ~~2D or 3D~~ — **2D, isometric from 3D models** (answered).
2. ~~Translation format~~ — **PO/gettext** ("whatever is scalable"; native fuzzy/stale
   marking, translator-standard tooling). (answered 2026-07-26)
3. Target platforms — must gamepad-only work at ship? (open)
4. ~~Multiplayer~~ — **maybe: BG3-style co-op is a live possibility.** Consequences:
   GodotGAS is single-player-scoped today (its networking is roadmap — re-verify before deep
   dependence, or keep abilities behind our own seam); `StateChartSerializer` matters early;
   keep game logic deterministic and GameState serializable. Do not build netcode now; do
   avoid single-player-only architecture. (answered 2026-07-26)
5. ~~Inventory~~ — **grid-based.** `Grid Size` is a REQUIRED Pandora property on the `Items`
   root; GLoot grid constraints are in scope. (answered 2026-07-26)
6. ~~gdUnit4 or GUT~~ — **gdUnit4.** See `docs/testing.md`. (answered 2026-07-26)

## Sources

Maaack's Godot Game Template — https://github.com/Maaack/Godot-Game-Template ·
Godot State Charts — https://github.com/derkork/godot-statecharts ·
Pandora — https://github.com/bitbrain/pandora ·
Dialogue Manager — https://github.com/nathanhoad/godot_dialogue_manager ·
QuestSystem — https://github.com/shomykohai/quest-system ·
GLoot — https://github.com/peter-kish/gloot ·
GodotGAS — https://store.godotengine.org/asset/indiegamedad/godotgas/ ·
Phantom Camera — https://github.com/ramokz/phantom-camera ·
awesome-godot — https://github.com/godotengine/awesome-godot ·
GDQuest hitbox/hurtbox — https://github.com/gdquest-demos/godot-4-hitbox-hurtbox ·
LimboAI — https://github.com/limbonaut/limboai

See also `docs/godot-flow-handoff.md` (the earlier UI-flow handoff: statechart tree, history
states, and the menu wiring task order).
