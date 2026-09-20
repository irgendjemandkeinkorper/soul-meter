class_name InjuryTreatment
extends RefCounted
## Atomic out-of-combat treatment of ONE serious injury (called-shots task 10A).
##
## Systems-layer coordinator over the durable owners: `PartyMember.injuries` for the wound,
## `GameState.spend_gp()` / `remove_items()` for payment. `quote()` never writes; `commit()`
## re-quotes, refuses a changed price, debits once, cures once, and rolls the debit back if
## application fails. No RNG, no SkillCheck.resolve(), no Soul. Mutation is synchronous and
## the state notification fires only after a coherent completed state.
##
## Cards below are TEST FIXTURES (design: 20 GP service, one supply unit). Production cards
## are content work (task 11) and must be displayed before commitment.

const TIER_ORDER: Array[String] = ["untrained", "trained", "expert"]

const CARDS: Dictionary = {
	## PRODUCTION (10B, provider chosen by the owner 2026-09-19). The fee is PROVISIONAL
	## pending the encounter/resupply pass; supplies are included, no party Mending needed.
	"herbalist-service": {
		"kind": "service", "provider_id": "root-and-reed", "gp": 20, "access": "vendor_band",
		"cures": ["arm", "throat"], "display_name": "Herbalist's setting",
		"alternative": "Shrine of the Held Flame offers succor once.",
	},
	## Authored finite remedy: the shrine keeper treats one wound per game for anyone, whatever
	## the party's standing or purse. This is the no-cash / locked-out route, not a global
	## free-healing rule.
	"shrine-succor": {
		"kind": "service", "provider_id": "held-flame-shrine", "gp": 0, "access": "any",
		"once_flag": "dom_shrine_succor_spent",
		"cures": ["arm", "throat"], "display_name": "Succor of the Held Flame",
		"alternative": "Root & Reed sets wounds for a fee.",
	},
	"service-test": {
		"kind": "service", "provider_id": "test-healer", "gp": 20,
		"cures": ["arm", "throat"],
	},
	"field-test": {
		"kind": "field", "skill": "mending", "min_tier": "trained",
		"supply_item": "materials/loamroot_sprig", "supply_quantity": 1,
		"cures": ["arm", "throat"],
		## Locations the practitioner needs unhurt to perform this card (authored per card;
		## a throat injury never blocks nonvocal medicine).
		"practitioner_requires": ["arm"],
	},
}


## Intent: {patient_id, instance_id, revision, card_id, practitioner_id | provider_id,
## expected_cost (optional, from a prior quote)}. `combat_active` comes from the caller so
## the coordinator has no autoload dependency; production passes Battle's live state.
static func quote(intent: Dictionary, state: Node, combat_active: bool) -> Dictionary:
	if combat_active:
		return _blocked("combat_active", "Treatment needs calm; combat is under way.")
	var card_id := str(intent.get("card_id", ""))
	var card: Dictionary = CARDS.get(card_id, {})
	if card.is_empty():
		return _blocked("unknown_card", "No such treatment.")
	var patient := member_by_id(state, str(intent.get("patient_id", "")))
	if patient == null:
		return _blocked("unknown_patient", "That patient is not in the party.")
	if patient.hp <= 0:
		return _blocked("patient_down", "%s is down; revival is a separate matter." % patient.display_name)
	var found := _find_injury(patient, str(intent.get("instance_id", "")))
	if found.is_empty():
		return _blocked("injury_missing", "That injury is no longer there.")
	var location := str(found["location"])
	var record: Dictionary = found["record"]
	var identity := CombatInjury.record_identity(record)
	if intent.has("revision") and int(intent["revision"]) != int(identity["revision"]):
		return _blocked("injury_changed", "That injury has changed since it was quoted.", {"identity": identity})
	if str(record.get("severity", "minor")) != CombatInjury.PERSISTENT_SEVERITY:
		return _blocked("not_treatable", "Only serious injuries take treatment.")
	if not (card.get("cures", []) as Array).has(location):
		return _blocked("unsupported_injury", "This treatment does not cover the %s." % location)
	var cost := {"gp": 0, "supply_item": "", "supply_quantity": 0}
	match str(card["kind"]):
		"service":
			if str(intent.get("provider_id", "")) != str(card["provider_id"]):
				return _blocked("invalid_access", "That provider does not offer this treatment.")
			if str(card.get("access", "any")) == "vendor_band":
				var status: Dictionary = state.vendor_trade_status(str(card["provider_id"]))
				if not bool(status.get("allowed", false)):
					return _blocked("invalid_access", str(status.get("reason", "PROVIDER UNAVAILABLE")),
						{"alternative": str(card.get("alternative", ""))})
			var once_flag := str(card.get("once_flag", ""))
			if not once_flag.is_empty() and state.flag_is_true(once_flag):
				return _blocked("remedy_spent", "That succor has already been given.",
					{"alternative": str(card.get("alternative", ""))})
			cost["gp"] = int(card["gp"])
			if not state.can_afford(cost["gp"]):
				return _blocked("insufficient_gp", "NEED %d GP · HAVE %d" % [cost["gp"], state.gp], {"cost": cost})
		"field":
			var practitioner := member_by_id(state, str(intent.get("practitioner_id", "")))
			if practitioner == null:
				return _blocked("unknown_practitioner", "No such practitioner in the party.")
			if practitioner.hp <= 0:
				return _blocked("practitioner_down", "%s cannot treat anyone while down." % practitioner.display_name)
			var tier := _tier_rank(str(practitioner.skill_tiers.get(str(card["skill"]), "untrained")))
			if tier < _tier_rank(str(card["min_tier"])):
				return _blocked("unqualified", "%s lacks %s %s." % [
					practitioner.display_name, str(card["min_tier"]).capitalize(), str(card["skill"]).capitalize()])
			for required: Variant in card.get("practitioner_requires", []):
				var hurt: Dictionary = practitioner.injuries.get(str(required), {})
				if not hurt.is_empty() and str(hurt.get("severity", "")) == CombatInjury.PERSISTENT_SEVERITY:
					return _blocked("practitioner_injured", "%s's %s injury prevents this treatment." % [
						practitioner.display_name, str(required)])
			cost["supply_item"] = str(card["supply_item"])
			cost["supply_quantity"] = int(card["supply_quantity"])
			if state.item_count(cost["supply_item"]) < cost["supply_quantity"]:
				return _blocked("insufficient_supply", "No %s to hand." % cost["supply_item"].get_file(), {"cost": cost})
	if intent.has("expected_cost") and intent["expected_cost"] != cost:
		return _blocked("price_changed", "The price has changed; confirm the new quote.", {"cost": cost})
	return {
		"allowed": true, "blocked_by": "", "message": "",
		"card_id": card_id, "display_name": str(card.get("display_name", card_id)),
		"patient_id": patient.id, "location": location,
		"identity": identity, "cost": cost,
		"before": record.duplicate(true), "after": {},
		"lifts": _restrictions(record),
	}


## Pays and cures exactly once, or changes nothing. `inject_apply_failure` exists so the
## rollback path is tested, not trusted.
static func commit(intent: Dictionary, state: Node, combat_active: bool, inject_apply_failure := false) -> Dictionary:
	var quoted := quote(intent, state, combat_active)
	if not bool(quoted["allowed"]):
		return quoted
	var patient := member_by_id(state, str(quoted["patient_id"]))
	var cost: Dictionary = quoted["cost"]
	var gp_before: int = state.gp
	var soul_before: float = state.soul_meter
	# Debit exactly once.
	if int(cost["gp"]) > 0 and not state.spend_gp(int(cost["gp"])):
		return _blocked("insufficient_gp", "SILVER LEDGER UNCHANGED", {"cost": cost})
	if int(cost["supply_quantity"]) > 0 and not state.remove_items(str(cost["supply_item"]), int(cost["supply_quantity"])):
		if int(cost["gp"]) > 0:
			state.earn_gp(int(cost["gp"]))
		return _blocked("insufficient_supply", "Supplies were not consumed.", {"cost": cost})
	# Apply the cure; on failure restore the debit before anything can observe it.
	var applied := not inject_apply_failure and _cure(patient, str(quoted["location"]), quoted["identity"])
	if not applied:
		if int(cost["gp"]) > 0:
			state.earn_gp(int(cost["gp"]))
		if int(cost["supply_quantity"]) > 0:
			_restore_supply(state, str(cost["supply_item"]), int(cost["supply_quantity"]))
		assert(state.gp == gp_before, "treatment rollback must restore GP")
		return _blocked("apply_failed", "Treatment failed; nothing was spent.", {"cost": cost})
	assert(is_equal_approx(state.soul_meter, soul_before), "treatment never touches Soul")
	var once_flag := str(CARDS[str(quoted["card_id"])].get("once_flag", ""))
	if not once_flag.is_empty():
		state.set_flag(once_flag, true)
	state.party_changed.emit()
	var result := quoted.duplicate(true)
	result["paid"] = cost
	result["after"] = {}
	return result


## Cards a provider (vendor id) offers, in authored order.
static func cards_for_provider(provider_id: String) -> Array[String]:
	var ids: Array[String] = []
	for card_id: String in CARDS.keys():
		if str((CARDS[card_id] as Dictionary).get("provider_id", "")) == provider_id:
			ids.append(card_id)
	return ids


## Every serious injury in the party as (member, location, record) rows for a UI to list.
static func treatable_rows(state: Node) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for member: PartyMember in state.party:
		for location: Variant in member.injuries.keys():
			var record: Dictionary = member.injuries[location]
			if str(record.get("severity", "minor")) == CombatInjury.PERSISTENT_SEVERITY:
				rows.append({"member": member, "location": str(location), "record": record})
	return rows


static func member_by_id(state: Node, member_id: String) -> PartyMember:
	if member_id.is_empty():
		return null
	for member: PartyMember in state.party:
		if str(member.id) == member_id:
			return member
	return null


static func _find_injury(patient: PartyMember, instance_id: String) -> Dictionary:
	if instance_id.is_empty():
		return {}
	for location: Variant in patient.injuries.keys():
		var record: Dictionary = patient.injuries[location]
		if str(record.get("instance_id", "")) == instance_id:
			return {"location": str(location), "record": record}
	return {}


static func _cure(patient: PartyMember, location: String, identity: Dictionary) -> bool:
	var record: Dictionary = patient.injuries.get(location, {})
	if record.is_empty() or CombatInjury.record_identity(record) != identity:
		return false
	patient.injuries.erase(location)
	return true


static func _restore_supply(state: Node, item_id: String, quantity: int) -> void:
	for _index: int in quantity:
		state.inventory.create_and_add_item(item_id)


static func _restrictions(record: Dictionary) -> Array[String]:
	var lifted: Array[String] = []
	var effects: Dictionary = record.get("effects", {})
	if bool(effects.get(CombatInjury.EFFECT_VOICE_BLOCKED, false)):
		lifted.append("voice")
	if int(effects.get(CombatInjury.EFFECT_ATTACK_ACCURACY, 0)) != 0:
		lifted.append("attack_accuracy")
	if int(effects.get(CombatInjury.EFFECT_VOCAL_ACCURACY, 0)) != 0:
		lifted.append("vocal_accuracy")
	return lifted


static func _tier_rank(tier: String) -> int:
	return TIER_ORDER.find(tier.to_lower().replace("-", "_").replace(" ", "_"))


static func _blocked(reason: String, message: String, extra: Dictionary = {}) -> Dictionary:
	var out := {"allowed": false, "blocked_by": reason, "message": message}
	out.merge(extra)
	return out
