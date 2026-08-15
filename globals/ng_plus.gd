class_name NGPlus
extends RefCounted
## Data-only NG+ block.  The Mirror Shop is intentionally outside this module.

const DEFAULT_BLOCK := {
	"style_points": 0,
	"purchased_carry_overs": [],
	"completion_metadata": {},
}


static func default_block() -> Dictionary:
	return DEFAULT_BLOCK.duplicate(true)


static func is_active(block: Variant) -> bool:
	## NG+ begins only after a completed-run marker exists. Style points can accrue
	## during the first run, so their presence alone must not unlock echo lines.
	var normalized := normalize(block)
	return not normalized["completion_metadata"].is_empty()


static func normalize(block: Variant) -> Dictionary:
	if not block is Dictionary:
		return default_block()
	var source: Dictionary = block
	var carry_overs: Array[String] = []
	for value: Variant in source.get("purchased_carry_overs", []):
		if value is String and not value.is_empty() and value not in carry_overs:
			carry_overs.append(value)
	var metadata: Dictionary = {}
	if source.get("completion_metadata", {}) is Dictionary:
		metadata = source.get("completion_metadata", {}).duplicate(true)
	return {
		"style_points": maxi(0, int(source.get("style_points", 0))),
		"purchased_carry_overs": carry_overs,
		"completion_metadata": metadata,
	}


static func apply_to_new_game(initial_state: Dictionary, block: Dictionary) -> Dictionary:
	## Idempotent transform: style points are a carried balance and carry-over
	## identifiers are a set, so applying the same block twice has no additive
	## effect.  Unknown identifiers remain data for their owning system to use.
	var result := initial_state.duplicate(true)
	var existing: Dictionary = {}
	if result.get("ng_plus", {}) is Dictionary:
		existing = result.get("ng_plus", {}).duplicate(true)
	var normalized := normalize(block)
	var existing_ids: Array[String] = []
	for value: Variant in existing.get("purchased_carry_overs", []):
		if value is String and value not in existing_ids:
			existing_ids.append(value)
	for value: String in normalized["purchased_carry_overs"]:
		if value not in existing_ids:
			existing_ids.append(value)
	var existing_metadata: Dictionary = {}
	if existing.get("completion_metadata", {}) is Dictionary:
		existing_metadata = existing.get("completion_metadata", {}).duplicate(true)
	for key: Variant in normalized["completion_metadata"]:
		existing_metadata[key] = normalized["completion_metadata"][key]
	existing["style_points"] = maxi(int(existing.get("style_points", 0)), normalized["style_points"])
	existing["purchased_carry_overs"] = existing_ids
	existing["completion_metadata"] = existing_metadata
	result["ng_plus"] = existing
	return result
