class_name SaveMigrations
extends RefCounted
## Version transitions for the serialized save envelope.

const LEGACY_SCHEMA_VERSION := 2

## Schema 8's element-id rename (the 2026-09-06 proto-Dramgidian wheel slate).
## `khor` is deliberately absent: it is the one element whose name did not change.
const ELEMENT_RENAMES_V8: Dictionary = {
	"suul": "sul",
	"bloei": "vel",
	"aqua": "luth",
	"terra": "tham",
	"daar": "vekh",
	"molm": "mozh",
	"scor": "khash",
	"nul": "zhem",
	"strom": "zhur",
}
## DRAMGID deletes Alchemy outright rather than renaming it, which is why it is the
## one skill id the rename table maps to an empty string.
const ALCHEMY_SKILL_ID := "alchemy"
const CURRENT_SCHEMA_VERSION := 9


static func prepare(payload: Variant) -> Dictionary:
	if not payload is Dictionary:
		return _failure("Save payload is not a dictionary.")
	var source: Dictionary = payload
	var source_version := _source_version(source)
	if source_version < 0:
		return _failure("Save payload has no valid schema_version.")
	if source_version > CURRENT_SCHEMA_VERSION:
		return _failure(
			"Save schema %d is newer than the supported schema %d."
			% [source_version, CURRENT_SCHEMA_VERSION]
		)
	if source_version < LEGACY_SCHEMA_VERSION:
		return _failure("Save schema %d is unsupported; refusing to load it." % source_version)

	var migrated := source.duplicate(true)
	if source_version == LEGACY_SCHEMA_VERSION:
		migrated = _migrate_v2_to_v3(migrated)
	if source_version <= 3:
		migrated = _migrate_v3_to_v4(migrated)
	if source_version <= 4:
		migrated = _migrate_v4_to_v5(migrated)
	if source_version <= 5:
		migrated = _migrate_v5_to_v6(migrated)
	if source_version <= 6:
		migrated = _migrate_v6_to_v7(migrated)
	if source_version <= 7:
		migrated = _migrate_v7_to_v8(migrated)
	if source_version <= 8:
		migrated = _migrate_v8_to_v9(migrated)
	migrated["skill_check"] = SkillCheckService.normalize_save_data(
		migrated.get("skill_check", {})
	)
	migrated["schema_version"] = CURRENT_SCHEMA_VERSION
	return {"ok": true, "payload": migrated, "error": ""}


static func _source_version(source: Dictionary) -> int:
	if source.has("schema_version"):
		if typeof(source["schema_version"]) != TYPE_INT:
			return -1
		return int(source["schema_version"])
	if source.has("version") and typeof(source["version"]) == TYPE_INT:
		return int(source["version"])
	return -1


static func _migrate_v2_to_v3(source: Dictionary) -> Dictionary:
	var migrated := source.duplicate(true)
	var game_state: Dictionary = {}
	if migrated.get("game_state", {}) is Dictionary:
		game_state = migrated.get("game_state", {}).duplicate(true)
	game_state["skills"] = game_state.get("skills", {})
	game_state["var_harmony"] = game_state.get("var_harmony", {})
	migrated["game_state"] = game_state
	migrated["zhavar"] = migrated.get("zhavar", {})
	migrated["ng_plus"] = NGPlus.normalize(migrated.get("ng_plus", {}))
	migrated["id_schemas"] = StableIds.schema_manifest()
	return migrated


static func _migrate_v3_to_v4(source: Dictionary) -> Dictionary:
	var migrated := source.duplicate(true)
	var game_state: Dictionary = {}
	if migrated.get("game_state", {}) is Dictionary:
		game_state = migrated.get("game_state", {}).duplicate(true)
	game_state["combat_knowledge"] = game_state.get("combat_knowledge", {})
	migrated["game_state"] = game_state
	return migrated


static func _migrate_v4_to_v5(source: Dictionary) -> Dictionary:
	var migrated := source.duplicate(true)
	var game_state: Dictionary = {}
	if migrated.get("game_state", {}) is Dictionary:
		game_state = migrated.get("game_state", {}).duplicate(true)
	game_state["vendor_stock"] = game_state.get("vendor_stock", {})
	game_state["vendor_restock_cycles"] = game_state.get("vendor_restock_cycles", {})
	migrated["game_state"] = game_state
	# Vendor is a new stable-id domain in schema 5. Refreshing the manifest is
	# the compatibility bridge for otherwise-valid schema-4 saves.
	migrated["id_schemas"] = StableIds.schema_manifest()
	return migrated


## Schema 6 adds the tactical layer's per-unit state (issue #141) and persisted
## Expert-reroll usage (issue #189).
##
## It lives at the TOP LEVEL of the envelope, not inside `game_state`, because the
## authored side of these tables belongs to Pandora and only the per-unit state is
## save data — mixing them into GameState's flag/soul/inventory block would blur that.
##
## The migration is derived, not empty: a schema-5 save already knows its party, so the
## unit rows are projected from `game_state.party` through UnitMigration. That keeps the
## PartyMember roster the single source of who is in the party, and means an old save
## loads with a populated roster instead of an empty one. Jobs, abilities, attunement
## values and loadouts all start at their neutral defaults because no job or ability
## content exists yet (canon is owned by GitHub #132).
static func _migrate_v5_to_v6(source: Dictionary) -> Dictionary:
	var migrated := source.duplicate(true)
	if not migrated.get("tactical") is Dictionary:
		var game_state: Dictionary = {}
		if migrated.get("game_state", {}) is Dictionary:
			game_state = migrated.get("game_state", {})
		migrated["tactical"] = UnitMigration.roster_from_party_rows(
			game_state.get("party", [])
		).to_dict()
	if not migrated.has("skill_check"):
		migrated["skill_check"] = {"expert_rerolls_used": {}}
	return migrated


## Schema 7 adds the FR-504a world clock (`docs/prd-amendment-living-world.md`
## §3.2). A pre-clock save gets the default phase — the amendment's own
## acceptance criterion 1: "a save written before this amendment must load".
static func _migrate_v6_to_v7(source: Dictionary) -> Dictionary:
	var migrated := source.duplicate(true)
	if not migrated.get("world_clock") is Dictionary:
		migrated["world_clock"] = {"phase": String(WorldClock.DEFAULT_PHASE)}
	var game_state: Variant = migrated.get("game_state", {})
	if game_state is Dictionary:
		for collection_key: String in ["party", "custom_recruits"]:
			var rows: Variant = game_state.get(collection_key, [])
			if not rows is Array:
				continue
			for value: Variant in rows:
				if not value is Dictionary:
					continue
				var member: Dictionary = value
				if not member.has("breath_max"):
					member["breath_max"] = PartyMember.DEFAULT_BREATH_MAX
				if not member.has("breath"):
					member["breath"] = int(member["breath_max"])
	return migrated


## Schema 8 renames every element id on the Wheel except `khor`.
##
## This is not cosmetic. Element ids are persisted as *dictionary keys* in the
## tactical attunement rows, and `UnitAttunement.from_dict` rejects an entire
## row when it sees an unknown element key — so a schema-7 save loaded without
## this migration would silently drop every unit's attunement. The same ids also
## appear as `tone_<element>` skill ids and as the party's major/minor/mastery
## element fields.
static func _migrate_v7_to_v8(source: Dictionary) -> Dictionary:
	var migrated := source.duplicate(true)

	var game_state: Variant = migrated.get("game_state", {})
	if game_state is Dictionary:
		var state: Dictionary = game_state
		for collection_key: String in ["party", "custom_recruits"]:
			var rows: Variant = state.get(collection_key, [])
			if not rows is Array:
				continue
			for value: Variant in rows:
				if value is Dictionary:
					_rename_member_elements(value)
		state["skills"] = _rename_actor_skill_keys(state.get("skills", {}))
		migrated["game_state"] = state

	var tactical: Variant = migrated.get("tactical", {})
	if tactical is Dictionary:
		var attunements: Variant = tactical.get("unit_attunement", {})
		if attunements is Dictionary:
			var rows: Dictionary = attunements
			for unit_id: Variant in rows.keys():
				var row: Variant = rows[unit_id]
				if not row is Dictionary:
					continue
				var attunement: Dictionary = row
				var values: Variant = attunement.get("values", {})
				if values is Dictionary:
					attunement["values"] = _rename_element_keys(values)
	return migrated


## Schema 9 is the DRAMGID migration (`docs/architecture-dramgid.md` §2.1): the six
## legacy attributes become seven DRAMGID ones, twelve legacy skill ids take their
## DRAMGID names, and Alchemy — which DRAMGID deletes rather than renames — returns
## the points it cost to the member's pool instead of taking them with it.
##
## Step 6 of §2.1 is deliberately NOT done here. It asks for `max_hp`/`attack`/
## `defense`/`breath_max` to be recomputed from the new attributes, but those formulas
## are §6's and still unratified, and `DramgidDerived` (§3.3) does not exist yet. A
## migrated member keeps its stored derived stats, so loading a save never silently
## changes its combat numbers ahead of the owner's ruling. When §6 freezes, the
## recompute is an addition to this function, not a rewrite of it.
static func _migrate_v8_to_v9(source: Dictionary) -> Dictionary:
	var migrated := source.duplicate(true)

	var game_state: Variant = migrated.get("game_state", {})
	if game_state is Dictionary:
		var state: Dictionary = game_state
		# The refund is read from the ledger BEFORE the ledger's own keys are
		# renamed, because the row it needs is filed under the id being deleted.
		var ledger: Variant = state.get("skills", {})
		for collection_key: String in ["party", "custom_recruits"]:
			var rows: Variant = state.get(collection_key, [])
			if not rows is Array:
				continue
			for value: Variant in rows:
				if value is Dictionary:
					_migrate_member_to_dramgid(value, ledger)
		state["skills"] = _rename_actor_dramgid_skills(ledger)
		migrated["game_state"] = state

	migrated["skill_check"] = _rename_reroll_skill_ids(migrated.get("skill_check", {}))
	return migrated


static func _migrate_member_to_dramgid(member: Dictionary, skill_ledger: Variant) -> void:
	var refund := _alchemy_refund(member, skill_ledger)
	member["attributes"] = _rename_attribute_keys(member.get("attributes", {}))
	for field: String in ["skill_percentages", "skill_tiers"]:
		member[field] = _rename_dramgid_skill_keys(member.get(field, {}))
	member["advancement_points"] = int(member.get("advancement_points", 0)) + refund
	if not member.has("xp"):
		member["xp"] = 0


static func _rename_attribute_keys(rows: Variant) -> Dictionary:
	if not rows is Dictionary:
		return {}
	var source_rows: Dictionary = rows
	var renamed: Dictionary = {}
	for key: Variant in source_rows.keys():
		var attribute_id := str(key)
		renamed[str(DramgidSchema.ATTRIBUTE_RENAMES.get(attribute_id, attribute_id))] = (
			source_rows[key]
		)
	# Doctrine is the seventh attribute and has no legacy counterpart, so a pre-DRAMGID
	# member has nothing to rename into it. It starts at the point-buy FLOOR rather than
	# 0: a 0 would read as worse than any legal build everywhere Doctrine scales
	# something — `Renown._attribute_scale` divides by it — and the legacy six were
	# bought against a 20-point budget, so floor-2 Doctrine lands the row on DRAMGID's 22.
	if not renamed.is_empty() and not renamed.has(String(DramgidSchema.ATTR_DOCTRINE)):
		renamed[String(DramgidSchema.ATTR_DOCTRINE)] = DramgidSchema.ATTRIBUTE_FLOOR
	return renamed


static func _rename_dramgid_skill_keys(rows: Variant) -> Dictionary:
	if not rows is Dictionary:
		return {}
	var source_rows: Dictionary = rows
	var renamed: Dictionary = {}
	for key: Variant in source_rows.keys():
		var skill_id := _dramgid_skill_id(str(key))
		if skill_id.is_empty():
			continue
		renamed[skill_id] = source_rows[key]
	return renamed


## Maps one skill id through the DRAMGID slate. An empty return means DRAMGID deleted
## the skill (Alchemy is the only one). An id the table does not mention — a DRAMGID id
## already, an ARMS id, a `tone_*` id — comes back untouched, which is what makes this
## safe to run over a save that is already part-migrated.
static func _dramgid_skill_id(skill_id: String) -> String:
	if not DramgidSchema.SKILL_RENAMES.has(skill_id):
		return skill_id
	return str(DramgidSchema.SKILL_RENAMES[skill_id])


static func _rename_actor_dramgid_skills(rows: Variant) -> Dictionary:
	if not rows is Dictionary:
		return {}
	var source_rows: Dictionary = rows
	var renamed: Dictionary = {}
	for actor_id: Variant in source_rows.keys():
		var row: Variant = source_rows[actor_id]
		renamed[actor_id] = _rename_dramgid_skill_keys(row) if row is Dictionary else row
	return renamed


## §2.1 step 2: DRAMGID deletes Alchemy, so what the member spent on it is returned to
## the advancement pool rather than disappearing with the skill.
##
## `GameState.skills` records the exact points spent per skill, so that figure is
## authoritative when it exists. The cost curve is the fallback for a member with no
## ledger row — an authored recruit, or a save from before the ledger was written — and
## it charges from a base of 0% because nothing in the envelope separates an authored
## base percentage from a bought one. That over-refunds a member who was authored with
## free Alchemy, which is the direction to err in: the alternative silently confiscates
## points a player paid.
static func _alchemy_refund(member: Dictionary, skill_ledger: Variant) -> int:
	var actor_id := str(member.get("id", ""))
	if skill_ledger is Dictionary and not actor_id.is_empty():
		var actor_rows: Variant = (skill_ledger as Dictionary).get(actor_id, {})
		if actor_rows is Dictionary:
			var row: Variant = (actor_rows as Dictionary).get(ALCHEMY_SKILL_ID, {})
			if row is Dictionary and (row as Dictionary).has("advancement_points_spent"):
				return maxi(int((row as Dictionary)["advancement_points_spent"]), 0)

	var percentages: Variant = member.get("skill_percentages", {})
	if not percentages is Dictionary:
		return 0
	var bought := float((percentages as Dictionary).get(ALCHEMY_SKILL_ID, 0.0))
	if bought <= 0.0:
		return 0
	return Advancement.points_spent_for_percentage(0.0, bought)


## §2.1 step 5. An expert-reroll key is "<scene>:<member>:<skill>" and only its last
## segment is a skill id. The split has to come from the RIGHT: a scene path carries its
## own colon ("res://..."), so scanning left to right cuts the wrong field.
static func _rename_reroll_skill_ids(data: Variant) -> Dictionary:
	if not data is Dictionary:
		return {}
	var source: Dictionary = (data as Dictionary).duplicate(true)
	var used: Variant = source.get("expert_rerolls_used", {})
	if not used is Dictionary:
		return source
	var source_used: Dictionary = used
	var renamed: Dictionary = {}
	for key: Variant in source_used.keys():
		var reroll_key := str(key)
		var separator := reroll_key.rfind(":")
		if separator < 0:
			renamed[reroll_key] = source_used[key]
			continue
		var skill_id := _dramgid_skill_id(reroll_key.substr(separator + 1))
		if skill_id.is_empty():
			continue
		renamed["%s:%s" % [reroll_key.left(separator), skill_id]] = source_used[key]
	source["expert_rerolls_used"] = renamed
	return source


static func _rename_member_elements(member: Dictionary) -> void:
	for field: String in ["major_element", "minor_element", "mastery_element", "starting_mastery"]:
		if member.has(field):
			member[field] = _rename_element(str(member[field]))
	for field: String in ["skill_percentages", "skill_tiers"]:
		var rows: Variant = member.get(field, {})
		if rows is Dictionary:
			member[field] = _rename_tone_keys(rows)


## Maps one element id through the schema-8 slate. An id that is not on the
## Wheel (including `khor`, and including an already-migrated id) is returned
## untouched, which is what makes this safe to run more than once.
static func _rename_element(value: String) -> String:
	var key := value.to_lower()
	if ELEMENT_RENAMES_V8.has(key):
		return str(ELEMENT_RENAMES_V8[key])
	return value


static func _rename_element_keys(rows: Dictionary) -> Dictionary:
	var renamed: Dictionary = {}
	for key: Variant in rows.keys():
		renamed[_rename_element(str(key))] = rows[key]
	return renamed


## `GameState.skills` is keyed by ACTOR, and the tone ids live one level down —
## `{actor_id: {skill_id: {percentage, tier, …}}}`. Renaming its top level would
## rename actor ids and miss every tone skill, which is how a schema-7 save could
## reach schema 8 still holding `tone_scor` while the build asks for `tone_khash`
## and reads the difference as untrained. A `PartyMember` row is a different
## shape — its `skill_percentages`/`skill_tiers` are flat skill maps — which is
## why `_rename_member_elements` calls `_rename_tone_keys` directly.
static func _rename_actor_skill_keys(rows: Variant) -> Dictionary:
	if not rows is Dictionary:
		return {}
	var source_rows: Dictionary = rows
	var renamed: Dictionary = {}
	for actor_id: Variant in source_rows.keys():
		var row: Variant = source_rows[actor_id]
		# A non-dictionary row is carried through verbatim rather than replaced
		# with {}: the loader's validator has to still see the corruption instead
		# of the migration quietly erasing it.
		renamed[actor_id] = _rename_tone_keys(row) if row is Dictionary else row
	return renamed


## Skill ids are `tone_<element>`, so the element sits behind an underscore and
## has to be split off rather than matched as a whole word.
static func _rename_tone_keys(rows: Variant) -> Dictionary:
	if not rows is Dictionary:
		return {}
	var source_rows: Dictionary = rows
	var renamed: Dictionary = {}
	for key: Variant in source_rows.keys():
		var skill_id := str(key)
		if skill_id.begins_with("tone_"):
			skill_id = "tone_%s" % _rename_element(skill_id.substr(5))
		renamed[skill_id] = source_rows[key]
	return renamed


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "payload": {}, "error": message}
