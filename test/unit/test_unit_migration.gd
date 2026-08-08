extends GdUnitTestSuite
## The PartyMember -> unit/loadout migration path (issue #141).

const PARTY_MEMBER_SOURCE_PATH := "res://globals/party_member.gd"


func _member(id: String, display_name: String, max_hp: int) -> PartyMember:
	var member := PartyMember.new()
	member.id = id
	member.display_name = display_name
	member.max_hp = max_hp
	return member


func test_a_party_member_projects_onto_a_unit_row() -> void:
	var unit := UnitMigration.unit_from_party_member(_member("vex", "Vex", 28))
	assert_str(unit.id).is_equal("vex")
	assert_str(unit.display_name).is_equal("Vex")
	assert_int(unit.base_hp).is_equal(28)
	# Deliberately unmapped — PartyMember has no source for these and filling them in
	# would be setting balance numbers, which issue #141 does not decide.
	assert_int(unit.base_mp).is_equal(0)
	assert_int(unit.base_spd).is_equal(0)
	assert_int(unit.move).is_equal(0)
	assert_int(unit.jump).is_equal(0)
	assert_str(unit.epithet).is_equal("")


func test_a_member_without_an_id_gets_a_deterministic_slug() -> void:
	var first := UnitMigration.unit_id_for(_member("", "Iris Illepah", 10))
	var second := UnitMigration.unit_id_for(_member("", "Iris Illepah", 10))
	assert_str(first).is_equal("iris-illepah")
	assert_str(first).is_equal(second)


func test_a_roster_built_from_a_party_starts_neutral_and_unequipped() -> void:
	var roster := UnitMigration.roster_from_party([_member("vex", "Vex", 28)])
	assert_array(Array(roster.unit_ids())).is_equal(["vex"])
	var attunement := roster.attunement("vex")
	assert_object(attunement).is_not_null()
	assert_bool(attunement.is_complete()).is_true()
	for element in ElementWheel.ORDER:
		assert_int(attunement.value_for(element)).is_equal(0)
	var loadout := roster.loadout("vex")
	assert_str(loadout.primary_job_id).is_equal("")
	assert_str(loadout.reaction_ability_id).is_equal("")
	assert_bool(loadout.equip.is_empty()).is_true()
	assert_bool((roster.job_progress["vex"] as Dictionary).is_empty()).is_true()


func test_serialized_party_rows_migrate_the_same_way_as_live_members() -> void:
	var member := _member("vex", "Vex", 28)
	var from_member := UnitMigration.unit_from_party_member(member).to_dict()
	var from_row := UnitMigration.unit_from_party_row(member.to_dict()).to_dict()
	assert_dict(from_row).is_equal(from_member)


func test_reconcile_adds_newcomers_and_drops_departures_without_losing_progress() -> void:
	var roster := UnitMigration.roster_from_party([_member("vex", "Vex", 28)])
	roster.attunement("vex").set_value(&"terra", 2)
	roster.loadout("vex").equip["hand"] = "synthetic-item"

	var reconciled := UnitMigration.reconcile(
		roster, [_member("vex", "Vex", 28), _member("iris", "Iris", 20)]
	)
	assert_array(Array(reconciled.unit_ids())).is_equal(["iris", "vex"])
	# Surviving units keep everything they had earned.
	assert_int(reconciled.attunement("vex").value_for(&"terra")).is_equal(2)
	assert_str(str(reconciled.loadout("vex").equip["hand"])).is_equal("synthetic-item")

	var shrunk := UnitMigration.reconcile(reconciled, [_member("iris", "Iris", 20)])
	assert_array(Array(shrunk.unit_ids())).is_equal(["iris"])
	assert_object(shrunk.attunement("vex")).is_null()
	assert_object(shrunk.loadout("vex")).is_null()


func test_migration_ignores_non_party_member_entries() -> void:
	var roster := UnitMigration.roster_from_party([_member("vex", "Vex", 28), null, "not-a-member"])
	assert_array(Array(roster.unit_ids())).is_equal(["vex"])


func test_a_roster_round_trips_through_a_dictionary() -> void:
	var roster := UnitMigration.roster_from_party([_member("vex", "Vex", 28)])
	roster.attunement("vex").set_value(&"suul", -3)
	(roster.job_progress["vex"] as Dictionary)["synthetic-job"] = UnitJobProgress.from_dict(
		{"unit_id": "vex", "job_id": "synthetic-job", "jp": 120, "mastered": ["b", "a"]}
	)
	var restored := UnitRoster.from_dict(roster.to_dict())
	assert_object(restored).is_not_null()
	assert_int(restored.attunement("vex").value_for(&"suul")).is_equal(-3)
	assert_int(restored.progress_for("vex", "synthetic-job").jp).is_equal(120)
	assert_array(Array(restored.progress_for("vex", "synthetic-job").mastered)).is_equal(["a", "b"])
	assert_dict(restored.to_dict()).is_equal(roster.to_dict())


func test_a_roster_rejects_rows_that_belong_to_no_unit() -> void:
	var roster := UnitMigration.roster_from_party([_member("vex", "Vex", 28)])
	var payload := roster.to_dict()
	(payload["unit_loadout"] as Dictionary)["ghost"] = {"unit_id": "ghost"}
	assert_object(UnitRoster.from_dict(payload)).is_null()

	var attunement_payload := roster.to_dict()
	(attunement_payload["unit_attunement"] as Dictionary)["ghost"] = {"unit_id": "ghost", "values": {}}
	assert_object(UnitRoster.from_dict(attunement_payload)).is_null()

	assert_object(UnitRoster.from_dict("not a dictionary")).is_null()


## Guard for #66: the migration must not widen — or route around — the portrait
## extension allowlist. UnitDefinition.portrait_ref is an opaque id and no unit code
## loads a texture, so PartyMember stays the only portrait deserialization path.
func test_portrait_extension_allowlist_is_unchanged() -> void:
	var source_file := FileAccess.open(PARTY_MEMBER_SOURCE_PATH, FileAccess.READ)
	assert_object(source_file).is_not_null()
	var source := source_file.get_as_text()
	source_file.close()
	assert_str(source).contains('if ext in ["png", "jpg", "jpeg", "svg", "webp", "tga"]:')


func test_no_unit_side_code_loads_a_resource() -> void:
	for path in [
		"res://globals/units/unit_definition.gd",
		"res://globals/units/unit_migration.gd",
		"res://globals/units/unit_roster.gd",
		"res://globals/units/unit_loadout.gd",
	]:
		var file := FileAccess.open(path, FileAccess.READ)
		assert_object(file).is_not_null()
		var source := file.get_as_text()
		file.close()
		assert_str(source).not_contains("load(")
