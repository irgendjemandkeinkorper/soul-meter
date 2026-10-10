extends WeftluminGameAdapter
## Shell-local host bridge until the separately scoped authoring adapter exists.


func env_flag() -> String:
	return "SOUL_METER_WEFTLUMIN"


func theme() -> Theme:
	return UIManager.ui_theme


## Field HUDs the editor hid, with the visibility each had, so close restores exactly.
var _hidden_huds: Dictionary[CanvasLayer, bool] = {}


func set_editor_open(open: bool) -> void:
	GameFlow.set_editor_open(open)
	_set_field_huds_hidden(open)


## FieldHUD sits at layer 5, under the shell, and its hotkey bar shows through the dock's open
## top edge. It hides while editing, the same way FieldMap.set_combat_mode hides it in battle.
func _set_field_huds_hidden(hidden: bool) -> void:
	if not hidden:
		for hud: CanvasLayer in _hidden_huds:
			if is_instance_valid(hud):
				hud.visible = _hidden_huds[hud]
		_hidden_huds.clear()
		return
	for node: Node in GameFlow.get_tree().root.find_children("*", "CanvasLayer", true, false):
		var hud := node as CanvasLayer
		if hud.scene_file_path == FieldMap.FIELD_HUD_SCENE and not _hidden_huds.has(hud):
			_hidden_huds[hud] = hud.visible
			hud.visible = false


func gameplay_scene_root() -> Node:
	return GameFlow.get_tree().current_scene


func production_owner_live() -> bool:
	return Battle.session_active or DialogueLab.production_dialogue_is_live()


func capture_runtime_state() -> Dictionary:
	return SaveGame.capture_runtime_state()


func restore_runtime_state(snapshot: Dictionary) -> bool:
	return SaveGame.restore_runtime_state(snapshot)
