class_name ZhavarToll
extends Node
## FR-308's one scripted tolling event: the single beat where the Zhavar stops
## being a rumor Dom repeats and becomes something the player is standing in.
##
## `ZhavarTelegraph` is the CONTINUOUS read of the same state — an overlay whose
## strength tracks the rung and that says the same thing every frame. This says
## something ONCE. The two are deliberately separate nodes: an ambience that also
## fires a one-shot cannot be disabled without losing the event, and the owner
## tuning surface on the telegraph (`PROVISIONAL_RUNG_INTENSITY`, zeroable) exists
## precisely so the ambience can be turned off. Zeroing it must not silence FR-308's
## scripted beat.
##
## Fires when the zone is at "tolling" OR ABOVE and has not been witnessed. Above,
## not equal: a save that reached "ringing" through a route the player did not
## stand in must not be owed a toll it can never collect, and the ladder is
## one-way, so "at least tolling" is the only honest test.
##
## One-time is DURABLE, not per-session: the witness flag rides `GameState`, which
## is what the save serializes. Re-entering the wilds, reloading, and travelling
## back all find the flag already set. Chapter 1 telegraphs the Zhavar; the
## dragon-response systemization this points at is Chapter 2+, so nothing here
## spawns anything or changes what the zone contains.

## The rung at which the toll is heard. Below this the event is inert.
const TOLLING_RUNG := "tolling"

## Set true the first time the toll is witnessed, per zone. A quest, a reaction
## rule or a dialogue condition may read it; nothing else writes it.
const WITNESS_FLAG_FORMAT := "zhavar_toll_witnessed_%s"

## The stroke: a swell and a long decay, not a pulse. Presentation only.
const SWELL_SECONDS := 0.45
const DECAY_SECONDS := 3.2
const PEAK_ALPHA := 0.34

@export var zone_id := "wilds"

## Emitted once, when the toll actually plays. Tests and any future consumer read
## this rather than reaching into the tween.
signal tolled(zone_id: String)

@onready var _stroke: ColorRect = $CanvasLayer/Stroke

var _tween: Tween = null


static func witness_flag(zone: String) -> String:
	return WITNESS_FLAG_FORMAT % zone


func _ready() -> void:
	if not SaveGame.zhavar_rung_changed.is_connected(_on_zhavar_rung_changed):
		SaveGame.zhavar_rung_changed.connect(_on_zhavar_rung_changed)
	# The rung is usually raised somewhere the player is not — a Dom ruling, a
	# dialogue `do` line. So arrival is the common trigger and the signal is the
	# rare one, not the other way round.
	_toll_if_due()


func _exit_tree() -> void:
	if SaveGame.zhavar_rung_changed.is_connected(_on_zhavar_rung_changed):
		SaveGame.zhavar_rung_changed.disconnect(_on_zhavar_rung_changed)


## True when the toll is owed: the zone is loud enough and nobody has stood in it.
func is_due() -> bool:
	var rungs: Array = SaveGame.ZHAVAR_RUNGS
	var reached := rungs.find(SaveGame.zhavar_rung(zone_id))
	if reached < rungs.find(TOLLING_RUNG):
		return false
	return not bool(GameState.get_flag(witness_flag(zone_id), false))


func _on_zhavar_rung_changed(changed_zone_id: String, _rung: String) -> void:
	if changed_zone_id == zone_id:
		_toll_if_due()


func _toll_if_due() -> void:
	if not is_due():
		return
	# The flag is written BEFORE the stroke plays. A scene change, a save, or a
	# quit during the 3.6 seconds of decay must still count as witnessed — the
	# alternative is an event that replays every time the player walks back in.
	GameState.set_flag(witness_flag(zone_id), true)
	_play_stroke()
	tolled.emit(zone_id)


func _play_stroke() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_stroke.color = Color(DS.VIOLET_2, 0.0)
	_stroke.visible = true
	_tween = create_tween()
	_tween.tween_property(_stroke, "color:a", PEAK_ALPHA, SWELL_SECONDS)
	_tween.tween_property(_stroke, "color:a", 0.0, DECAY_SECONDS)
	_tween.tween_callback(func() -> void: _stroke.visible = false)
