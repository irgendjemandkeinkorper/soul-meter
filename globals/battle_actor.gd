class_name BattleActor
extends Resource
## Runtime combatant. Party actors retain their party_index so damage can be
## committed back to GameState when combat ends.
##
## AP round economy (Gate T-10 as amended 2026-08-28, `docs/fallout2-adoption-spec.md`
## Wave 0 item 5): AP is the SHIPPED default scheduler, so `action_points`,
## `max_action_points`, and `effective_max_action_points()` are live gameplay state, not a
## rollback shim — ticket #176's deletion plan is superseded by the CT→AP promotion.
## Charge-time gameplay still reads `TurnScheduler.charge_of()`.

@export var display_name: String = ""
@export var hp: int = 10
@export var max_hp: int = 10
@export var attack: int = 5
@export var defense: int = 2
## Tactical casting resource. Pool sizing remains owner-authored; zero is the neutral default.
@export var breath: int = 0
@export var attributes: Dictionary = {}
## Stable Combatant Id from Pandora. This is the enemy-archetype key used by
## Defining Strike knowledge; ad-hoc test actors may leave it empty.
@export var archetype_id: StringName = &""
@export_range(-1, 1) var balance_affinity: int = 0
@export var balance_pressure: int = 12
## This actor's elemental attunement (`ElementWheel.ORDER`), read as the TARGET side of
## `ElementMatrix.target_relation()`/`Resolution.resolve()` when this actor is struck — see
## globals/combat/resolution.gd and globals/units/unit_attunement.gd's header for why this is
## never a per-element table on BattleActor: it is a single leaning, not the ten-value
## `UnitAttunement` row (that table is authored per patron class, not wired here — issue #142
## follow-up). Empty is a deliberate, valid "no attunement authored yet" sentinel:
## `ElementMatrix.target_relation()` returns its neutral `IDENTITY_ROW` (×1.0) for an unknown
## element id, so an un-authored actor is neither resisted nor exposed, matching pre-#142
## damage exactly until real per-unit attunement data lands.
@export var element_id: StringName = &""
## This actor's multiplier on `Resolution.resolve()`'s `power × attack_scale × ...` chain
## (globals/combat/resolution.gd). 1.0 is neutral — every actor hits at the same scale until
## per-unit/per-job tuning is authored.
@export_range(0.0, 5.0) var attack_scale: float = 1.0
## GameState flag to set on a win, so a defeated enemy actor doesn't respawn
## a fight. Empty for the player's own BattleActor.
@export var defeated_flag: String = ""

## Reputation consequence for beating/losing to this actor. Mirrors
## FetchQuest's reward_* fields (quests/fetch_quest.gd) — empty faction means
## no-op, so most BattleActors (including the player's own) can leave these
## unset. Fleeing has no consequence here; only a clean win or loss does.
@export var win_faction: String = ""
@export var win_delta: float = 0.0
@export var win_cause: String = ""
@export var loss_faction: String = ""
@export var loss_delta: float = 0.0
@export var loss_cause: String = ""

var party_index: int = -1
var guarding := false
## FR-802 stable id (globals/stable_ids.gd, StableIds.ACTOR kind). Unique per combatant WITHIN
## one encounter — NOT unique per archetype, since two identical enemies (e.g. two Bog Wights)
## share `display_name` and `archetype_id` but must not share this. Assigned deterministically
## by `CombatController._assign_combat_ids()` at encounter setup, before the battlefield model
## is built, so it is stable across two runs with identical inputs and safe to key persistent
## battlefield state on. Never derive from `get_instance_id()`, allocation order, or a
## scene-tree path — see issue #186.
var combat_id: StringName = &""

## Which side this combatant fights on — &"ally" or &"enemy". Assigned beside `combat_id` when
## the battle starts.
##
## It is stored explicitly because the side was previously recoverable ONLY by reading the prefix
## of `combat_id` ("ally-0", "enemy-1"). Anything needing to know a side therefore had to parse an
## identifier, and an id whose substrings carry meaning stops being opaque the moment one caller
## does that. TurnScheduler needs sides to order a round, so this makes the fact a field rather
## than a naming convention.
var side: StringName = &""
var action_points: int = 0
var max_action_points: int = 0
var source_member: PartyMember
var discovered_weakness_ids: Array[StringName] = []
var defining_effects: Dictionary = {}
var balance_band_id: StringName = &""
var balance_effects: Dictionary = {}
## Temporary Wave 1 payoff earned by voluntarily ending an AP turn. Cleared at
## the next AP refresh; authored CombatRules own both its rate and hard cap.
var unused_ap_defense_bonus: int = 0


func is_alive() -> bool:
	return hp > 0


func attribute_value(attribute_id: StringName) -> int:
	return int(attributes.get(String(attribute_id), attributes.get(attribute_id, 0)))


func effective_attack() -> int:
	return maxi(0, attack + int(defining_effects.get("attack_delta", 0)))


func effective_defense() -> int:
	return maxi(0, defense + int(defining_effects.get("defense_delta", 0)) + unused_ap_defense_bonus)


func effective_max_action_points(base_value: int) -> int:
	return maxi(0, base_value + int(defining_effects.get("max_ap_delta", 0)))


func combat_stat(stat_id: StringName) -> int:
	match stat_id:
		&"attack":
			return effective_attack()
		&"defense":
			return effective_defense()
		&"max_ap":
			return max_action_points
		_:
			return attribute_value(stat_id)


func apply_defining_effect(parameters: Dictionary) -> void:
	for key: Variant in parameters:
		var effect_key := str(key)
		var value: Variant = parameters[key]
		if effect_key.ends_with("_delta") and typeof(value) in [TYPE_INT, TYPE_FLOAT]:
			defining_effects[effect_key] = int(defining_effects.get(effect_key, 0)) + int(value)
		else:
			defining_effects[effect_key] = value


func apply_balance_band(band_id: StringName, effects: Dictionary) -> void:
	balance_band_id = band_id
	balance_effects = effects.duplicate(true)
