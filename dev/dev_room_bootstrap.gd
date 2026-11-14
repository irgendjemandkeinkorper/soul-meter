extends Node
## GameFlow owns this session across room changes. Title entry restores and disarms it.

const PRESET_PATH := "res://dev/dev_room_preset.tres"
const LOCATION_ID := &"dev-room"
const Art := preload("res://ui/screens/chargen/chargen_art_resolver.gd")

var _sandbox := WeftluminSandbox.new()
var _registered := false


func begin(scene_path: String, preset: Resource = null) -> bool:
	if not OS.is_debug_build() or SaveGame.runtime_sandbox_is_armed() or Battle.session_active:
		return false
	if preset == null:
		preset = ResourceLoader.load(PRESET_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if preset == null:
		return false
	var error: String = preset.validation_error()
	if not error.is_empty():
		push_warning("DEV preset: " + error)
		return false
	_sandbox.add_default_surfaces(SaveGame, SkillCheck)
	_sandbox.arm(&"dev-room")
	SaveGame.new_game()
	# The normal new-game entry retains some optional roster/equipment state.
	# Reset those through the public serializer before applying this fresh fixture.
	var fresh := GameState.to_dict()
	fresh["custom_recruits"] = []
	fresh["equipped_slots"] = {}
	if not GameState.from_dict(fresh):
		finish()
		return false
	var build: ChargenBuild = preset.character_build()
	var protagonist := build.to_party_member()
	protagonist.portrait = Art.portrait_texture(build.likeness_id)
	GameState.set_party([])
	GameState.apply_created_character(protagonist)
	Advancement.seed_creation_ledger(protagonist, build.creation_ledger_rows())
	while protagonist.level < int(preset.level):
		Advancement.award_xp(protagonist, Advancement.xp_for_next_level(protagonist.level))
	Advancement.award_xp(protagonist, int(preset.xp))
	var party: Array[PartyMember] = [protagonist]
	var candidates := GameState.recruitable_candidates()
	for id: String in preset.companion_ids:
		for candidate: PartyMember in candidates:
			if candidate.id == id:
				party.append(candidate)
	GameState.set_party(party)
	GameState.inventory.clear()
	for item_id: String in preset.items:
		var remaining: int = int(preset.items[item_id])
		while remaining > 0:
			var item := GameState.inventory.create_and_add_item(item_id)
			if item == null:
				finish()
				return false
			var count := mini(remaining, item.get_max_stack_size())
			item.set_stack_size(count)
			remaining -= count
	GameState.set_gp(int(preset.silver))
	GameState.set_soul_meter(float(preset.soul))
	for flag: String in preset.flags:
		GameState.set_flag(flag)
	# new_game stages its initial checkpoint directly; discard it while contained.
	SaveGame.flush_pending_autosave()
	var location := LocationDefinition.new()
	location.id = LOCATION_ID
	location.scene_path = scene_path
	location.respawn_policy = "none"
	_registered = LocationRegistry.register_runtime(location)
	if not _registered:
		finish()
	return _registered


func finish() -> void:
	if _sandbox.is_armed():
		# Quit-to-title can happen while paused in a fight. Release it before rollback
		# so unloading the old field cannot apply late combat consequences.
		Battle.abandon()
		SaveGame.flush_pending_autosave()
		var result := _sandbox.disarm()
		if not bool(result["allowed"]):
			push_error("DEV rollback failed: " + str(result["message"]))
	if _registered:
		LocationRegistry.unregister_runtime(LOCATION_ID)
		_registered = false


func _exit_tree() -> void:
	finish()
