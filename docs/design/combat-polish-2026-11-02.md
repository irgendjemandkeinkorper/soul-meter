# Combat polish — as built (2026-11-02)

Branch `claude/combat-polish`, stacked on `claude/combat-hotbar` (PR #556). Owner request,
2026-11-02: "click on a target outside melee range and have the unit walk up adjacent and
attack … keep polishing the combat and animations and elemental effects for the classes …
a demo of 5 v 5 battle with 1 of each class". Rulings are in `docs/owner-decisions.md` §5
(2026-11-02, combat polish). Captures: `docs/qa/combat-polish-2026-11-02/`.

## Slices

| # | What it does | Main files |
|---|---|---|
| 1 | **Walk in and act.** Pressing a creature out of reach walks the unit into reach and acts, as one order. Hover shows the path and the quote "WALK IN · MOVE n + STRIKE m = t AP". When the AP covers the walk but not the action, the quote says so and the click is refused. A plain ground click still only moves. | `globals/combat/combat_controller.gd`, `globals/combat/grid_battlefield_model.gd`, `ui/hud/battle_interface.gd`, `world/combat_overlay.gd` |
| 2 | **KitAI.** An enemy built from a party member (`source_member`) fights with its class kit: its class commands, the spells in its own tones, and the common arms. Each option passes the same gates as the player's bar (`query_action_for`) and is scored by the forecast damage the player sees, plus small PROVISIONAL weights for effects. Each step it acts, walks into reach, or passes. Plain hostiles keep the old AI. | `globals/combat/kit_ai.gd` |
| 3 | **CLASS DEMO (5V5).** A debug-build title button. You lead Ironbrand, River-Mother, Lensbearer, Mirrorblade and Oathclock; KitAI runs Husk-bearer, Flamebinder, Stormbearer, Locksmirk and Threadwalker. The fight is in Kesselford, two lines five steps apart. It runs inside the save sandbox, writes nothing, and returning to the title restores the real game. | `globals/combat/class_demo.gd`, `ui/flow/game_flow.gd`, `globals/encounter_catalog.gd` |
| 4 | **Poses on the current art.** The overlay moves each body's sprite, never the body: a hop per cell on a walk, a lean into a strike, a recoil on a hit, a lift on a cast, a slump on a fall, a squash-turn when facing changes. Every pose but the slump returns to rest. Reduced motion poses nothing. | `world/combat_poses.gd`, `world/combat_overlay.gd` |
| 5 | **One look per tone, a flourish per class.** Each of the ten tones has one impact look shared by every spell of that tone. Each class command plays its class's flourish at the actor, in the colours of the class's suggested major (bronze if it has none). | `ui/hud/combat_look.gd`, `ui/hud/class_flourish.gd`, `ui/hud/spell_cast_effect.gd` |

Slice 3 needed three supporting changes, all scoped to the demo:

- `EncounterCatalog.register_debug_encounter()` holds a debug-build-only encounter. It refuses
  any id that is committed or already in use.
- An encounter may carry `"formation": {"lines": true, "gap": n}` to seat two lines.
- `SaveGame` refuses manual and chapter-end saves while the sandbox is armed.

The branch also carries PR #563's chargen commit B1 (`KitPreview`/`KitGate`), cherry-picked
so the flourish and the chargen ability tiles share one definition of a class command
(`KitGate.is_class_command`). When #563 lands first, that commit drops out on rebase.

## The looks

Motion language for the tones follows the hexgame Element Atlas tone phrases (owner's
artifact, 2026-11-02). Colours stay on the game's `DS.WHEEL`.

| Tone | Atlas phrase | Look |
|---|---|---|
| Sul | struck crystal | A flash, twelve rays and flying shards |
| Vel | a rising glissando | Motes spiralling out over one ring |
| Luth | a low liquid pulse | Three slow rings and spreading motes |
| Khor | any tones, provably arranged | Three evenly timed rings and eight short rays |
| Tham | the deep fundamental | One heavy ring and falling blocks |
| Vekh | a sound being taken away | A dark drain and motes drawn inward |
| Mozh | a soft granular crumble | Slow falling grains over a thin ring |
| Khash | the crackle-roar | A flash and sparks thrown upward |
| Zhem | none, audibly | A pale drain and a thin ring |
| Zhur | tuned thunder | A forked bolt, a flash and six rays |

Class flourishes: Mirrorblade shards and four rays; River-Mother two slow rings and rising
motes; Ironbrand a flash and sparks; Lensbearer a ten-ray crown; Husk-bearer a dark drain;
Flamebinder a heavy ring and rising embers; Stormbearer a short bolt; Oathclock a clock face;
Locksmirk a turning gear; Threadwalker crossing threads.

## Verified

- Unit and integration tests: approach (walk-in quote, refuse, one order), KitAI, class demo
  (sandbox round trip, title-only, ten seated with five distinct enemy bodies), poses (5),
  looks (5), plus the full tree.
- Rendered captures under Xvfb, listed in the QA folder README.

## Follow-ups

1. Real walk, attack, hit and fall frames replace the poses (art list, owner item 30).
2. Look sizes, timings and colours are PROVISIONAL until the owner plays the demo (item 30).
3. A cast that deals no damage (Douse) draws the miss seal. Predates this branch.
4. Whether to borrow hexgame units or its palette is an owner question (item 29).
