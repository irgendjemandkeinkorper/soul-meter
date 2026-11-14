extends GdUnitTestSuite
## KitPreview (the chargen CALLING tab's ability tiles) against the real combat gates.

var _controllers: Array[CombatController] = []


func after_test() -> void:
	for controller: CombatController in _controllers:
		for actor: BattleActor in controller.allies + controller.enemies:
			actor.class_resource.host = null
	_controllers.clear()


func test_ironbrand_groups_its_commands_its_tones_and_the_common_kit() -> void:
	var groups := KitPreview.for_member(_member("ironbrand"))
	assert_array(_names(groups[KitPreview.CLASS])).contains_exactly_in_any_order(["Spend Scars", "Debt of Arms"])
	assert_array(_names(groups[KitPreview.TONES])).contains_exactly_in_any_order(
		["Kindle", "Firebreak", "Crown of Embers", "Reclaim", "Rot the Brace"]
	)
	# Sentence of Ash and Verdict by Fire are Khash, but they belong to the Pazzah kit.
	for group: StringName in KitPreview.GROUPS:
		assert_array(_names(groups[group])).not_contains(["Sentence of Ash", "Verdict by Fire", "Record Name"])
	assert_int((groups[KitPreview.OTHER_TONES] as Array).size()).is_equal(14)
	var common := _names(groups[KitPreview.COMMON])
	assert_array(common).contains(["Strike", "Guard", "Focus", "Cast"])
	assert_array(common).not_contains(["Move", "Move: Front"])


func test_a_signature_command_is_locked_until_its_perk_is_picked() -> void:
	var entry := _entry(KitPreview.for_member(_member("ironbrand")), KitPreview.CLASS, "Debt of Arms")
	assert_str(str(entry["lock"])).is_equal("Needs the Debt of Arms perk.")
	assert_str(str(_entry(KitPreview.for_member(_member("ironbrand")), KitPreview.CLASS, "Spend Scars")["lock"])).is_empty()
	var picked := _member("ironbrand")
	picked.perk_ids = PackedStringArray([_perk_granting("debt_of_arms")])
	assert_str(str(_entry(KitPreview.for_member(picked), KitPreview.CLASS, "Debt of Arms")["lock"])).is_empty()


func test_tones_only_sort_spells_and_follow_the_held_pair() -> void:
	var member := _member("ironbrand")
	member.major_element = "luth"
	member.minor_element = ""
	var groups := KitPreview.for_member(member)
	for entry: Dictionary in groups[KitPreview.TONES]:
		assert_str(String((entry["action"] as CombatAction).element_id)).is_equal("luth")
	assert_array(_names(groups[KitPreview.OTHER_TONES])).contains(["Kindle"])


## The preview and the battle agree for every class: an action the preview leaves out is
## refused by combat as another class's, and an action it shows is never refused that way.
func test_every_class_preview_matches_what_combat_allows() -> void:
	for row: Dictionary in ClassCatalog.ALL:
		var groups := KitPreview.for_member(_member(str(row["id"])))
		var shown: Dictionary = {}
		for group: StringName in KitPreview.GROUPS:
			for entry: Dictionary in groups[group]:
				shown[(entry["action"] as CombatAction).id] = str(entry["lock"])
		var controller := _battle(str(row["patron"]))
		var ally := controller.allies[0]
		var enemy := controller.enemies[0]
		for action: CombatAction in CombatActionCatalog.player_actions():
			if action.kind == CombatAction.Kind.MOVE or action.kind == CombatAction.Kind.RESOLUTION:
				continue
			var target := ally if action.requires_ally_target() else enemy
			var gate := controller.query_action(action, target, {"availability_only": true})
			var blocked_by := StringName(str(gate.get("blocked_by", "")))
			var label := "%s / %s: %s" % [row["name"], action.display_name, gate.get("message", "")]
			if shown.has(action.id):
				assert_bool(blocked_by == &"class_resource").override_failure_message(label).is_false()
				if not str(shown[action.id]).is_empty():
					assert_str(String(blocked_by)).override_failure_message(label).is_equal("perk_missing")
			elif action.kind != CombatAction.Kind.PASS or not action.class_resource_action.is_empty():
				assert_str(String(blocked_by)).override_failure_message(label).is_equal("class_resource")


## The "In a fight" preview is the battle's own fill over the kit: eight slots, Strike then
## Guard, one command per role within its quota, nothing outside the kit and no signature
## whose perk is unpicked.
func test_every_class_hotbar_preview_fills_eight_slots_by_role_from_its_kit() -> void:
	for row: Dictionary in ClassCatalog.ALL:
		var member := _member(str(row["id"]))
		var groups := KitPreview.for_member(member)
		var usable: Dictionary = {}
		for group: StringName in KitPreview.GROUPS:
			for entry: Dictionary in groups[group]:
				if str(entry["lock"]).is_empty():
					usable[(entry["action"] as CombatAction).id] = true
		var bar := KitPreview.hotbar(member)
		var label := str(row["name"])
		assert_int(bar.size()).override_failure_message(label).is_equal(HotbarFill.SIZE)
		assert_str(String(bar[0].id)).override_failure_message(label).is_equal("strike")
		assert_str(String(bar[1].id)).override_failure_message(label).is_equal("guard")
		var roles: Dictionary = {}
		for action: CombatAction in bar:
			assert_bool(usable.has(action.id)).override_failure_message("%s slots %s" % [label, action.display_name]).is_true()
			var role := HotbarFill.slot_role(action)
			roles[role] = int(roles.get(role, 0)) + 1
		assert_int(int(roles.get(HotbarFill.SlotRole.SPELL, 0))).override_failure_message(label).is_less_equal(2)
		assert_int(int(roles.get(HotbarFill.SlotRole.WEAPON_ART, 0))).override_failure_message(label).is_less_equal(2)
		assert_int(int(roles.get(HotbarFill.SlotRole.SIGNATURE, 0))).override_failure_message(label).is_less_equal(1)


## A signature slot holds the class command even with nothing banked yet (the battle keeps
## it, dimmed); a signature whose perk is unpicked is not in the kit and never slots.
func test_the_signature_slot_holds_the_banked_command_not_an_unpicked_perk() -> void:
	var ids: Array[StringName] = []
	for action: CombatAction in KitPreview.hotbar(_member("ironbrand")):
		ids.append(action.id)
	assert_array(ids).contains([&"spend-scars"])
	assert_array(ids).not_contains([&"debt-of-arms"])


func test_only_the_listed_gap_classes_add_no_actions_of_their_own() -> void:
	var without: PackedStringArray = []
	for row: Dictionary in ClassCatalog.ALL:
		if (KitPreview.for_member(_member(str(row["id"])))[KitPreview.CLASS] as Array).is_empty():
			without.append(str(row["name"]))
	# Stormbearer's Attribution is passive: no command, no patron working. The CALLING tab
	# says so (chargen plan, gap 5) rather than inventing one. A class joining this list must
	# be added to the plan's gaps, not given abilities.
	assert_array(Array(without)).contains_exactly(["Stormbearer"])


func _member(class_id: String) -> PartyMember:
	var row := ClassCatalog.by_id(class_id)
	var member := PartyMember.new()
	member.class_id = class_id
	member.patron = str(row.get("patron", ""))
	member.major_element = str(row.get("suggested_major", ""))
	member.minor_element = str(row.get("suggested_minor", ""))
	return member


func _battle(patron: String) -> CombatController:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	var ally := _actor("Preview tester")
	ally.class_resource = ClassResourceRegistry.for_patron(patron)
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), BattlefieldModel.create_default(rules), rules)
	var party: Array[BattleActor] = [ally]
	controller.start(party, [_actor("Target")], &"kit-preview")
	_controllers.append(controller)
	return controller


func _actor(display_name: String) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = display_name
	actor.hp = 100
	actor.max_hp = 100
	actor.attack = 5
	actor.defense = 1
	return actor


func _names(entries: Array) -> Array:
	var names: Array = []
	for entry: Dictionary in entries:
		names.append((entry["action"] as CombatAction).display_name)
	return names


func _entry(groups: Dictionary, group: StringName, display_name: String) -> Dictionary:
	for entry: Dictionary in groups[group]:
		if (entry["action"] as CombatAction).display_name == display_name:
			return entry
	return {"lock": "<missing>"}


func _perk_granting(op: String) -> String:
	for perk: Dictionary in PerkCatalog.all():
		var perk_id := str(perk.get("id", ""))
		if PerkCatalog.effect_total(PackedStringArray([perk_id]), op) > 0:
			return perk_id
	return ""
