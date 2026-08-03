class_name StableIds
extends RefCounted
## Stable identifier schemas shared by saves and the later consequence audit.
##
## IDs are intentionally opaque strings.  Their meaning belongs to the owning
## data source (Pandora, the quest/dialogue content, or the lore vault), while
## this module keeps the serialized shape and spelling rules consistent.

const ACTOR := &"actor"
const QUEST := &"quest"
const SKILL := &"skill"
const ITEM := &"item"
const ZONE := &"zone"
const WORLD_FACT := &"world_fact"
const DIALOGUE_NODE := &"dialogue_node"

const KINDS: Array[StringName] = [
	ACTOR, QUEST, SKILL, ITEM, ZONE, WORLD_FACT, DIALOGUE_NODE
]

const _ID_PATTERN := "^[A-Za-z0-9][A-Za-z0-9._:/-]*$"


static func schema_manifest() -> Dictionary:
	var manifest: Dictionary = {}
	for kind in KINDS:
		manifest[String(kind)] = schema_for(kind)
	return manifest


static func schema_for(kind: StringName) -> Dictionary:
	if kind not in KINDS:
		return {}
	return {
		"kind": String(kind),
		"field": "id",
		"format": "opaque non-empty identifier (no whitespace)",
		"pattern": _ID_PATTERN,
	}


static func make(kind: StringName, identifier: String) -> Dictionary:
	if not is_valid(kind, identifier):
		return {}
	return {"kind": String(kind), "id": identifier}


static func is_valid(kind: StringName, identifier: String) -> bool:
	if kind not in KINDS or identifier.is_empty():
		return false
	var expression := RegEx.new()
	if expression.compile(_ID_PATTERN) != OK:
		return false
	return expression.search(identifier) != null


static func is_valid_record(kind: StringName, record: Dictionary) -> bool:
	return (
		record.get("kind", "") == String(kind)
		and record.get("id", "") is String
		and is_valid(kind, str(record.get("id", "")))
	)


static func actor(identifier: String) -> Dictionary:
	return make(ACTOR, identifier)


static func quest(identifier: String) -> Dictionary:
	return make(QUEST, identifier)


static func skill(identifier: String) -> Dictionary:
	return make(SKILL, identifier)


static func item(identifier: String) -> Dictionary:
	return make(ITEM, identifier)


static func zone(identifier: String) -> Dictionary:
	return make(ZONE, identifier)


static func world_fact(identifier: String) -> Dictionary:
	return make(WORLD_FACT, identifier)


static func dialogue_node(identifier: String) -> Dictionary:
	return make(DIALOGUE_NODE, identifier)
