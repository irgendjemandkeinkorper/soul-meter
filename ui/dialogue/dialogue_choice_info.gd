class_name DialogueChoiceInfo
extends RefCounted
## What a conversation choice means to the player. Owner rulings 2026-11-01
## (docs/design/ui-rework-plan-2026-11-01.md, U1):
##  - A locked choice stays visible only when the player could EARN it: each failing part
##    of its condition is a skill check, a faction standing, a Soul floor, or "not
##    hollowed". Quest state, flags, NG+, patron, hollowed-only and low-Soul-only lines
##    are hidden. `[#lock=show]` / `[#lock=hide]` on the response overrides either way.
##  - A lock names its system and its remedy in one line (FR-606).
##  - A choice shows its exact effects (Soul, faction, Renown, Infamy), read from the
##    branch's own leading `do` mutations, so nothing is authored twice. Karma stays off
##    the chips: it has no player-facing readout anywhere yet.
##  - A skill check shows the player's chance, which is their effective skill.
## Read-only: reads the compiled dialogue (`DialogueResource.lines`), `SkillCheck`,
## `Reputation` and `GameState`; it never writes game state.

const LOCK_TAG := "lock"
const MINUS := "−"
## Walking a branch's leading mutations stops here even on a malformed resource.
const MAX_LEADING_MUTATIONS := 32

enum Gate { NONE, SKILL, STANDING, SOUL, HOLLOWING }


## {"visible": bool, "locked": bool, "reasons": PackedStringArray}
static func visibility(
	resource: DialogueResource, response: DialogueResponse, extra_game_states: Array = []
) -> Dictionary:
	var reasons := PackedStringArray()
	if response.is_allowed:
		return {"visible": true, "locked": false, "reasons": reasons}
	var override := tag_value(response.tags, LOCK_TAG)
	if override == "hide":
		return {"visible": false, "locked": true, "reasons": reasons}
	# DM short-circuits `and`, and authors lean on it: in `QuestRegistry.is_done(Q) and
	# GameState.get_flag("f") == "returned"` the comparison is only safe once the quest is
	# done (an unset flag is `false`, and `false == "returned"` is a runtime error). So the
	# guard parts (quest, flag, NG+, patron, any non-earnable lock) run first, in authored
	# order, stopping at the first that fails: exactly the parts DM itself would have run.
	# The earnable parts are numeric reads with no such guards, so they are safe after.
	var guards: Array[Array] = []
	var gates: Array[Array] = []
	for part: Array in conjuncts(condition_tokens(resource, response)):
		if is_earnable(gate_of(part)):
			gates.append(part)
		else:
			guards.append(part)
	var earnable := true
	for part: Array in guards:
		if not await _holds(part, extra_game_states):
			earnable = false
			break
	if earnable or override == "show":
		for part: Array in gates:
			if not await _holds(part, extra_game_states):
				reasons.append(reason_for(gate_of(part)))
	if override == "show":
		return {"visible": true, "locked": true, "reasons": reasons}
	return {"visible": earnable and not reasons.is_empty(), "locked": true, "reasons": reasons}


## Effects of choosing `response`: the branch's leading mutations, in order.
## Each is {"kind": &"soul"|&"faction"|&"renown"|&"infamy"|&"check", ...}.
static func effects(resource: DialogueResource, response: DialogueResponse) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var id := line_key(resource, response.next_id)
	for _step: int in MAX_LEADING_MUTATIONS:
		var line: Dictionary = resource.lines.get(id, {})
		if str(line.get("type", "")) != "mutation":
			break
		var mutation: Dictionary = line.get("mutation", {})
		var effect := effect_of(mutation.get("expression", []))
		if not effect.is_empty():
			found.append(effect)
		id = line_key(resource, str(line.get("next_id", "")))
	return found


## A runtime line id is `<resource uid>@<key>|<return stack>` (DM resolves it the same way
## in `get_line`); the compiled `resource.lines` are keyed by the bare `<key>`. A jump into
## another resource has no lines here, so it reads as "".
static func line_key(resource: DialogueResource, id: String) -> String:
	var key := id.get_slice("|", 0)
	if "@" in key:
		var uid := key.get_slice("@", 0)
		var own := ResourceUID.path_to_uid(resource.resource_path).replace("uid://", "")
		if uid != own:
			return ""
		key = key.get_slice("@", 1)
	return key


## The skill a choice rolls: its branch's `SkillCheck.resolve`, else its `check()` gate.
static func check_skill(resource: DialogueResource, response: DialogueResponse) -> String:
	for effect: Dictionary in effects(resource, response):
		if effect["kind"] == &"check":
			return str(effect["skill"])
	for part: Array in conjuncts(condition_tokens(resource, response)):
		var gate := gate_of(part)
		if gate["gate"] == Gate.SKILL:
			return str(gate["skill"])
	return ""


## "SOUL −6 · SSAE SEEDERS +3 · INFAMY +5" — the chips a choice or the ledger strip shows.
static func chips_text(found: Array[Dictionary]) -> String:
	var chips := PackedStringArray()
	for kind: StringName in [&"soul", &"faction", &"renown", &"infamy"]:
		for effect: Dictionary in found:
			if effect["kind"] == kind:
				chips.append("%s %s" % [effect_label(effect), signed(float(effect["delta"]))])
	return "  ·  ".join(chips)


static func effect_label(effect: Dictionary) -> String:
	match effect["kind"]:
		&"soul":
			return _t("SOUL")
		&"faction":
			return faction_label(str(effect["faction"])).to_upper()
		&"renown":
			return _t("RENOWN")
		&"infamy":
			return _t("INFAMY")
	return ""


## The chance shown on a check, rounded: the player's effective skill.
static func odds(skill: String) -> int:
	return roundi(SkillCheck.preview(skill))


static func skill_label(skill: String) -> String:
	var definition: Dictionary = DramgidSchema.skill_check_definitions().get(skill.to_lower(), {})
	return str(definition.get("label", skill.capitalize()))


## Faction ids are the lore vault's kebab ids ("ssae-seeders" → "Ssae Seeders").
static func faction_label(faction: String) -> String:
	return faction.replace("-", " ").replace("_", " ").capitalize()


static func signed(value: float) -> String:
	var magnitude := absf(value)
	var digits := (
		"%d" % roundi(magnitude) if is_equal_approx(magnitude, roundf(magnitude))
		else "%.1f" % magnitude
	)
	return ("+" if value >= 0.0 else MINUS) + digits


static func _t(text: String) -> String:
	return String(TranslationServer.translate(text))


static func tag_value(tags: PackedStringArray, key: String) -> String:
	for tag: String in tags:
		if tag.begins_with(key + "="):
			return tag.substr(key.length() + 1)
	return ""


# --- conditions -----------------------------------------------------------------------------

static func condition_tokens(resource: DialogueResource, response: DialogueResponse) -> Array:
	var line: Dictionary = resource.lines.get(line_key(resource, response.id), {})
	var condition: Dictionary = line.get("condition", {})
	return condition.get("expression", [])


## Splits a condition on its top-level `and`s. Any top-level `or` keeps it whole: an
## alternative cannot be blamed on one part.
static func conjuncts(tokens: Array) -> Array[Array]:
	var parts: Array[Array] = []
	if tokens.is_empty():
		return parts
	for token: Dictionary in tokens:
		if str(token.get("type", "")) == "and_or" and str(token.get("value", "")) != "and":
			parts.append(tokens)
			return parts
	var current: Array = []
	for token: Dictionary in tokens:
		if str(token.get("type", "")) == "and_or":
			if not current.is_empty():
				parts.append(current)
			current = []
		else:
			current.append(token)
	if not current.is_empty():
		parts.append(current)
	return parts


## {"gate": Gate, ...}: what kind of lock one condition part is.
static func gate_of(part: Array) -> Dictionary:
	var negated := not part.is_empty() and str(part[0].get("type", "")) == "not"
	for index: int in part.size():
		var token: Dictionary = part[index]
		var type := str(token.get("type", ""))
		var owner := _owner_of(part, index)
		if type == "function":
			var function := str(token.get("function", ""))
			if function == "check" and (owner.is_empty() or owner == "SkillCheck"):
				return {
					"gate": Gate.SKILL,
					"skill": _arg_string(token, 0),
					"need": _arg_number(token, 1),
				}
			if owner == "Reputation" and function in ["standing", "band_at_least"]:
				return {
					"gate": Gate.STANDING,
					"faction": _arg_string(token, 0),
					"op": _comparison_after(part, index),
					"need": _number_after(part, index),
				}
			if owner == "GameState" and function == "is_hollowing":
				return {"gate": Gate.HOLLOWING, "negated": negated}
		elif type == "variable":
			var name := str(token.get("value", ""))
			if owner == "GameState" and name == "soul_meter":
				return {
					"gate": Gate.SOUL,
					"op": _comparison_after(part, index),
					"need": _number_after(part, index),
				}
			if owner == "GameState" and name == "is_hollowing":
				return {"gate": Gate.HOLLOWING, "negated": negated}
	return {"gate": Gate.NONE}


## Earnable = the player can lift it by playing: raise a skill, gain standing, keep or
## regain Soul. Hollowed-only and low-Soul-only lines are consequences, not goals.
static func is_earnable(gate: Dictionary) -> bool:
	match gate["gate"]:
		Gate.SKILL:
			return true
		Gate.STANDING:
			return str(gate.get("op", "")) in [">=", ">", ""]
		Gate.SOUL:
			return str(gate.get("op", "")) in [">=", ">"]
		Gate.HOLLOWING:
			return bool(gate.get("negated", false))
	return false


## One line in the administrative voice: the system named, the bar, and where you stand.
static func reason_for(gate: Dictionary) -> String:
	match gate["gate"]:
		Gate.SKILL:
			var skill := str(gate["skill"])
			return _t("%s %d needed — you have %d.") % [
				skill_label(skill), roundi(float(gate["need"])), odds(skill)
			]
		Gate.STANDING:
			var faction := str(gate["faction"])
			var have := roundi(Reputation.standing(faction))
			if gate.get("need") == null:
				return _t("%s standing too low — you have %d.") % [
					faction_label(faction), have
				]
			return _t("%s standing %d needed — you have %d.") % [
				faction_label(faction), roundi(float(gate["need"])), have
			]
		Gate.SOUL:
			return _t("Soul %d needed — you have %d.") % [
				roundi(float(gate["need"])), roundi(GameState.soul_meter)
			]
		Gate.HOLLOWING:
			return _t("Hollowed — your Soul must rise above 0.")
	return ""


static func _holds(part: Array, extra_game_states: Array) -> bool:
	# Dialogue Manager's own evaluator (vendor, unmodified), so a part means exactly what
	# it meant when DM decided `is_allowed`. Pinned by test_dialogue_choice_info.gd.
	var value: Variant = await DialogueManager._resolve(part.duplicate(true), extra_game_states)
	return bool(value)


## "Reputation" for `Reputation.standing(...)`; "" for a bare call such as `check(...)`.
static func _owner_of(part: Array, index: int) -> String:
	if index >= 2 and str(part[index - 1].get("type", "")) == "dot":
		var owner: Dictionary = part[index - 2]
		if str(owner.get("type", "")) == "variable":
			return str(owner.get("value", ""))
	return ""


static func _comparison_after(part: Array, index: int) -> String:
	for later: int in range(index + 1, part.size()):
		if str(part[later].get("type", "")) == "comparison":
			return str(part[later].get("value", ""))
	return ""


static func _number_after(part: Array, index: int) -> Variant:
	var seen_comparison := false
	for later: int in range(index + 1, part.size()):
		var type := str(part[later].get("type", ""))
		if type == "comparison":
			seen_comparison = true
		elif seen_comparison and type == "number":
			return float(part[later].get("value", 0.0))
	return null


# --- mutations ------------------------------------------------------------------------------

static func effect_of(tokens: Array) -> Dictionary:
	if tokens.size() < 3:
		return {}
	var owner := str(tokens[0].get("value", "")) if str(tokens[0].get("type", "")) == "variable" else ""
	var call_token: Dictionary = tokens[2]
	if str(tokens[1].get("type", "")) != "dot" or str(call_token.get("type", "")) != "function":
		return {}
	var function := str(call_token.get("function", ""))
	match [owner, function]:
		["Reputation", "record"]:
			return {"kind": &"faction", "faction": _arg_string(call_token, 1), "delta": _arg_number(call_token, 2)}
		["Renown", "gain_reputation"]:
			return {"kind": &"renown", "delta": _arg_number(call_token, 1)}
		["Renown", "gain_infamy"]:
			return {"kind": &"infamy", "delta": _arg_number(call_token, 1)}
		["SkillCheck", "resolve"]:
			return {"kind": &"check", "skill": _arg_string(call_token, 0)}
		# P1.1 (Soul trace) moved dialogue onto the cause-carrying setter; the delta is arg 0 in both.
		["GameState", "set_soul_meter"], ["GameState", "set_soul_meter_with_cause"]:
			var delta: Variant = _soul_delta(_arg_tokens(call_token, 0))
			return {} if delta == null else {"kind": &"soul", "delta": float(delta)}
	return {}


## `GameState.soul_meter - 6.0` → -6.0; anything else is not a delta we can state exactly.
static func _soul_delta(tokens: Array) -> Variant:
	if tokens.size() < 5:
		return null
	if str(tokens[2].get("value", "")) != "soul_meter" or str(tokens[3].get("type", "")) != "operator":
		return null
	var amount := float(tokens[4].get("value", 0.0))
	match str(tokens[3].get("value", "")):
		"-":
			return -amount
		"+":
			return amount
	return null


static func _arg_tokens(call_token: Dictionary, index: int) -> Array:
	var args: Array = call_token.get("value", [])
	if index >= args.size():
		return []
	var tokens: Array = []
	for token: Dictionary in args[index]:
		if str(token.get("type", "")) != "parens_close":
			tokens.append(token)
	return tokens


static func _arg_string(call_token: Dictionary, index: int) -> String:
	for token: Dictionary in _arg_tokens(call_token, index):
		if str(token.get("type", "")) == "string":
			return str(token.get("value", ""))
	return ""


static func _arg_number(call_token: Dictionary, index: int) -> float:
	var sign_factor := 1.0
	for token: Dictionary in _arg_tokens(call_token, index):
		var type := str(token.get("type", ""))
		if type == "operator" and str(token.get("value", "")) == "-":
			sign_factor = -1.0
		elif type == "number":
			return sign_factor * float(token.get("value", 0.0))
	return 0.0
