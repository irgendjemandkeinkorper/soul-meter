extends Node
## Debug-build-only state console coordinator. Without explicit opt-in it is inert.

signal log_changed

const DEBUG_CAUSE_PREFIX := "[debug] "
## Durable, write-once tamper marker: any save the console touched carries it,
## so debug-mutated state is never mistaken for honest play. Deliberately not
## settable from the console itself — see _command_flag().
const USED_FLAG := "dev_console_used"
const DEV_CONSOLE_SCENE: PackedScene = preload("res://ui/debug/dev_console.tscn")
# PROVISIONAL owner surface: F1 may move after facilitator playtesting.
const TOGGLE_HOTKEY: Key = KEY_F1

var force_enabled_for_tests: bool = false:
	set(value):
		force_enabled_for_tests = value
		_refresh_activation()

var _enabled: bool = false
var _overlay_layer: CanvasLayer = null
var _previous_paused: bool = false
var _log_entries: Array[Dictionary] = []
var _history: Array[String] = []
var _history_cursor: int = 0
var _command_audit: Array[String] = []
var _session_marked_used: bool = false


static func is_debug_caused(cause: String) -> bool:
	return cause.begins_with(DEBUG_CAUSE_PREFIX)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_key_input(false)
	_refresh_activation()


func _exit_tree() -> void:
	close_console()


func _unhandled_key_input(event: InputEvent) -> void:
	if not _enabled or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode != TOGGLE_HOTKEY and key_event.keycode != TOGGLE_HOTKEY:
		return
	if _overlay_layer == null:
		open_console()
	else:
		close_console()
	get_viewport().set_input_as_handled()


func open_console() -> void:
	if not _enabled or _overlay_layer != null:
		return
	_previous_paused = get_tree().paused
	get_tree().paused = true
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "DevConsoleLayer"
	_overlay_layer.layer = 1100
	_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay_layer)
	var overlay: Control = DEV_CONSOLE_SCENE.instantiate() as Control
	overlay.name = "DevConsoleOverlay"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay_layer.add_child(overlay)
	overlay.call("configure", self)


func close_console() -> void:
	if _overlay_layer == null:
		return
	var layer: CanvasLayer = _overlay_layer
	_overlay_layer = null
	remove_child(layer)
	layer.free()
	get_tree().paused = _previous_paused


func execute_command(raw_command: String) -> bool:
	if not _enabled:
		return false
	var command := raw_command.strip_edges()
	if command.is_empty():
		_append_error("Enter a command. Type 'help' for the command list.")
		return false
	_history.append(command)
	_history_cursor = _history.size()
	_command_audit.append(command)
	_append_line("> %s" % command)
	_mark_session_used()
	_record_playtest_interference(command)

	var args := command.split(" ", false)
	var verb := args[0].to_lower()
	match verb:
		"flag":
			return _command_flag(args)
		"flags":
			return _command_flags(args)
		"soul":
			return _command_soul(args)
		"gp":
			return _command_gp(args)
		"rep":
			return _command_rep(args)
		"standing":
			return _command_standing(args)
		"why":
			return _command_why(args)
		"renown", "infamy":
			return _command_renown(args, verb)
		"item":
			return _command_item(args)
		"quest":
			return _command_quest(args)
		"phase":
			return _command_phase(args)
		"goto":
			return _command_goto(args)
		"help":
			if args.size() != 1:
				return _usage("help")
			_append_line("flag <name> [true|false]  |  flags [filter]")
			_append_line("soul <value>  |  gp <value>")
			_append_line("rep <faction> <delta>  |  standing <faction>")
			_append_line("renown <delta>  |  infamy <delta>")
			_append_line("why <faction|renown|infamy>")
			_append_line("item <item_id> [count]")
			_append_line("quest offer <quest_id>")
			_append_line("quest complete <quest_id> (unavailable: provenance guard)")
			_append_line("phase <morning|afternoon|evening|night|next>")
			_append_line("goto <scene-or-hub-id>  |  help  |  clear")
			return true
		"clear":
			if args.size() != 1:
				return _usage("clear")
			_log_entries.clear()
			_append_line("Cleared console log.")
			return true
		_:
			_append_error("Unknown command '%s'. Type 'help' for the command list." % args[0])
			return false


func _command_flag(args: PackedStringArray) -> bool:
	if args.size() < 2 or args.size() > 3 or args[1].is_empty():
		return _usage("flag <name> [true|false]")
	# The tamper marker exists so a debug-touched save can never look clean.
	# The console must not be able to erase its own evidence — and the
	# once-per-session guard in _mark_session_used() means a cleared marker
	# would never be re-set.
	if args[1] == USED_FLAG:
		return _refuse(
			"'%s' is the debug tamper marker and cannot be set from the console." % USED_FLAG
		)
	var value := true
	if args.size() == 3:
		var normalized := args[2].to_lower()
		if normalized not in ["true", "false"]:
			return _usage("flag <name> [true|false]")
		value = normalized == "true"
	GameState.set_flag(args[1], value)
	var stored: Variant = GameState.get_flag(args[1], false)
	_append_line("Set flag %s = %s." % [args[1], str(stored)])
	return true


func _command_flags(args: PackedStringArray) -> bool:
	if args.size() > 2:
		return _usage("flags [filter]")
	var filter := args[1].to_lower() if args.size() == 2 else ""
	var names: Array[String] = []
	for key: Variant in GameState.flags.keys():
		var flag_name := str(key)
		if filter.is_empty() or filter in flag_name.to_lower():
			names.append(flag_name)
	names.sort()
	if names.is_empty():
		_append_line("No flags match '%s'." % filter if not filter.is_empty() else "No flags are set.")
		return true
	_append_line("Flags (%d):" % names.size())
	for flag_name: String in names:
		var value: Variant = GameState.get_flag(flag_name, false)
		_append_line("%s = %s" % [flag_name, str(value)])
	return true


func _command_soul(args: PackedStringArray) -> bool:
	if args.size() != 2 or not args[1].is_valid_float():
		return _usage("soul <value>")
	var value := args[1].to_float()
	if is_nan(value) or is_inf(value):
		return _usage("soul <value>")
	GameState.set_soul_meter(value)
	_append_line("Set Soul Meter to %s." % GameState.soul_meter)
	return true


func _command_gp(args: PackedStringArray) -> bool:
	if args.size() != 2 or not args[1].is_valid_int():
		return _usage("gp <value>")
	GameState.set_gp(args[1].to_int())
	_append_line("Set GP to %d." % GameState.gp)
	return true


func _command_rep(args: PackedStringArray) -> bool:
	if args.size() != 3 or not args[2].is_valid_float():
		return _usage("rep <faction> <delta>")
	var faction := args[1]
	if not _is_known_faction(faction):
		_append_error("Unknown faction '%s'." % faction)
		return false
	var delta := args[2].to_float()
	if is_nan(delta) or is_inf(delta):
		return _usage("rep <faction> <delta>")
	var cause := DEBUG_CAUSE_PREFIX + "console rep %s %s" % [faction, _signed(delta)]
	Reputation.record("player", faction, delta, cause)
	_append_line(
		"Recorded %s reputation %s; standing is %s. Cause: %s"
		% [faction, _signed(delta), Reputation.standing(faction), cause]
	)
	return true


func _command_standing(args: PackedStringArray) -> bool:
	if args.size() != 2:
		return _usage("standing <faction>")
	var faction := args[1]
	if not _is_known_faction(faction):
		_append_error("Unknown faction '%s'." % faction)
		return false
	_append_line("%s standing: %s (%s)." % [
		faction, Reputation.standing(faction), Reputation.band(faction)
	])
	return true


func _command_why(args: PackedStringArray) -> bool:
	if args.size() != 2:
		return _usage("why <faction|renown|infamy>")
	var target := args[1].to_lower()
	if target == "renown":
		return _show_renown_reasons(&"reputation", "renown")
	if target == "infamy":
		return _show_renown_reasons(&"infamy", "infamy")
	if not _is_known_faction(target):
		_append_error("Unknown faction '%s'." % target)
		return false
	var events: Array[ReputationEvent] = Reputation.why(target)
	if events.is_empty():
		_append_line("No recorded reasons for %s." % target)
		return true
	_append_line("Why %s:" % target)
	for event: ReputationEvent in events:
		_append_line("%s %s — %s" % [_signed(event.delta), event.scene, event.cause])
	return true


func _command_renown(args: PackedStringArray, kind: String) -> bool:
	if args.size() != 2 or not args[1].is_valid_float():
		return _usage("%s <delta>" % kind)
	var delta := args[1].to_float()
	if is_nan(delta) or is_inf(delta):
		return _usage("%s <delta>" % kind)
	var cause := DEBUG_CAUSE_PREFIX + "console %s %s" % [kind, _signed(delta)]
	if kind == "renown":
		Renown.gain_reputation("player", delta, cause)
		_append_line("Recorded renown %s; total is %s. Cause: %s" % [
			_signed(delta), Renown.reputation(), cause
		])
	else:
		Renown.gain_infamy("player", delta, cause)
		_append_line("Recorded infamy %s; total is %s. Cause: %s" % [
			_signed(delta), Renown.infamy(), cause
		])
	return true


func _show_renown_reasons(kind: StringName, label: String) -> bool:
	var events: Array[RenownEvent] = Renown.why(kind)
	if events.is_empty():
		_append_line("No recorded reasons for %s." % label)
		return true
	_append_line("Why %s:" % label)
	for event: RenownEvent in events:
		_append_line("%s %s — %s" % [_signed(event.delta), event.scene, event.cause])
	return true


func _command_item(args: PackedStringArray) -> bool:
	if args.size() < 2 or args.size() > 3:
		return _usage("item <item_id> [count]")
	var item_id := args[1]
	if not _is_known_item(item_id):
		_append_error("Unknown item '%s'." % item_id)
		return false
	var count := 1
	if args.size() == 3:
		if not args[2].is_valid_int() or args[2].to_int() <= 0:
			return _usage("item <item_id> [count]")
		count = args[2].to_int()
	for index: int in range(count):
		var added: InventoryItem = GameState.inventory.create_and_add_item(item_id)
		if added == null:
			_append_error("Inventory refused item '%s' after %d added." % [item_id, index])
			return false
	_append_line("Added %d × %s; inventory now has %d." % [
		count, item_id, GameState.item_count(item_id)
	])
	return true


func _command_quest(args: PackedStringArray) -> bool:
	if args.size() != 3 or args[1] not in ["offer", "complete"]:
		return _usage("quest offer|complete <quest_id>")
	if not args[2].is_valid_int():
		return _usage("quest offer|complete <quest_id>")
	var quest := _quest_for_id(args[2].to_int())
	if quest == null:
		_append_error("Unknown quest id '%s'." % args[2])
		return false
	if args[1] == "complete":
		_append_error(
			"Quest completion is unavailable: QuestRegistry.debug_force_complete() cannot "
			+ "accept tagged provenance for consequence-ledger writes."
		)
		return false
	# QuestRegistry.offer() is a no-op on an already-completed quest (its
	# side-effect block is guarded by `newly_started`), so reporting success
	# would tell the operator a state was reached that was not.
	if QuestRegistry.is_done(quest):
		return _refuse(
			"Quest %d (%s) is already completed; offer() will not reopen it."
			% [quest.id, quest.quest_name]
		)
	var already_active := QuestRegistry.is_active(quest)
	QuestRegistry.offer(quest)
	if already_active:
		_append_line("Quest %d: %s was already active." % [quest.id, quest.quest_name])
	else:
		_append_line("Offered quest %d: %s." % [quest.id, quest.quest_name])
	return true


func _command_phase(args: PackedStringArray) -> bool:
	if args.size() != 2:
		return _usage("phase <morning|afternoon|evening|night|next>")
	var requested := StringName(args[1].to_lower())
	if requested == &"next":
		var next: StringName = WorldClock.advance(DEBUG_CAUSE_PREFIX + "console phase next")
		_append_line("Advanced world phase to %s." % next)
		return true
	if not WorldClock.PHASES.has(requested):
		return _usage("phase <morning|afternoon|evening|night|next>")
	var changed: bool = WorldClock.set_phase(
		requested, DEBUG_CAUSE_PREFIX + "console phase %s" % requested
	)
	if not changed:
		_append_error("WorldClock refused phase '%s'." % requested)
		return false
	_append_line("Set world phase to %s." % WorldClock.phase())
	return true


func _command_goto(args: PackedStringArray) -> bool:
	if args.size() != 2:
		return _usage("goto <scene-or-hub-id>")
	var target := args[1]
	var location: LocationDefinition = LocationRegistry.by_id(StringName(target))
	if location == null:
		location = LocationRegistry.by_scene(target)
	var scene_path := target
	if location != null:
		if not location.allowed_gameplay:
			_append_error("Location '%s' is not a gameplay destination." % target)
			return false
		scene_path = location.scene_path
	elif not GameFlow.GAMEPLAY_SCENES.has(target):
		_append_error("Unknown gameplay scene or location id '%s'." % target)
		return false
	var traveled: bool = GameFlow.travel(scene_path)
	if not traveled:
		_append_error("GameFlow refused travel to '%s'." % scene_path)
		return false
	_append_line("Requested GameFlow travel to %s." % scene_path)
	return true


func _quest_for_id(quest_id: int) -> Quest:
	for quest: Quest in QuestRegistry.ALL_QUESTS:
		if quest.id == quest_id:
			return quest
	return null


func _is_known_faction(faction: String) -> bool:
	return _script_constants_contain(FactionIds as Script, faction)


func _is_known_item(item_id: String) -> bool:
	return _script_constants_contain(ItemIds as Script, item_id)


func _script_constants_contain(script: Script, expected: String) -> bool:
	var constants: Dictionary = script.get_script_constant_map()
	for value: Variant in constants.values():
		if value is String and value == expected:
			return true
	return false


func _signed(value: float) -> String:
	return ("+" if value >= 0.0 else "") + str(value)


func log_entries() -> Array[Dictionary]:
	return _log_entries.duplicate(true)


func last_log_entry() -> Dictionary:
	if _log_entries.is_empty():
		return {}
	return _log_entries.back().duplicate(true)


func commands_run() -> Array[String]:
	return _command_audit.duplicate()


func history_previous() -> String:
	if _history.is_empty():
		return ""
	_history_cursor = maxi(0, _history_cursor - 1)
	return _history[_history_cursor]


func history_next() -> String:
	if _history.is_empty():
		return ""
	_history_cursor = mini(_history.size(), _history_cursor + 1)
	if _history_cursor == _history.size():
		return ""
	return _history[_history_cursor]


func _refresh_activation() -> void:
	if not is_inside_tree():
		return
	var should_enable: bool = OS.is_debug_build() and (
		OS.get_environment("SOUL_METER_DEV_CONSOLE") == "1" or force_enabled_for_tests
	)
	if should_enable == _enabled:
		return
	_enabled = should_enable
	set_process_unhandled_key_input(_enabled)
	if _enabled:
		_begin_session()
	else:
		close_console()


func _begin_session() -> void:
	_log_entries.clear()
	_history.clear()
	_history_cursor = 0
	_command_audit.clear()
	_session_marked_used = false


func _mark_session_used() -> void:
	if _session_marked_used:
		return
	_session_marked_used = true
	GameState.set_flag("dev_console_used", true)


func _record_playtest_interference(command: String) -> void:
	var recorder: Node = get_node_or_null("/root/PlaytestRecorder")
	if recorder == null or not recorder.has_method("append_event"):
		return
	recorder.call("append_event", &"dev_console_command", {"command": command})


func _append_line(text: String) -> void:
	_log_entries.append({"text": text, "error": false})
	log_changed.emit()


func _append_error(text: String) -> void:
	_log_entries.append({"text": "ERROR: %s" % text, "error": true})
	log_changed.emit()


func _usage(command: String) -> bool:
	_append_error("Bad arguments for '%s'. Type 'help' for usage." % command)
	return false


## A well-formed command the console deliberately declines to perform.
func _refuse(reason: String) -> bool:
	_append_error(reason)
	return false
