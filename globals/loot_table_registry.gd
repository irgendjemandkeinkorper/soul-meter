class_name LootTableRegistry
extends RefCounted
## Read-only weighted loot tables for F4's fourth field verb (#284).
##
## Design choice, matching FastTravelRegistry: Pandora stays canonical and
## nothing writes back, but Pandora has no ratified loot-table entity contract
## yet, so this registry holds the small table set in GDScript. Migrate it to
## generated output once that contract exists; do not hand-edit `data.pandora`
## to satisfy a container.
##
## `roll()` is PURE and deterministic. It takes a seed and the already-resolved
## skill outcomes rather than reaching for `SkillCheck` itself, for the same
## reason `VendorRegistry.price_for()` takes a barter ratio: a table that reads
## global state cannot be tested without an autoload harness, and cannot promise
## the same contents twice. `GameState.ensure_loot_container()` writes a
## container's contents exactly once, so a rolled table is frozen at first
## contact and survives save/load without a second roll.
##
## PROVISIONAL: every weight, roll count and difficulty here is tuning, and #284
## hands numeric values to DeepSeek. The SHAPE — weighted rows, optional
## skill-gated rows, one frozen roll per container — is the decision.
##
## Note for #349 (AccordZone): `sounding` and `unweave`, which gate the two
## hardest rows below, are both `LoomSensitivity.FULL`. When `loom_penalty()`
## stops returning 0, hidden compartments become genuinely harder to find inside
## a Hush or Waning zone with no change needed here. That is deliberate — these
## rows are gated behind Loom-sensitive skills BECAUSE searching a thinned place
## should be harder, and it gives the hook something real to do on arrival.

## `rolls`   how many WEIGHTED rows are drawn, without replacement.
## `rows`    an ungated row is {item_id, quantity, weight} and competes in that
##           draw. A GATED row is {item_id, quantity, skill, modifier} and carries
##           NO weight: it does not compete, it is granted outright when its check
##           passes — this is "loot tables checked against the 22 skills".
##
## Gated rows sit OUTSIDE the weighted pool deliberately. Putting them in it looked
## right and was wrong: adding a row changes the distribution of every other row,
## so passing a check could hand the player a DIFFERENT ordinary item rather than
## an extra one. Verified on the shipped road-cache seed, which gave hearthloaf on
## a failed `sounding` and salted riverfish on a passed one — a strictly better
## searcher, strictly different loot, and no way to tell that from a bug.
##
## Outside the pool, the rule is one a player can feel: **passing a check can only
## ever add.** The difficulty modifier is then the whole knob, which is also why a
## gated row needs no weight — you beat a −15 check, you get the thing.
const _TABLES: Dictionary = {
	&"road-cache":
	{
		"rolls": 2,
		"rows":
		[
			{"item_id": "consumables/hearthloaf", "quantity": 1, "weight": 30},
			{"item_id": "materials/lamp_oil", "quantity": 1, "weight": 25},
			{"item_id": "materials/iron_rivets", "quantity": 2, "weight": 20},
			{"item_id": "consumables/salted_riverfish", "quantity": 1, "weight": 15},
			# A false bottom only a careful searcher finds. `sounding` rides
			# Intuition, so the gated rows across these two tables are not all
			# one attribute wearing three names — a table set that only ever
			# rewards Reason is a table set with one skill in it.
			{
				"item_id": "tools/lockpick_roll",
				"quantity": 1,
				"skill": "sounding",
				"modifier": -10.0,
			},
		],
	},
	&"wight-hoard":
	{
		"rolls": 2,
		"rows":
		[
			{"item_id": "materials/grave_salt", "quantity": 2, "weight": 35},
			{"item_id": "materials/cinder_ink_vial", "quantity": 1, "weight": 25},
			{"item_id": "consumables/bitterleaf_poultice", "quantity": 1, "weight": 20},
			# Reading what the dead left behind. `recall` is the lore skill.
			{
				"item_id": "relics/votive_cinder",
				"quantity": 1,
				"skill": "recall",
				"modifier": -15.0,
			},
			{
				"item_id": "relics/quine_shard",
				"quantity": 1,
				"skill": "unweave",
				"modifier": -20.0,
			},
		],
	},
}


static func has_table(table_id: StringName) -> bool:
	return _TABLES.has(table_id)


static func table(table_id: StringName) -> Dictionary:
	var row: Variant = _TABLES.get(table_id, {})
	return row.duplicate(true) if row is Dictionary else {}


static func table_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in _TABLES:
		ids.append(id)
	ids.sort()
	return ids


## Every distinct skill a table's gated rows need, sorted so callers resolve them
## in a stable order. Empty for a table with no gated rows.
static func skills_required(table_id: StringName) -> PackedStringArray:
	var skills := PackedStringArray()
	for row: Dictionary in _rows(table_id):
		var skill := str(row.get("skill", ""))
		if not skill.is_empty() and not skills.has(skill):
			skills.append(skill)
	skills.sort()
	return skills


## The situational modifier authored for a gated row, so the caller resolves the
## check the table intended rather than a bare one.
static func modifier_for_skill(table_id: StringName, skill: String) -> float:
	for row: Dictionary in _rows(table_id):
		if str(row.get("skill", "")) == skill:
			return float(row.get("modifier", 0.0))
	return 0.0


## Draws `rolls` ungated rows without replacement, weighted, then appends every
## gated row whose skill is marked passed in `skill_outcomes`.
##
## Deterministic: the same seed and the same outcomes give the same contents,
## every time and on every machine. Drawing WITHOUT replacement is deliberate —
## with replacement, a 30-weight row would routinely fill a two-roll container
## with two loaves, which reads as a bug rather than as luck.
static func roll(
	table_id: StringName, rng_seed: int, skill_outcomes: Dictionary = {}
) -> Array[Dictionary]:
	var contents: Array[Dictionary] = []
	var pool: Array[Dictionary] = []
	var granted: Array[Dictionary] = []
	for row: Dictionary in _rows(table_id):
		var skill := str(row.get("skill", ""))
		if skill.is_empty():
			if int(row.get("weight", 0)) > 0:
				pool.append(row)
		elif bool(skill_outcomes.get(skill, false)):
			granted.append(row)
	if pool.is_empty():
		return _as_contents(granted)

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var draws: int = mini(int(table(table_id).get("rolls", 0)), pool.size())
	for _draw in draws:
		var total := 0
		for row: Dictionary in pool:
			total += int(row["weight"])
		var pick := rng.randi_range(1, total)
		var running := 0
		for index in pool.size():
			running += int(pool[index]["weight"])
			if pick <= running:
				var taken: Dictionary = pool[index]
				contents.append(
					{"item_id": str(taken["item_id"]), "quantity": int(taken.get("quantity", 1))}
				)
				pool.remove_at(index)
				break
	# Granted rows are appended AFTER the weighted draw, never mixed into it, so
	# the base contents of a container are identical whether the player passed the
	# search or not. Passing adds; it never substitutes.
	contents.append_array(_as_contents(granted))
	return contents


## Just the gated rows a set of outcomes earns, with no weighted draw. Callers
## that resolve the search separately from the base contents use this rather than
## diffing two `roll()` results — a positional diff would silently depend on
## granted rows always being appended last.
static func granted_rows(table_id: StringName, skill_outcomes: Dictionary) -> Array[Dictionary]:
	var granted: Array[Dictionary] = []
	for row: Dictionary in _rows(table_id):
		var skill := str(row.get("skill", ""))
		if not skill.is_empty() and bool(skill_outcomes.get(skill, false)):
			granted.append(row)
	return _as_contents(granted)


## A container's seed. Derived from its own id so the same crate rolls the same
## contents in every playthrough of the same save, and two crates sharing a table
## still differ from each other.
static func seed_for_container(container_id: String) -> int:
	return int(container_id.hash())


static func _as_contents(rows: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in rows:
		result.append(
			{"item_id": str(row["item_id"]), "quantity": int(row.get("quantity", 1))}
		)
	return result


static func _rows(table_id: StringName) -> Array:
	var definition: Dictionary = _TABLES.get(table_id, {})
	var rows: Variant = definition.get("rows", [])
	return rows if rows is Array else []
