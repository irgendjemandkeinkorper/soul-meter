extends GdUnitTestSuite
## #330 skeleton: E2.1 must lift the literal suite gate after adding the real bootstrap.
## Activation only; shell/panel lifecycle follows in E2. No absent shell API is called.
## Run with an isolated, initially clean user-data root. Never delete scratch to pass.

const BOOTSTRAP_PATH := "/root/WeftluminBootstrap"
const ENV_FLAG := "SOUL_METER_WEFTLUMIN"
const TOGGLE_ACTION := &"weftlumin_toggle"
const SCRATCH_PATH := "user://weftlumin"

var _env_existed: bool = false
var _env_value: String = ""
var _force_before: bool = false
var _restore_activation: bool = false


@warning_ignore("unused_parameter")
func before(do_skip: bool = true, skip_reason: String = "E2.1 pending: real WeftluminBootstrap required; see docs/weftlumin-test-migration.md") -> void:
	pass


func before_test() -> void:
	_env_existed = OS.has_environment(ENV_FLAG)
	_env_value = OS.get_environment(ENV_FLAG)
	_restore_activation = false
	var bootstrap: Node = get_node_or_null(BOOTSTRAP_PATH)
	if bootstrap == null or not _has_activation_seam(bootstrap):
		return
	_force_before = bool(bootstrap.get("force_enabled_for_tests"))
	_restore_activation = true
	OS.set_environment(ENV_FLAG, "0")
	bootstrap.set("force_enabled_for_tests", false)
	await get_tree().process_frame


func after_test() -> void:
	if _env_existed:
		OS.set_environment(ENV_FLAG, _env_value)
	else:
		OS.unset_environment(ENV_FLAG)
	var bootstrap: Node = get_node_or_null(BOOTSTRAP_PATH)
	if _restore_activation and bootstrap != null:
		bootstrap.set("force_enabled_for_tests", _force_before)
		await get_tree().process_frame


@warning_ignore("unused_parameter")
func test_bootstrap_is_inert(cycle_enabled: bool, test_parameters := [[false], [true]]) -> void:
	var bootstrap: Node = get_node_or_null(BOOTSTRAP_PATH)
	assert_object(bootstrap).override_failure_message("E2.1 must register the real bootstrap").is_not_null()
	if bootstrap == null:
		return
	assert_bool(_has_activation_seam(bootstrap)).override_failure_message(
		"E2.1 must implement the specified force_enabled_for_tests activation setter"
	).is_true()
	if not _has_activation_seam(bootstrap):
		return

	var before_state: Dictionary = _inert_state(bootstrap)
	_assert_disabled(before_state)
	if cycle_enabled:
		bootstrap.set("force_enabled_for_tests", true)
		await get_tree().process_frame
		assert_bool(InputMap.has_action(TOGGLE_ACTION)).override_failure_message(
			"The enabled-then-disabled case must actually activate the bootstrap"
		).is_true()
		bootstrap.set("force_enabled_for_tests", false)
		await get_tree().process_frame

	var after_state: Dictionary = _inert_state(bootstrap)
	_assert_disabled(after_state)
	assert_dict(after_state).is_equal(before_state)


func _assert_disabled(state: Dictionary) -> void:
	assert_int(int(state["children"])).is_equal(0)
	assert_bool(bool(state["unhandled_key"])).is_false()
	assert_bool(bool(state["toggle_action"])).is_false()
	assert_bool(bool(state["scratch_dir"])).is_false()
	assert_array(state["weftlumin_connections"]).is_empty()


func _inert_state(bootstrap: Node) -> Dictionary:
	return {
		"children": bootstrap.get_child_count(),
		"unhandled_key": bootstrap.is_processing_unhandled_key_input(),
		"toggle_action": InputMap.has_action(TOGGLE_ACTION),
		"scratch_dir": DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCRATCH_PATH)),
		"weftlumin_connections": _production_connections_to_weftlumin(bootstrap),
	}


func _production_connections_to_weftlumin(bootstrap: Node) -> Array[String]:
	var offenders: Array[String] = []
	var pending: Array[Node] = [get_tree().root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node == bootstrap or bootstrap.is_ancestor_of(node) or _is_weftlumin_object(node):
			continue
		for signal_info: Dictionary in node.get_signal_list():
			var signal_name: StringName = StringName(signal_info.get("name", ""))
			for connection: Dictionary in node.get_signal_connection_list(signal_name):
				var callback: Callable = connection.get("callable", Callable())
				if not callback.is_null() and _is_weftlumin_object(callback.get_object()):
					offenders.append("%s.%s" % [String(node.get_path()), String(signal_name)])
		for child: Node in node.get_children():
			pending.append(child)
	offenders.sort()
	return offenders


func _is_weftlumin_object(target: Object) -> bool:
	if not is_instance_valid(target):
		return false
	var script: Script = target.get_script() as Script
	while script != null:
		var path: String = script.resource_path
		if path.begins_with("res://addons/weftlumin/") or path.begins_with("res://weftlumin/"):
			return true
		script = script.get_base_script()
	return false


func _has_activation_seam(bootstrap: Node) -> bool:
	for property: Dictionary in bootstrap.get_property_list():
		if String(property.get("name", "")) == "force_enabled_for_tests":
			return int(property.get("type", TYPE_NIL)) == TYPE_BOOL
	return false
