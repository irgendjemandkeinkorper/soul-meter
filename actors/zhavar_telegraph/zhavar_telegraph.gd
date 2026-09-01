class_name ZhavarTelegraph
extends Node
## Read-only ambient visualization of one zone's authored Zhavar rung.

# PROVISIONAL: owner-tunable overlay strengths. Zeroing every value disables
# the telegraph without touching authored Zhavar state or scene wiring.
const PROVISIONAL_RUNG_INTENSITY := {
	"low": 0.0,
	"rising": 0.025,
	"tolling": 0.05,
	"ringing": 0.08,
	"unprecedented": 0.12,
}

@export var zone_id := "wilds"

var intensity := 0.0

@onready var _overlay: ColorRect = $CanvasLayer/Overlay


func _ready() -> void:
	if not SaveGame.zhavar_rung_changed.is_connected(_on_zhavar_rung_changed):
		SaveGame.zhavar_rung_changed.connect(_on_zhavar_rung_changed)
	_apply_rung(SaveGame.zhavar_rung(zone_id))


func _exit_tree() -> void:
	if SaveGame.zhavar_rung_changed.is_connected(_on_zhavar_rung_changed):
		SaveGame.zhavar_rung_changed.disconnect(_on_zhavar_rung_changed)


static func intensity_for_rung(rung: String) -> float:
	return float(PROVISIONAL_RUNG_INTENSITY.get(rung, 0.0))


func _on_zhavar_rung_changed(changed_zone_id: String, rung: String) -> void:
	if changed_zone_id == zone_id:
		_apply_rung(rung)


func _apply_rung(rung: String) -> void:
	intensity = intensity_for_rung(rung)
	_overlay.visible = intensity > 0.0
	_overlay.color = Color(DS.VIOLET_2, intensity)
