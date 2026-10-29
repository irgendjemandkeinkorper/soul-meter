class_name PerkCatalog
extends RefCounted
## Runtime reader for the patron-class perks (#285). Canon owns them
## (`canon/<hub>/perks/*.json`, schema `weftlumin.perk.v1`), Pandora stores them, and
## tools/generate_gloot.gd emits `data/generated/perks.json`; nothing here reads Pandora.
##
## Owner item 2 (ruled 2026-10-16, confirmed 2026-10-22): perks at levels 2 / 4 / 6, one pick
## each. Owner item 22 (2026-10-24): the lists in docs/perks-draft-285.md are approved; a
## level-6 capstone pair offers one gated and one ungated perk. A pick is a pick: no respec in
## Chapter 1.

const DATA_PATH := "res://data/generated/perks.json"
const PICK_LEVELS: Array[int] = [2, 4, 6]
## Perks whose effect is already in play. Jam the Gears and Nothing Wasted shipped as class
## features before the cadence existed; every other perk is recorded when picked and gains its
## effect in a later #285 slice, so the sheet marks it planned rather than pretend it works.
const IN_PLAY: Dictionary = {
	"locksmirk-jam-the-gears": true,
	"husk-bearer-nothing-wasted": true,
}

static var _rows: Array[Dictionary] = []
static var _by_id: Dictionary = {}


static func all() -> Array[Dictionary]:
	_ensure_loaded()
	return _rows.duplicate(true)


static func definition(perk_id: String) -> Dictionary:
	_ensure_loaded()
	return (_by_id.get(perk_id, {}) as Dictionary).duplicate(true)


## The class's perks in sheet order: level, then id.
static func for_class(class_id: String) -> Array[Dictionary]:
	_ensure_loaded()
	var result: Array[Dictionary] = []
	for row: Dictionary in _rows:
		if str(row["class_id"]) == class_id:
			result.append(row.duplicate(true))
	return result


static func is_in_play(perk_id: String) -> bool:
	return IN_PLAY.has(perk_id)


## The perks a member has picked, in pick-level order. Ids the catalog no longer knows are
## skipped, not dropped from the save.
static func picked(member: PartyMember) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if member == null:
		return result
	for perk_id: String in member.perk_ids:
		var row := definition(perk_id)
		if not row.is_empty():
			result.append(row)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["level"]) < int(b["level"])
	)
	return result


## The lowest pick level the member has reached and not yet spent, or 0. Levels are taken in
## order, so a member who jumps from 1 to 5 picks the level-2 perk before the level-4 one.
static func pending_level(member: PartyMember) -> int:
	if member == null or for_class(member.class_id).is_empty():
		return 0
	var spent := {}
	for row: Dictionary in picked(member):
		spent[int(row["level"])] = true
	for level: int in PICK_LEVELS:
		if level > member.level:
			return 0
		if not spent.has(level):
			return level
	return 0


## What the member may choose from right now: every perk at the pending level, gated or not.
## The caller shows `gate_refusal()` beside a gated one it cannot take yet.
static func offers(member: PartyMember) -> Array[Dictionary]:
	var level := pending_level(member)
	var result: Array[Dictionary] = []
	if level == 0:
		return result
	for row: Dictionary in for_class(member.class_id):
		if int(row["level"]) == level:
			result.append(row)
	return result


## Empty when the perk's gate is open, otherwise the sentence the sheet shows. Reads the
## live ledgers through Renown's tier helpers, the same ones NPC reactions use.
## Karma gates went live with the Karma act writers (owner, 2026-10-25); item 22 had held them.
static func gate_refusal(perk: Dictionary) -> String:
	var fame := str(perk.get("minimum_fame_tier", ""))
	if not fame.is_empty() and not Renown.fame_tier_at_least(fame):
		return "Needs Fame: %s or more." % fame
	var karma_floor := str(perk.get("minimum_karma_tier", ""))
	if not karma_floor.is_empty() and not Renown.karma_tier_at_least(karma_floor):
		return "Needs Karma: %s or better." % karma_floor
	var karma_ceiling := str(perk.get("maximum_karma_tier", ""))
	if not karma_ceiling.is_empty() and not Renown.karma_tier_at_most(karma_ceiling):
		return "Needs Karma: %s or worse." % karma_ceiling
	return ""


## Records a pick. Refuses anything but one of `offers(member)` whose gate is open.
static func pick(member: PartyMember, perk_id: String) -> Dictionary:
	var refused := func(reason: StringName, message: String) -> Dictionary:
		return {"allowed": false, "reason": reason, "message": message}
	if member == null:
		return refused.call(&"no_member", "Nobody to choose for.")
	var row := definition(perk_id)
	if row.is_empty():
		return refused.call(&"unknown_perk", "No such perk.")
	if str(row["class_id"]) != member.class_id:
		return refused.call(&"wrong_class", "%s is not a %s perk." % [row["display_name"], member.class_id])
	var level := pending_level(member)
	if level == 0 or int(row["level"]) != level:
		return refused.call(&"not_offered", "%s is not on offer now." % row["display_name"])
	var gate := gate_refusal(row)
	if not gate.is_empty():
		return refused.call(&"gated", gate)
	member.perk_ids.append(perk_id)
	return {"allowed": true, "reason": &"", "message": "%s learned %s." % [member.display_name, row["display_name"]]}


static func key_for(perk_id: String, field: String) -> String:
	var normalized_id := perk_id.strip_edges().to_upper().replace("-", "_")
	return "PERK_%s_%s" % [normalized_id, "NAME" if field == "name" else "BLURB"]


static func display_name(perk: Dictionary) -> String:
	return _text(perk, "name", str(perk.get("display_name", "")))


static func blurb(perk: Dictionary) -> String:
	return _text(perk, "blurb", str(perk.get("blurb", "")))


static func _text(perk: Dictionary, field: String, fallback: String) -> String:
	var key := key_for(str(perk.get("id", "")), field)
	return ItemLocalization.with_fallback(TranslationServer.translate(key), key, fallback)


static func _ensure_loaded() -> void:
	if not _rows.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Array:
		push_error("Could not load generated perk data from %s." % DATA_PATH)
		return
	for row: Variant in parsed:
		if row is Dictionary:
			_rows.append(row)
			_by_id[str(row["id"])] = row
