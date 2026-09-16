# Combat kits and reaction matrix — Codex handoff (2026-09-16)

**Read first:** `AGENTS.md`, then `docs/ideas/class-kits-first-nine.md` §"Runtime handoff"
and `docs/ideas/elemental-reaction-matrix.md` §"Runtime handoff" (both carry per-step runtime
tables written as the work landed). This file says what is done, what is next, in what order,
and what not to decide. Claude owns architecture and review; the owner reviews commits.

Branch: `feat/ch1-facade-occlusion` (unmerged, ahead of `origin` by several commits). Keep
working on this branch unless the owner says otherwise. Do not rebase or squash history.

## 1. Ground rules

1. **One step = one commit.** Commit message shape: `feat(combat): <step> (<codes or cards>)`,
   body listing the mechanics, ending with the attribution line the session gives you. Commit
   only when a step is green; never commit red.
2. **Stay inside `globals/combat/**`, `globals/combat_action.gd`, `data/combat/actions/*.tres`,
   `test/unit/*`, `test/integration/test_battle_cell_targeting.gd`, `ui/hud/**`,
   `world/combat_overlay.gd`, and the two design docs' runtime sections.** Anything else is a
   question, not a change. Never touch `addons/*` (except `addons/soul_meter_tools`),
   `.godot/`, `data/generated/*`, `data.pandora`, the vault, or `.dialogue` files.
3. **Never decide design.** Every "Open" or "Design conflict" line in the runtime sections is an
   owner decision. Implement the literal rule, flag the conflict in the runtime table, move on.
4. **Preserve save compatibility.** New state rides inside `class_resources_to_dict()` under a
   reserved `__key__`, omitted when empty (see `docs/class-resources.md` §Save). No schema bump.
5. **Typed GDScript** (`: Dictionary`, `: Array[Vector2i]`, `: int` on every untyped call
   result or the parser refuses "Cannot infer the type"), snake_case files, signals for
   communication, no `change_scene_to_file()`.
6. **Tests are yours to run.** Do not hand the owner a test command.

## 2. Verification recipe

```bash
export GODOT_BIN="$HOME/.local/bin/godot"
# after adding ANY class_name script, refresh the class cache first:
timeout 300 "$GODOT_BIN" --headless --path . --import --quit
# one suite (one -a per suite; the CLI is fail-fast per suite):
LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-test.XXXXXX)" \
  bash scripts/test.sh -a test/unit/<suite>.gd
# before a commit: whole unit tree + the HUD suite (about 8 minutes):
LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-test.XXXXXX)" \
  bash scripts/test.sh -a test/unit -a test/integration/test_battle_cell_targeting.gd
```

Baseline at `ae8f4746`: 1585 cases, 0 failures. gdUnit's diff output scrambles strings after
the ANSI strip: `print()` the refusal dict to read it, then delete the print. `.gd.uid` files
are tracked; add them with the suite.

Known, not yours: four integration suites (`test_town_townsfolk`, `test_interior_population`,
`test_consequence_notices`, `test_field_room`) fail only in a whole-tree run and pass alone.
Recorded in `docs/testing.md` §"Whole-tree order dependence". Do not chase it.

## 3. What is done (do not redo)

| Commit | Delivered | Suite |
|---|---|---|
| `03f12c6a` | Ash Magistrate (Pazzah × Khash): fire substrate `FireField`, Kindle/Firebreak/Crown/Douse, polearm cards, Ledger-filed fire | `test_ash_magistrate.gd` |
| `4f68703b` | Witness Weaver (Izhakel × Sul): light substrate `LightField`, Witness Light/Noonday/Unveil/Veil, fist cards, Threads contracts | `test_witness_weaver.gd` |
| `4f09cfed` | HUD pointer flow for cell workings and any-side cards | `test_battle_cell_targeting.gd` |
| `f8dea421` | Sluice Runner (Fickah × Luth): Breath restoration, refuges, Jam window | `test_sluice_runner.gd` |
| `2048e9bc` | Nightfeeder (Vhorr × Vekh): Shroud/Eclipse fields, Blinded, Blindside, blades, Blinding Throw | `test_nightfeeder.gd` |
| `ae8f4746` | Reaction matrix step 1: `MaterialField` (timber/stone), object casts, Reclaim, Rot the Brace, Sever on a line; L2 H2 M4 Z6 | `test_reaction_matrix_step1.gd` |

Runtime map (all in `globals/combat/combat_controller.gd` unless noted):

- **Effect cards**: `CombatAction.effect_id` + `effect_payload`. Gates in `_query_effect_gate`
  (`requires_patron`, `requires_tier` 2 = Chord / 3 = Triad via `CastingGate`, `refrain_use`,
  `ledger_entry`, `requires_jam_within`, `cells` capability). Every id must be in
  `_KNOWN_EFFECTS` or the card is refused.
- **Creature riders**: `_apply_effect_after_attack` (burning_strike, douse, pull, push, unseat,
  unveil, veil, blinding_throw, blindside, open_seam, second_breath...).
- **Cell workings**: `target_profile = &"cells"`, `options.cells = [{x,y}]`,
  `_query_cell_action` → `_apply_cell_action`; costs and fizzle through `_resolve_cell_cast`.
- **Object / working casts**: `options.object_id` or `options.line_id`,
  `_query_object_action` → `_apply_object_action`.
- **Deferred queue**: `enqueue_deferred` (`delay_rounds`, `due_tick`, `due_round`,
  `due_turn_of`), `_fire_due_deferred`, `request_cancel` (the Jam).
- **Checkpoints**, in this order on `round_ended` / CT measure: `_fire_checkpoint`,
  `_material_checkpoint`, `_light_checkpoint`.
- **Substrates**: `fire_field.gd`, `light_field.gd` (light + shroud fields, Exposed/Veiled/
  Lit/Blinded impositions in `BattleActor.impositions`), `material_field.gd`.
- **Save keys** inside `class_resources_to_dict()`: `__deferred__`, `__fire__`, `__light__`,
  `__jams__`, `__vekh__`, `__materials__`, `__impositions__`.
- **Card numbering** in `data/combat/actions/`: 30–44 elemental and martial, 45–49 blades and
  Blindside, 50–58 kit tiers, 59–65 Vekh/Mozh/Zhem. Next free number: **66**. Template: copy
  `63_sever.tres`; `kind 0` = ATTACK, `verb 1` ATTACK / `2` CAST; magnitudes note/phrase/song/
  refrain; default prices N 2 AP 3 Breath, P 3/6, S 4/12, R 4/24.
- **Test battle helper**: copy `_battle()` from `test/unit/test_reaction_matrix_step1.gd`
  (7×3 flat grid, AP mode, `defining_effects = {"hit": true}`, `NO_FIZZLE`, `_end_round`).
  Bystanders go diagonal to the caster: any occupant on the Bresenham line blocks sight. The
  enemy AI walks toward the party unless adjacent, so place actors deliberately. Fickah
  casters keep a 5% fizzle floor: branch on `fizzled` and return.

## 4. Next: reaction matrix step 2 (this handoff's scope)

Codes K3, T2, H3, Z3, Z4 from `docs/ideas/elemental-reaction-matrix.md`. They need three
workings that do not exist yet plus one extension:

1. **Hold Note** (Khor N, `elemental-spell-cards.md` row 148): 1 AP / 30 CT and 1 Breath at
   cast and at every upkeep; one sustain slot per caster; freezes one owned eligible Note's
   remaining duration through the next checkpoint. Eligible Notes for this step: a Witness Light
   field, a Firebreak line, a Shroud, an owned Aftertone on a creature. Missing upkeep or the
   caster leaving reach (4) or dying breaks the hold; the duration resumes. Upkeep is paid at
   the holder's turn start; refusal to pay releases. Suggested state: `_holds` {holder_id:
   {kind, id, target_id, since_round}} saved under `__holds__`; frozen fields skip their
   `remaining_checkpoints` decrement while held.
2. **Anchor** (Tham P, row 61): anchor one friendly Aftertone within 4 (`aftertone["anchored"]
   = true`, the flag `Resolution` already reads at `resolution.gd:183,201`). Rejected before
   costs on anything that is not an Aftertone (T2 second half).
3. **Consume Aftertone** is not a card: it is the existing unanchored-Aftertone burst on Khash
   creature attacks (`resolution.gd` ~183). H3: consuming a held unanchored Aftertone ends the
   hold and the upkeep; an anchored one is refused (already true in Resolution; add the hold
   release and the events).
4. **Sever extension** (Z3, Z4): `63_sever.tres` gains `options.aftertone` {target_id, index}
   and `options.hold_of` (holder id). Sever ends a held Note despite the hold (slot freed, no
   refund) and ends an anchored Aftertone. Do NOT implement the Vault Triad Sealed Ground
   exception (Z4): refuse nothing, note it as open.
5. **K3**: hold + anchor stack on one Aftertone. Preview must show both flags.

Acceptance (from the matrix): forecast equals commit for every listed cell; a rejected cast
spends nothing (assert Breath and AP unchanged); no reaction fires that is not in the table.
Suite: `test/unit/test_reaction_matrix_step2.gd`, 12–16 tests, one per rule and one save
round-trip. Then add a "Step 2 runtime" table under step 1 in the matrix doc and the new save
key to `docs/class-resources.md` §Save. One commit.

Do not decide:
- Whether anchoring also resists Zhem (matrix "Open tuning" 2). Implement: it does not.
- Upkeep timing for CT battles (measure vs turn). Implement turn start; note it.
- Whether a hold survives the holder being Jammed. Implement: `request_cancel` does not touch
  holds; note it.
- HUD symbols for held/anchored. Out of scope; leave a line in the runtime table.

## 5. After step 2 (in order, each its own handoff or commit)

1. Matrix step 3: growth and cover (V3, V4, T1, T3, H1, L1, M1, Z2) — needs Rootwork (Vel S)
   and Raise Cover (Tham S) substrates. Tham cover on a Firebreak cell (T3) and cover in
   `GridBattlefieldModel.set_cover` are the hooks.
2. Matrix step 4: concealment and revelation windows (S3, X1, X2, X4, Z1, Z5) — mostly done
   by the Witness Weaver and Nightfeeder work; audit against the table, add Sever on a field
   (Z1, Z5), and write the tests as a step-4 suite.
3. Matrix step 5: conduction (R2, T4, R1) — needs Zhur Conduct/Arc and Wet-cell connectivity
   (Wet today lives on objects, not floor cells; the floor half is a new `MaterialField` or
   `TileState` decision for Claude, not Codex).
4. Kits 5–9 (Cairnkeeper, Unbroken, Mortuary Sage, Sparkwright, Wildbloom) in the order of
   `class-kits-first-nine.md`; each leans on steps 2–5 above. Same shape as the four done kits:
   substrate → controller wiring → `.tres` → suite → runtime table → commit.

## 6. Open owner decisions already flagged (do not resolve)

- Opened Sluice cap 9 unreachable under "never more than paid" at a 6-Breath price.
- Term of Daylight costs 6 AP against a 4 AP default.
- Blinded weakening is provisional (no flank, facing reads front).
- Blindside's hidden preparation has no reader beyond Blindside Bite.
- Turning Tide mode B Soaks only allies and quenched creatures (interpretation).
- Reclaim yield from growth (3 Breath) and Anchored vs Sever (matrix "Open tuning").
- Yard scene bridge to `place_material`, HUD object picking, Cinder Spear: not built.

## 7. Handoff back to Claude

Reply with: status; changed files; the whole-tree summary line; per-rule test names; risks;
questions raised as bullets quoting the doc line. Keep it under a page. Do not spawn other
workers.
