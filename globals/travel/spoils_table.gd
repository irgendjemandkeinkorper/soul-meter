class_name SpoilsTable
extends RefCounted
## Deterministic, modest rewards for victories during a journey.

# Avoidance uses `seed + slot_index`. This large fixed offset gives spoils an
# independent stream while preserving one stable stream per schedule slot.
const SPOILS_STREAM_OFFSET := 5_000_003
const TABLES: Dictionary = {
	&"bog-wight": [
		ItemIds.MATERIALS_GRAVE_SALT,
		ItemIds.CONSUMABLES_BITTERLEAF_POULTICE,
	],
	&"loam-boar": [
		ItemIds.MATERIALS_LOAMROOT_SPRIG,
		ItemIds.CONSUMABLES_LOAM_BREAD,
	],
	&"dorthkor-vanguard": [
		ItemIds.MATERIALS_IRON_RIVETS,
		ItemIds.MATERIALS_BINDING_THREAD,
	],
}


static func roll(encounter_id: StringName, seed: int, slot_index: int) -> Array[Dictionary]:
	var item_ids: Array = TABLES.get(encounter_id, [])
	if item_ids.is_empty():
		return []

	var rng := RandomNumberGenerator.new()
	rng.seed = seed + slot_index + SPOILS_STREAM_OFFSET
	var spoils: Array[Dictionary] = [{
		"item_id": String(item_ids[0]),
		"quantity": rng.randi_range(1, 2),
	}]
	if item_ids.size() > 1 and rng.randf() < 0.5:
		spoils.append({
			"item_id": String(item_ids[1]),
			"quantity": rng.randi_range(1, 2),
		})
	return spoils
