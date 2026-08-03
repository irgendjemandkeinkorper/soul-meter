class_name ElementsData
extends RefCounted

## Default runtime table for Issue #89.
##
## Pandora is canonical. Issue #91 must generate a table with this exact shape:
## ELEMENT_ROWS: [{id, display_name, imposition_id, imposition_display_name,
## rule_bend_id, rule_bend_description, deals_damage}], and TRIAD_ROWS:
## [{id, display_name, elements, center, unique_effect: {id, display_name,
## parameters}}]. This committed table is the development default until that
## one-way generator replaces it; gameplay code must not write to Pandora.

const ELEMENT_ROWS: Array[Dictionary] = [
	{"id": &"suul", "display_name": "Suul", "imposition_id": &"exposed", "imposition_display_name": "Exposed", "rule_bend_id": &"reveals_aftertones", "rule_bend_description": "Reveals Aftertones, Discord signatures, and illusions.", "deals_damage": true},
	{"id": &"bloei", "display_name": "Bloei", "imposition_id": &"overgrown", "imposition_display_name": "Overgrown", "rule_bend_id": &"extends_own_buff_duration", "rule_bend_description": "Extends the duration of your own buffs.", "deals_damage": true},
	{"id": &"aqua", "display_name": "Aqua", "imposition_id": &"soaked", "imposition_display_name": "Soaked", "rule_bend_id": &"restores_breath", "rule_bend_description": "The only element that restores Breath.", "deals_damage": true},
	{"id": &"khor", "display_name": "Khor", "imposition_id": &"", "imposition_display_name": "", "rule_bend_id": &"extends_durations_holds_notes", "rule_bend_description": "Extends durations and holds Notes across rounds.", "deals_damage": false},
	{"id": &"terra", "display_name": "Terra", "imposition_id": &"weighted", "imposition_display_name": "Weighted", "rule_bend_id": &"creates_cover_anchors_aftertones", "rule_bend_description": "Creates cover and anchors Aftertones.", "deals_damage": true},
	{"id": &"daar", "display_name": "Daar", "imposition_id": &"blinded", "imposition_display_name": "Blinded", "rule_bend_id": &"conceals_discord_signatures", "rule_bend_description": "Conceals Discord signatures.", "deals_damage": true},
	{"id": &"molm", "display_name": "Molm", "imposition_id": &"decaying", "imposition_display_name": "Decaying", "rule_bend_id": &"converts_to_breath", "rule_bend_description": "Converts corpses and objects into Breath.", "deals_damage": true},
	{"id": &"scor", "display_name": "Scor", "imposition_id": &"burning", "imposition_display_name": "Burning", "rule_bend_id": &"consumes_aftertone_for_burst", "rule_bend_description": "Consumes an Aftertone for burst power.", "deals_damage": true},
	{"id": &"nul", "display_name": "Nul", "imposition_id": &"muted", "imposition_display_name": "Muted", "rule_bend_id": &"cancels_and_zeroes_tempo", "rule_bend_description": "Cancels buffs, ends Aftertones, and zeroes Tempo.", "deals_damage": false},
	{"id": &"strom", "display_name": "Strom", "imposition_id": &"shocked", "imposition_display_name": "Shocked", "rule_bend_id": &"ignores_instability_die", "rule_bend_description": "Ignores the Instability die.", "deals_damage": true},
]

const TRIAD_ROWS: Array[Dictionary] = [
	{"id": &"dayspring", "display_name": "Dayspring", "elements": [&"strom", &"suul", &"bloei"], "center": &"suul", "unique_effect": {"id": &"first_light", "display_name": "First Light", "parameters": {"duration": "round", "reveals": ["aftertones", "discord_signatures", "queued_effects", "discovered_weaknesses"], "defining_strike_cost": 0}}},
	{"id": &"fruiting", "display_name": "Fruiting", "elements": [&"suul", &"bloei", &"aqua"], "center": &"bloei", "unique_effect": {"id": &"second_season", "display_name": "Second Season", "parameters": {"copy_active_friendly_buffs": true, "targets_per_new_buff": 2}}},
	{"id": &"rivermouth", "display_name": "Rivermouth", "elements": [&"bloei", &"aqua", &"khor"], "center": &"aqua", "unique_effect": {"id": &"the_mouth_opens", "display_name": "The Mouth Opens", "parameters": {"duration": "round", "zone_change_ap": 0, "aoe_ignores_zone_boundaries": true}}},
	{"id": &"founding", "display_name": "Founding", "elements": [&"aqua", &"khor", &"terra"], "center": &"khor", "unique_effect": {"id": &"cornerstone", "display_name": "Cornerstone", "parameters": {"freeze_remaining_durations": true, "until": "end_of_next_turn"}}},
	{"id": &"vault", "display_name": "Vault", "elements": [&"khor", &"terra", &"daar"], "center": &"terra", "unique_effect": {"id": &"sealed_ground", "display_name": "Sealed Ground", "parameters": {"fortify_zone": true, "encounter_scope": true, "entry_ap_add": 1, "ranged_attacks_apply_weighted": true, "anchored_aftertones_enemy_consumption": false}}},
	{"id": &"barrow", "display_name": "Barrow", "elements": [&"terra", &"daar", &"molm"], "center": &"daar", "unique_effect": {"id": &"unlisted", "display_name": "Unlisted", "parameters": {"hide_friendly_signatures": true, "hide_friendly_queued_effects": true, "hide_friendly_positions": true, "enemy_back_zone_targetable": false, "enemy_reveal_effects": false, "duration": "round"}}},
	{"id": &"pyre", "display_name": "Pyre", "elements": [&"daar", &"molm", &"scor"], "center": &"molm", "unique_effect": {"id": &"the_rendering", "display_name": "The Rendering", "parameters": {"convert_corpses": true, "convert_destroyed_objects": true, "convert_expired_aftertones": true, "split_breath_across_side": true, "shared_corpse_applies_decaying": true}}},
	{"id": &"cinderfall", "display_name": "Cinderfall", "elements": [&"molm", &"scor", &"nul"], "center": &"scor", "unique_effect": {"id": &"everything_burns_at_once", "display_name": "Everything Burns At Once", "parameters": {"consume_all_aftertones": true, "include_both_sides": true, "yield_bursts_to_caster_side": true}}},
	{"id": &"stillpoint", "display_name": "Stillpoint", "elements": [&"scor", &"nul", &"strom"], "center": &"nul", "unique_effect": {"id": &"the_held_silence", "display_name": "The Held Silence", "parameters": {"balance_gauge": "exact_center", "lock_until": "end_of_next_round", "suppress_threshold_effects": true}}},
	{"id": &"thunderhead", "display_name": "Thunderhead", "elements": [&"nul", &"strom", &"suul"], "center": &"strom", "unique_effect": {"id": &"nothing_is_uncertain", "display_name": "Nothing Is Uncertain", "parameters": {"skip_instability_die": true, "out_of_turn_allies": 1, "duration": "round"}}},
]


static func element(element_id: Variant) -> ElementDefinition:
	var requested := ElementWheel.normalize(element_id)
	for row: Dictionary in ELEMENT_ROWS:
		if StringName(row.get("id", "")) == requested:
			return ElementDefinition.from_row(row)
	return ElementDefinition.new()


static func all_elements() -> Array[ElementDefinition]:
	var definitions: Array[ElementDefinition] = []
	for row: Dictionary in ELEMENT_ROWS:
		definitions.append(ElementDefinition.from_row(row))
	return definitions


static func triad(triad_id: Variant) -> TriadDefinition:
	var requested := ElementWheel.normalize(triad_id)
	for row: Dictionary in TRIAD_ROWS:
		if StringName(row.get("id", "")) == requested:
			return TriadDefinition.from_row(row)
	return TriadDefinition.new()


static func all_triads() -> Array[TriadDefinition]:
	var definitions: Array[TriadDefinition] = []
	for row: Dictionary in TRIAD_ROWS:
		definitions.append(TriadDefinition.from_row(row))
	return definitions


static func triad_for_elements(elements: Array[StringName]) -> TriadDefinition:
	for candidate in all_triads():
		if candidate.elements.size() != elements.size():
			continue
		var matches := true
		for element in elements:
			if not candidate.elements.has(element):
				matches = false
				break
		if matches:
			return candidate
	return TriadDefinition.new()
