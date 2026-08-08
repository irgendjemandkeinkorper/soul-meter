class_name UnitMigration
extends RefCounted
## The PartyMember -> unit/loadout migration path (issue #141).
##
## DERIVES, DOES NOT REPLACE. PartyMember stays the field-layer roster row and keeps
## owning portrait deserialization behind its #66 extension allowlist — this module
## never touches that path and never loads a resource. GameState.party remains the
## source of who is in the party; the roster is the tactical projection of it.
##
## WHAT MAPS AND WHAT DOES NOT
## PartyMember predates the tactical layer, so only part of a unit has a source:
##   max_hp        -> base_hp
##   id/display_name -> id/display_name
## These have NO source on PartyMember and are left at zero on purpose:
##   base_mp, base_spd, move, jump, epithet
## Filling them in would be setting balance numbers, which issue #141 explicitly
## does not decide. They are an OWNER QUESTION: either PartyMember grows the fields,
## or every party member gets an authored Pandora `units` row. Until then a migrated
## unit is a valid, complete, round-trippable row that is not yet battle-ready —
## note that base_spd 0 means the CT scheduler would treat the unit as minimum speed.
##
## Attunement starts at all-zero. That is not a balance choice: zero is the neutral
## identity of a signed -3..+3 scale, i.e. "no leaning recorded yet".

## Deterministic id for a party member that has no explicit id. Falls back to a slug
## of the display name so two saves of the same party agree on unit ids.
static func unit_id_for(member: PartyMember) -> String:
	if member == null:
		return ""
	if not member.id.is_empty():
		return member.id
	return _slug(member.display_name)


static func unit_from_party_member(member: PartyMember) -> UnitDefinition:
	if member == null:
		return null
	var unit := UnitDefinition.new()
	unit.id = unit_id_for(member)
	unit.display_name = member.display_name
	unit.base_hp = member.max_hp
	# base_mp / base_spd / move / jump / epithet / portrait_ref: see header — no source.
	return unit


## The same mapping applied to a SERIALIZED party row. The save migration runs on raw
## payload dictionaries and must not instantiate PartyMember: from_dict() resolves and
## LOADS the portrait texture, and a schema migration has no business touching the
## filesystem or the #66 allowlist. Both entry points share this one mapping so they
## cannot drift.
static func unit_from_party_row(data: Dictionary) -> UnitDefinition:
	var unit := UnitDefinition.new()
	var id := str(data.get("id", ""))
	unit.id = id if not id.is_empty() else _slug(str(data.get("display_name", "")))
	unit.display_name = str(data.get("display_name", ""))
	unit.base_hp = int(data.get("max_hp", 0))
	return unit


## Builds a roster from serialized party rows (the save-migration entry point).
static func roster_from_party_rows(rows: Variant) -> UnitRoster:
	var roster := UnitRoster.new()
	if not rows is Array:
		return roster
	for row: Variant in (rows as Array):
		if not row is Dictionary:
			continue
		var unit := unit_from_party_row(row)
		if unit.id.is_empty():
			continue
		roster.add_unit(unit)
	return roster


## Builds a roster from a party. Members with an unresolvable id are skipped rather
## than colliding into one another.
static func roster_from_party(members: Array) -> UnitRoster:
	var roster := UnitRoster.new()
	for entry: Variant in members:
		if not entry is PartyMember:
			continue
		var unit := unit_from_party_member(entry)
		if unit == null or unit.id.is_empty():
			continue
		roster.add_unit(unit)
	return roster


## Reconciles an existing roster against the live party: adds units for members that
## have none, and drops units whose member has left. Per-unit state (JP, mastery,
## attunement, loadout) of surviving units is preserved untouched.
static func reconcile(roster: UnitRoster, members: Array) -> UnitRoster:
	var reconciled := roster if roster != null else UnitRoster.new()
	var live_ids: Dictionary = {}
	for entry: Variant in members:
		if not entry is PartyMember:
			continue
		var member: PartyMember = entry
		var id := unit_id_for(member)
		if id.is_empty():
			continue
		live_ids[id] = true
		if not reconciled.units.has(id):
			reconciled.add_unit(unit_from_party_member(member))
	for existing_id: String in reconciled.unit_ids():
		if not live_ids.has(existing_id):
			reconciled.units.erase(existing_id)
			reconciled.job_progress.erase(existing_id)
			reconciled.attunements.erase(existing_id)
			reconciled.loadouts.erase(existing_id)
	return reconciled


static func _slug(value: String) -> String:
	var slug := ""
	for character in value.to_lower():
		if (character >= "a" and character <= "z") or (character >= "0" and character <= "9"):
			slug += character
		else:
			slug += "-"
	while slug.contains("--"):
		slug = slug.replace("--", "-")
	return slug.lstrip("-").rstrip("-")
