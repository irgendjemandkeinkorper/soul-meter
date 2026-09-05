extends Node
## WorldClock — the FR-504a four-phase world clock
## (`docs/prd-amendment-living-world.md`, RATIFIED 2026-08-07).
##
## The clock advances ONLY on declared events (§3.1): travel through
## `GameFlow.travel()` and a quest completion whose resource declares
## `advances_clock`. No rest mechanic exists, so per §6.2 the trigger list is
## exactly those two. NEVER on a timer — this node has no _process and must
## not gain one; a player who stands still does not lose the day (§5.3).
##
## The combat layer's 16-tick weather measure is a SEPARATE system (§4.5) —
## do not unify them.
##
## Reversibility (§7): if the clock is ever removed, dialogue written against
## it must not break — `phase()` always returns a valid phase name, and
## `DEFAULT_PHASE` is the defined value for "clock disabled or never advanced".

signal phase_changed(previous: StringName, current: StringName, cause: String)

## §3.1: four phases, not twenty-four — the phase count is the authoring cost
## multiplier for every routine row in NpcRoutines.
const PHASES: Array[StringName] = [&"morning", &"afternoon", &"evening", &"night"]
const DEFAULT_PHASE: StringName = &"morning"

var _phase: StringName = DEFAULT_PHASE
var phase_count: int = 0


func phase() -> StringName:
	return _phase


## Dialogue-facing sugar: `[if WorldClock.is_phase("evening") /]`.
func is_phase(name: String) -> bool:
	return _phase == StringName(name)


## Zero-based world day derived from four declared phase advances per day.
func day_index() -> int:
	@warning_ignore("integer_division")
	return phase_count / PHASES.size()


## Advance one phase (wrapping night → morning). `cause` is diagnostic and
## rides the signal so a stray advance can be traced to its trigger.
func advance(cause: String) -> StringName:
	var index := PHASES.find(_phase)
	var previous := _phase
	_phase = PHASES[(index + 1) % PHASES.size()]
	phase_count += 1
	phase_changed.emit(previous, _phase, cause)
	return _phase


## §3.1's quest-step trigger: the quest RESOURCE declares the advance
## (`advances_clock` on FlagQuest/DomSideQuest); code never decides per-site.
## Called from QuestRegistry.turn_in() on completion.
func advance_for_quest(quest: Quest) -> void:
	if quest == null:
		return
	# Addon Quest subclasses without the property return null from get();
	# only an explicit `advances_clock = true` on the resource advances.
	var declared: Variant = quest.get("advances_clock")
	if declared is bool and declared:
		advance("quest:%s" % quest.quest_name)


## Restore/reset entry point. Rejects unknown phase names instead of clamping
## silently, so a corrupt save fails loud in validation, not quiet here.
func set_phase(name: StringName, cause: String = "restore") -> bool:
	if not PHASES.has(name):
		return false
	if name == _phase:
		return true
	var previous := _phase
	_phase = name
	phase_changed.emit(previous, name, cause)
	return true


func reset() -> void:
	phase_count = 0
	set_phase(DEFAULT_PHASE, "reset")


# --- persistence (schema 7 `world_clock` envelope; FR-802 world fact) --------


func to_dict() -> Dictionary:
	return {"phase": String(_phase), "phase_count": phase_count}


func from_dict(data: Dictionary) -> void:
	var name := StringName(str(data.get("phase", DEFAULT_PHASE)))
	if not PHASES.has(name):
		name = DEFAULT_PHASE
	phase_count = maxi(0, int(data.get("phase_count", 0)))
	set_phase(name, "load")


static func validate_save_data(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var data: Dictionary = value
	var name: Variant = data.get("phase", String(DEFAULT_PHASE))
	var saved_phase_count: Variant = data.get("phase_count", 0)
	return (
		name is String
		and PHASES.has(StringName(name))
		and typeof(saved_phase_count) == TYPE_INT
		and int(saved_phase_count) >= 0
	)
