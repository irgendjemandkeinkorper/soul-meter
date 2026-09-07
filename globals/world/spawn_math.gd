class_name SpawnMath
extends RefCounted
## The numbers behind per-map spawn tables (`docs/architecture-in-game-editor.md` §4.10; design
## note: `docs/spawn-math.md`). Weight normalisation with the `empty` sentinel, danger scaling by
## thinning tier, respawn cadence against the Zhavar rung, pack-size curves, `max_alive` defaults
## and the `limited` policy bounds.
##
## **Pure and deterministic.** Every function is static and reads nothing but its arguments and
## the constants below. The RNG arrives as a parameter so `SpawnDirector` keeps full control of
## the stream: §4.10 seeds one `RandomNumberGenerator` per slot roll from
## `hash([world_seed, table_id, slot_id, day_index])`, and that only reproduces if the helpers
## consume a fixed, documented number of draws. `pick()` takes exactly one; `pack_size()` takes
## exactly one; neither takes any when there is nothing to draw from.
##
## Nothing here instantiates, saves, or knows what a `Hostile` is — that is E4.1 (#345).
##
## ALL NUMBERS BELOW ARE **PROVISIONAL**. #327 owns the shape; balance owns the values.

## Added weight per danger rank per thinning tier, as a share of the table's own authored total.
##
## Deliberately scale-relative rather than the flat `+1` that `EncounterDirector` adds. Travel
## tables are authored with weights in the single digits, where `+1` is a real shift; §4.10's own
## spawn-table example uses 40/40/20, where the same `+1` per tier moves the mix by under two
## points and is invisible in play. Expressed as a share, one constant behaves the same on a
## 3-weight table and a 300-weight one.
##
## Setting this to zero restores authored weights exactly, which is the property that makes the
## coupling owner-tunable rather than baked in.
const THINNING_SHARE_PER_DANGER_RANK := 0.10

## `LocationDefinition.thinning_tier` is `@export_range(0, 3)`.
const MAX_THINNING_TIER := 3

## Days shaved off a slot's authored cadence per Zhavar rung above the calmest.
## The front pushes things ahead of it: a ringing zone refills faster than a quiet one.
const RESPAWN_DAYS_PER_ZHAVAR_RUNG := 1

## A slot never refills more than once a day, whatever the front is doing.
const MIN_RESPAWN_DAYS := 1

## Extra living members allowed per Zhavar rung, on `wilderness` maps only.
##
## The ladder's main outlet, because the cadence cannot carry it. See `respawn_days()`.
const MAX_ALIVE_PER_ZHAVAR_RUNG := 2

## Per-scene living-member caps by `respawn_policy` (§4.10 ruling 13).
const MAX_ALIVE_DEFAULTS := {"none": 0, "limited": 4, "wilderness": 12}

## The `limited` bounds §4.10 leaves for this issue to set. Kept as the spec's provisional values:
## they are already the right shape, and the measured sweep in the design note says they land
## where "minor respawns in otherwise settled areas" should land.
const LIMITED_MAX_SLOTS := 2
const LIMITED_MIN_RESPAWN_DAYS := 3
const LIMITED_MAX_PACK_SIZE := 2
const LIMITED_MIN_EMPTY_SHARE := 0.5


## Sanitised entries with their share of the total, in file order.
##
## Weight is relative and only meaningful against a total, so the share is computed once here
## rather than by every caller. Entries with a non-positive weight are dropped: §4.10's schema
## invariants reject them at validation time, and a table that slipped through must not be able
## to make `pick()` return something with a zero chance of being picked.
static func normalized(entries: Array) -> Array[Dictionary]:
	var valid: Array[Dictionary] = []
	for raw: Variant in entries:
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		var weight := int(entry.get("weight", 0))
		if weight <= 0:
			continue
		valid.append({
			"archetype_id": StringName(entry.get("archetype_id", &"")),
			"empty": bool(entry.get("empty", false)),
			"weight": weight,
		})
	var total := 0
	for entry: Dictionary in valid:
		total += int(entry["weight"])
	var result: Array[Dictionary] = []
	for entry: Dictionary in valid:
		var shared := entry.duplicate()
		shared["share"] = float(entry["weight"]) / float(total) if total > 0 else 0.0
		result.append(shared)
	return result


static func total_weight(entries: Array) -> int:
	var total := 0
	for entry: Dictionary in normalized(entries):
		total += int(entry["weight"])
	return total


## Combined share of the `empty` sentinel — the chance a slot rolls "nothing here today".
static func empty_share(entries: Array) -> float:
	var share := 0.0
	for entry: Dictionary in normalized(entries):
		if bool(entry["empty"]):
			share += float(entry["share"])
	return share


## Danger rank for an archetype, from the one table the travel director already uses.
##
## Not copied. `EncounterDirector` and `SpawnDirector` stay separate systems but read the same
## archetype ids (§4.10), and a second ranking table would be a second thing to drift.
static func danger_rank(archetype_id: StringName, ranks: Dictionary = {}) -> int:
	var table: Dictionary = (
		ranks if not ranks.is_empty() else EncounterDirector.PROVISIONAL_ENCOUNTER_DANGER_RANK
	)
	if table.has(archetype_id):
		return int(table[archetype_id])
	return int(table.get(String(archetype_id), 0))


## Authored weights pushed toward the dangerous end by the location's thinning tier.
##
## Additive, so an entry can only gain: thinning never suppresses something the author placed. The
## `empty` sentinel carries no archetype and so gains nothing, which means a thinned location is
## not just more dangerous but also less often quiet. That is the intended reading of a place
## nearer the Wound, and it is worth knowing it falls out of the shape rather than being tuned in.
static func scaled_weights(
	entries: Array, thinning_tier: int, ranks: Dictionary = {}
) -> Array[Dictionary]:
	var base := normalized(entries)
	var tier := clampi(thinning_tier, 0, MAX_THINNING_TIER)
	if tier <= 0 or THINNING_SHARE_PER_DANGER_RANK <= 0.0:
		return base
	var authored_total := 0
	for entry: Dictionary in base:
		authored_total += int(entry["weight"])
	var scaled: Array[Dictionary] = []
	for entry: Dictionary in base:
		var rank := 0 if bool(entry["empty"]) else danger_rank(entry["archetype_id"], ranks)
		var added := int(
			round(float(authored_total) * THINNING_SHARE_PER_DANGER_RANK * float(tier * rank))
		)
		scaled.append({
			"archetype_id": entry["archetype_id"],
			"empty": entry["empty"],
			"weight": int(entry["weight"]) + added,
		})
	return normalized(scaled)


## One weighted draw. Consumes exactly one `randi_range`, or none when there is nothing to draw.
##
## Returns `{archetype_id, empty, index}`. `index` is the position in the sanitised list, or -1
## when the table held nothing pickable — the caller treats that as `empty` and clears the slot
## rather than raising, because a bad table must not be able to stop a scene loading.
static func pick(entries: Array, rng: RandomNumberGenerator) -> Dictionary:
	var table := normalized(entries)
	if table.is_empty() or rng == null:
		return {"archetype_id": &"", "empty": true, "index": -1}
	var total := 0
	for entry: Dictionary in table:
		total += int(entry["weight"])
	var roll := rng.randi_range(1, total)
	var running := 0
	for index: int in table.size():
		running += int(table[index]["weight"])
		if roll <= running:
			return {
				"archetype_id": table[index]["archetype_id"],
				"empty": bool(table[index]["empty"]),
				"index": index,
			}
	var last: int = table.size() - 1
	return {
		"archetype_id": table[last]["archetype_id"],
		"empty": bool(table[last]["empty"]),
		"index": last,
	}


## Pack size from a `{"min": int, "max": int}` range, weighted toward the small end.
##
## Not uniform. A uniform 1..3 slot rolls a three-pack a third of the time, and a map of slots
## doing that reads as a swarm rather than as wildlife. The weight of size k is `max - k + 1`, so
## the smallest size is the most likely and the largest is the rarest, with the gap widening as
## the authored range widens. Consumes exactly one `randi_range`.
static func pack_size(pack_range: Dictionary, rng: RandomNumberGenerator) -> int:
	var minimum := maxi(int(pack_range.get("min", 1)), 1)
	var maximum := maxi(int(pack_range.get("max", minimum)), minimum)
	if maximum == minimum or rng == null:
		return minimum
	var span := maximum - minimum + 1
	# Sum of the falloff weights `span, span-1, ... 1`.
	var total := span * (span + 1) / 2
	var roll := rng.randi_range(1, total)
	var running := 0
	for size: int in range(minimum, maximum + 1):
		running += maximum - size + 1
		if roll <= running:
			return size
	return maximum


## Mean pack size under `pack_size()`, for the design note's tables and the density lint.
static func expected_pack_size(pack_range: Dictionary) -> float:
	var minimum := maxi(int(pack_range.get("min", 1)), 1)
	var maximum := maxi(int(pack_range.get("max", minimum)), minimum)
	var span := maximum - minimum + 1
	var total := float(span * (span + 1) / 2)
	var weighted := 0.0
	for size: int in range(minimum, maximum + 1):
		weighted += float(size) * float(maximum - size + 1)
	return weighted / total


## Mean living members a single slot contributes on a visit it is eligible to roll.
static func expected_spawns_per_slot(
	entries: Array, pack_range: Dictionary, thinning_tier: int = 0
) -> float:
	var scaled := scaled_weights(entries, thinning_tier)
	return (1.0 - empty_share(scaled)) * expected_pack_size(pack_range)


## Authored cadence shortened by the zone's Zhavar rung, floored at one day.
##
## **This saturates, on purpose, and it is not the ladder's main outlet.** Cadence is counted in
## whole days and authored cadences are small — a `limited` slot is required to be at least 3 —
## so a five-rung ladder has at most two steps to spend before it hits the one-day floor, and
## `tolling`, `ringing` and `unprecedented` all mean the same thing here. Days cannot express five
## rungs at this scale and no arrangement of this function makes them.
##
## So the rung's legible effect lives in `max_alive_for()` instead: on a wilderness map the front
## shows up as **more things at once**, which the player can see, rather than as **things sooner**,
## which they cannot. This function stays as the secondary term.
static func respawn_days(authored_days: int, zhavar_rung_index: int) -> int:
	var authored := maxi(authored_days, MIN_RESPAWN_DAYS)
	var rungs_above := maxi(zhavar_rung_index, 0)
	return maxi(authored - rungs_above * RESPAWN_DAYS_PER_ZHAVAR_RUNG, MIN_RESPAWN_DAYS)


## Per-scene `max_alive` for a location that did not author one. An unknown policy gets the
## strictest answer, so a typo in a location document cannot silently open a town to spawns.
static func max_alive_default(respawn_policy: String) -> int:
	return int(MAX_ALIVE_DEFAULTS.get(respawn_policy, MAX_ALIVE_DEFAULTS["none"]))


## The per-scene cap actually in force, given the zone's Zhavar rung.
##
## Only `wilderness` grows. A `limited` location is settled ground by definition, and letting the
## front raise its ceiling would quietly turn it into wilderness — the policy would stop meaning
## anything. `none` stays at zero at every rung; nothing about the front opens a town to spawns.
static func max_alive_for(
	respawn_policy: String, zhavar_rung_index: int, authored_max_alive: int = 0
) -> int:
	var base := authored_max_alive if authored_max_alive > 0 else max_alive_default(respawn_policy)
	if respawn_policy != "wilderness":
		return base
	return base + maxi(zhavar_rung_index, 0) * MAX_ALIVE_PER_ZHAVAR_RUNG


## The `spawn_tables` kind's policy check (§4.10 ruling 13), as messages rather than a bool so the
## author is told which bound they crossed and by how much.
static func policy_violations(respawn_policy: String, table: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	var raw_slots: Variant = table.get("slots", [])
	var slots: Array = raw_slots if raw_slots is Array else []
	var label := str(table.get("id", "this table"))

	if respawn_policy == "none":
		problems.append(
			"%s targets a scene with respawn_policy \"none\"; no spawn table may target it."
			% label
		)
		return problems

	if respawn_policy != "limited":
		return problems

	if slots.size() > LIMITED_MAX_SLOTS:
		problems.append(
			"%s has %d slots; a \"limited\" location allows at most %d."
			% [label, slots.size(), LIMITED_MAX_SLOTS]
		)
	for raw_slot: Variant in slots:
		if not raw_slot is Dictionary:
			continue
		var slot: Dictionary = raw_slot
		var slot_id := str(slot.get("id", "?"))
		var days := int(slot.get("respawn_days", 0))
		if days < LIMITED_MIN_RESPAWN_DAYS:
			problems.append(
				"%s slot \"%s\" respawns every %d day(s); \"limited\" requires at least %d."
				% [label, slot_id, days, LIMITED_MIN_RESPAWN_DAYS]
			)
		var raw_range: Variant = slot.get("pack_size", {})
		var pack_range: Dictionary = raw_range if raw_range is Dictionary else {}
		var pack_max := int(pack_range.get("max", pack_range.get("min", 1)))
		if pack_max > LIMITED_MAX_PACK_SIZE:
			problems.append(
				"%s slot \"%s\" packs up to %d; \"limited\" allows at most %d."
				% [label, slot_id, pack_max, LIMITED_MAX_PACK_SIZE]
			)
		var slot_entries: Variant = slot.get("entries", [])
		var share := empty_share(slot_entries if slot_entries is Array else [])
		if share < LIMITED_MIN_EMPTY_SHARE:
			problems.append(
				(
					"%s slot \"%s\" is empty only %.0f%% of the time; \"limited\" requires at "
					+ "least %.0f%%."
				)
				% [label, slot_id, share * 100.0, LIMITED_MIN_EMPTY_SHARE * 100.0]
			)
	return problems
