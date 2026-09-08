class_name NPC
extends StaticBody2D
## A field NPC the player can talk to. Walk into range, press the interact key (E) —
## the configured dialogue starts via Dialogue Manager (which loads our balloon).

@export var npc_name: String = "NPC"
@export var npc_id: String = ""
@export_file("*.dialogue") var dialogue_path: String
@export var dialogue_start: String = "start"
@export var vendor_id: String = ""
@export_range(32.0, 240.0, 1.0) var interaction_radius: float = 120.0
@export_group("Pickpocket (#284)")
## Identifies this NPC's pocket in the flag store. Empty disables the verb
## entirely — an NPC without a pocket id cannot be robbed, and the prompt says
## nothing about stealing.
@export var pocket_id: String = ""
## The skill rolled. `slip` by default (DRAMGID's rename of sleight_of_hand).
@export var pocket_skill: String = "slip"
## Situational modifier handed to SkillCheck. Negative is harder.
@export var pocket_modifier: float = 0.0
@export var pocket_item_id: String = ""
@export var pocket_gp: int = 0
## Faction that takes the reputation hit when the attempt is CAUGHT. Empty
## records infamy only — a stranger with no affiliation still saw you try.
@export var pocket_faction: String = ""
@export var pocket_caught_message: String = "A hand closes on your wrist. They saw."

@export_group("Placeholder presentation")
## Scene-owned presentation keeps NPC content from branching on lore names.
## Only relevant when npc_id is empty and no generated unit art applies —
## the default Sprite2D texture is already a painterly crowd figure at 1:1.
@export var visual_region := Rect2(0, 68, 16, 16)
@export var visual_modulate := Color.WHITE
@export var visual_scale := Vector2.ONE

const UnitArtScript := preload("res://globals/unit_art.gd")

var _player_in_range := false
var _prompt: Label
var _collision_layer_default := 0
var _authored_visible := true
var _authored_process_mode := Node.PROCESS_MODE_INHERIT
var _authored_dialogue_path := ""
var _authored_dialogue_start := "start"
var _reaction_dialogue_path := ""
var _reaction_dialogue_start := ""
## Where the scene author placed this NPC, captured before any routine runs.
## The deterministic fallback for a reaction that makes an NPC present in a
## phase whose routine row supplies no position — see _refresh_world_state().
var _authored_position := Vector2.ZERO


func _ready() -> void:
	GridPlacement.snap_to_walkable_cell(self, global_position)
	_authored_position = global_position
	# A standing NPC is a solid body. Overworld click-paths must route around it rather than
	# grind into it (GH #190) — see world/nav/nav_occupancy.gd.
	NavOccupancy.register(self)
	_apply_visual_identity()
	var range_area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = interaction_radius
	shape.shape = circle
	range_area.add_child(shape)
	add_child(range_area)
	range_area.body_entered.connect(_on_body.bind(true))
	range_area.body_exited.connect(_on_body.bind(false))

	_prompt = Label.new()
	_prompt.text = _prompt_text()
	_prompt.theme_type_variation = "EyebrowLabel"
	_prompt.position = Vector2(-100, -108)
	_prompt.size = Vector2(200, 32)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	add_child(_prompt)

	# FR-504a routines: a named NPC with a NpcRoutines row is placed (or made
	# absent) per clock phase, on scene load and again on each phase change.
	# An NPC without a row keeps FR-504 flag/rep reactivity — that path does
	# nothing here by design.
	_collision_layer_default = collision_layer
	_authored_visible = visible
	_authored_process_mode = process_mode
	_authored_dialogue_path = dialogue_path
	_authored_dialogue_start = dialogue_start
	_refresh_world_state()
	WorldClock.phase_changed.connect(_on_world_phase_changed)
	GameState.flag_changed.connect(_on_reaction_flag_changed)
	Reputation.reputation_changed.connect(_on_reaction_reputation_changed)


func _exit_tree() -> void:
	if WorldClock.phase_changed.is_connected(_on_world_phase_changed):
		WorldClock.phase_changed.disconnect(_on_world_phase_changed)
	if GameState.flag_changed.is_connected(_on_reaction_flag_changed):
		GameState.flag_changed.disconnect(_on_reaction_flag_changed)
	if Reputation.reputation_changed.is_connected(_on_reaction_reputation_changed):
		Reputation.reputation_changed.disconnect(_on_reaction_reputation_changed)


## The scene file this NPC is hosted in: nearest ancestor (excluding the NPC's
## own packed scene) that is an instanced scene root. Empty when hosted in a
## code-built tree (unit-test worlds) — routines then never apply.
func _containing_scene_path() -> String:
	var node: Node = get_parent()
	while node != null:
		if not node.scene_file_path.is_empty():
			return node.scene_file_path
		node = node.get_parent()
	return ""


func _on_world_phase_changed(
	_previous: StringName, _current: StringName, _cause: String
) -> void:
	_refresh_world_state()


func _on_reaction_flag_changed(_flag: String, _value: Variant) -> void:
	if NpcReactions.has_reaction(_stable_actor_id()):
		_refresh_world_state()


func _on_reaction_reputation_changed(
	_faction: String, _standing: float, _event: ReputationEvent
) -> void:
	if NpcReactions.has_reaction(_stable_actor_id()):
		_refresh_world_state()


func _refresh_world_state() -> void:
	# PRECEDENCE: the routine chooses WHERE; the reaction chooses WHETHER and
	# WHAT dialogue. Apply the routine first so a matching reaction's presence
	# verdict wins without discarding a present routine's authored position.
	# `_stable_actor_id()`, not `npc_id`: TownNpcSpawner hands its 60 generated
	# townsfolk their identity as node META, never as the exported property, so
	# reading `npc_id` here saw "" for every one of them — no routine and no
	# reaction could ever reach a spawned NPC. The quest router already resolved
	# identity this way; the world-state path now agrees with it.
	var actor_id := _stable_actor_id()
	var has_routine := NpcRoutines.has_routine(actor_id)
	var has_reaction := NpcReactions.has_reaction(actor_id)
	var routine_placed := false
	if has_routine:
		routine_placed = _apply_routine()
	elif has_reaction:
		_restore_authored_presence()
	if has_reaction:
		_apply_reaction()
		# A reaction may make an NPC present in a phase whose routine row says
		# absent — and an absent row carries no position. Without an anchor the
		# NPC would simply keep wherever it last stood, so arrival HISTORY, not
		# the routine, would decide where it is: a fresh night load and an
		# evening→night transition would place the same NPC differently. Fall
		# back to the authored position so the placement is deterministic and
		# the precedence rule still holds — the routine (or its absence)
		# decides WHERE, the reaction only decides WHETHER.
		if visible and not routine_placed:
			GridPlacement.snap_to_walkable_cell(self, _authored_position)


## Returns true when the routine supplied an authored position this refresh.
func _apply_routine() -> bool:
	var actor_id := _stable_actor_id()
	if actor_id.is_empty():
		return false
	var row := NpcRoutines.placement(actor_id, WorldClock.phase())
	if row.is_empty():
		return false
	# Routine positions are HUB_SCENE coordinates; never apply them elsewhere.
	# Judge by the scene THIS NPC lives in, not get_tree().current_scene — under
	# the test harness current_scene is the runner (or null), which let hub
	# routines clobber interior placements (the 3 pre-2026-08-31
	# test_interior_population failures).
	if _containing_scene_path() != NpcRoutines.HUB_SCENE:
		return false
	var present := bool(row.get("present", false))
	if present:
		var routine_position: Vector2 = row["position"]
		GridPlacement.snap_to_walkable_cell(self, routine_position)
	_set_present(present)
	return present


func _apply_reaction() -> void:
	_reaction_dialogue_path = ""
	_reaction_dialogue_start = ""
	dialogue_path = _authored_dialogue_path
	dialogue_start = _authored_dialogue_start
	var reaction := NpcReactions.resolve(_stable_actor_id())
	if reaction.is_empty():
		return
	if reaction.has("present"):
		_set_present(bool(reaction["present"]))
	var path := str(reaction.get("dialogue_path", ""))
	if not path.is_empty():
		_reaction_dialogue_path = path
		_reaction_dialogue_start = str(reaction["dialogue_title"])
		dialogue_path = _reaction_dialogue_path
		dialogue_start = _reaction_dialogue_start


func _restore_authored_presence() -> void:
	visible = _authored_visible
	collision_layer = _collision_layer_default
	process_mode = _authored_process_mode
	if visible and collision_layer > 0:
		NavOccupancy.register(self)


func _set_present(present: bool) -> void:
	visible = present
	if present:
		collision_layer = _collision_layer_default
		process_mode = Node.PROCESS_MODE_INHERIT
		NavOccupancy.register(self)
		return
	# Absent means not findable, interactable, solid, or nav-occupying.
	collision_layer = 0
	process_mode = Node.PROCESS_MODE_DISABLED
	remove_from_group(NavOccupancy.GROUP)
	_player_in_range = false
	_prompt.visible = false


func _on_body(body: Node2D, entered: bool) -> void:
	if body is Player:
		_player_in_range = entered
		_prompt.visible = entered


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("steal") and not get_tree().paused:
		get_viewport().set_input_as_handled()
		attempt_pickpocket()
		_prompt.text = _prompt_text()
		return
	if _player_in_range and event.is_action_pressed("interact") and not get_tree().paused:
		get_viewport().set_input_as_handled()
		if not vendor_id.is_empty():
			var shop_screen := UIManager.open(UIManager.SHOP, true)
			shop_screen.call("configure_vendor", vendor_id)
			return
		var route: Dictionary = _resolved_dialogue_route()
		var dialogue: DialogueResource = route.get("resource") as DialogueResource
		var resolved_title: String = str(route.get("title", "start"))
		if dialogue == null and str(route.get("error", "")) == "unreadable":
			push_error(_dialogue_load_failure_message(route))
			return
		if dialogue == null:
			push_error("NPC '%s' has no dialogue resource." % npc_name)
			return
		DialogueManager.show_dialogue_balloon(dialogue, resolved_title)


## Whether this NPC carries a pocket at all. An NPC with no `pocket_id` is not
## robbable and never shows the prompt.
func has_pocket() -> bool:
	return not pocket_id.is_empty()


func pocket_lifted_flag() -> String:
	return "pocket_lifted_%s" % pocket_id


func pocket_failed_flag() -> String:
	return "pocket_failed_%s" % pocket_id


## True while the pocket is still worth trying: it exists and has neither been
## lifted nor been fumbled.
func pocket_is_live() -> bool:
	return (
		has_pocket()
		and not GameState.flag_is_true(pocket_lifted_flag())
		and not GameState.flag_is_true(pocket_failed_flag())
	)


## ONE COMMITTED ATTEMPT, matching the skill-locked containers of #414. Either
## outcome closes the pocket for good.
##
## The alternative — retry until it works — makes the skill decorative: any
## `slip` above zero eventually lifts every pocket in Dom, so the check stops
## being a decision and becomes a delay. Committing also removes the incentive
## to reload, which matters more here than on a chest: a caught thief pays in
## reputation, and a consequence a player can undo by pressing F5 is not one.
## `forced_rolls` is passed straight through to `SkillCheck.resolve`, which
## already exposes it for exactly this reason: the check is capped at
## MAX_EFFECTIVE_PERCENT, so no modifier can make either outcome certain and
## neither branch is testable without pinning the die.
func attempt_pickpocket(forced_rolls: Array[int] = []) -> Dictionary:
	if not has_pocket():
		return {"attempted": false, "success": false, "reason": "no_pocket"}
	if GameState.flag_is_true(pocket_lifted_flag()):
		return {"attempted": false, "success": true, "reason": "already_lifted"}
	if GameState.flag_is_true(pocket_failed_flag()):
		return {"attempted": false, "success": false, "reason": "already_failed"}
	if not DramgidSchema.is_skill(pocket_skill):
		# Deliberately the opposite of #414's unknown-lock-skill fallback, which
		# OPENS the lock. There the player loses content to an authoring typo; here
		# they would gain loot and take no risk from one. An unrobbable NPC is the
		# safe direction, and the warning names the author's mistake either way.
		push_warning(
			"NPC '%s' authors unknown pocket skill '%s'; the pocket stays shut."
			% [npc_name, pocket_skill]
		)
		return {"attempted": false, "success": false, "reason": "unknown_skill"}

	var check: Dictionary = SkillCheck.resolve(
		pocket_skill, null, pocket_modifier, "pocket-%s" % pocket_id, forced_rolls
	)
	var succeeded := bool(check.get("success", false))
	GameState.set_flag(pocket_lifted_flag() if succeeded else pocket_failed_flag(), true)
	var result := {"attempted": true, "success": succeeded, "check": check}
	if succeeded:
		result["taken"] = _grant_pocket_contents()
	else:
		_record_caught()
	return result


## Grants what the pocket held. Reports what actually landed rather than what was
## authored: a full GLoot grid must not silently eat the item and still read as a
## clean lift.
func _grant_pocket_contents() -> Dictionary:
	var taken := {"gp": 0, "item_id": ""}
	if pocket_gp > 0:
		GameState.earn_gp(pocket_gp)
		taken["gp"] = pocket_gp
	if not pocket_item_id.is_empty():
		var added: InventoryItem = GameState.inventory.create_and_add_item(pocket_item_id)
		if added != null:
			taken["item_id"] = pocket_item_id
		else:
			push_warning(
				"NPC '%s' pocket item '%s' did not fit the inventory." % [npc_name, pocket_item_id]
			)
	return taken


## PROVISIONAL magnitudes — #284 hands numeric values to DeepSeek. The SHAPE is
## the decision: getting caught is a consequence written to the ledgers, not a
## message and a shrug. Infamy always, faction reputation only when the NPC has
## an affiliation to be indignant on behalf of.
const CAUGHT_INFAMY := 4.0
const CAUGHT_REPUTATION_DELTA := -3.0


func _record_caught() -> void:
	var scene := _containing_scene_path()
	Renown.gain_infamy("player", CAUGHT_INFAMY, "Caught with a hand in a pocket.", scene)
	if not pocket_faction.is_empty():
		Reputation.record(
			"player",
			pocket_faction,
			CAUGHT_REPUTATION_DELTA,
			"Caught stealing from %s." % npc_name,
			scene
		)


func _prompt_text() -> String:
	var primary := "E — Trade" if not vendor_id.is_empty() else "E — Talk"
	return "%s    F — Steal" % primary if pocket_is_live() else primary


func _resolved_dialogue_route() -> Dictionary:
	var route: Dictionary = QuestRegistry.dialogue_route_for_actor(
		_stable_actor_id(), dialogue_path, dialogue_start
	)
	if not _reaction_dialogue_path.is_empty():
		var resource: Resource = ResourceLoader.load(
			_reaction_dialogue_path, "", ResourceLoader.CACHE_MODE_REUSE
		)
		return {
			"resource": resource as DialogueResource,
			"title": _reaction_dialogue_start,
			"error": "" if resource is DialogueResource else "unreadable",
			"source": _reaction_dialogue_path,
		}
	return route


func _dialogue_load_failure_message(route: Dictionary) -> String:
	# `source` is the route's diagnostic-only provenance: a res:// path for
	# committed dialogue, the package .dialogue file for a compiled campaign one.
	# Never load from it — the route's `resource` is the only load path.
	var source: String = str(route.get("source", ""))
	if not source.is_empty():
		return "NPC '%s' could not load dialogue '%s'." % [npc_name, source]
	var resolved_title: String = str(route.get("title", "start"))
	return (
		"NPC '%s' could not load dialogue title '%s' from an unidentified resource."
		% [npc_name, resolved_title]
	)


func _stable_actor_id() -> String:
	if not npc_id.is_empty():
		return npc_id
	return str(get_meta(&"npc_id", ""))


func _apply_visual_identity() -> void:
	# A scene-authored npc_id (e.g. the hand-placed story NPCs in
	# starting_town.tscn) self-wires to its own generated unit art here;
	# TownNpcSpawner-driven NPCs get theirs later via apply_isometric_visual.
	if not npc_id.is_empty() and apply_isometric_visual(npc_id):
		return
	var sprite := $Sprite2D as Sprite2D
	if sprite == null:
		return
	sprite.region_rect = visual_region
	sprite.modulate = visual_modulate
	if sprite.has_meta(&"unit_art_world_scaled"):
		# A spawner already dressed and world-scaled this sprite before it
		# entered the tree — re-imposing visual_scale would undo the shrink.
		return
	sprite.scale = visual_scale
	UnitArtScript.apply_world_scale(sprite, get_node_or_null("Shadow"))


func apply_isometric_visual(model_name: String, facing: String = "east") -> bool:
	var resolved_id := UnitArtScript.resolve(model_name)
	var texture := load(UnitArtScript.texture_path(resolved_id)) as Texture2D
	if texture == null:
		push_error("Could not load generated NPC sprite for '%s'." % model_name)
		return false
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		push_error("NPC '%s' is missing its Sprite2D presentation node." % npc_name)
		return false
	visual_modulate = Color.WHITE
	visual_scale = Vector2.ONE
	sprite.texture = texture
	sprite.region_enabled = false
	sprite.position = Vector2.ZERO
	sprite.offset = UnitArtScript.PIVOT_OFFSET
	sprite.scale = Vector2.ONE
	sprite.modulate = Color.WHITE
	sprite.flip_h = facing == "west"
	# Absolutes above reset any prior application — clear the guard so the
	# world scale re-applies to the fresh unscaled state.
	if sprite.has_meta(&"unit_art_world_scaled"):
		sprite.remove_meta(&"unit_art_world_scaled")
	UnitArtScript.apply_world_scale(sprite, get_node_or_null("Shadow"))
	return true
