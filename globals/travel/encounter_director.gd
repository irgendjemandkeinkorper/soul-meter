class_name EncounterDirector
extends RefCounted
## Pure helpers for deterministic journey encounters and avoidance previews.

# PROVISIONAL: owner-tunable FR-506 coupling. Setting the step to zero restores
# authored route and band weights exactly. Ranks only classify existing entries;
# they do not add encounters or replace any authored weight.
const PROVISIONAL_THINNING_WEIGHT_PER_DANGER_RANK := 1
const PROVISIONAL_ENCOUNTER_DANGER_RANK := {
	&"loam-boar": 0,
	&"bog-wight": 1,
	&"dorthkor-vanguard": 2,
}


static func build_schedule(route: Dictionary, seed: int) -> Array[Dictionary]:
	var steps := maxi(int(route.get("steps", 0)), 0)
	var table := _encounter_table_for_route(route)
	if steps <= 0 or table.is_empty():
		return []

	var minimum := clampi(int(route.get("min_encounters", 0)), 0, steps)
	var maximum := clampi(int(route.get("max_encounters", minimum)), minimum, steps)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var encounter_count := rng.randi_range(minimum, maximum)
	var candidate_steps: Array[int] = []
	for step: int in range(1, steps + 1):
		candidate_steps.append(step)
	_shuffle_with_rng(candidate_steps, rng)

	var schedule: Array[Dictionary] = []
	for index: int in encounter_count:
		schedule.append({
			"at_step": candidate_steps[index],
			"encounter_id": _weighted_encounter(table, rng),
			"resolved": false,
			"spoils_granted": false,
		})
	schedule.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return int(first["at_step"]) < int(second["at_step"])
	)
	return schedule


static func avoidance_chance(route: Dictionary, party: Array[PartyMember]) -> float:
	var best_chance := 0.0
	for member: PartyMember in party:
		if member == null:
			continue
		best_chance = maxf(best_chance, SkillCheck.preview("survival", member))
	var risk_modifier := maxf(float(route.get("risk_modifier", 0.0)), 0.0)
	return maxf(minf(best_chance, SkillCheckService.MAX_EFFECTIVE_PERCENT) - risk_modifier, 0.0)


static func _valid_encounter_table(raw_table: Variant) -> Array[Dictionary]:
	var table: Array[Dictionary] = []
	if not raw_table is Array:
		return table
	for raw_entry: Variant in raw_table:
		if not raw_entry is Dictionary:
			continue
		var encounter_id := StringName(raw_entry.get("encounter_id", ""))
		var weight := int(raw_entry.get("weight", 0))
		if encounter_id.is_empty() or weight <= 0:
			continue
		table.append({"encounter_id": encounter_id, "weight": weight})
	return table


static func _encounter_table_for_route(route: Dictionary) -> Array[Dictionary]:
	var table := _valid_encounter_table(route.get("encounter_table", []))
	var configuration: Variant = route.get("band_encounter_weights", {})
	if configuration is Dictionary:
		var faction_id := StringName(configuration.get("faction_id", &""))
		var raw_bands: Variant = configuration.get("bands", {})
		if not faction_id.is_empty() and raw_bands is Dictionary:
			var raw_overrides: Variant = raw_bands.get(
				Reputation.band(String(faction_id)), {}
			)
			if raw_overrides is Dictionary:
				table = _apply_band_overrides(table, raw_overrides)
	return _apply_thinning_weights(table, _thinning_tier_for_route(route))


static func _apply_band_overrides(
	table: Array[Dictionary], raw_overrides: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in table:
		var encounter_id := StringName(entry["encounter_id"])
		var weight := int(entry["weight"])
		if raw_overrides.has(encounter_id):
			weight = int(raw_overrides[encounter_id])
		elif raw_overrides.has(String(encounter_id)):
			weight = int(raw_overrides[String(encounter_id)])
		if weight > 0:
			result.append({"encounter_id": encounter_id, "weight": weight})
	return result


static func _apply_thinning_weights(
	table: Array[Dictionary], thinning_tier: int
) -> Array[Dictionary]:
	if thinning_tier <= 0 or PROVISIONAL_THINNING_WEIGHT_PER_DANGER_RANK <= 0:
		return table
	var result: Array[Dictionary] = []
	for entry: Dictionary in table:
		var encounter_id := StringName(entry["encounter_id"])
		var danger_rank := int(PROVISIONAL_ENCOUNTER_DANGER_RANK.get(encounter_id, 0))
		var added_weight := (
			thinning_tier * PROVISIONAL_THINNING_WEIGHT_PER_DANGER_RANK * danger_rank
		)
		result.append({
			"encounter_id": encounter_id,
			"weight": int(entry["weight"]) + added_weight,
		})
	return result


static func _thinning_tier_for_route(route: Dictionary) -> int:
	var tier := 0
	for key: String in ["origin_id", "destination_id"]:
		var location_id := StringName(route.get(key, &""))
		var map_location := WorldMapRegistry.location(location_id)
		if map_location.is_empty():
			continue
		tier = maxi(
			tier,
			LocationRegistry.thinning_tier_by_scene(str(map_location.get("scene_path", ""))),
		)
	return tier


static func _shuffle_with_rng(values: Array[int], rng: RandomNumberGenerator) -> void:
	for index: int in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var held := values[index]
		values[index] = values[swap_index]
		values[swap_index] = held


static func _weighted_encounter(
	table: Array[Dictionary], rng: RandomNumberGenerator
) -> StringName:
	var total_weight := 0
	for entry: Dictionary in table:
		total_weight += int(entry["weight"])
	var roll := rng.randi_range(1, total_weight)
	for entry: Dictionary in table:
		roll -= int(entry["weight"])
		if roll <= 0:
			return StringName(entry["encounter_id"])
	return StringName(table.back()["encounter_id"])
