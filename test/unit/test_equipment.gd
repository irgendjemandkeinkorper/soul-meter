extends GdUnitTestSuite
## P1.4: owner-ratified provisional bonuses, isolated from saved base stats.

const EXPECTED: Dictionary = {
	ItemIds.WEAPONS_FORGE_HAMMER: {"attack": 2, "defense": 0},
	ItemIds.WEAPONS_ROADWARDEN_SPEAR: {"attack": 1, "defense": 1},
	ItemIds.WEAPONS_TAUBSTUMMER_AXE: {"attack": 3, "defense": -1},
}

var _before: Dictionary
var _lead: PartyMember
var _other: PartyMember


func before_test() -> void:
	_before = GameState.to_dict()
	GameState.inventory.clear()
	_lead = PartyMember.new()
	_lead.id = GameState.PROTAGONIST_ID
	_lead.attack = 11
	_lead.defense = 4
	_lead.kit_weapon_skill = "heft"
	_lead.skill_tiers = {"heft": "trained"}
	_other = PartyMember.new()
	_other.id = "iris"
	GameState.set_party([_lead, _other])


func after_test() -> void:
	GameState.from_dict(_before)


func test_only_the_three_ruled_weapons_have_generated_bonuses() -> void:
	var prototypes: Dictionary = GameState.inventory.protoset.data
	var with_bonuses: Array[String] = []
	for prototype_id: String in prototypes:
		var row: Dictionary = prototypes[prototype_id]
		if row.has("attack_bonus") or row.has("defense_bonus"):
			with_bonuses.append(prototype_id)
			assert_dict({"attack": int(row.get("attack_bonus", 0)), "defense": int(row.get("defense_bonus", 0))}).is_equal(EXPECTED[prototype_id])
	assert_int(with_bonuses.size()).is_equal(3)


func test_each_weapon_applies_once_and_unequipping_restores_base_stats() -> void:
	var saved_base := _lead.to_dict()
	var rules := load("res://data/combat/combat_rules.tres") as CombatRules
	var bare := BattleActor.from_party_member(_lead, 0)
	for prototype_id: String in EXPECTED:
		var item := GameState.inventory.create_and_add_item(prototype_id)
		assert_bool(GameState.equip_item(_lead, item, &"main")).is_true()
		assert_bool(GameState.inventory.has_item(item)).is_true()
		assert_dict(_lead.equipment_bonus()).is_equal(EXPECTED[prototype_id])
		for reconstruction: int in 3:
			var actor := BattleActor.from_party_member(_lead, 0)
			assert_int(actor.effective_attack()).is_equal(11 + int(EXPECTED[prototype_id]["attack"]))
			assert_int(actor.effective_defense()).is_equal(4 + int(EXPECTED[prototype_id]["defense"]))
			assert_int(rules.action_points_for(actor)).is_equal(rules.action_points_for(bare))
			assert_int(rules.charge_speed_for(actor)).is_equal(rules.charge_speed_for(bare))
		assert_int(BattleActor.from_party_member(_other, 1).attack).is_equal(_other.attack)
		assert_bool(GameState.unequip_item(_lead, &"main")).is_true()
		assert_dict(_lead.equipment_bonus()).is_equal({"attack": 0, "defense": 0})
		assert_int(BattleActor.from_party_member(_lead, 0).attack).is_equal(11)
		assert_int(BattleActor.from_party_member(_lead, 0).defense).is_equal(4)
		assert_dict(_lead.to_dict()).is_equal(saved_base)


func test_different_members_keep_their_own_weapon_and_cannot_share_an_item() -> void:
	var hammer := GameState.inventory.create_and_add_item(ItemIds.WEAPONS_FORGE_HAMMER)
	var spear := GameState.inventory.create_and_add_item(ItemIds.WEAPONS_ROADWARDEN_SPEAR)
	assert_bool(GameState.equip_item(_lead, hammer, &"main")).is_true()
	assert_bool(GameState.equip_item(_other, spear, &"main")).is_true()
	assert_bool(GameState.equip_item(_other, hammer, &"main")).is_false()
	assert_int(BattleActor.from_party_member(_lead, 0).attack).is_equal(13)
	assert_int(BattleActor.from_party_member(_other, 1).attack).is_equal(_other.attack + 1)
	assert_int(BattleActor.from_party_member(_other, 1).defense).is_equal(_other.defense + 1)
	assert_int(GameState.inventory.get_item_count()).is_equal(2)
	assert_bool(GameState.equip_item(_lead, hammer, &"off")).is_false()
	assert_bool(GameState.equip_item(PartyMember.new(), hammer, &"main")).is_false()
	assert_bool(GameState.unequip_item(_lead, &"main")).is_true()
	assert_bool(GameState.equip_item(_other, hammer, &"main")).is_true()
	assert_dict(_other.equipment_bonus()).is_equal(EXPECTED[ItemIds.WEAPONS_FORGE_HAMMER])


func test_removing_the_equipped_item_clears_the_member_slot_and_notifies() -> void:
	var hammer := GameState.inventory.create_and_add_item(ItemIds.WEAPONS_FORGE_HAMMER)
	var changes: Array[PartyMember] = []
	var on_change := func(member: PartyMember) -> void: changes.append(member)
	GameState.equipment_changed.connect(on_change)
	GameState.equip_item(_lead, hammer, &"main")
	GameState.inventory.remove_item(hammer)
	GameState.equipment_changed.disconnect(on_change)
	assert_int(changes.size()).is_equal(2)
	assert_dict(_lead.equipped_slots).is_empty()
	assert_int(BattleActor.from_party_member(_lead, 0).attack).is_equal(11)


func test_separate_copies_can_be_equipped_but_a_physical_item_cannot_be_shared() -> void:
	var first := GameState.inventory.create_and_add_item(ItemIds.WEAPONS_FORGE_HAMMER)
	var second := GameState.inventory.create_and_add_item(ItemIds.WEAPONS_FORGE_HAMMER)
	assert_bool(GameState.equip_item(_other, first, &"main")).is_true()
	assert_bool(GameState.equip_item(_lead, first, &"main")).is_false()
	assert_bool(GameState.equip_item(_lead, second, &"main")).is_true()
	GameState.inventory.move_item(0, 1)
	assert_object(GameState.equipment_owner(first)).is_same(_other)
	assert_object(GameState.equipment_owner(second)).is_same(_lead)
	assert_int(BattleActor.from_party_member(_lead, 0).attack).is_equal(13)
	assert_int(BattleActor.from_party_member(_other, 1).attack).is_equal(_other.attack + 2)
	GameState.inventory.remove_item(first)
	assert_dict(_other.equipped_slots).is_empty()
	assert_dict(_lead.equipped_slots).is_equal({"main": ItemIds.WEAPONS_FORGE_HAMMER})
	assert_object(GameState.equipped_item(_lead, &"main")).is_same(second)


func test_same_prototype_on_two_members_survives_save_restore_without_sharing() -> void:
	var first := GameState.inventory.create_and_add_item(ItemIds.WEAPONS_FORGE_HAMMER)
	var second := GameState.inventory.create_and_add_item(ItemIds.WEAPONS_FORGE_HAMMER)
	GameState.equip_item(_lead, first, &"main")
	GameState.equip_item(_other, second, &"main")
	var saved := GameState.to_dict()
	assert_bool(GameState.from_dict(saved)).is_true()
	var restored_first := GameState.equipped_item(GameState.party[0], &"main")
	var restored_second := GameState.equipped_item(GameState.party[1], &"main")
	assert_object(restored_first).is_not_null()
	assert_object(restored_second).is_not_null()
	assert_bool(restored_first == restored_second).is_false()
	assert_dict(GameState.to_dict()).is_equal(saved)
	assert_int(GameState.inventory.get_item_count()).is_equal(2)


func test_member_round_trip_and_duplicate_or_unknown_references_are_safe() -> void:
	_lead.equipped_slots = {"main": ItemIds.WEAPONS_FORGE_HAMMER, "off": ItemIds.WEAPONS_FORGE_HAMMER, "head": "unknown/item"}
	var restored := PartyMember.from_dict(_lead.to_dict())
	assert_dict(restored.equipped_slots).is_equal(_lead.equipped_slots)
	assert_dict(restored.equipment_bonus()).is_equal({"attack": 2, "defense": 0})
	restored.equipped_slots.clear()
	assert_bool(_lead.equipped_slots.is_empty()).is_false()
	assert_dict(PartyMember.from_dict({}).equipped_slots).is_empty()
	assert_dict(PartyMember.from_dict({"equipped_slots": null}).equipped_slots).is_empty()


func test_game_state_round_trip_preserves_owners_items_and_base_stats() -> void:
	var hammer := GameState.inventory.create_and_add_item(ItemIds.WEAPONS_FORGE_HAMMER)
	var axe := GameState.inventory.create_and_add_item(ItemIds.WEAPONS_TAUBSTUMMER_AXE)
	GameState.equip_item(_lead, hammer, &"main")
	GameState.equip_item(_other, axe, &"main")
	var payload := GameState.to_dict()
	assert_bool(payload.has("equipped_slots")).is_false()
	assert_bool(GameState.from_dict(payload)).is_true()
	assert_dict(GameState.to_dict()).is_equal(payload)
	assert_int(GameState.inventory.get_item_count()).is_equal(2)
	assert_int(BattleActor.from_party_member(GameState.party[0], 0).attack).is_equal(13)
	assert_int(BattleActor.from_party_member(GameState.party[1], 1).defense).is_equal(_other.defense - 1)
	assert_int(GameState.party[0].attack).is_equal(11)
