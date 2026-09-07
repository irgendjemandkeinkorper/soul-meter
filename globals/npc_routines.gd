class_name NpcRoutines
extends RefCounted
## FR-504a §2 routine registry (`docs/prd-amendment-living-world.md`).
##
## A routine is a TABLE: per named hub NPC, a position and a state for each
## WorldClock phase. Nothing computes it, nothing pathfinds to it — the NPC is
## in one place before the phase change and in the other after it (§2.2).
##
## The rows themselves live in `canon/<hub>/characters/*.json` as the `routine`
## and `phase_agnostic` fields of the NPC they describe (issue #385) — one
## document per NPC, the same move #383 made for portraits, bios and epithets.
## This class is the runtime READER of those fields plus the FR-504a rules that
## canon deliberately does not carry. Reversibility (§7) is unchanged: emptying
## an NPC's `routine` returns them to FR-504 flag/rep reactivity, and emptying
## every one returns the whole hub to it.
##
## The cap is a NUMBER, not a principle (§2.2): 15 routines across all three
## hubs. Routine 16 requires a further amendment, not a judgement call here.
## `test/unit/test_npc_routines.gd` enforces the cap and §5 criterion 4
## (every routine NPC findable-or-declared-absent in every phase).

const ROUTINE_CAP := 15

## Routine positions are authored in THIS scene's coordinates. An NPC node in
## any other scene ignores the table even if its id matches, so a future
## interior placement cannot inherit town coordinates.
const HUB_SCENE := "res://world/starting_town.tscn"

## Marker meaning "not in the hub this phase" — hidden, non-interactable,
## out of the nav occupancy group. §5 criterion 4 requires absence to be
## DECLARED (a null row), never accidental (a missing key).
const ABSENT := &"absent"

const CANON_ROOT := "res://canon"
const CHARACTER_KIND := "characters"

## npc_id → phase → {"position": Vector2, "state": StringName} | null (absent).
## Read-only: mutating it does not write back to canon.
##
## Sella Varn gives BELLHOUSE_REPAIR, so FR-905/§3.4 applies: she is present
## (interactable) in three phases — comfortably over the two-phase floor.
static var ROUTINES: Dictionary = {}

## §3.3 back-fill: named NPCs WITHOUT a routine, declared phase-agnostic on
## purpose (FR-504a item 4 — flag/rep reactivity only IS the design, not a
## fallback). Marshal Coiljaw anchors the Broken Muster ruling, so he stays
## findable in every phase rather than gaining a routine.
static var DECLARED_PHASE_AGNOSTIC: Array[String] = []


## Read once, when the class is first loaded. `tools/seed_pandora.gd` owns the
## authoring-time contract for these documents, but it lives under `tools/`,
## which the export presets exclude — so the runtime reads the same files
## through the small purpose-built walker below rather than preloading a tool
## script into the game.
static func _static_init() -> void:
	var canon := _read_canon()
	ROUTINES = canon["routines"]
	DECLARED_PHASE_AGNOSTIC = canon["phase_agnostic"]


static func has_routine(npc_id: String) -> bool:
	return ROUTINES.has(npc_id)


## The placement for one NPC in one phase.
## Returns {} when the NPC has no routine (FR-504 behaviour applies),
## {"present": false} for a declared absence, and
## {"present": true, "position": Vector2, "state": StringName} otherwise.
static func placement(npc_id: String, phase: StringName) -> Dictionary:
	if not ROUTINES.has(npc_id):
		return {}
	var routine: Dictionary = ROUTINES[npc_id]
	var row: Variant = routine.get(phase)
	if row == null:
		return {"present": false, "state": ABSENT}
	return {
		"present": true,
		"position": row["position"],
		"state": row["state"],
	}


## Phases in which the NPC is present and interactable — the FR-905 §3.4
## reachability surface (quest-critical NPCs need this ≥ 2, or no routine).
static func present_phase_count(npc_id: String) -> int:
	if not ROUTINES.has(npc_id):
		return WorldClock.PHASES.size()
	var count := 0
	for phase: StringName in ROUTINES[npc_id]:
		if ROUTINES[npc_id][phase] != null:
			count += 1
	return count


static func routine_count() -> int:
	return ROUTINES.size()


## Walks `canon/<hub>/characters/*.json` in a stable order and splits the two
## authored fields out of the character documents. A document that is present
## but malformed is reported and skipped rather than crashing the hub: a bad
## routine row costs one NPC their schedule, and CI's CANON-SEED stage is where
## it is meant to be caught.
static func _read_canon() -> Dictionary:
	var routines: Dictionary = {}
	var phase_agnostic: Array[String] = []
	var hubs: PackedStringArray = []
	if DirAccess.dir_exists_absolute(CANON_ROOT):
		hubs = DirAccess.get_directories_at(CANON_ROOT)
	hubs.sort()
	for hub: String in hubs:
		var kind_root: String = CANON_ROOT.path_join(hub).path_join(CHARACTER_KIND)
		if not DirAccess.dir_exists_absolute(kind_root):
			continue
		var filenames: PackedStringArray = DirAccess.get_files_at(kind_root)
		filenames.sort()
		for filename: String in filenames:
			if filename.get_extension().to_lower() != "json":
				continue
			var document: Dictionary = _read_document(kind_root.path_join(filename))
			if document.is_empty():
				continue
			var npc_id := String(document.get("id", ""))
			if npc_id.is_empty():
				continue
			var routine := _routine_rows(document.get("routine"), npc_id)
			if not routine.is_empty():
				routines[npc_id] = routine
			# Not `elif`: a document that does both is a contradiction, and
			# `test_declared_agnostic_and_routines_are_disjoint` can only catch it
			# if the reader reports it rather than quietly preferring one field.
			if bool(document.get("phase_agnostic", false)):
				phase_agnostic.append(npc_id)
	return {"routines": routines, "phase_agnostic": phase_agnostic}


static func _read_document(document_path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(document_path, FileAccess.READ)
	if file == null:
		push_error("NPC-ROUTINES: could not read %s." % document_path)
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		push_error("NPC-ROUTINES: %s must contain one JSON object." % document_path)
		return {}
	return parser.data


## Canon authors phases as strings and positions as `[x, y]`; the table this
## class hands out is keyed by StringName and carries real Vector2s, because
## that is what `actors/npc/npc.gd` and the phase clock already speak.
static func _routine_rows(authored: Variant, npc_id: String) -> Dictionary:
	if authored == null or typeof(authored) != TYPE_DICTIONARY:
		return {}
	var rows: Dictionary = {}
	for phase: Variant in authored as Dictionary:
		var placement_row: Variant = (authored as Dictionary)[phase]
		if placement_row == null:
			rows[StringName(phase)] = null
			continue
		if typeof(placement_row) != TYPE_DICTIONARY:
			push_error(
				"NPC-ROUTINES: '%s' phase '%s' is neither null nor a row." % [npc_id, phase]
			)
			return {}
		var row: Dictionary = placement_row
		var position: Variant = row.get("position")
		if typeof(position) != TYPE_ARRAY or (position as Array).size() != 2:
			push_error(
				"NPC-ROUTINES: '%s' phase '%s' has no [x, y] position." % [npc_id, phase]
			)
			return {}
		rows[StringName(phase)] = {
			"position": Vector2(float((position as Array)[0]), float((position as Array)[1])),
			"state": StringName(row.get("state", "")),
		}
	return rows
