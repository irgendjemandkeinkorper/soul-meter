class_name Chest
extends SMInteractable
## A reusable loot container. Interaction policy stays in SMInteractable; this
## class only applies the chest-specific loot and visual state.
## Ownership consequence rule: the first successful take in each opened panel
## session writes one theft event. Further takes and Take All in that same session
## do not. Opening the container again begins a new session and may write again.

const CLOSED_TEXTURE_PATH := "res://assets/generated/sprites/world/objects/dom-chest-wood--closed.png"
const OPEN_TEXTURE_PATH := "res://assets/generated/sprites/world/objects/dom-chest-wood--open.png"
const PLACEHOLDER_TEXTURE_PATH := "res://assets/kenney/ui/fantasy-ui-borders/PNG/Default/Panel/panel-013.png"

@export var loot: Array[Dictionary] = []
@export var container_id: String = ""
@export var owned_by_faction: String = ""
## #284 verb 4. When set, contents are rolled from a LootTableRegistry table
## instead of the hand-authored `loot` list. Authored `loot` wins if both are
## present, so a set-piece container stays exactly as its author wrote it.
@export var loot_table_id: StringName = &""

@onready var _closed_sprite: Sprite2D = $ClosedSprite
@onready var _open_sprite: Sprite2D = $OpenSprite


func _ready() -> void:
	# #284: a container's `container_id` is already unique and durable, so it is
	# the natural lock id. Authoring both would be two ids for one crate.
	if lock_id.is_empty():
		lock_id = container_id
	GameState.ensure_loot_container(container_id, _base_contents())
	repeatable = true
	super._ready()
	_closed_sprite.texture = _texture_or_placeholder(CLOSED_TEXTURE_PATH)
	_open_sprite.texture = _texture_or_placeholder(OPEN_TEXTURE_PATH)
	_refresh_visual()


## The WEIGHTED half of a table, rolled once. `ensure_loot_container` writes a
## container's contents exactly once, so this is frozen from then on and survives
## save/load — the crate cannot be re-rolled by walking away, and two players on
## the same seed find the same thing in it.
func _base_contents() -> Array[Dictionary]:
	if not loot.is_empty() or loot_table_id == &"":
		return loot
	if not LootTableRegistry.has_table(loot_table_id):
		push_warning(
			"Chest '%s' names unknown loot table '%s'; it stays empty." % [name, loot_table_id]
		)
		return loot
	return LootTableRegistry.roll(
		loot_table_id, LootTableRegistry.seed_for_container(container_id)
	)


func searched_flag() -> String:
	return "loot_searched_%s" % container_id


## The GATED half, resolved on FIRST OPEN rather than at `_ready()`.
##
## Rolling it with the rest would decide the crate the moment the player entered
## the map — before they had seen it, using whatever their skill happened to be
## then, and with no way to know a check had ever occurred. A player who walked
## past at level 1 would find it silently settled at level 10.
##
## Resolved here it is still ONE committed attempt, the same rule the lock (#414)
## and the pocket (#417) follow, but the attempt happens when the player actually
## reaches in.
func _apply_table_search() -> void:
	if loot_table_id == &"" or not LootTableRegistry.has_table(loot_table_id):
		return
	if not loot.is_empty() or GameState.flag_is_true(searched_flag()):
		return
	GameState.set_flag(searched_flag(), true)
	var earned := LootTableRegistry.granted_rows(loot_table_id, _resolve_table_skills())
	if earned.is_empty():
		return
	var combined: Array[Dictionary] = []
	combined.append_array(GameState.loot_container_contents(container_id))
	combined.append_array(earned)
	GameState.set_loot_container_contents(container_id, combined)


## Resolves each skill the table gates a row behind, once. Doing it here rather
## than inside `roll()` keeps the registry pure and keeps the checks out of the
## draw loop, where they would be re-rolled per row.
func _resolve_table_skills() -> Dictionary:
	var outcomes := {}
	for skill: String in LootTableRegistry.skills_required(loot_table_id):
		if not DramgidSchema.is_skill(skill):
			push_warning(
				"Loot table '%s' gates a row behind unknown skill '%s'; the row is skipped."
				% [loot_table_id, skill]
			)
			outcomes[skill] = false
			continue
		var check: Dictionary = SkillCheck.resolve(
			skill,
			null,
			LootTableRegistry.modifier_for_skill(loot_table_id, skill),
			"loot-%s" % container_id
		)
		outcomes[skill] = bool(check.get("success", false))
	return outcomes


func _apply_interaction() -> void:
	if not interaction_flag.is_empty():
		GameState.set_flag(interaction_flag, true)
	_used = true
	_refresh_visual()
	_apply_table_search()
	var remaining := GameState.loot_container_contents(container_id)
	if remaining.is_empty():
		interaction_text = "EMPTY"
		_refresh_prompt()
		return
	GameState.begin_loot_container_session(container_id)
	var panel := UIManager.open(UIManager.LOOT_PANEL, true) as LootPanel
	panel.configure(display_name, remaining, container_id, owned_by_faction)
	panel.dismissed.connect(_on_loot_panel_dismissed, CONNECT_ONE_SHOT)


func _on_loot_panel_dismissed(_remaining: Array[Dictionary]) -> void:
	if GameState.loot_container_contents(container_id).is_empty():
		interaction_text = "EMPTY"
	_refresh_prompt()


func _refresh_prompt() -> void:
	if _prompt == null:
		return
	if not _is_unlocked():
		_prompt.text = "LOCKED — " + locked_message
	elif not container_id.is_empty() and GameState.loot_container_contents(container_id).is_empty():
		_prompt.text = "E — EMPTY"
	else:
		_prompt.text = "E — " + prompt_text


func _refresh_visual() -> void:
	var is_open := _used or (not interaction_flag.is_empty() and GameState.flag_is_true(interaction_flag))
	_closed_sprite.visible = not is_open
	_open_sprite.visible = is_open


func _texture_or_placeholder(path: String) -> Texture2D:
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)
	# The interactive-object art landed (dom-chest-wood--*); null now only means
	# a missing/corrupt file, and the caller keeps its drawn placeholder.
	return null
