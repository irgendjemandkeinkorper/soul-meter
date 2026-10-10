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


## Soul Meter's tool panels (§4.1 `weftlumin/panels/`), in dock order. The directory is
## export-excluded, so each scene loads lazily and a build without it mounts none (fails closed).
const PANEL_SCENES: Array[String] = [
	"res://weftlumin/panels/console_panel.tscn",
	"res://weftlumin/panels/timeline_panel.tscn",
	"res://weftlumin/panels/combat_lab_panel.tscn",
	"res://weftlumin/panels/dialogue_panel.tscn",
	"res://weftlumin/panels/quest_panel.tscn",
]


func panels() -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	for path: String in PANEL_SCENES:
		var packed: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
		if packed == null:
			push_warning("Weftlumin: panel %s is missing; its tab stays a placeholder." % path)
			continue
		result.append(packed)
	return result


func gameplay_scene_root() -> Node:
	return GameFlow.get_tree().current_scene


func production_owner_live() -> bool:
	return Battle.session_active or _production_dialogue_live()


## True while a Dialogue Manager balloon is showing under the current scene. Formerly read from the
## dialogue lab's autoload, which E2.5b (#337) removed; the dialogue panel's own model still applies
## its finer lab-owned-balloon exclusion before starting a replay.
func _production_dialogue_live() -> bool:
	var current_scene: Node = null
	if DialogueManager.get_current_scene.is_valid():
		current_scene = DialogueManager.get_current_scene.call() as Node
	return current_scene != null and _contains_dialogue_balloon(current_scene)


static func _contains_dialogue_balloon(node: Node) -> bool:
	for child: Node in node.get_children():
		if child.get("dialogue_resource") is DialogueResource:
			return true
		if _contains_dialogue_balloon(child):
			return true
	return false


func capture_runtime_state() -> Dictionary:
	return SaveGame.capture_runtime_state()


func restore_runtime_state(snapshot: Dictionary) -> bool:
	return SaveGame.restore_runtime_state(snapshot)
