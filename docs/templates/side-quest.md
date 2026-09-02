# Template — side quest

Use this for C10–C19. The rule set is PRD FR-502 + FR-403: **≥ 2 genuinely different
outcomes, ≥ 1 ledger write per resolution, every resolution visibly read back later, and
the resolution must involve a choice** (a fetch skeleton may carry the quest, the ending may not
be a fetch).

## File set a worker must produce

| File | Purpose |
|---|---|
| `quests/<slug>.tres` | `DomSideQuest` resource (`quests/dom_side_quest.gd`, extends `FlagQuest` → `Quest`) |
| `globals/quest_registry.gd` | `const <NAME>: DomSideQuest = preload(...)`, appended to `DOM_SIDE_QUESTS` and `ALL_QUESTS` |
| `dialogue/<file>.dialogue` | Offer, gate, decision, and read-back lines (Dialogue Manager) |
| a read-back site outside the resolving dialogue | Another NPC line, a `BuildingDoor` transition `required_flag`, a price, or an encounter gate |
| `test/integration/test_<slug>.gd` | Both outcomes reachable; ledger written; flag set; read-back gated |

## `DomSideQuest` fields

From `quests/flag_quest.gd` (base): `required_flags`, `objectives`, `quest_giver`,
`quest_location`, `destination_scene`, `destination_position`, `advances_clock`.
From QuestSystem `Quest`: `id` (int, unique across `quests/`), `quest_name`, `quest_description`,
`quest_objective`.

From `quests/dom_side_quest.gd`:

| Field | Meaning |
|---|---|
| `stable_id` | `"<hub>/side/<slug>"` — the durable id used by saves and the audit |
| `giver_actor_id` | kebab NPC id; makes the NPC quest-critical for `phase_reachability` |
| `participant_actor_ids` | every NPC with a line in the quest |
| `hook_ids` | `"<hub>/<npc>/<role>"` — one per NPC role (giver, information, gate, target) |
| `dialogue_title` | the `~ title` in the `.dialogue` file that opens the quest |
| `decision_prompt` | one sentence naming the choice |
| `resolution_flag` | `<domain>_<subject>_resolution`; value = the chosen `outcome_id` |
| `outcome_ids` / `outcome_labels` | parallel arrays, ≥ 2 entries, ids kebab |
| `outcome_faction_ids` | vault faction kebab id per outcome (60 exist in `dramgid-vault/factions/`) |
| `outcome_reputation_deltas` | `PackedFloat32Array`, per outcome |
| `outcome_causes` | the `cause` string written to the `Reputation` ledger |
| `outcome_readbacks` | one sentence per outcome describing the visible world change |

`has_complete_outcome_schema()` requires all six `outcome_*` arrays to be the same length.

## Runtime contract (do not duplicate it in dialogue)

- Offer: `do QuestRegistry.offer_side_quest(QuestRegistry.<NAME>)` — idempotent.
- Resolve: `do QuestRegistry.resolve_side_quest(QuestRegistry.<NAME>, "<outcome_id>")` —
  this is the ONLY place that completes the quest, writes `Reputation.record("player",
  faction, delta, cause, "dom")`, sets `resolution_flag`, and autosaves. Dialogue never calls
  `Reputation` or `Renown` directly.
- Intermediate progress uses `GameState.set_flag("<domain>_<subject>_<predicate>", true)`
  and is listed in `required_flags` so the decision cannot be reached early.

## Worked example — Dishonest Water (real asset)

`quests/dom_dishonest_casks.tres` (abridged to the fields that matter):

```
id = 6
quest_name = "Dishonest Water"
quest_objective = "Trace the suspect cooling-water casks."
required_flags = PackedStringArray("dom_dishonest_casks_traced")
objectives = PackedStringArray("Compare Arvek's cooper mark with the forge shutdown tally.",
                               "Return to Keth Varr and rule on the suspect casks.")
stable_id = "dom/side/dishonest-casks"
giver_actor_id = "keth-varr"
participant_actor_ids = PackedStringArray("keth-varr", "arvek-stormcup", "orm-redtongs", "torv-bellowskin")
hook_ids = PackedStringArray("dom/keth-varr/giver", "dom/arvek-stormcup/information",
                             "dom/orm-redtongs/gate", "dom/torv-bellowskin/target")
dialogue_title = "dom_side_dishonest_casks"
resolution_flag = "dom_dishonest_casks_resolution"
outcome_ids = PackedStringArray("halt-the-water", "keep-the-roar")
outcome_faction_ids = PackedStringArray("trial-council", "shattersteel-concord")
outcome_reputation_deltas = PackedFloat32Array(6.0, 6.0)
outcome_causes = PackedStringArray("Put East Arm safety ahead of an uninterrupted Hammer Roar",
                                   "Kept the Hammer Roar alive while the Concord replaced suspect cooling water")
outcome_readbacks = PackedStringArray("The suspect casks remain under Council seal; ...",
                                      "Every cooling cask now carries a Concord watcher; ...")
```

Registry (`globals/quest_registry.gd`):

```
const DISHONEST_CASKS: DomSideQuest = preload("res://quests/dom_dishonest_casks.tres")
const DOM_SIDE_QUESTS: Array[DomSideQuest] = [DISHONEST_CASKS, ...]
const ALL_QUESTS: Array[Quest] = [..., DISHONEST_CASKS, ...]
```

Dialogue (`dialogue/dom_side_quests.dialogue`, abridged). Conditions MUST use the
self-closing `[if expr /]` form — plain `[if expr]` silently no-ops:

```
~ dom_side_dishonest_casks_hub
do QuestRegistry.offer_side_quest(QuestRegistry.DISHONEST_CASKS)
- "Arvek's mark and the forge tally agree." [if QuestRegistry.is_active(QuestRegistry.DISHONEST_CASKS) and not GameState.get_flag("dom_dishonest_casks_traced") /]
	do GameState.set_flag("dom_dishonest_casks_traced", true)
- "Seal the casks." [if ... /]
	do QuestRegistry.resolve_side_quest(QuestRegistry.DISHONEST_CASKS, "halt-the-water")
- "Keep the forges sounding." [if ... /]
	do QuestRegistry.resolve_side_quest(QuestRegistry.DISHONEST_CASKS, "keep-the-roar")
- "What changed after the casks were sealed?" [if QuestRegistry.is_done(QuestRegistry.DISHONEST_CASKS) and GameState.get_flag("dom_dishonest_casks_resolution") == "halt-the-water" /]
```

Read-back outside the quest dialogue: `actors/building_door/transitions/cask_warehouse_enter.tres`
carries `required_flag = "dom_dishonest_casks_traced"` — the warehouse only opens once the
casks are traced. Prefer read-backs of this kind (a door, a price, an encounter's
`required_flag`) over a second dialogue line; the audit's read-back scanner is
co-occurrence based (see the header of `tools/quest_audit.gd`), so a real gate is stronger
evidence than a line.

## Skill-check routes

A check in dialogue (`[#tag=Persuasion]`) must always have a non-check alternative that
reaches the same objective, otherwise `quest_audit` `check_softlocks` errors. See
`docs/dialogue-checks.md`.

## Pre-handoff checklist

- [ ] `has_complete_outcome_schema()` true; ≥ 2 outcome ids with different faction or delta
- [ ] Registry consts + both arrays updated; `id` unique
- [ ] Offer and both resolves reachable in dialogue; every `[if ... /]` self-closing
- [ ] ≥ 1 read-back outside the resolving dialogue
- [ ] All flags obey the grammar; no new domain without a `FLAG_DOMAINS` entry
- [ ] `quest_audit.gd` 0 errors (`outcome_count`, `resolution_writes`, `readbacks`,
      `check_softlocks`, `template_conformance`)
- [ ] Integration test covers both outcomes and the read-back gate
- [ ] Premise is the one claimed in the issue comments; prose marked
      `PROVISIONAL — CANON REVIEW REQUIRED` if it names anything not in the vault
