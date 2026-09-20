class_name CombatController
extends RefCounted
## Command/event-driven combat session coordinator. It owns runtime turn state,
## AP, fixed effect pipelines, and positioning queries; presentation consumes
## CombatEvent snapshots and never needs to know which battlefield backs them.
##
## FR-102a (amendment §2.1): turn order and timing are NOT decided here. `scheduler`
## (a `TurnScheduler`, built by `TurnScheduler.create_default(rules)`) is the single
## authority for "who acts next, when, may they, and what does this cost" — this file
## never names `ApRoundScheduler` or `ChargeTimeScheduler` directly, only the interface.
## `rules.use_charge_time` (the flag `create_default()` reads) is therefore the entire
## abort path: flipping it swaps the scheduler implementation without touching a line
## here. AP compatibility is retained by construction, not by a branch in this file —
## `ApRoundScheduler` is a faithful port of the old round/phase loop expressed behind
## the same interface CT uses (amendment §8.1: AP is not removed in the change that
## makes CT authoritative).
##
## Event vocabulary is versioned per amendment §2.1's mandate ("events will change
## shape"): `round_started` / `ap_refreshed` / `round_ended` fire only when the active
## scheduler's `advance()` reports AP round bookkeeping (i.e. only under the AP
## scheduler) via `_translate_scheduler_extras()`. `measure_started` is the CT-native
## replacement beat, firing whenever `advance()` reports a crossed 16-tick measure with
## no round bookkeeping attached. `turn_started` / `turn_ended` / `enemy_turn_started`
## keep their names — they gain new meaning (charge/ticks data instead of AP-only data)
## rather than being replaced, since "whose turn is it" stays meaningful under both
## models.
##
## AP COMPATIBILITY SHIM (Gate T-10, removal ticket #176). The remaining AP-named outcome keys,
## snapshot fields, translated AP-round events, and zero-cost pass field are wire compatibility
## for the rollback scheduler and event-driven HUD. They do not decide readiness, order, or CT
## price; every such decision routes through `scheduler`. Delete these fields together with
## `ApRoundScheduler` after the Gate T rollback window.

signal event_emitted(event: CombatEvent)
signal battle_finished(state: ResultState, outcome_id: StringName)

enum State { IDLE, ROUND_START, ALLY_TURN, ENEMY_TURN, FINISHED }
enum ResultState { VICTORY, DEFEAT, FLED }

const ACTION_MOVE: StringName = &"move"
## PROVISIONAL Wave P positional-AI weight: cover beats adjacency (+500), while a rear
## opportunity (+1000) remains the stronger tactical instinct.
const _ENEMY_COVER_POSITION_SCORE := 750
## Doublings of `admission_delay` allowed while satisfying invariant A1 (F0 ruling 6). A fast
## newcomer needs a bigger delay than a slow one to land behind the party, and the flat
## constant cannot know which it got, so the delay is raised until the invariant actually
## holds. Sixteen doublings is far past any speed the rules can produce.
const _ADMISSION_ESCALATION_LIMIT := 16

var state: State = State.IDLE
var allies: Array[BattleActor] = []
var enemies: Array[BattleActor] = []
var active_ally_index := -1
var round_number := 0
var balance := 0
var balance_band_id: StringName = &""
var balance_lock_until_round := 0
var threshold_effects_suppressed := false
## PROVISIONAL Triad windows with concrete controller consumers. Claude ruling for Dayspring/
## Barrow: these side windows flow through Resolution positioning terms so forecast and commit
## use the same revealed/covered target state; owner confirmation is still pending.
var duration_freeze_until_round := 0
var revealed_until_round := 0
var concealed_until_round := 0
var zone_boundaries_open_until_round := 0
var thunderhead_hit_until_round := 0
var range_bonus_until_round := 0
var founding_anchor_restore: Dictionary = {}
var revealed_side: StringName = &"ally"
var concealed_side: StringName = &"ally"
var spent_aftertones := 0
var last_refusal: Dictionary = {}
var battlefield: BattlefieldModel
var rules: CombatRules
var skill_check_service: SkillCheckService
var scheduler: TurnScheduler
## Location/encounter input for fizzle. Battle resolves it once at setup so
## forecast and commit cannot observe different scene state.
var agreement_integrity: float = 100.0
## Issue #209: the live Weather instance. Ticks on the scheduler's real CT cadence
## (`_advance_weather()`), applies its per-measure feed/starve to `tile_states`, and
## feeds `Resolution` context. Stays at the UNCHARGED sentinel unless the encounter
## authors an element via `configure_weather()` — which encounters do is an owner
## (balance) decision, not decided here.
var weather: Weather = Weather.new()
## Issue #209: per-cell TileState for grid battles ([] for zone battles). Built from
## the battlefield's static terrain in start(); charge moves only through Weather's
## measure application (residue-on-cast wiring is a separate authored-ability task).
var tile_states: Array[TileState] = []
var _tile_by_cell: Dictionary = {}  ## Vector2i -> TileState
## Khash prototype fire substrate (globals/combat/fire_field.gd): fire lines, Burning, Soaked.
## The controller applies every hazard/burn HP change through `_apply_resolution_writes()`.
var fire: FireField = FireField.new()
## Sul/Vekh revelation substrate: Witness Light fields; Exposed/Veiled/Lit impositions.
var light: LightField = LightField.new()
## combat_id -> Refrain uses this battle. PROVISIONAL: one Refrain allowance per character per
## battle, shared by every `refrain_use` working (Crown of Embers, Verdict by Fire).
var _refrain_uses: Dictionary = {}

## Authored effect pipelines (`CombatAction.effect_id`). Every id here has a concrete consumer
## below; an authored action naming any other id is refused at query time.
const EFFECT_BURNING_STRIKE := &"burning_strike"  ## hit → Burning (Kindle, Cinder Spear)
const EFFECT_DOUSE := &"douse"                    ## clear Burning, apply Soaked
const EFFECT_THRUST := &"thrust"                  ## plain reach attack; gates only
const EFFECT_PULL := &"pull"                      ## hit → pull target one cell toward wielder
const EFFECT_FIRE_LINE := &"fire_line"            ## create a Firebreak now
const EFFECT_SENTENCE_OF_ASH := &"sentence_of_ash"  ## file a Firebreak on the Ledger
const EFFECT_CROWN_OF_EMBERS := &"crown_of_embers"  ## mark cells, release at next own turn
const EFFECT_VERDICT_BY_FIRE := &"verdict_by_fire"  ## mark cells, release at the Ledger beat
const EFFECT_UNVEIL := &"unveil"                  ## Exposed + reveal the target's signature
const EFFECT_VEIL := &"veil"                      ## Veiled on self/ally (refused over Exposed)
const EFFECT_WITNESS_LIGHT := &"witness_light"    ## revelation field, radius 1, two checkpoints
const EFFECT_NOONDAY := &"noonday_revelation"     ## instant sweep, radius 2, one checkpoint
const EFFECT_PUSH := &"push"                      ## hit → shove target one cell away
const EFFECT_UNSEAT := &"unseat"                  ## hit → end the target's Guard
const EFFECT_TERM_OF_DAYLIGHT := &"term_of_daylight"  ## Witness Light + Daylight contract
const EFFECT_NOON_CONTRACT := &"noon_contract"    ## Noonday + trigger Witness contracts inside
const EFFECT_SECOND_BREATH := &"second_breath"    ## restore Breath to one ally, capped by paid
const EFFECT_TURNING_TIDE := &"turning_tide"      ## mode A: split Breath; mode B: quench a refuge
const EFFECT_GREAT_CONFLUENCE := &"great_confluence"  ## instant refuge: restore up to four + quench
const EFFECT_OPENED_SLUICE := &"opened_sluice"    ## Second Breath, cap 9 within a checkpoint of a Jam
const EFFECT_WASH_THE_GEARS := &"wash_the_gears"  ## Turning Tide B; Jam-cancelled enemies inside Soaked
const EFFECT_FLOODGATE := &"floodgate"            ## Great Confluence; discharges an armed Jam retry
const EFFECT_BLINDING_THROW := &"blinding_throw"  ## hit → Blinded, one checkpoint, no damage
const EFFECT_OPEN_SEAM := &"open_seam"            ## side/rear blade attack; a Bite waives the angle
const EFFECT_BLINDSIDE := &"blindside"            ## self: hide the next working's preparation
const EFFECT_BLINDSIDE_BITE := &"blindside_bite"  ## Blindside; next Open Seam on a Blinded target is flanked
const EFFECT_SHROUD := &"shroud"                  ## fixed concealment field, radius 1, two checkpoints
const EFFECT_ECLIPSE := &"eclipse_procession"     ## moving concealment field around the caster
const EFFECT_ECLIPSE_FEAST := &"eclipse_feast"    ## Eclipse; Hunger inside ticks once more at the checkpoint
const EFFECT_RECLAIM := &"reclaim"                ## consume a ruined source once for Breath (M4)
const EFFECT_ROT_THE_BRACE := &"rot_the_brace"    ## decay integrity damage on susceptible material
const EFFECT_SEVER := &"sever"                    ## end a working: a Firebreak line (Z6)
const EFFECT_HOLD_NOTE := &"hold_note"
const EFFECT_ANCHOR := &"anchor"
const _KNOWN_EFFECTS: Array[StringName] = [
	EFFECT_SECOND_BREATH, EFFECT_TURNING_TIDE, EFFECT_GREAT_CONFLUENCE, EFFECT_OPENED_SLUICE,
	EFFECT_WASH_THE_GEARS, EFFECT_FLOODGATE,
	EFFECT_BLINDING_THROW, EFFECT_OPEN_SEAM, EFFECT_BLINDSIDE, EFFECT_BLINDSIDE_BITE,
	EFFECT_SHROUD, EFFECT_ECLIPSE, EFFECT_ECLIPSE_FEAST,
	EFFECT_RECLAIM, EFFECT_ROT_THE_BRACE, EFFECT_SEVER,
	EFFECT_HOLD_NOTE, EFFECT_ANCHOR,
	EFFECT_UNVEIL, EFFECT_VEIL, EFFECT_WITNESS_LIGHT, EFFECT_NOONDAY, EFFECT_PUSH, EFFECT_UNSEAT,
	EFFECT_TERM_OF_DAYLIGHT, EFFECT_NOON_CONTRACT,
	EFFECT_BURNING_STRIKE, EFFECT_DOUSE, EFFECT_THRUST, EFFECT_PULL, EFFECT_FIRE_LINE,
	EFFECT_SENTENCE_OF_ASH, EFFECT_CROWN_OF_EMBERS, EFFECT_VERDICT_BY_FIRE,
]
## Write kinds that address cells rather than a combatant; deferred entries carrying them fire
## without a live target.
const _CELL_WRITE_KINDS: Array[StringName] = [&"fire_line", &"crown_release"]
## PROVISIONAL Refrain allowance per character per battle.
const REFRAIN_USES_PER_BATTLE := 1

var _actions: Dictionary = {}
var _abilities: Dictionary = {}
var _tactical_tables: TacticalTables
var _sequence := 0
## Seam v2 (#223 follow-up): effects queued by class resources for a later scheduler boundary.
## Fired by `_fire_due_deferred()` from `_drive_scheduler()` — the one place turns advance — and
## applied through `_apply_resolution_writes()`, the same path Resolution writes take.
var _deferred: Array[Dictionary] = []
var _deferred_sequence := 0
## True while an `action_resolved` event is being delivered (hooks + listeners) and the acting
## actor's scheduler commit is still unreleased. `request_cancel(&"committed")` on that actor
## is refused during this window; voiding the commit here would leave `scheduler.release()`
## with nothing to release.
var _resolving := false
## Reserved key inside the `class_resources` save dict that carries the deferred queue.
const DEFERRED_SAVE_KEY := "__deferred__"
## Reserved keys inside the same dict for the fire substrate and per-combatant impositions.
const FIRE_SAVE_KEY := "__fire__"
const LIGHT_SAVE_KEY := "__light__"
const JAMS_SAVE_KEY := "__jams__"
## Successful Jams by requester: {"round": int, "targets": [combat ids]}. The Sluice Runner
## reads this for its windows; it is data the controller already emitted as `action_cancelled`.
var _jam_log: Dictionary = {}
const IMPOSITIONS_SAVE_KEY := "__impositions__"
## Vekh preparations: {combat_id: {"until_round", "bite"}} for armed Blindsides and
## {combat_id: field_id} for an Eclipse Feast waiting on its checkpoint.
var _blindside: Dictionary = {}
var _feast: Dictionary = {}
const VEKH_SAVE_KEY := "__vekh__"
## Physical material on the board (yard timber, stone control): reaction-matrix step 1.
var material := MaterialField.new()
const MATERIALS_SAVE_KEY := "__materials__"
const HOLDS_SAVE_KEY := "__holds__"
## One owned Note per holder. held_by survives Aftertone array edits; upkeep_paid spans
## any CT recharge between paying upkeep and taking the first action of that turn.
var _holds: Dictionary = {}
## Effects that only ever address an object or a working, never a creature or a cell.
const _OBJECT_ONLY_EFFECTS: Array[StringName] = [&"reclaim", &"rot_the_brace", &"sever", &"hold_note", &"anchor"]
var _encounter_id: StringName = &""
## Tracks whose turn was last announced so a continuing actor (AP: still has AP left;
## CT: overflow keeps them past READY_AT) does not get a redundant `turn_started`.
var _last_turn_actor: BattleActor = null
## Tracks which side last acted so `enemy_turn_started` announces a PHASE change (ally
## control handing to the enemy side), not every individual enemy activation — this
## keeps the event's old meaning ("the enemy phase began") intact for both schedulers,
## including CT where several enemies can act back-to-back if they are fast enough.
var _last_side: StringName = &"ally"
## side -> the next ordinal a minted combat_id may use. Ids end in the actor's position within
## its side, so deriving that from the live array size would hand a departed combatant's id to
## the next arrival the moment release() compacts the array.
var _admission_ordinal: Dictionary = {}


func configure(
	actions: Array[CombatAction],
	positioning: BattlefieldModel,
	combat_rules: CombatRules,
	check_service: SkillCheckService = null,
	abilities: Array[AbilityDefinition] = [],
	tactical_tables: TacticalTables = null,
) -> void:
	_actions.clear()
	for action in actions:
		_actions[action.id] = action
	_abilities.clear()
	for ability in abilities:
		_abilities[ability.id] = ability
	_tactical_tables = tactical_tables if tactical_tables != null else TacticalTables.shared()
	battlefield = positioning
	rules = combat_rules
	scheduler = TurnScheduler.create_default(rules)
	skill_check_service = check_service
	if skill_check_service == null:
		var main_loop := Engine.get_main_loop()
		if main_loop is SceneTree:
			skill_check_service = (
				(main_loop as SceneTree).root.get_node_or_null("SkillCheck") as SkillCheckService
			)
	if skill_check_service == null:
		skill_check_service = SkillCheckService.new()


func configure_agreement_integrity(value: float) -> void:
	agreement_integrity = clampf(value, 0.0, 100.0)


## Issue #209: authors this battle's weather element (from encounter data — the caller
## owns where that is authored). Returns Weather's own validation result, so an
## unrecognized element is a loud refusal, never silently "weather".
func configure_weather(element_id: StringName, hush: bool = false) -> Dictionary:
	weather.set_hush(hush)
	if element_id == Weather.UNCHARGED:
		return {"allowed": true, "element_id": String(Weather.UNCHARGED)}
	return weather.set_element(element_id)


## Physical visibility for this shot, composed by the battlefield (worst cell wins) and marked
## applicable only for ranged, non-spell attacks: melee swings and direct spells carry no
## visibility term until an explicit profile says so. A Blinded attacker keeps its accepted
## behavior (the facing restriction in _positional_terms) and gets no second penalty here.
func visibility_context(actor: BattleActor, target: BattleActor, action: CombatAction) -> Dictionary:
	var composed: Dictionary = battlefield.visibility_between(actor, target)
	var blinded := LightField.is_blinded(actor)
	var applicable := (
		action != null and action.kind == CombatAction.Kind.ATTACK
		and action.target_profile == &"ranged" and not action.spell
	)
	return {
		"level": String(composed.get("level", &"clear")),
		"causes": (composed.get("causes", []) as Array).duplicate(true),
		"applies": applicable and not blinded,
		"blinded": blinded,
		"reason": "blinded_facing_restriction" if blinded else ("" if applicable else "action_profile"),
	}


## Authors physical visibility on one cell mid-battle and refreshes every forecast consumer:
## the event carries a fresh ordinary-strike forecast context so region D re-quotes at once.
func configure_visibility(cell: Vector2i, level: StringName) -> Dictionary:
	var result: Dictionary = battlefield.set_visibility(cell, level)
	if not bool(result.get("allowed", false)):
		return result
	var actor := active_actor()
	var target := _first_living(enemies)
	_emit_event(&"visibility_changed", actor, target, {
		"cell": FireField.cells_to_data([cell])[0], "level": String(level),
		"forecast_context": forecast_context(actor, target, action_by_id(&"strike")),
	})
	return result


## Builds one TileState per battlefield cell (grid battles only; a cell-less model
## reports no tiles and the battle keeps zone semantics). Heights come from the same
## terrain snapshot the presentation layer uses, so the two can never disagree.
func _reset_tile_states() -> void:
	tile_states.clear()
	_tile_by_cell.clear()


## Advances weather by the CT ticks the scheduler just reported. Every 16th tick
## Weather applies its measure over the live tiles; an application that moved charge
## is presentation-worthy, so it is emitted as its own event.
func _advance_weather(ticks_elapsed: int) -> void:
	for i in ticks_elapsed:
		var result := weather.tick(tile_states, balance)
		if not bool(result.get("applied", false)):
			continue
		if weather.element_id == Weather.UNCHARGED:
			continue
		_emit_event(&"weather_applied", null, null, {
			"element_id": String(weather.element_id),
			"charged_tiles": int(result.get("charged_tiles", 0)),
			"drained_tiles": int(result.get("drained_tiles", 0)),
			"measures_applied": weather.measures_applied(),
		})


func tile_state_at(cell: Vector2i) -> TileState:
	if _tile_by_cell.has(cell):
		return _tile_by_cell[cell]
	if battlefield == null:
		return null
	for terrain: Dictionary in battlefield.tiles_snapshot():
		if Vector2i(int(terrain.get("x", 0)), int(terrain.get("y", 0))) != cell:
			continue
		var tile := TileState.create(
			_encounter_id, cell.x, cell.y,
			int(terrain.get("height_delta", 0)), bool(terrain.get("cover", false))
		)
		_tile_by_cell[cell] = tile
		tile_states.append(tile)
		# Preserve the original row-major order of weather effects regardless of touch order.
		tile_states.sort_custom(func(a: TileState, b: TileState) -> bool:
			return a.y < b.y or (a.y == b.y and a.x < b.x)
		)
		return tile
	return null


## The diametric Clash element (wheel distance 5) — what this weather starves.
static func _clash_of(element_id: StringName) -> StringName:
	for candidate: StringName in ElementWheel.ORDER:
		if ElementWheel.distance(element_id, candidate) == Weather.CLASH_WHEEL_DISTANCE:
			return candidate
	return &""


func start(
	ally_group: Array[BattleActor],
	enemy_group: Array[BattleActor],
	encounter_id: StringName = &""
) -> void:
	for holder_id: String in _holds.keys():
		release_hold(holder_id, "battle_restarted")
	allies = ally_group
	enemies = enemy_group
	_encounter_id = encounter_id
	_sequence = 0
	round_number = 0
	balance = 0
	balance_band_id = &""
	balance_lock_until_round = 0
	duration_freeze_until_round = 0
	revealed_until_round = 0
	concealed_until_round = 0
	zone_boundaries_open_until_round = 0
	thunderhead_hit_until_round = 0
	range_bonus_until_round = 0
	founding_anchor_restore.clear()
	revealed_side = &"ally"
	concealed_side = &"ally"
	spent_aftertones = 0
	threshold_effects_suppressed = false
	last_refusal.clear()
	active_ally_index = -1
	_last_turn_actor = null
	_last_side = &"ally"
	_deferred.clear()
	_deferred_sequence = 0
	fire.reset()
	light.reset()
	_jam_log.clear()
	_refrain_uses.clear()
	_blindside.clear()
	_feast.clear()
	material.reset()
	_holds.clear()
	for combatant: BattleActor in allies + enemies:
		combatant.impositions.clear()
	_assign_combat_ids(allies, &"ally", encounter_id)
	_assign_combat_ids(enemies, &"enemy", encounter_id)
	_admission_ordinal = {&"ally": allies.size(), &"enemy": enemies.size()}
	_attach_class_resources(allies)
	_attach_class_resources(enemies)
	battlefield.setup(allies, enemies)
	scheduler.setup(allies + enemies)
	_reset_tile_states()
	_apply_balance_band(false)
	state = State.ROUND_START
	_emit_event(&"battle_started", null, null, {})
	if not _has_living(enemies):
		_finish(ResultState.VICTORY, &"slain")
		return
	_drive_scheduler()


## Seats one combatant in a battle that is ALREADY RUNNING (same-map combat D5): the hostile a
## party member just walked past, admitted without restarting anything. Idempotent, because the
## alert that calls it can fire more than once for the same mob.
##
## `admission_delay` is what keeps this fair: the newcomer is seated that far behind ready, so
## it cannot act before the party's next turn. Every step reuses the code start() uses — one
## insertion path, or the two would drift.
func admit(actor: BattleActor, cell: Vector2i, side: StringName = &"enemy") -> Dictionary:
	if actor == null:
		return _blocked(
			&"composition", "There is no combatant to admit.", {"type": &"present_combatant"}
		)
	if state == State.IDLE or state == State.FINISHED:
		return _blocked(&"battle_not_live", "No live battle to admit into.", {})
	if side != &"ally" and side != &"enemy":
		return _blocked(&"composition", "Unknown side: %s." % side, {"type": &"known_side"})
	if not actor.combat_id.is_empty():
		var existing := _actor_by_id(String(actor.combat_id))
		if existing == actor:
			return _allowed({"already_admitted": true, "combat_id": String(actor.combat_id)})
		if existing != null:
			return _blocked(
				&"composition", "Combat id %s is already taken." % actor.combat_id,
				{"type": &"unique_id"}
			)

	var ordinal := int(_admission_ordinal.get(side, 0))
	_assign_combat_id(actor, side, _encounter_id, ordinal)
	_admission_ordinal[side] = ordinal + 1
	if _actor_by_id(String(actor.combat_id)) != null:
		# A duplicate id would alias two combatants in every id-keyed map at once, silently.
		return _blocked(
			&"composition", "Combat id %s is already taken." % actor.combat_id, {"type": &"unique_id"}
		)

	var group: Array[BattleActor] = allies if side == &"ally" else enemies
	var placed := battlefield.admit_combatant(
		actor, StringName("c:%d,%d,0" % [cell.x, cell.y]), side
	)
	if not bool(placed.get("allowed", false)):
		last_refusal = placed
		return placed
	var seated := _seat_with_admission_guarantee(actor, side)
	if not bool(seated.get("allowed", false)):
		battlefield.remove_combatant(actor)
		last_refusal = seated
		return seated

	var single: Array[BattleActor] = [actor]
	_attach_class_resources(single)
	group.append(actor)
	return _allowed({
		"combat_id": String(actor.combat_id),
		"side": String(side),
		"position": String(battlefield.position_of(actor)),
		"charge": scheduler.charge_of(actor),
	})


## F0 ruling 6, invariant A1: for any actor admitted mid-session at tick T, at least one
## party-side actor's turn begins strictly between T and that actor's first turn.
##
## `rules.admission_delay` is the default mechanism, not the guarantee — it is a flat CT
## number and a newcomer's speed decides how many ticks that buys. A fast mob admitted during
## an enemy turn can clear a flat delay before any ally acts, which is exactly the case the
## constant was supposed to prevent. So the delay is raised until the projected order actually
## satisfies A1, and the invariant is asserted rather than assumed.
func _seat_with_admission_guarantee(actor: BattleActor, side: StringName) -> Dictionary:
	var delay := maxi(rules.admission_delay if rules != null else 0, 0)
	var seated := scheduler.admit(actor, delay)
	if not bool(seated.get("allowed", false)):
		return seated
	# An ally admitted mid-session is the party; there is nothing to protect it from. With no
	# living ally at all A1 is unsatisfiable, and the battle is over on the next drive anyway.
	if side == &"ally" or not _has_living(allies):
		return seated
	for _attempt in _ADMISSION_ESCALATION_LIMIT:
		if _party_acts_before(actor):
			return seated
		scheduler.remove_participant(actor)
		delay = maxi(delay * 2, 1)
		seated = scheduler.admit(actor, delay)
		if not bool(seated.get("allowed", false)):
			return seated
	var held := _party_acts_before(actor)
	if not held:
		push_warning(
			"Admission invariant A1 unmet for %s after %d escalations; admitted anyway."
			% [actor.display_name, _ADMISSION_ESCALATION_LIMIT]
		)
	assert(held, "Admission invariant A1 violated (F0 ruling 6).")
	return seated


## True when some living ally's turn begins strictly before `actor`'s first projected turn.
## Read from `scheduler.peek_order()`, which projects from the same arithmetic `advance()`
## uses — asking the timeline is the only way this check cannot disagree with resolution.
func _party_acts_before(actor: BattleActor) -> bool:
	var depth := maxi(16, (allies.size() + enemies.size() + 2) * 4)
	for entry: Dictionary in scheduler.peek_order(depth):
		var next := entry.get("actor") as BattleActor
		if next == actor:
			return false
		if next != null and next.is_alive() and allies.has(next):
			return true
	return false


## Takes a combatant OUT of a running battle: it fled, or it left the field. Not the same verb
## as `TurnScheduler.release(actor)`, which means "the committed action resolved" — this one is
## the inverse of `admit()`. Death is NOT a release: a downed actor stays in the arrays and is
## filtered by `is_alive()`, which is what lets the ledger and the corpse still find it.
func release(combat_id: StringName) -> Dictionary:
	if state == State.IDLE or state == State.FINISHED:
		return _blocked(&"battle_not_live", "No live battle to release from.", {})
	var actor := _actor_by_id(String(combat_id))
	if actor == null:
		return _blocked(&"unknown_target", "No combatant with id %s." % combat_id, {})
	var side := actor.side
	battlefield.remove_combatant(actor)
	scheduler.remove_participant(actor)
	allies.erase(actor)
	enemies.erase(actor)
	if _last_turn_actor == actor:
		_last_turn_actor = null
	active_ally_index = allies.find(scheduler.active_actor())
	return _allowed({"combat_id": String(combat_id), "from_side": String(side)})


func active_actor() -> BattleActor:
	if scheduler == null:
		return null
	var actor := scheduler.active_actor()
	active_ally_index = allies.find(actor) if actor != null else -1
	return actor


func action_by_id(action_id: StringName) -> CombatAction:
	return _actions.get(action_id) as CombatAction


func query_action(
	action: CombatAction, target: BattleActor = null, options: Dictionary = {}
) -> Dictionary:
	var actor := active_actor()
	if state != State.ALLY_TURN or actor == null or not actor.is_alive():
		return _blocked(&"turn_state", "No party combatant can act right now.", {})
	if action == null:
		return _blocked(&"action", "Unknown combat action.", {"type": &"known_action"})
	if action.requires_voice:
		var voice_block := CombatInjury.voice_block(actor)
		if not voice_block.is_empty():
			return _blocked(
				&"voice_required",
				"%s needs a voice; %s's %s injury prevents it." % [
					action.display_name, actor.display_name, str(voice_block.get("location_id", "throat")).capitalize().to_lower(),
				],
				{"type": &"intact_voice", "location_id": str(voice_block.get("location_id", "")), "injury_id": str(voice_block.get("injury_id", ""))},
			)
	var aim_location := StringName(str(options.get("aim_location", "")))
	if not aim_location.is_empty():
		if options.has("object_id") or options.has("line_id"):
			return _blocked(&"aim_action", "Anatomical aim requires a creature target.", {})
		var aim := _query_aim(actor, target, action, aim_location)
		if not bool(aim.get("allowed", false)):
			return aim
	if not action.class_resource_action.is_empty():
		# A class-resource action is authored once and offered to every actor, so
		# the resource itself decides whether the command means anything for this
		# patron. Before #236 a Lensbearer could press Record Name and nothing at
		# all happened; now the button locks with a reason.
		var resource := _class_resource_of(actor)
		if not resource.accepts_command(action.class_resource_action):
			return _blocked(
				&"class_resource",
				"%s cannot use that class action." % actor.display_name,
				{"type": &"patron", "patron": resource.patron_id},
			)
	if action.requires_ally_target():
		if target == null or not target.is_alive() or not allies.has(target):
			return _blocked(&"no_target", "%s requires an explicit living ally target." % action.display_name, {"type": &"living_ally"})
	if not action.effect_id.is_empty() or not action.effect_payload.is_empty() or action.targets_cells():
		var effect_gate := _query_effect_gate(actor, action, options)
		if not bool(effect_gate.get("allowed", false)):
			return effect_gate
	if options.has("object_id") or options.has("line_id") or _OBJECT_ONLY_EFFECTS.has(action.effect_id):
		var object_affordability := _can_afford(actor, action)
		if not bool(object_affordability.get("allowed", false)):
			return object_affordability
		return _query_object_action(actor, action, options)
	if action.targets_cells():
		var cell_affordability := _can_afford(actor, action)
		if not bool(cell_affordability.get("allowed", false)):
			return cell_affordability
		if bool(options.get("availability_only", false)):
			# The command rail asks "can this be armed?" before any cell is picked.
			return _allowed({"cells_pending": int(action.effect_payload.get("cell_count", 3))})
		return _query_cell_action(actor, action, options, target)
	if action.targets_any_side():
		if target == null or not target.is_alive() or (not allies.has(target) and not enemies.has(target)):
			return _blocked(&"no_target", "%s requires a living creature target." % action.display_name, {"type": &"living_target"})
	if not action.class_resource_action.is_empty():
		if action.requires_enemy_target() and (target == null or not target.is_alive() or not enemies.has(target)):
			return _blocked(&"no_target", "%s requires a living enemy target." % action.display_name, {"type": &"living_enemy"})
		var command_gate := _class_resource_of(actor).query_command(
			action.class_resource_action, target.combat_id if target != null else &"",
			action.class_resource_payload,
		)
		if not bool(command_gate.get("allowed", false)):
			return command_gate
		if _soul_meter() < action.soul_cost:
			return _blocked(&"soul", "Requires %d Soul." % int(action.soul_cost), {
				"type": &"soul", "minimum": action.soul_cost,
			})
	if action.kind == CombatAction.Kind.MOVE:
		var movement := battlefield.move_query(actor, _move_destination(action, options))
		if not bool(movement.get("allowed", false)):
			return movement
		var priced_action := _priced_move_action(action, movement, options, actor)
		var move_affordability := _can_afford(actor, priced_action)
		if not bool(move_affordability.get("allowed", false)):
			return move_affordability
		movement["ap_cost"] = priced_action.ap_cost
		movement["ct_cost"] = priced_action.ct_cost
		movement["move_modifiers"] = CombatInjury.move_cost_modifiers(actor)
		return movement
	var affordability := _can_afford(actor, CalledShot.priced_action(action, aim_location))
	if not bool(affordability.get("allowed", false)):
		return affordability
	if action.requires_enemy_target():
		var targeting := battlefield.target_query(actor, target, action.target_profile)
		if not bool(targeting.get("allowed", false)):
			return targeting
	if action.requires_ally_target() and action.class_resource_action.is_empty() and target != actor:
		var ally_sight := battlefield.line_of_sight(actor, target)
		if not bool(ally_sight.get("allowed", false)):
			return ally_sight
	if action.targets_any_side() and target != actor:
		var any_sight := battlefield.line_of_sight(actor, target)
		if not bool(any_sight.get("allowed", false)):
			return any_sight
	if target != null and (not action.effect_id.is_empty() or action.effect_payload.has("range")):
		var effect_targeting := _query_effect_target(actor, target, action)
		if not bool(effect_targeting.get("allowed", false)):
			return effect_targeting
	if action.kind == CombatAction.Kind.DEFINING_STRIKE:
		var defining_gate := _query_defining_strike(
			target, StringName(options.get("weakness_id", ""))
		)
		if not bool(defining_gate.get("allowed", false)):
			return defining_gate
		var resolution_options := options.duplicate(true)
		resolution_options.merge({
			"weakness": defining_gate.get("weakness", {}).duplicate(true),
			"seed": _sequence,
			"ability_id": String(action.id),
			"battle_id": String(_encounter_id),
		}, true)
		var resolution_gate := _query_attack_resolution(
			actor, target, action, resolution_options
		)
		if not bool(resolution_gate.get("allowed", false)):
			return resolution_gate
		defining_gate.merge(resolution_gate, true)
		return defining_gate
	if action.kind == CombatAction.Kind.CAST:
		return _query_cast(actor, target, action, options)
	if action.kind == CombatAction.Kind.ATTACK:
		if action.spell and target != null:
			# An authored spell card resolves like a loadout cast: fizzle and Breath come from the
			# same Resolution call, so the Soul-after-Breath refusal surfaces here, before commit.
			var spell_gate := _query_attack_resolution(actor, target, action, options)
			if not bool(spell_gate.get("allowed", false)):
				return spell_gate
			var spell_resolution: Dictionary = spell_gate["resolution"]
			var spell_soul := 0.0
			for write: Dictionary in spell_resolution.get("writes", []):
				if StringName(str(write.get("kind", ""))) == &"soul_meter":
					spell_soul = -float(write.get("delta", 0.0))
			spell_gate["breath_cost"] = action.breath_cost
			spell_gate["soul_cost"] = spell_soul
			return spell_gate
		return _query_attack_resolution(actor, target, action, options)
	return _allowed()


func submit_action(
	action_id: StringName, target: BattleActor = null, options: Dictionary = {}
) -> Dictionary:
	var action := action_by_id(action_id)
	if action != null and action.requires_enemy_target() and target == null:
		target = _first_living(enemies)
	var query := query_action(action, target, options)
	if not bool(query.get("allowed", false)):
		last_refusal = query.duplicate(true)
		_emit_event(&"action_refused", active_actor(), target, {"action_id": action_id, "reason": query})
		return query

	var actor := active_actor()
	var committed_action := _priced_move_action(action, query, options, actor)
	committed_action = CalledShot.priced_action(
		committed_action, StringName(str(options.get("aim_location", "")))
	)
	var commit_result := scheduler.commit(actor, committed_action)
	if not bool(commit_result.get("allowed", false)):
		# query_action() already validated affordability via the same gate, so this is a
		# defensive re-check (e.g. a race between query and submit), not duplicated UX.
		last_refusal = commit_result.duplicate(true)
		_emit_event(&"action_refused", actor, target, {"action_id": action_id, "reason": commit_result})
		return commit_result
	var resolved_options := options.duplicate(true)
	if query.has("resolution"):
		resolved_options["_resolution"] = query["resolution"]
		resolved_options["_resolution_context"] = query.get("context", {})
	if query.has("object"):
		resolved_options["_object"] = query["object"]
	if query.has("cells"):
		resolved_options["_cells"] = query["cells"]
		if target != null:
			resolved_options["_target_id"] = String(target.combat_id)
	if bool(committed_action.effect_payload.get("refrain_use", false)):
		# The proposed spent-use rule: the allowance is consumed at commit, fizzle or not.
		_refrain_uses[String(actor.combat_id)] = int(_refrain_uses.get(String(actor.combat_id), 0)) + 1
	if committed_action.kind == CombatAction.Kind.PASS and not committed_action.class_resource_action.is_empty():
		if committed_action.soul_cost > 0.0:
			_set_soul_meter(_soul_meter() - committed_action.soul_cost)
		_class_resource_of(actor).execute_command(
			committed_action.class_resource_action,
			target.combat_id if target != null else &"",
			committed_action.class_resource_payload.duplicate(true),
		)
	var outcome := _apply_action(actor, target, committed_action, resolved_options)
	_finish_hold_turn(actor)
	_check_holds()
	outcome["action_id"] = action.id
	if options.has("aim_location") and not str(options["aim_location"]).is_empty():
		outcome["aim_location"] = str(options["aim_location"])
	outcome["verb"] = action.verb
	outcome["ap_cost"] = committed_action.ap_cost
	outcome["ct_spent"] = int(commit_result.get("ct_spent", 0))
	outcome["ap_remaining"] = actor.action_points
	outcome["charge_remaining"] = int(commit_result.get("charge", 0))
	_emit_event(&"action_resolved", actor, target, outcome)
	last_refusal.clear()
	scheduler.release(actor)
	if action.kind == CombatAction.Kind.RESOLUTION:
		_finish(ResultState.VICTORY, action.outcome_id)
		return _allowed(outcome)
	_drive_scheduler()
	return _allowed(outcome)


func submit_speech(
	action_id: StringName, check_result: Dictionary, option: CombatSpeechOption
) -> Dictionary:
	var action := action_by_id(action_id)
	var query := query_action(action)
	if not bool(query.get("allowed", false)):
		last_refusal = query.duplicate(true)
		_emit_event(&"action_refused", active_actor(), null, {"action_id": action_id, "reason": query})
		return query
	if action.verb != CombatAction.Verb.SPEECH:
		var wrong_verb := _blocked(
			&"action_verb",
			"Only a declared speech verb can resolve a combat speech check.",
			{"type": &"verb", "required": CombatAction.Verb.SPEECH},
		)
		last_refusal = wrong_verb.duplicate(true)
		_emit_event(
			&"action_refused", active_actor(), null, {"action_id": action_id, "reason": wrong_verb}
		)
		return wrong_verb
	var option_refusal := option.validation_refusal() if option != null else _blocked(
		&"speech_option", "Unknown combat speech option.", {"type": &"known_speech_option"}
	)
	if not bool(option_refusal.get("allowed", false)):
		last_refusal = option_refusal.duplicate(true)
		_emit_event(
			&"action_refused",
			active_actor(),
			null,
			{"action_id": action_id, "reason": option_refusal},
		)
		return option_refusal

	var actor := active_actor()
	var commit_result := scheduler.commit(actor, action)
	if not bool(commit_result.get("allowed", false)):
		last_refusal = commit_result.duplicate(true)
		_emit_event(&"action_refused", actor, null, {"action_id": action_id, "reason": commit_result})
		return commit_result
	var succeeded := bool(check_result.get("success", false))
	var outcome: Dictionary = {
		"action_id": action.id,
		"verb": action.verb,
		"ap_cost": action.ap_cost,
		"ct_spent": int(commit_result.get("ct_spent", 0)),
		"ap_remaining": actor.action_points,
		"charge_remaining": int(commit_result.get("charge", 0)),
		"speech_option_id": option.id,
		"speech_outcome": option.outcome_name(),
		"outcome_id": option.outcome_id,
		"check": check_result.duplicate(true),
		"success": succeeded,
		"damage": 0,
		"message": option.success_message if succeeded else option.failure_message,
	}
	if succeeded:
		outcome.merge(_apply_speech_composition(actor, option), true)
	_emit_event(&"action_resolved", actor, null, outcome)
	last_refusal.clear()
	scheduler.release(actor)

	if succeeded and (
		option.outcome == CombatSpeechOption.Outcome.END or not _has_living(enemies)
	):
		_finish(ResultState.VICTORY, option.outcome_id)
		return _allowed(outcome)
	_drive_scheduler()
	return _allowed(outcome)


func end_turn() -> bool:
	if state != State.ALLY_TURN or active_actor() == null:
		return false
	var actor := active_actor()
	var forfeited_ap := actor.action_points
	# Yield before publishing the end-of-turn transition. Charge time can refuse a third
	# consecutive wait, in which case the ready actor must remain in control and act.
	var yield_result := scheduler.yield_turn(actor)
	if not bool(yield_result.get("allowed", false)):
		last_refusal = yield_result.duplicate(true)
		_emit_event(&"action_refused", actor, null, {"action_id": &"", "reason": yield_result})
		return false
	var unused_ap_defense := 0
	_finish_hold_turn(actor)
	if (
		rules != null
		and str(scheduler.to_dict().get("scheduler", "")) == "ap_round"
		and forfeited_ap >= 1
	):
		unused_ap_defense = mini(
			forfeited_ap * rules.unused_ap_defense_per_ap,
			rules.unused_ap_defense_cap,
		)
		actor.unused_ap_defense_bonus = unused_ap_defense
	last_refusal.clear()
	_emit_event(
		&"turn_ended",
		actor,
		null,
		{
			"ap_remaining": actor.action_points,
			"charge_remaining": scheduler.charge_of(actor),
			"forfeited_ap": forfeited_ap,
			"unused_ap_defense_bonus": unused_ap_defense,
		},
	)
	# Forfeits whatever resource remains — a no-op if there is nothing left to give up. This
	# is the ONLY place a turn is yielded voluntarily; a turn that already spent its action
	# via submit_action() is advanced by _drive_scheduler() below without yielding, so a
	# charge-time actor with banked overflow is not made to give it up just because it acted.
	_drive_scheduler()
	return true


func force_finish(result_state: ResultState, outcome_id: StringName) -> void:
	_finish(result_state, outcome_id)


func shift_balance(amount: int) -> void:
	_change_balance(amount)


func apply_balance_effect(parameters: Dictionary, actor: BattleActor = null) -> Dictionary:
	if (
		str(parameters.get("balance_gauge", "")) != "exact_center"
		or str(parameters.get("lock_until", "")) != "end_of_next_round"
	):
		return _blocked(&"balance_effect", "Unsupported Balance Gauge effect.", {})
	var previous := balance
	balance = 0
	threshold_effects_suppressed = bool(parameters.get("suppress_threshold_effects", false))
	balance_lock_until_round = round_number + 1
	_apply_balance_band()
	if previous != balance:
		_emit_event(
			&"balance_changed",
			actor,
			null,
			{"balance": balance, "delta": balance - previous, "band_id": balance_band_id},
		)
	_emit_event(
		&"balance_locked",
		actor,
		null,
		{
			"balance": balance,
			"until_round": balance_lock_until_round,
			"threshold_effects_suppressed": threshold_effects_suppressed,
		},
	)
	return _allowed({"balance": balance, "until_round": balance_lock_until_round})


func snapshot() -> Dictionary:
	return {
		"state": state,
		"encounter_id": _encounter_id,
		"round": round_number,
		"balance": balance,
		"revealed_until_round": revealed_until_round,
		"concealed_until_round": concealed_until_round,
		"zone_boundaries_open_until_round": zone_boundaries_open_until_round,
		"balance_band_id": balance_band_id,
		"balance_lock_until_round": balance_lock_until_round,
		"threshold_effects_suppressed": threshold_effects_suppressed,
		"active_actor_id": active_actor().combat_id if active_actor() else &"",
		"allies": _actor_snapshots(allies),
		"enemies": _actor_snapshots(enemies),
		"tiles": _tile_snapshots(),
		"weather": _weather_snapshot(),
		"scheduler_mode": str(scheduler.to_dict().get("scheduler", "")) if scheduler != null else "",
		"turn_order": _turn_order_snapshot(),
		"movement": _movement_snapshot(),
		"deferred": deferred_entries(),
		"fire": {"lines": fire.snapshot(), "marks": _marks_snapshot()},
		"materials": material.snapshot(),
		"holds": _holds.duplicate(true),
		"light": {"fields": _light_snapshot(), "shrouds": _shroud_snapshot()},
	}


## Additive UI query surface for a selected destination. The result uses the battlefield's
## refusal taxonomy and includes the exact AP/CT quote submit_action() will commit.
func move_query(destination: StringName) -> Dictionary:
	return query_action(action_by_id(ACTION_MOVE), null, {"destination": destination})


func _movement_snapshot() -> Dictionary:
	var actor := active_actor()
	var action := action_by_id(ACTION_MOVE)
	if actor == null or action == null or battlefield == null:
		return {}
	var capabilities: Dictionary = battlefield.capabilities()
	if not bool(capabilities.get("cells", false)) or state != State.ALLY_TURN:
		return {}
	var base_move_cost := maxi(1, rules.move_ct_cost if rules != null else 1)
	var per_cell_ap := maxi(1, action.ap_cost)
	var ct_budget := int(
		float(int(actor.action_points / per_cell_ap) * base_move_cost)
		/ CombatInjury.move_cost_multiplier(actor)
	)
	var reachable: Array[Dictionary] = []
	for destination: StringName in battlefield.reachable_positions(actor, ct_budget):
		var query := move_query(destination)
		if not bool(query.get("allowed", false)):
			continue
		reachable.append({
			"destination": destination,
			"ap_cost": int(query.get("ap_cost", 0)),
			"ct_cost": int(query.get("ct_cost", 0)),
			"path": (query.get("path", []) as Array).duplicate(),
			"path_cells": _describe_path_cells(query.get("path", [])),
		})
	return {
		"action_id": ACTION_MOVE,
		"per_cell_ap_cost": per_cell_ap,
		"remaining_ap": actor.action_points,
		"reachable": reachable,
	}


func _turn_order_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if scheduler == null:
		return result
	# The AP scheduler exposes the complete living-round order (acted actors included);
	# CT keeps the forecast-depth view. Region E must never lose an actor mid-round.
	var order: Array[Dictionary]
	if scheduler.has_method("round_overview"):
		order = scheduler.round_overview()
	else:
		order = scheduler.peek_order(8)
	for entry: Dictionary in order:
		var actor := entry.get("actor") as BattleActor
		if actor == null:
			continue
		var row := entry.duplicate(true)
		row.erase("actor")
		row["actor_id"] = actor.combat_id
		row["display_name"] = actor.display_name
		result.append(row)
	return result


## Keep the complete replay payload without allocating persistent state for untouched cells.
## Weather only changes already-charged cells, so untouched cells remain neutral.
func _tile_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if battlefield == null:
		return result
	var neutral: Dictionary = TileState.create(_encounter_id, 0, 0).to_dict()
	for terrain: Dictionary in battlefield.tiles_snapshot():
		var cell := Vector2i(int(terrain.get("x", 0)), int(terrain.get("y", 0)))
		var tile: TileState = _tile_by_cell.get(cell)
		if tile != null:
			result.append(tile.to_dict())
		else:
			var data: Dictionary = neutral.duplicate()
			data["x"] = cell.x
			data["y"] = cell.y
			data["height_delta"] = int(terrain.get("height_delta", 0))
			data["cover"] = bool(terrain.get("cover", false))
			result.append(data)
	return result


func _weather_snapshot() -> Dictionary:
	var data := weather.to_dict()
	data["tick"] = scheduler.tick_count() if scheduler != null else 0
	if weather.element_id != Weather.UNCHARGED:
		data["gains"] = String(weather.element_id)
		data["drains"] = String(_clash_of(weather.element_id))
	return data


## Placeholder Wheel element substituted when an authored `CombatAction` leaves `element_id`
## empty (issue #142 follow-up). `Resolution.resolve()` requires the ability side to name a real
## Wheel element — an empty one blocks with `&"unknown_element"` — but `BattleActor.element_id`
## (the TARGET side) is left empty by default and resolves to `ElementMatrix`'s neutral
## `IDENTITY_ROW` (×1.0) for any attack element. So which real element an unauthored ability is
## "wearing" is inert until a real per-unit attunement is authored on the target: any fixed
## choice here reproduces the same ×1.0 multiplier as before this wiring existed. This is NOT a
## balance or lore decision — it exists only so the resolver's schema-validity check has
## something to validate against.
const _UNAUTHORED_ELEMENT_ID := &"sul"


## Routes live combat damage through the pure `Resolution.resolve()` (globals/combat/resolution.gd,
## #142) instead of standalone arithmetic, while keeping the RPG stat layer (attack/defense/
## flank/cover) this file already owns. The split:
##   - Attacker-side power modifiers (base attack, authored power bonus, flank, Order/Chaos
##     damage_bonus) feed `ability.power`, so they flow through Resolution's
##     `power × attack_scale × element_matrix × facing × tile_charge` chain.
##   - Target-side mitigation (defense, defense_bonus, cover) is subtracted from Resolution's
##     result afterward, exactly as it was subtracted before this change — Resolution has no
##     defense-stat concept of its own (it is the Elements & Music resolver, not the RPG stat
##     system), so this file keeps owning that term rather than inventing one inside Resolution.
## `battle_id`/`tick`/tile-state/weather context stay neutral. Grid-capable callers provide the
## FR-105a height/facing context; zone combat keeps its existing additive flank behavior.
static func calculate_damage(
	attacker: BattleActor,
	target: BattleActor,
	power_bonus: int,
	_alignment_shift: int,
	_current_balance: int,
	flank_bonus: int = 0,
	cover_bonus: int = 0,
	ability_element_id: StringName = &"",
	ability_magnitude: StringName = &"note",
	seed: int = 0,
	positional_context: Dictionary = {},
	resolution_context: Dictionary = {},
) -> int:
	var element_id := ability_element_id
	if String(element_id).is_empty():
		element_id = _UNAUTHORED_ELEMENT_ID
	var power := (
		attacker.effective_attack()
		+ power_bonus
		+ flank_bonus
		+ int(attacker.balance_effects.get("damage_bonus", 0))
	)
	var unit_context := {
			"id": String(attacker.combat_id),
			"attack_scale": attacker.attack_scale,
			# To-hit (#169 ruling): grid callers supply positional context and opt in; zone
			# combat keeps its legacy auto-hit behavior.
			"to_hit_enabled": not positional_context.is_empty(),
			"tick": int(seed),
			"alacrity": attacker.attribute_value(&"alacrity"),
			# #209: tile/weather terms ride the same positional channel. Absent keys
			# resolve to Resolution's neutral terms (uncharged tiles, no weather).
			"tile_state": positional_context.get("source_tile", {}),
			"weather": positional_context.get("weather", {}),
			"aftertones": attacker.aftertones.duplicate(true),
			"tempo": attacker.tempo,
			"last_cast_element": attacker.last_cast_element,
			"hit": bool(attacker.defining_effects.get("hit", false)),
		}
	if resolution_context.has("weakness_id"):
		unit_context["weakness_id"] = resolution_context["weakness_id"]
		unit_context["weakness"] = resolution_context.get("weakness", {}).duplicate(true)
	if resolution_context.has("battle_id"):
		unit_context["battle_id"] = resolution_context["battle_id"]
	var result := Resolution.resolve_action(
		unit_context,
		{
			# Defining strikes pass their real ability id so the deterministic roll key
			# matches `forecast_defining_strike()` — forecast==resolution. Plain attacks
			# keep the legacy "attack" key (changing it would reshuffle every battle's RNG).
			"id": str(resolution_context.get("ability_id", "attack")),
			"element_id": element_id,
			"magnitude": ability_magnitude,
			"power": power,
		},
		{
			"target": {
				"id": String(target.combat_id),
				"hp": target.hp,
				"element_id": target.element_id,
				"alacrity": target.attribute_value(&"alacrity"),
				"aftertones": target.aftertones.duplicate(true),
				"tempo": target.tempo,
				"last_cast_element": target.last_cast_element,
				"hit": bool(target.defining_effects.get("hit", false)),
			},
			"tile_state": positional_context.get("target_tile", {}),
			"facing": positional_context.get("facing", {}),
			"height_advantage_steps": int(
				positional_context.get("height_advantage_steps", 0)
			),
		},
		seed,
	)
	var raw_damage := 0
	if bool(result.get("allowed", false)):
		if not bool(result.get("hit", true)):
			# A rolled miss deals nothing: bypass the 1-damage floor below, which exists for
			# glancing hits, not for whiffs.
			return 0
		raw_damage = int(result.get("damage", 0))
	else:
		# Should be unreachable: a valid Wheel `element_id` (real or the placeholder above) with
		# magnitude `&"note"` is always a legal single-element Tone, which `CastingGate` always
		# allows regardless of harmony. Surfacing this loudly rather than silently degrading to
		# the 1-damage floor below, in case that invariant is ever violated by a future caller.
		push_warning(
			"CombatController.calculate_damage: Resolution refused (%s) — %s"
			% [result.get("blocked_by", ""), result.get("message", "")]
		)
	return maxi(
		1,
		raw_damage
		- target.effective_defense()
		- int(target.balance_effects.get("defense_bonus", 0))
		- cover_bonus,
	)


## The scheduler-driven turn loop. FR-102a / amendment §2.1: this is the ONLY place
## CombatController decides whose turn it is; everything else asks `active_actor()` or
## reacts to `turn_started` / `enemy_turn_started` events. Loops (rather than recurses)
## through however many actors resolve automatically — every living enemy that becomes
## ready — until it is a living ally's turn or the battle ends, so presentation always
## gets a clean, ordered event stream with a bounded call stack.
func _drive_scheduler() -> void:
	while state != State.FINISHED:
		_check_holds()
		if not _has_living(allies):
			_finish(ResultState.DEFEAT, &"defeat")
			return
		if not _has_living(enemies):
			_finish(ResultState.VICTORY, &"slain")
			return
		state = State.ROUND_START
		var result := scheduler.advance()
		if not bool(result.get("allowed", false)):
			# The only way advance() refuses here is &"no_participants" — everyone alive was
			# already excluded above — or an internal scheduler defect. Either way the battle
			# cannot continue; side with the party rather than hang.
			_finish(ResultState.DEFEAT, &"defeat")
			return
		_translate_scheduler_extras(result)
		# A round-end fire checkpoint can empty a side before anyone's turn begins.
		if not _has_living(allies):
			_finish(ResultState.DEFEAT, &"defeat")
			return
		if not _has_living(enemies):
			_finish(ResultState.VICTORY, &"slain")
			return
		var upcoming: BattleActor = result.get("actor")
		var is_continuation := upcoming == _last_turn_actor and int(result.get("ticks_elapsed", 0)) == 0
		# Entries due at "the start of X's next scheduled turn" fire only when X's turn truly
		# begins — an AP continuation of the turn that queued them is not a new turn.
		_fire_due_deferred(null if is_continuation else upcoming)
		if state == State.FINISHED:
			return
		var actor: BattleActor = result.get("actor")
		if actor == null:
			_finish(ResultState.DEFEAT, &"defeat")
			return
		if not actor.is_alive():
			# A checkpoint effect (burn tick, filed Firebreak) killed the combatant the scheduler
			# just seated. Forfeit that seat and let the next advance() pick a living one; the
			# side checks at the top of the loop decide whether the battle is over.
			scheduler.force_advance(actor)
			_last_turn_actor = null
			continue

		var turn_payload := {
			"charge": result.get("charge", 0),
			"ticks_elapsed": result.get("ticks_elapsed", 0),
			"measures_crossed": result.get("measures_crossed", 0),
		}
		if not is_continuation:
			_pay_hold_upkeep(actor)
			if not bool(scheduler.can_act(actor).get("allowed", false)):
				_last_turn_actor = actor
				continue

		if actor.side == &"ally":
			state = State.ALLY_TURN
			if not is_continuation:
				_emit_event(&"turn_started", actor, null, turn_payload)
				_class_resource_of(actor).on_turn_start()
			_last_turn_actor = actor
			_last_side = &"ally"
			active_ally_index = allies.find(actor)
			return

		state = State.ENEMY_TURN
		if _last_side != &"enemy":
			_emit_event(&"enemy_turn_started", actor, null, turn_payload)
		if actor != _last_turn_actor or int(result.get("ticks_elapsed", 0)) != 0:
			_class_resource_of(actor).on_turn_start()
		_last_turn_actor = actor
		_last_side = &"enemy"
		_resolve_enemy_actor(actor)
		# Loop continues: the next scheduler.advance() picks whoever is ready next, ally or
		# enemy, without this function recursing into itself.


## Translates the scheduler's optional round bookkeeping (`round_started` / `refreshed` /
## `round_ended`, set only by the AP scheduler) into the legacy events, and fires the CT-
## native `measure_started` beat when the scheduler crossed a measure with no round
## bookkeeping attached (i.e. the CT scheduler is live). This is the one place the two
## event vocabularies fork, and it forks on DATA the scheduler returned, never on
## `rules.use_charge_time` — CombatController does not know which scheduler is active.
func _translate_scheduler_extras(result: Dictionary) -> void:
	_check_holds()
	# A single advance() call can carry BOTH keys at once — the AP scheduler closes the old
	# round and opens the new one in one step when the last actor's turn passes. `round_ended`
	# must be emitted (and the balance lock checked against the round that JUST ended, not the
	# one about to open) first, matching the original `_resolve_enemy_turn()` order — end the
	# round, release the lock if it was due, THEN `_begin_round()` opens the next one — or the
	# lock would release one round early and presentation would see "round 2 started" before
	# "round 1 ended".
	# #209: weather shares the scheduler's clock — one Weather.tick() per CT tick the
	# scheduler just advanced, so the 16-tick measure cadences can never drift apart.
	_advance_weather(int(result.get("ticks_elapsed", 0)))
	if bool(result.get("round_ended", false)):
		var ended_round := int(result.get("ended_round", round_number))
		_emit_event(&"round_ended", null, null, {"round": ended_round})
		_release_balance_lock_if_due(ended_round)
		_tick_actor_aftertones()
		_fire_checkpoint(round_number)
		_material_checkpoint(round_number)
		_light_checkpoint(round_number)
	round_number = scheduler.measure_index() + 1
	_expire_temporary_effects()
	if bool(result.get("round_started", false)):
		_emit_event(&"round_started", null, null, {"round": int(result.get("round", round_number))})
		for row: Variant in result.get("refreshed", []):
			if row is Dictionary:
				var refreshed_actor := row.get("actor") as BattleActor
				if refreshed_actor != null:
					refreshed_actor.unused_ap_defense_bonus = 0
				_emit_event(
					&"ap_refreshed",
					row.get("actor"),
					null,
					{"current_ap": row.get("current_ap", 0), "maximum_ap": row.get("maximum_ap", 0)},
				)
	if not result.has("round_started") and not result.has("round_ended"):
		# AP emits round_ended; CT emits measures_crossed. These branches are exclusive because
		# each scheduler owns one cadence, so Aftertones tick exactly once per cadence boundary.
		var crossed := int(result.get("measures_crossed", 0))
		if crossed > 0:
			_emit_event(&"measure_started", null, null, {"measure": scheduler.measure_index()})
			_tick_actor_aftertones()
			_release_balance_lock_if_due(round_number)
			# Hazard events during the measure that just closed were tracked under the previous
			# round number; the checkpoint settles against that same number.
			_fire_checkpoint(round_number - 1)
			_material_checkpoint(round_number - 1)
			_light_checkpoint(round_number - 1)


## Resolves exactly one enemy's turn. The scheduler — not a `for foe in enemies` loop — decides
## which enemy this is and when. Grid-capable battlefields plan a legal move before committing;
## attack affordability is checked only after a target is in range.
func _resolve_enemy_actor(actor: BattleActor) -> void:
	var enemy_action := action_by_id(&"enemy-strike")
	var target := _first_living(allies)
	if target == null:
		return
	var targeting := battlefield.target_query(actor, target, enemy_action.target_profile)
	var has_cells := bool(battlefield.capabilities().get("cells", false))
	if not bool(targeting.get("allowed", false)) and has_cells:
		var destination := _best_enemy_position(actor, target)
		if destination != &"":
			_resolve_enemy_move(actor, target, destination)
			return
		_emit_event(
			&"action_refused", actor, target, {"action_id": enemy_action.id, "reason": targeting}
		)
		_force_pass(actor)
		return
	var aim_options := choose_enemy_aim(actor, target, enemy_action)
	var resolution_gate := _query_attack_resolution(actor, target, enemy_action, aim_options)
	if not bool(resolution_gate.get("allowed", false)):
		_emit_event(
			&"action_refused", actor, target, {"action_id": enemy_action.id, "reason": resolution_gate}
		)
		_force_pass(actor)
		return
	var committed_action := CalledShot.priced_action(
		enemy_action, StringName(str(aim_options.get("aim_location", "")))
	)
	var commit_result := scheduler.commit(actor, committed_action)
	if not bool(commit_result.get("allowed", false)):
		_emit_event(
			&"action_refused", actor, target, {"action_id": enemy_action.id, "reason": commit_result}
		)
		_force_pass(actor)
		return
	_face_toward(actor, target)
	var apply_options := aim_options.duplicate(true)
	apply_options["_resolution"] = resolution_gate["resolution"]
	apply_options["_resolution_context"] = resolution_gate["context"]
	var outcome := _apply_action(actor, target, committed_action, apply_options)
	_finish_hold_turn(actor)
	outcome["action_id"] = enemy_action.id
	outcome["verb"] = enemy_action.verb
	if aim_options.has("aim_location"):
		outcome["aim_location"] = str(aim_options["aim_location"])
	outcome["ap_cost"] = committed_action.ap_cost
	outcome["ct_spent"] = int(commit_result.get("ct_spent", 0))
	outcome["ap_remaining"] = actor.action_points
	outcome["charge_remaining"] = int(commit_result.get("charge", 0))
	_emit_event(&"action_resolved", actor, target, outcome)
	scheduler.release(actor)
	_change_balance(actor.balance_affinity * actor.balance_pressure, actor)


## PROVISIONAL (called-shots task 12): how many HP of expected damage one full injury is
## worth to the AI. A balance-facilitator number, not a ratified rule.
const PROVISIONAL_AI_INJURY_VALUE := 6


## Called-shots task 12: picks the aim the enemy's action should use, or `{}` for an ordinary
## attack. Bounded to the action's authored profiles, legal through the same `_query_aim` and
## scheduler gates the player faces, and scored from FORECAST data only (hit chance, damage
## on hit, injury chance): the committed roll is never consulted. Observable state only:
## authored anatomy exposure, cover, visibility, and the target's existing injuries.
func choose_enemy_aim(actor: BattleActor, target: BattleActor, action: CombatAction) -> Dictionary:
	if actor == null or target == null or action == null or action.aim_profiles.is_empty():
		return {}
	var best := {}
	var best_value := _enemy_attack_value(actor, target, action, {})
	if best_value < 0.0:
		return {}
	var locations: Array = action.aim_profiles.keys()
	locations.sort()
	for location: Variant in locations:
		var location_id := StringName(str(location))
		# An already-injured part has nothing more to lose: the aim would pay for nothing.
		if target.injuries.has(str(location_id)):
			continue
		var legality := _query_aim(actor, target, action, location_id)
		if not bool(legality.get("allowed", false)):
			continue
		if not _enemy_can_pay(actor, CalledShot.priced_action(action, location_id)):
			continue
		var options := {"aim_location": str(location_id)}
		# A shot held up to the minimum chance by the clamp is a coin toss the surcharge
		# cannot improve; the floor is never a reason to pay more.
		var breakdown := Resolution.accuracy_breakdown(forecast_context(actor, target, action, options))
		if int(breakdown.get("clamp_adjustment", 0)) > 0:
			continue
		var value := _enemy_attack_value(actor, target, action, options)
		if value > best_value:
			best_value = value
			best = options
	return best


## Cost-only affordability for a candidate, independent of whose turn it is: the AP
## scheduler quotes the priced action against the actor's points; CT legality of the
## surcharge was already settled by `_query_aim` against the action cost limit.
func _enemy_can_pay(actor: BattleActor, priced: CombatAction) -> bool:
	if scheduler != null and scheduler.has_method("quote"):
		return int(scheduler.call("quote", actor, priced)) <= actor.action_points
	return true


## Expected value of one attack from its forecast: hit% × damage on hit, plus the injury's
## overall chance weighted by PROVISIONAL_AI_INJURY_VALUE when the quoted damage can reach
## the authored threshold. Returns -1 when the attack cannot be forecast at all.
func _enemy_attack_value(actor: BattleActor, target: BattleActor, action: CombatAction, options: Dictionary) -> float:
	var context := forecast_context(actor, target, action, options)
	if context.is_empty():
		return -1.0
	var breakdown := Resolution.accuracy_breakdown(context)
	var hit_chance := float(breakdown.get("effective_hit_chance", breakdown.get("hit_chance", 100))) / 100.0
	var damage_on_hit := _forecast_damage_on_hit(context, target)
	var value := hit_chance * float(damage_on_hit)
	var injury: Dictionary = context.get("injury", {})
	if not injury.is_empty() and damage_on_hit >= int(injury.get("min_damage", 1)):
		var overall := hit_chance * float(int(injury.get("chance_on_hit", 0))) / 100.0
		value += overall * float(PROVISIONAL_AI_INJURY_VALUE)
	return value


## Grid-capable enemies spend movement on height and rear access before closing directly. The
## capability check keeps zone combat on its legacy attack-or-pass behavior and avoids a concrete
## GridBattlefieldModel dependency at this consumer seam.
func _best_enemy_position(actor: BattleActor, target: BattleActor) -> StringName:
	var capabilities: Dictionary = battlefield.capabilities()
	if not bool(capabilities.get("cells", false)):
		return &""
	var target_position: Dictionary = battlefield.describe_position(battlefield.position_of(target))
	if not target_position.has("cell"):
		return &""
	var budget := int(
		float(rules.maximum_action_ct_cost if rules != null else 0)
		/ CombatInjury.move_cost_multiplier(actor)
	)
	var candidates: Array[StringName] = battlefield.reachable_positions(actor, budget)
	var best := &""
	var best_score := -2147483648
	for candidate in candidates:
		var described: Dictionary = battlefield.describe_position(candidate)
		if not described.has("cell"):
			continue
		var score := _enemy_position_score(candidate, described, target_position, target)
		# Tie-break through String: StringName's `<` orders by interning pointer,
		# which varies with process history — the same tie resolved differently
		# in two tests of one run before this was made genuinely lexical.
		if score > best_score \
				or (score == best_score and (best == &"" or String(candidate) < String(best))):
			best = candidate
			best_score = score
	return best


func _enemy_position_score(
	candidate_position: StringName,
	candidate: Dictionary,
	target_position: Dictionary,
	target: BattleActor,
) -> int:
	var candidate_cell: Vector2i = candidate.get("cell", Vector2i.ZERO)
	var target_cell: Vector2i = target_position.get("cell", Vector2i.ZERO)
	var delta := candidate_cell - target_cell
	var distance := maxi(absi(delta.x), absi(delta.y))
	var score := int(candidate.get("elevation", 0)) * 1000 - distance
	if distance <= 1:
		score += 500
	if battlefield.cover_bonus_at(target, candidate_position) > 0:
		score += _ENEMY_COVER_POSITION_SCORE
	var attack_direction := _facing_for_delta(delta)
	if attack_direction != &"" and attack_direction == _opposite_facing(battlefield.facing_of(target)):
		score += 1000
	return score


func _resolve_enemy_move(actor: BattleActor, target: BattleActor, destination: StringName) -> void:
	var path: Dictionary = battlefield.path_query(actor, destination)
	if not bool(path.get("allowed", false)):
		_force_pass(actor)
		return
	var move_action := CombatAction.new()
	move_action.id = &"__enemy_grid_move__"
	move_action.display_name = "Move"
	move_action.kind = CombatAction.Kind.MOVE
	move_action.verb = CombatAction.Verb.MOVE
	move_action.target_profile = &"self"
	move_action.destination = destination
	move_action.ap_cost = 1
	move_action.ct_cost = _injured_move_ct(
		actor, int(path.get("ct_cost", rules.move_ct_cost if rules != null else 0))
	)
	var commit_result := scheduler.commit(actor, move_action)
	if not bool(commit_result.get("allowed", false)):
		_force_pass(actor)
		return
	var outcome := _apply_action(actor, target, move_action)
	_finish_hold_turn(actor)
	_check_holds()
	outcome["action_id"] = move_action.id
	outcome["verb"] = move_action.verb
	outcome["ap_cost"] = move_action.ap_cost
	outcome["ct_spent"] = int(commit_result.get("ct_spent", 0))
	outcome["ap_remaining"] = actor.action_points
	outcome["charge_remaining"] = int(commit_result.get("charge", 0))
	_emit_event(&"action_resolved", actor, target, outcome)
	_face_toward(actor, target)
	scheduler.release(actor)


func _face_toward(actor: BattleActor, target: BattleActor) -> void:
	var capabilities: Dictionary = battlefield.capabilities()
	if not bool(capabilities.get("facing", false)) or not bool(capabilities.get("cells", false)):
		return
	var actor_position: Dictionary = battlefield.describe_position(battlefield.position_of(actor))
	var target_position: Dictionary = battlefield.describe_position(battlefield.position_of(target))
	if not actor_position.has("cell") or not target_position.has("cell"):
		return
	var actor_cell: Vector2i = actor_position.get("cell", Vector2i.ZERO)
	var target_cell: Vector2i = target_position.get("cell", Vector2i.ZERO)
	var facing := _facing_for_delta(target_cell - actor_cell)
	if facing != &"":
		battlefield.set_facing(actor, facing)


func _facing_for_delta(delta: Vector2i) -> StringName:
	if delta == Vector2i.ZERO:
		return &""
	var order: Array[StringName] = [&"e", &"se", &"s", &"sw", &"w", &"nw", &"n", &"ne"]
	var angle := atan2(delta.y, delta.x)
	var index := int(round(angle / (PI / 4.0)))
	index = ((index % order.size()) + order.size()) % order.size()
	return order[index]


func _opposite_facing(facing: StringName) -> StringName:
	var order: Array[StringName] = [&"e", &"se", &"s", &"sw", &"w", &"nw", &"n", &"ne"]
	var index := order.find(facing)
	return &"" if index == -1 else order[(index + 4) % order.size()]


## An enemy that cannot afford its action or cannot reach a target still has to leave
## readiness — otherwise the scheduler would keep re-selecting it (AP: still "unacted
## this round"; CT: still at or above READY_AT) and the battle would hang. A zero-cost
## PASS action is the cleanest way to say "this turn happened and produced nothing"
## through the same commit()/release() pair every other action uses, so the scheduler's
## round/acted bookkeeping updates exactly as if a real action had resolved.
func _force_pass(actor: BattleActor) -> void:
	_finish_hold_turn(actor)
	var result := scheduler.commit(actor, _pass_action())
	if bool(result.get("allowed", false)):
		scheduler.release(actor)
	else:
		# Two bounded attempts: a normal yield preserves scheduler-specific wait semantics. If
		# that is refused by the same non-resource gate (for example an interrupt), consume the
		# readiness with zero refund. Never return with this actor still selectable forever.
		var yielded := scheduler.yield_turn(actor)
		if not bool(yielded.get("allowed", false)):
			var forced := scheduler.force_advance(actor)
			if not bool(forced.get("allowed", false)):
				# Contract violation: force_advance may only refuse not_participating,
				# and a stuck-selectable actor is exactly the hang this path prevents.
				push_error("CombatController._force_pass(): force_advance refused for %s (%s)." % [
					actor.combat_id, str(forced.get("blocked_by", ""))])


func _pass_action() -> CombatAction:
	var action := CombatAction.new()
	action.id = &"__scheduler_pass__"
	action.kind = CombatAction.Kind.PASS
	action.verb = CombatAction.Verb.DEFEND
	action.ap_cost = 0
	action.ct_cost = 0
	return action


## Whether `actor` can pay for `action` specifically, as opposed to `scheduler.can_act()`
## which only answers "is it structurally your turn". The AP scheduler exposes this via
## `can_afford()` (not part of the base `TurnScheduler` contract, since only a resource-
## metered model needs it); the CT scheduler has no equivalent because every authored
## action costs at most `maximum_action_ct_cost` (60) against a 100 threshold, so being
## ready (`can_act()`) already implies being able to afford any authored action. This is
## checked via `has_method()` rather than a concrete-type check so this file still never
## names `ApRoundScheduler` or `ChargeTimeScheduler`.
func _can_afford(actor: BattleActor, action: CombatAction) -> Dictionary:
	if scheduler.has_method("can_afford"):
		return scheduler.call("can_afford", actor, action)
	return scheduler.can_act(actor)


func _move_destination(action: CombatAction, options: Dictionary) -> StringName:
	var authored: Variant = options.get("destination", action.destination)
	return StringName(str(authored))


func _query_aim(
	actor: BattleActor, target: BattleActor, action: CombatAction, location: StringName,
) -> Dictionary:
	var accuracy_enabled := (
		actor != null and target != null
		and not _positional_resolution_context(actor, target).is_empty()
	)
	var cover: Dictionary = (
		battlefield.location_cover(actor, target) if actor != null and target != null else {}
	)
	return CalledShot.query(
		action, target, location, accuracy_enabled, rules.maximum_action_ct_cost, cover
	)


## AP prices the same weighted path the enemy/CT move path quotes. The authored move
## action's AP cost is the per-cell rate; elevation can raise the number of cost units.
## A leg injury raises the path price before either scheduler reads it, so AP units and CT
## both grow and NPCs pay the same rule (`_resolve_enemy_move`).
func _priced_move_action(
	action: CombatAction, movement: Dictionary, options: Dictionary, actor: BattleActor = null
) -> CombatAction:
	if action == null or action.kind != CombatAction.Kind.MOVE:
		return action
	var priced := action.duplicate(true) as CombatAction
	priced.destination = _move_destination(action, options)
	if movement.has("ct_cost"):
		var base_move_cost := maxi(1, rules.move_ct_cost if rules != null else 1)
		var path_ct := _injured_move_ct(actor, int(movement.get("ct_cost", base_move_cost)))
		var cost_units := maxi(1, ceili(float(path_ct) / float(base_move_cost)))
		priced.ap_cost = maxi(1, action.ap_cost) * cost_units
		priced.ct_cost = path_ct
	return priced


func _injured_move_ct(actor: BattleActor, path_ct: int) -> int:
	if actor == null:
		return path_ct
	return maxi(1, ceili(float(path_ct) * CombatInjury.move_cost_multiplier(actor)))


func _apply_action(
	actor: BattleActor, target: BattleActor, action: CombatAction, options: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {"message": "%s uses %s." % [actor.display_name, action.display_name]}
	_spend_blindside(actor, action)
	if options.has("_object"):
		result.merge(_apply_object_action(actor, action, options), true)
		return result
	if action.targets_cells():
		result.merge(_apply_cell_action(actor, action, options), true)
		if action.balance_shift != 0:
			_change_balance(action.balance_shift, actor)
		return result
	match action.kind:
		CombatAction.Kind.ATTACK:
			result.merge(_resolve_attack(actor, target, action, options), true)
			if not action.effect_id.is_empty():
				result.merge(_apply_effect_after_attack(actor, target, action, result), true)
		CombatAction.Kind.CAST:
			result.merge(_resolve_attack(actor, target, action, options), true)
		CombatAction.Kind.DEFINING_STRIKE:
			result.merge(_resolve_defining_strike(actor, target, action, options), true)
		CombatAction.Kind.GUARD:
			actor.guarding = true
			result["message"] = "%s guards; incoming damage is reduced." % actor.display_name
		CombatAction.Kind.STABILIZE:
			actor.guarding = true
			_shift_toward_center(action.center_pull, actor)
			result["message"] = "%s steadies the field toward equilibrium." % actor.display_name
		CombatAction.Kind.MOVE:
			var movement := battlefield.move(actor, action.destination)
			result.merge(movement, true)
			result["path_cells"] = _describe_path_cells(result.get("path", []))
			result["message"] = "%s moves to %s." % [actor.display_name, action.destination]
			if bool(movement.get("allowed", false)):
				result["hazard"] = _hazard_on_path(actor, result["path_cells"])
				# Threads read this: a Daylight contract fires on a MOVE ending inside its field.
				var landed: Variant = _actor_cell(actor)
				result["ended_in_light"] = (
					int(light.field_at(landed as Vector2i).get("id", 0)) if landed is Vector2i else 0
				)
		CombatAction.Kind.RESOLUTION:
			result["outcome_id"] = action.outcome_id
			result["message"] = "%s chooses %s." % [actor.display_name, action.display_name]
		CombatAction.Kind.PASS:
			pass
	if action.kind != CombatAction.Kind.RESOLUTION:
		if action.balance_shift != 0:
			_change_balance(action.balance_shift, actor)
		elif action.kind != CombatAction.Kind.STABILIZE and action.center_pull > 0:
			_shift_toward_center(action.center_pull, actor)
	return result


## Converts model-owned opaque handles at the controller boundary. Presentation receives
## renderable cells without learning GridBattlefieldModel's handle serialization.
func _describe_path_cells(value: Variant) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if battlefield == null or value is not Array:
		return cells
	for handle_value: Variant in value as Array:
		var described: Dictionary = battlefield.describe_position(StringName(str(handle_value)))
		var cell_value: Variant = described.get("cell")
		if cell_value is not Vector2i:
			return []
		cells.append(cell_value)
	return cells


func _query_defining_strike(target: BattleActor, weakness_id: StringName) -> Dictionary:
	if target == null or target.archetype_id.is_empty():
		return _blocked(
			&"archetype", "This enemy has no authored Defining Strike table.", {"type": &"archetype"}
		)
	if weakness_id.is_empty():
		return _blocked(
			&"weakness",
			"Choose a discovered weakness to name.",
			{"type": &"discovered_weakness", "available": target.discovered_weakness_ids.size()},
		)
	var weakness := CombatIdentityCatalog.weakness(target.archetype_id, weakness_id)
	if weakness.is_empty():
		return _blocked(
			&"weakness", "Unknown weakness for this archetype.", {"type": &"authored_weakness"}
		)
	if weakness_id not in target.discovered_weakness_ids:
		return _blocked(
			&"weakness",
			"That weakness has not been discovered.",
			{"type": &"discovered_weakness", "weakness_id": weakness_id},
		)
	return _allowed({"weakness": weakness})


func _query_cast(
	actor: BattleActor, target: BattleActor, action: CombatAction, options: Dictionary
) -> Dictionary:
	var requested := str(options.get("ability_id", ""))
	if requested.is_empty():
		return _blocked(
			&"ability",
			"Select an action ability from this unit's loadout to cast.",
			{"type": &"ability_selection"},
		)
	var ability := _cast_ability(actor, options)
	if ability == null:
		return _blocked(
			&"ability",
			"Equip %s in this unit's action loadout before casting it." % requested,
			{"type": &"unit_loadout", "ability_id": requested},
		)
	var context := forecast_context(actor, target, action, options)
	var terms := _positional_terms(actor, target)
	var resolution := _finalize_resolution_damage(
		Resolution.resolve(context), target,
		int((context.get("positioning", {}) as Dictionary).get("cover_bonus", terms["cover_bonus"])),
		int(context.get("defense_bypass", 0)),
	)
	if not bool(resolution.get("allowed", false)):
		return resolution
	var soul_cost := 0.0
	for write: Dictionary in resolution.get("writes", []):
		if StringName(str(write.get("kind", ""))) == &"soul_meter":
			soul_cost = -float(write.get("delta", 0.0))
	return _allowed({
		"ability_id": ability.id,
		"breath_cost": ability.breath_cost,
		"soul_cost": soul_cost,
		"context": context,
		"resolution": resolution,
	})


func _query_attack_resolution(
	actor: BattleActor, target: BattleActor, action: CombatAction, options: Dictionary
) -> Dictionary:
	var context := forecast_context(actor, target, action, options)
	var resolution := _finalize_resolution_damage(
		Resolution.resolve(context), target,
		int((context.get("positioning", {}) as Dictionary).get("cover_bonus", 0)),
		int(context.get("defense_bypass", 0)),
	)
	if not bool(resolution.get("allowed", false)):
		return resolution
	return _allowed({"context": context, "resolution": resolution})


func _cast_ability(actor: BattleActor, options: Dictionary) -> AbilityDefinition:
	var requested := str(options.get("ability_id", ""))
	if requested.is_empty() or actor == null or _tactical_tables == null:
		return null
	for ability: AbilityDefinition in _tactical_tables.abilities_for_unit(
		_actor_unit_id(actor), AbilityDefinition.SLOT_ACTION
	):
		if ability.id == requested:
			return _abilities.get(requested) as AbilityDefinition
	return null


func _actor_unit_id(actor: BattleActor) -> String:
	if actor == null:
		return ""
	if actor.source_member != null:
		return actor.source_member.id
	return String(actor.archetype_id)


func _fizzle_context(actor: BattleActor, options: Dictionary) -> Dictionary:
	var raw: Variant = options.get("fizzle", {})
	var context: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
	if not context.has("harmonic_accord") and not context.has("agreement_integrity"):
		context["harmonic_accord"] = agreement_integrity
		context["agreement_integrity"] = agreement_integrity # alias wave, #329
	if not context.has("pitch"):
		context["pitch"] = actor.attribute_value(&"pitch")
	if actor.source_member != null and not context.has("patron"):
		context["patron"] = actor.source_member.patron
	return context


func _resolved_attack(
	actor: BattleActor,
	target: BattleActor,
	action: CombatAction,
	options: Dictionary,
) -> Dictionary:
	if options.has("_resolution"):
		var cached := (options["_resolution"] as Dictionary).duplicate(true)
		for write: Dictionary in cached.get("writes", []):
			if (
			StringName(str(write.get("kind", ""))) == &"hp"
				and String(write.get("target_id", "")) == String(target.combat_id)
			):
				return cached
	var context := forecast_context(actor, target, action, options)
	return _finalize_resolution_damage(
		Resolution.resolve(context), target,
		int((context.get("positioning", {}) as Dictionary).get("cover_bonus", 0)),
		int(context.get("defense_bypass", 0)),
	)


func _finalize_resolution_damage(
	resolution: Dictionary, target: BattleActor, cover_bonus: int, defense_bypass: int = 0
) -> Dictionary:
	if not bool(resolution.get("allowed", false)):
		return resolution
	var finalized := resolution.duplicate(true)
	var damage := 0
	var has_damage := bool(finalized.get("direct_damage_enabled", true)) or int(finalized.get("damage", 0)) > 0
	if has_damage and bool(finalized.get("hit", true)) and not bool(finalized.get("fizzled", false)):
		damage = maxi(
			1,
			int(finalized.get("damage", 0))
			- maxi(target.effective_defense() - maxi(defense_bypass, 0), 0)
			- int(target.balance_effects.get("defense_bonus", 0))
			- cover_bonus,
		)
	finalized["damage"] = damage
	var writes: Array = finalized.get("writes", [])
	for write: Dictionary in writes:
		if StringName(str(write.get("kind", ""))) != &"hp":
			continue
		write["before"] = target.hp
		write["after"] = maxi(target.hp - damage, 0)
		write["delta"] = int(write["after"]) - target.hp
	if finalized.has("injury"):
		# Injury eligibility is decided HERE, after hit and mitigation: a miss or a fizzle never
		# injures, and a hit below the authored damage threshold does not either.
		var injury: Dictionary = finalized["injury"]
		var eligible := (
			bool(finalized.get("hit", true)) and not bool(finalized.get("fizzled", false))
			and damage >= int(injury.get("min_damage", 1))
		)
		injury["eligible"] = eligible
		injury["applies"] = eligible and bool(injury.get("rolled", false))
		if bool(injury["applies"]):
			writes.append({
				"kind": "injury", "target_id": String(target.combat_id),
				"injury": injury.duplicate(true),
			})
		finalized["writes"] = writes
	var action_log: Dictionary = finalized.get("action_log", {})
	if not action_log.is_empty():
		action_log["deltas"] = writes.duplicate(true)
		finalized["action_log"] = action_log
	return finalized


func _apply_resolution_writes(
	actor: BattleActor,
	target: BattleActor,
	resolution: Dictionary,
	apply_tile_writes: bool = true,
	cause: StringName = &"attack",
) -> void:
	for write: Dictionary in resolution.get("writes", []):
		match StringName(write.get("kind", "")):
			&"hp":
				var hp_before := target.hp
				target.hp = int(write.get("after", target.hp))
				# #223 class-resource hooks fire from the one place HP actually changes.
				var lost := hp_before - target.hp
				if lost > 0:
					_class_resource_of(target).on_damage_taken(lost, actor.combat_id)
				if hp_before > 0 and target.hp <= 0:
					_class_resource_of(actor).on_kill(target.combat_id, cause)
					_notify_combatant_fell(target.combat_id)
			&"dot":
				# Seam v2: damage-over-time is an HP loss whose kill cause is &"dot" regardless of
				# the action that queued it (Husk-bearer Hunger keys refunds on that cause).
				var dot_before := target.hp
				target.hp = int(write.get("after", target.hp))
				var dot_lost := dot_before - target.hp
				if dot_lost > 0:
					_class_resource_of(target).on_damage_taken(dot_lost, actor.combat_id)
				if dot_before > 0 and target.hp <= 0:
					_class_resource_of(actor).on_kill(target.combat_id, &"dot")
					_notify_combatant_fell(target.combat_id)
			&"injury":
				var applied := CombatInjury.apply(
					target, write.get("injury", {}),
					"%s|%d|%s|%s" % [
						str(resolution.get("battle_id", "")), int(resolution.get("tick", 0)),
						String(actor.combat_id), str(resolution.get("ability_id", "")),
					],
					int(resolution.get("tick", 0)),
				)
				if bool(applied.get("applied", false)):
					_emit_event(&"injury_applied", actor, target, applied)
					_interrupt_voice(target)
			&"breath":
				actor.breath = int(write.get("after", actor.breath))
			&"aftertones":
				var aftertone_actor := _actor_by_id(str(write.get("target_id", actor.combat_id)))
				if aftertone_actor != null:
					var removed := maxi(0, aftertone_actor.aftertones.size() - _aftertone_writes(write, aftertone_actor.aftertones).size())
					aftertone_actor.aftertones = _aftertone_writes(write, aftertone_actor.aftertones)
					spent_aftertones += removed
			&"tempo":
				var tempo_actor := _actor_by_id(str(write.get("target_id", actor.combat_id)))
				if tempo_actor != null:
					tempo_actor.tempo = int(write.get("after", tempo_actor.tempo))
			&"aftertone_spent":
				spent_aftertones += int(write.get("count", 1))
				if write.has("consumed"):
					_check_holds("consumed")
					_emit_event(&"aftertone_consumed", actor, target, {"aftertone": (write["consumed"] as Dictionary).duplicate(true)})
			&"last_cast_element":
				var cast_actor := _actor_by_id(str(write.get("target_id", actor.combat_id)))
				if cast_actor != null:
					cast_actor.last_cast_element = StringName(str(write.get("after", "")))
			&"triad_effect":
				_apply_triad_effect(actor, target, write)
			&"soul_meter":
				# Owner ruling (docs/game-identity.md ruling 3, reaffirmed 2026-09-08 on
				# #286): the Soul Gauge rises ONLY through an act of Agreement, which is a
				# tagged quest outcome. Combat may spend it and may never return it, so this
				# write is clamped to a decrease rather than trusted. `Resolution` only ever
				# emits a spend here; the clamp is the guard, not the mechanism.
				_set_soul_meter(minf(float(write.get("after", _soul_meter())), _soul_meter()))
			&"tile_state":
				if not apply_tile_writes:
					continue
				var cell := Vector2i(int(write.get("x", 0)), int(write.get("y", 0)))
				var live_tile := tile_state_at(cell)
				var after: Dictionary = write.get("after", {})
				if live_tile != null and not after.is_empty():
					live_tile.charge_element_id = StringName(after.get("charge_element_id", ""))
					live_tile.charge_level = int(after.get("charge_level", 0))
					live_tile.height_delta = int(after.get("height_delta", live_tile.height_delta))
					live_tile.hush = bool(after.get("hush", live_tile.hush))
			&"burning":
				_apply_burning(target, StringName(str(write.get("source_id", actor.combat_id))))
			&"douse":
				_apply_douse(actor, target)
			&"fire_line":
				_create_fire_line(
					StringName(str(write.get("owner_id", actor.combat_id))),
					FireField.cells_from_data(write.get("cells", [])),
					String(write.get("label", "firebreak")),
				)
			&"crown_release":
				_release_crown(actor, write)
			&"exposed":
				_apply_exposed(
					target, StringName(str(write.get("source_id", actor.combat_id))),
					int(write.get("checkpoints", LightField.EXPOSED_CHECKPOINTS)),
				)
			&"veiled":
				_apply_veiled(target, StringName(str(write.get("source_id", actor.combat_id))))
			&"reveal_signature":
				_reveal_signature(actor, target)
			&"lit":
				_apply_lit(
					target, StringName(str(write.get("source_id", actor.combat_id))),
					int(write.get("field_id", 0)), int(write.get("checkpoints", LightField.LIT_CHECKPOINTS)),
				)
	_check_holds()


func _notify_combatant_fell(target_id: StringName) -> void:
	_check_holds()
	for observer: BattleActor in allies + enemies:
		_class_resource_of(observer).on_combatant_fell(target_id)


func _game_state() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("GameState")


func _soul_meter() -> float:
	var game_state := _game_state()
	return float(game_state.get("soul_meter")) if game_state != null else 0.0


func _set_soul_meter(value: float) -> void:
	var game_state := _game_state()
	if game_state != null:
		game_state.call("set_soul_meter", value)


func _resolve_attack(
	actor: BattleActor,
	target: BattleActor,
	action: CombatAction,
	resolution_context: Dictionary = {},
) -> Dictionary:
	var total_damage := 0
	var positional_results: Array[Dictionary] = []
	var committed_resolution: Dictionary = {}
	var hit_targets := battlefield.targets_for(actor, target, action.aoe_shape)
	var pending_hits: Array[Dictionary] = []
	for hit_target: BattleActor in hit_targets:
		var terms := _positional_terms(actor, hit_target)
		var positional_context: Dictionary = terms["positional_context"]
		var resolved := _resolved_attack(actor, hit_target, action, resolution_context)
		if not bool(resolved.get("allowed", false)):
			return resolved
		pending_hits.append({
			"target": hit_target,
			"terms": terms,
			"positional_context": positional_context,
			"resolution": resolved,
		})
	# Resolve every target against the same pre-action resource/tile state. Applying afterward
	# keeps one Breath/Soul/tile cost idempotent while each target receives its own HP write.
	for pending: Dictionary in pending_hits:
		var hit_target := pending["target"] as BattleActor
		var terms: Dictionary = pending["terms"]
		var positional_context: Dictionary = pending["positional_context"]
		var resolved: Dictionary = pending["resolution"]
		# #215 promotes Resolution tile writes for CAST. Mundane attacks keep their ratified
		# non-mutating tile behavior; widening elemental residue to every attack is out of scope.
		_apply_resolution_writes(
			actor,
			hit_target,
			resolved,
			action.kind == CombatAction.Kind.CAST,
			_kill_cause_for(action),
		)
		if bool(resolved.get("fizzled", false)):
			_class_resource_of(actor).on_fizzle(resolved)
		committed_resolution = resolved
		var damage := int(resolved.get("damage", 0))
		total_damage += damage
		if not positional_context.is_empty():
			var modifiers := Resolution.positional_modifiers(
				int(positional_context["height_advantage_steps"]),
				StringName(positional_context["facing"]["id"]),
			)
			positional_results.append({
				"target_id": String(hit_target.combat_id),
				"facing": modifiers["facing"],
				"height_advantage_steps": modifiers["height_advantage_steps"],
				"hit_bonus": modifiers["hit_bonus"],
				"line_of_sight": (
					battlefield.line_of_sight(actor, hit_target)
					if action.target_profile == &"ranged" else _allowed()
				),
				"cover_bonus": int(terms["cover_bonus"]),
				"flank_bonus": int(terms["flank_bonus"]),
			})
	return {
		"damage": total_damage,
		"resolution": committed_resolution,
		"positioning": positional_results,
		"message": "%s uses %s for %d damage."
		% [actor.display_name, action.display_name, total_damage],
	}


## #209 forecast parity: the same Resolution context an actual strike will use — same
## power arithmetic, same tile/weather/facing terms — minus the to-hit roll (a forecast
## shows the on-hit number). Region D's only calculator is Resolution.resolve(); feeding
## it this context keeps forecast == resolution by construction.
func forecast_context(
	actor: BattleActor, target: BattleActor, action: CombatAction, options: Dictionary = {}
) -> Dictionary:
	if actor == null or target == null or action == null:
		return {}
	var terms := _positional_terms(actor, target)
	var positional_context: Dictionary = terms["positional_context"]
	var flank_bonus := int(terms["flank_bonus"])
	var cover_bonus := int(terms["cover_bonus"])
	if action.effect_id == EFFECT_OPEN_SEAM and _bite_applies(actor, target):
		# Blindside Bite: a Blinded target is treated as flanked whatever its true facing.
		if positional_context.is_empty():
			flank_bonus = rules.flank_power_bonus if rules != null else flank_bonus
		else:
			positional_context = positional_context.duplicate(true)
			positional_context["facing"] = {"id": &"side"}
	var line_of_sight := (
		battlefield.line_of_sight(actor, target)
		if action.target_profile == &"ranged" else _allowed()
	)
	var cast_ability: AbilityDefinition = (
		_cast_ability(actor, options) if action.kind == CombatAction.Kind.CAST else null
	)
	var element_id := cast_ability.element_id if cast_ability != null else action.element_id
	if String(element_id).is_empty():
		element_id = _UNAUTHORED_ELEMENT_ID
	var power := cast_ability.power if cast_ability != null else (
		actor.effective_attack()
		+ action.power_bonus
		+ flank_bonus
		+ int(actor.balance_effects.get("damage_bonus", 0))
	)
	if cast_ability == null and action.spell:
		# An authored spell card carries the card's flat creature power, like a loadout ability.
		power = action.power_bonus
	if options.has("power_override"):
		# A delayed release (Crown of Embers) resolves the card's authored power at fire time.
		power = int(options["power_override"])
	var ability_id := "attack"
	var battle_id := ""
	if cast_ability != null:
		ability_id = cast_ability.id
		battle_id = String(_encounter_id)
	elif action.kind == CombatAction.Kind.DEFINING_STRIKE:
		ability_id = str(options.get("ability_id", action.id))
		battle_id = str(options.get("battle_id", _encounter_id))
	elif action.spell or not action.effect_id.is_empty():
		# Authored cards key their deterministic rolls on their own id; plain attacks keep the
		# frozen legacy key so existing self-play rolls do not reshuffle.
		ability_id = String(action.id)
		battle_id = String(_encounter_id)
	var resolution_seed := int(options.get("seed", _sequence))
	var ability_context := {
		# Plain attacks retain the pre-#215 deterministic roll key. Casts use the selected
		# AbilityDefinition id so forecast and commit identify the same authored working.
		"id": ability_id,
		"element_id": element_id,
		"elements": cast_ability.elements.duplicate() if cast_ability != null else [element_id],
		"magnitude": cast_ability.magnitude if cast_ability != null else action.magnitude,
		"power": power,
	}
	if cast_ability != null:
		ability_context["is_spell"] = true
		ability_context["breath_cost"] = cast_ability.breath_cost
	elif action.spell:
		ability_context["is_spell"] = true
		ability_context["breath_cost"] = action.breath_cost
	if action.no_damage:
		ability_context["no_damage"] = true
	var target_height := 0
	var target_position: Dictionary = battlefield.describe_position(battlefield.position_of(target))
	if target_position.has("elevation"):
		target_height = int(target_position["elevation"])
	var context := {
		# Legacy calculate_damage() passed a wrapper with no top-level battle_id to
		# Resolution.resolve_action(), so plain attacks hashed the empty-string fallback.
		# That key is deliberately frozen for legacy roll parity: changing it reshuffles
		# every Gate T-1 self-play roll.
		# Casts and Defining Strikes retain their authored encounter identity.
		"battle_id": battle_id,
		"tick": resolution_seed,
		"seed": resolution_seed,
		"unit": {
			"id": String(actor.combat_id),
			"harmony": actor.attribute_value(&"harmony"),
			"attack_scale": actor.attack_scale,
			"alacrity": actor.attribute_value(&"alacrity"),
			"breath": actor.breath,
			"aftertones": actor.aftertones.duplicate(true),
			"tempo": actor.tempo,
			"concealed": concealed_until_round >= round_number and actor.side == concealed_side,
			"last_cast_element": actor.last_cast_element,
			"hit": bool(actor.defining_effects.get("hit", false)),
		},
		"ability": ability_context,
		"target": {
			"id": String(target.combat_id),
			"hp": target.hp,
			"element_id": target.element_id,
			"alacrity": target.attribute_value(&"alacrity"),
			"aftertones": target.aftertones.duplicate(true),
			"tempo": target.tempo,
			"height": target_height,
			"attunements": {},
		},
		"source_tile": positional_context.get("source_tile", {}),
		"target_tile": positional_context.get("target_tile", {}),
		"weather": positional_context.get("weather", weather.to_dict()),
		"facing": positional_context.get("facing", {}),
		"height_advantage_steps": int(positional_context.get("height_advantage_steps", 0)),
		"to_hit_enabled": not positional_context.is_empty(),
		"soul_meter": _soul_meter(),
		"fizzle": _fizzle_context(actor, options),
		"caster_context": (options.get("caster_context", {}) as Dictionary).duplicate(true),
		"positioning": {
			"line_of_sight": line_of_sight,
			"cover_bonus": cover_bonus,
			"flank_bonus": flank_bonus,
			"facing": positional_context.get("facing", {}),
			"height_advantage_steps": int(
				positional_context.get("height_advantage_steps", 0)
			),
		},
	}
	if options.has("weakness_id"):
		context["weakness_id"] = options["weakness_id"]
		context["weakness"] = (options.get("weakness", {}) as Dictionary).duplicate(true)
	if action.effect_payload.has("armor_bypass"):
		context["defense_bypass"] = int(action.effect_payload.get("armor_bypass", 0))
	# #223: the class resource's ONLY channel into resolution. Same call at forecast and commit,
	# so whatever it overrides is seen identically by both — no second calculator.
	var overrides: Dictionary = _class_resource_of(actor).on_cast_forecast(context.duplicate(true))
	if not overrides.is_empty():
		# Seam v2: key-level merge, so `{"unit": {"attack_scale": 1.25}}` keeps unit.id/edge/breath
		# and `{"fizzle": {"mastery": true}}` keeps fizzle.patron/pitch. A shallow merge replaced
		# the whole sub-dict (found by the B1–B5 review).
		deep_merge(context, overrides)
	# Seam v2 channel: ONE top-level `reveal` key. Dayspring (unit.reveal, A5) and ClassResource
	# reveal overrides both land here so Resolution and the panel read one shape.
	context["reveal"] = _is_revealed(actor) or _is_exposed_now(target) or bool(context.get("reveal", false))
	var resolved_positioning: Dictionary = context.get("positioning", {}) as Dictionary
	if bool(context["reveal"]):
		resolved_positioning["cover_bonus"] = 0
	context["positioning"] = resolved_positioning
	context["visibility"] = visibility_context(actor, target, action)
	var aim_location := StringName(str(options.get("aim_location", "")))
	var injury_modifiers: Array[Dictionary] = []
	if action.kind == CombatAction.Kind.ATTACK and not action.spell:
		injury_modifiers.append_array(CombatInjury.attack_accuracy_modifiers(actor))
	if action.requires_voice:
		injury_modifiers.append_array(CombatInjury.vocal_accuracy_modifiers(actor))
	# Sight-dependent shots: the physical-visibility applicability, or any called shot.
	var sight_dependent := (
		action.kind == CombatAction.Kind.ATTACK and not action.spell
		and (action.target_profile == &"ranged" or not aim_location.is_empty())
	)
	if sight_dependent:
		injury_modifiers.append_array(CombatInjury.sight_accuracy_modifiers(actor))
	if not injury_modifiers.is_empty():
		context["attacker_injury_modifiers"] = injury_modifiers
	if not aim_location.is_empty():
		context["aim"] = _query_aim(actor, target, action, aim_location)
		if bool(context["aim"].get("allowed", false)) and context["aim"].has("injury"):
			context["injury"] = (context["aim"]["injury"] as Dictionary).duplicate(true)
	return context


## Recursive key-wise merge: nested Dictionaries merge, everything else overwrites. Mutates
## `base`. Used for `on_cast_forecast` overrides at forecast AND commit (same function, same
## input, same result).
static func deep_merge(base: Dictionary, overrides: Dictionary) -> void:
	for key: Variant in overrides:
		var incoming: Variant = overrides[key]
		if incoming is Dictionary and base.get(key) is Dictionary:
			deep_merge(base[key] as Dictionary, incoming as Dictionary)
		else:
			base[key] = incoming.duplicate(true) if incoming is Dictionary or incoming is Array else incoming


## User-facing forecast: gate first (including ranged LOS), then run the same pure context and
## post-mitigation damage pipeline submit_action() uses. Refusals are returned unchanged so the
## blocked_by taxonomy is identical at forecast and commit.
func forecast_action(
	action: CombatAction, target: BattleActor = null, options: Dictionary = {}
) -> Dictionary:
	var gate := query_action(action, target, options)
	if not bool(gate.get("allowed", false)):
		return gate
	if not action.class_resource_action.is_empty():
		return _allowed({
			"action_id": action.id, "class_command": true,
			"ap_cost": action.ap_cost, "ct_cost": action.ct_cost, "soul_cost": action.soul_cost,
			"damage": 0, "description": action.description,
		})
	var actor := active_actor()
	if gate.has("object"):
		return _allowed({
			"action_id": action.id, "object": (gate["object"] as Dictionary).duplicate(true),
			"ap_cost": action.ap_cost, "ct_cost": action.ct_cost, "breath_cost": action.breath_cost,
			"damage": 0, "resolution": gate.get("resolution", {}),
			"fizzle_percent": float((gate.get("resolution", {}) as Dictionary).get("fizzle_percent", 0.0)),
			"description": action.description,
		})
	if action.kind == CombatAction.Kind.MOVE:
		return _allowed({
			"action_id": action.id,
			"ap_cost": int(gate.get("ap_cost", action.ap_cost)),
			"ct_cost": int(gate.get("ct_cost", action.ct_cost)),
			"path": (gate.get("path", []) as Array).duplicate(),
			"destination": _move_destination(action, options),
		})
	if action.targets_cells():
		var cell_resolution: Dictionary = gate.get("resolution", {})
		return _allowed({
			"action_id": action.id,
			"cell_working": true,
			"effect_id": action.effect_id,
			"ap_cost": action.ap_cost,
			"ct_cost": action.ct_cost,
			"damage": 0,
			"cells": FireField.cells_to_data(gate.get("cells", [] as Array[Vector2i])),
			"fizzle_percent": float(cell_resolution.get("fizzle_percent", 0.0)),
			"breath_cost": action.breath_cost,
			"soul_cost": float(gate.get("soul_cost", 0.0)),
			"description": action.description,
			"resolution": cell_resolution,
			"context": gate.get("context", {}),
		})
	if action.spell and action.kind == CombatAction.Kind.ATTACK:
		var card_resolution: Dictionary = gate["resolution"]
		return _allowed({
			"action_id": action.id,
			"ap_cost": action.ap_cost,
			"damage": int(card_resolution.get("damage", 0)),
			"damage_on_hit": _forecast_damage_on_hit(gate["context"], target),
			"fizzle_percent": float(card_resolution.get("fizzle_percent", 0.0)),
			"breath_cost": action.breath_cost,
			"soul_cost": float(gate.get("soul_cost", 0.0)),
			"resolution": card_resolution,
			"context": gate["context"],
			"positioning": (gate["context"].get("positioning", {}) as Dictionary).duplicate(true),
			"description": action.description,
		})
	if action.kind == CombatAction.Kind.CAST:
		var cast_resolution: Dictionary = gate["resolution"]
		return _allowed({
			"action_id": action.id,
			"ability_id": gate["ability_id"],
			"ap_cost": action.ap_cost,
			"damage": int(cast_resolution.get("damage", 0)),
			"damage_on_hit": _forecast_damage_on_hit(gate["context"], target),
			"fizzle_percent": float(cast_resolution.get("fizzle_percent", 0.0)),
			"breath_cost": int(gate.get("breath_cost", 0)),
			"soul_cost": float(gate.get("soul_cost", 0.0)),
			"resolution": cast_resolution,
			"context": gate["context"],
			"positioning": (gate["context"].get("positioning", {}) as Dictionary).duplicate(true),
		})
	var context := forecast_context(actor, target, action, options)
	var resolution := _finalize_resolution_damage(
		Resolution.resolve(context), target,
		int((context.get("positioning", {}) as Dictionary).get("cover_bonus", 0)),
		int(context.get("defense_bypass", 0)),
	)
	var damage := int(resolution.get("damage", 0))
	var priced_action := CalledShot.priced_action(action, StringName(str(options.get("aim_location", ""))))
	return _allowed({
		"action_id": action.id,
		"ap_cost": priced_action.ap_cost,
		"ct_cost": priced_action.ct_cost,
		"aim_location": str(options.get("aim_location", "")),
		"damage": damage,
		"resolution": resolution,
		"context": context,
		"damage_on_hit": _forecast_damage_on_hit(context, target),
		"positioning": (context.get("positioning", {}) as Dictionary).duplicate(true),
		"injury_forecast": _injury_forecast(resolution, _forecast_damage_on_hit(context, target)),
	})


## The three chances a forecast must label separately: to hit, to injure ON hit, overall.
## Purely presentational; never reads the rolled result.
func _injury_forecast(resolution: Dictionary, damage_on_hit: int) -> Dictionary:
	if not resolution.has("injury"):
		return {}
	var injury: Dictionary = resolution["injury"]
	var chances: Dictionary = resolution.get("injury_chance", {})
	var eligible := damage_on_hit >= int(injury.get("min_damage", 1))
	return {
		"id": str(injury.get("id", "")), "location_id": str(injury.get("location_id", "")),
		"severity": str(injury.get("severity", "minor")),
		"hit_chance": int(chances.get("hit", 0)),
		"chance_on_hit": int(chances.get("on_hit", 0)) if eligible else 0,
		"overall_chance": int(chances.get("overall", 0)) if eligible else 0,
		"eligible": eligible, "min_damage": int(injury.get("min_damage", 1)),
	}


func _forecast_damage_on_hit(context: Dictionary, target: BattleActor) -> int:
	var preview := _finalize_resolution_damage(
		Resolution.preview_on_hit(context), target,
		int((context.get("positioning", {}) as Dictionary).get("cover_bonus", 0)),
		int(context.get("defense_bypass", 0)),
	)
	return int(preview.get("damage", 0))


func forecast_defining_strike(target: BattleActor, weakness_id: StringName) -> Dictionary:
	var actor := active_actor()
	var action := action_by_id(&"definition")
	var gate := query_action(action, target, {"weakness_id": weakness_id})
	if not bool(gate.get("allowed", false)):
		return gate
	var weakness: Dictionary = gate.get("weakness", {})
	var resolution_options := {
		"weakness_id": weakness_id,
		"weakness": weakness.duplicate(true),
		"seed": _sequence,
		"ability_id": String(action.id),
		"battle_id": String(_encounter_id),
	}
	var context := forecast_context(actor, target, action, resolution_options)
	var terms := _positional_terms(actor, target)
	var resolution := _finalize_resolution_damage(
		Resolution.resolve(context), target, int(terms["cover_bonus"])
	)
	if not bool(resolution.get("allowed", false)):
		return resolution
	return _allowed({
		"action_id": action.id,
		"weakness_id": weakness_id,
		"weakness_name": str(weakness.get("display_name", weakness_id)),
		"damage": int(resolution.get("damage", 0)),
		"damage_on_hit": _forecast_damage_on_hit(context, target),
		"ap_cost": action.ap_cost,
		"chance": skill_check_service.preview(
			str(weakness.get("check_skill", "lore")),
			actor.source_member,
			float(weakness.get("check_modifier", 0.0)),
		),
		"effect_id": StringName(weakness.get("effect_id", "")),
		"effect_parameters": (weakness.get("effect_parameters", {}) as Dictionary).duplicate(true),
		"resolution": resolution,
	})


## The ONE source of positional damage terms. _resolve_attack, forecast_context
## and forecast_action must all draw from here: when forecast_action fetched its
## own flank_bonus without the positional-context guard, forecast and committed
## damage diverged for side/back facing on grid battles (Wave P gate finding).
## Grid battles pay flanking through the ratified facing MULTIPLIERS inside the
## positional context (x1.10 side / x1.25 back); the flat flank_bonus is the
## zone model's mechanism and must stay zero here or flanking double-dips.
func _positional_terms(actor: BattleActor, target: BattleActor) -> Dictionary:
	var positional_context := _positional_resolution_context(actor, target)
	var cover_bonus := battlefield.cover_bonus(actor, target)
	if _is_revealed(actor) or _is_exposed_now(target):
		cover_bonus = 0
	if _is_concealed(target):
		cover_bonus = rules.cover_defense_bonus if rules != null else cover_bonus
	var flank_bonus := battlefield.flank_bonus(actor, target)
	if not positional_context.is_empty():
		flank_bonus = 0
	if LightField.is_blinded(actor):
		# PROVISIONAL Blinded: the attacker cannot read a facing, so no flank or facing edge.
		flank_bonus = 0
		if not positional_context.is_empty():
			positional_context = positional_context.duplicate(true)
			positional_context["facing"] = {"id": &"front"}
	return {
		"positional_context": positional_context,
		"cover_bonus": cover_bonus,
		"flank_bonus": flank_bonus,
	}


func _positional_resolution_context(actor: BattleActor, target: BattleActor) -> Dictionary:
	var capabilities: Dictionary = battlefield.capabilities()
	if (
		not bool(capabilities.get("cells", false))
		or not bool(capabilities.get("elevation", false))
		or not bool(capabilities.get("facing", false))
	):
		return {}
	var actor_position: Dictionary = battlefield.describe_position(battlefield.position_of(actor))
	var target_position: Dictionary = battlefield.describe_position(battlefield.position_of(target))
	if not actor_position.has("cell") or not target_position.has("cell"):
		return {}
	var attack_direction := _facing_for_delta(
		(actor_position["cell"] as Vector2i) - (target_position["cell"] as Vector2i)
	)
	var target_facing := battlefield.facing_of(target)
	var facing_id := &"side"
	if attack_direction == target_facing:
		facing_id = &"front"
	elif attack_direction == _opposite_facing(target_facing):
		facing_id = &"back"
	return {
		"height_advantage_steps": maxi(-battlefield.elevation_delta(actor, target), 0),
		"facing": {"id": facing_id},
		# #209: live tactical terrain context. Empty dicts resolve to Resolution's
		# neutral terms, so a grid battle without charges behaves exactly as before.
		"source_tile": _tile_context(actor_position["cell"] as Vector2i),
		"target_tile": _tile_context(target_position["cell"] as Vector2i),
		"weather": weather.to_dict(),
	}


func _tile_context(cell: Vector2i) -> Dictionary:
	var tile := tile_state_at(cell)
	return tile.to_dict() if tile != null else {}


func _resolve_defining_strike(
	actor: BattleActor, target: BattleActor, action: CombatAction, options: Dictionary
) -> Dictionary:
	var weakness_id := StringName(options.get("weakness_id", ""))
	var weakness := CombatIdentityCatalog.weakness(target.archetype_id, weakness_id)
	# Captured BEFORE the check emits `check_resolved` (which advances _sequence), so the
	# damage seed equals the one `forecast_defining_strike()` used — forecast==resolution.
	var damage_seed := _sequence
	var forced_rolls: Array[int] = []
	var authored_rolls: Variant = options.get("forced_rolls", [])
	if authored_rolls is Array:
		for roll: Variant in authored_rolls:
			if typeof(roll) == TYPE_INT:
				forced_rolls.append(int(roll))
	var check_skill := str(weakness.get("check_skill", "lore"))
	# Was `"combat-%d" % get_instance_id()` — CombatController's own instance id is
	# process-local and allocation-order dependent (issue #186). `actor.combat_id` is the
	# FR-802 stable id assigned deterministically at encounter setup, so the same encounter
	# produces the same scene_id/reroll-dedup key on every run and across a mid-battle
	# save/load. Note: skill_check.gd's own `_reroll_key()` still folds in
	# `member.get_instance_id()` (the PartyMember, not this actor) — that is a separate,
	# out-of-scope defect in a file this issue does not own; see the report.
	var check := skill_check_service.resolve(
		check_skill,
		actor.source_member,
		float(weakness.get("check_modifier", 0.0)),
		"combat-%s" % actor.combat_id,
		forced_rolls,
	)
	var result := {
		"defining_strike": true,
		"weakness_id": weakness_id,
		"weakness_name": str(weakness.get("display_name", weakness_id)),
		"check_skill": check_skill,
		"check": check,
		"effect_id": StringName(weakness.get("effect_id", "")),
		"effect_applied": false,
		"resisted": false,
		"damage": 0,
	}
	if not bool(check.get("success", false)):
		result["message"] = (
			"%s names %s, but the strike misses."
			% [actor.display_name, result["weakness_name"]]
		)
		return result

	var resolution_options := options.duplicate(true)
	resolution_options.merge({
		"weakness_id": weakness_id,
		"weakness": weakness.duplicate(true),
		"seed": damage_seed,
		"ability_id": String(action.id),
		"battle_id": String(_encounter_id),
	}, true)
	result.merge(_resolve_attack(actor, target, action, resolution_options), true)
	var physical_resolution: Dictionary = result.get("resolution", {})
	if not bool(physical_resolution.get("allowed", false)) or not bool(physical_resolution.get("hit", false)):
		result["message"] = (
			"%s names %s, but the physical strike misses."
			% [actor.display_name, result["weakness_name"]]
		)
		return result
	var resistance: Variant = weakness.get("resistance", {})
	var resisted := false
	if resistance is Dictionary:
		var threshold := int(resistance.get("threshold", 0))
		var stat_id := StringName(resistance.get("stat", ""))
		resisted = threshold > 0 and target.combat_stat(stat_id) >= threshold
	result["resisted"] = resisted
	if resisted:
		result["message"] = (
			"%s names %s, but %s resists the targeted effect."
			% [actor.display_name, result["weakness_name"], target.display_name]
		)
		return result

	var effect_parameters: Variant = weakness.get("effect_parameters", {})
	if effect_parameters is Dictionary:
		target.apply_defining_effect(effect_parameters)
		var updated_max_ap := rules.action_points_for(target)
		if target.max_action_points > 0:
			target.max_action_points = mini(target.max_action_points, updated_max_ap)
			target.action_points = mini(target.action_points, target.max_action_points)
		result["effect_applied"] = true
	result["message"] = (
		"%s names %s; %s is %s."
		% [
			actor.display_name,
			result["weakness_name"],
			target.display_name,
			str(result["effect_id"]).replace("_", " "),
		]
	)
	return result


func _apply_speech_composition(
	actor: BattleActor, option: CombatSpeechOption
) -> Dictionary:
	var candidates: Array[BattleActor] = []
	for foe in enemies:
		if foe.is_alive() and battlefield.has_combatant(foe):
			candidates.append(foe)
	var count := candidates.size()
	if option.outcome != CombatSpeechOption.Outcome.END:
		count = mini(option.target_count, candidates.size())
	var removed_ids: Array[StringName] = []
	var turned_ids: Array[StringName] = []
	var ally_side := battlefield.side_of(actor)
	for i in count:
		var target := candidates[i]
		if option.outcome == CombatSpeechOption.Outcome.TURN:
			var transfer := battlefield.transfer_combatant(target, ally_side)
			if not bool(transfer.get("allowed", false)):
				continue
			enemies.erase(target)
			allies.append(target)
			# Neither scheduler indexes participants by side internally — ApRoundScheduler
			# reads `actor.side` live on every call, and ChargeTimeScheduler never looks at
			# side at all — so flipping the field is enough. Deliberately NOT calling
			# remove_participant()/setup() here: that would wipe every combatant's banked
			# charge/seat, which is exactly the "a split must not reorder survivors"
			# guarantee the scheduler's own tests require (see test_turn_scheduler.gd).
			target.side = &"ally"
			turned_ids.append(target.combat_id)
		else:
			var removal := battlefield.remove_combatant(target)
			if not bool(removal.get("allowed", false)):
				continue
			enemies.erase(target)
			scheduler.remove_participant(target)
			removed_ids.append(target.combat_id)
	var result := {
		"removed_ids": removed_ids,
		"turned_ids": turned_ids,
		"remaining_enemies": _living_count(enemies),
	}
	_emit_event(&"battlefield_changed", actor, null, result)
	return result


func _change_balance(amount: int, actor: BattleActor = null) -> void:
	if amount == 0:
		return
	if balance_lock_until_round > 0:
		_emit_event(
			&"balance_shift_suppressed",
			actor,
			null,
			{"attempted_delta": amount, "until_round": balance_lock_until_round},
		)
		return
	var previous := balance
	balance = clampi(
		balance + amount,
		CombatIdentityCatalog.balance_minimum(),
		CombatIdentityCatalog.balance_maximum(),
	)
	if balance == previous:
		return
	_apply_balance_band()
	_emit_event(
		&"balance_changed",
		actor,
		null,
		{"balance": balance, "delta": balance - previous, "band_id": balance_band_id},
	)


func _shift_toward_center(amount: int, actor: BattleActor) -> void:
	if balance > 0:
		_change_balance(-mini(balance, amount), actor)
	elif balance < 0:
		_change_balance(mini(-balance, amount), actor)


func _apply_balance_band(emit_change: bool = true) -> void:
	var band := CombatIdentityCatalog.balance_band(balance)
	var next_band_id := StringName(band.get("id", ""))
	var previous_band_id := balance_band_id
	balance_band_id = next_band_id
	var effects := CombatIdentityCatalog.balance_effects(balance, threshold_effects_suppressed)
	var affected_ids: Array[StringName] = []
	for actor: BattleActor in allies + enemies:
		var actor_effects := effects
		if not bool(band.get("global", false)) and actor not in allies:
			actor_effects = {}
		actor.apply_balance_band(balance_band_id, actor_effects)
		affected_ids.append(actor.combat_id)
	if emit_change and next_band_id != previous_band_id:
		_emit_event(
			&"balance_band_changed",
			null,
			null,
			{
				"band_id": balance_band_id,
				"effects": effects.duplicate(true),
				"affected_actor_ids": affected_ids,
			},
		)


func _release_balance_lock_if_due(current_round: int) -> void:
	if balance_lock_until_round <= 0 or current_round < balance_lock_until_round:
		return
	balance_lock_until_round = 0
	threshold_effects_suppressed = false
	_apply_balance_band()
	_emit_event(&"balance_unlocked", null, null, {"balance": balance})


func _finish(result_state: ResultState, outcome_id: StringName) -> void:
	if state == State.FINISHED:
		return
	for holder_id: String in _holds.keys():
		release_hold(holder_id, "battle_ended")
	for actor: BattleActor in allies + enemies:
		_class_resource_of(actor).on_battle_end(result_state == ResultState.VICTORY)
	state = State.FINISHED
	_settle_due_breath_refunds()
	_emit_event(&"battle_finished", null, null, {"result": result_state, "outcome_id": outcome_id})
	battle_finished.emit(result_state, outcome_id)


func _emit_event(
	type: StringName, actor: BattleActor, target: BattleActor, payload: Dictionary
) -> void:
	_sequence += 1
	var event := CombatEvent.new()
	event.sequence = _sequence
	event.type = type
	event.actor_id = actor.combat_id if actor else &""
	event.target_id = target.combat_id if target else &""
	event.data = payload.duplicate(true)
	event.data["snapshot"] = snapshot()
	# The parent event goes out BEFORE any hook runs: a hook that enqueues or cancels emits a
	# child event with a higher sequence, and replay must see parent then child, monotonic.
	var resolving_window := type == &"action_resolved"
	if resolving_window:
		_resolving = true
	event_emitted.emit(event)
	if type == &"action_resolved" and actor != null:
		_class_resource_of(actor).on_action(event)
		# Seam v2 broadcast: every actor's resource sees every resolved action (Threads).
		var action_id := StringName(str(event.data.get("action_id", "")))
		for observer: BattleActor in allies + enemies:
			_class_resource_of(observer).on_any_action(
				event.actor_id, action_id, event.target_id, event.data.duplicate(true)
			)
	if resolving_window:
		_resolving = false


func _actor_snapshots(group: Array[BattleActor]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for actor in group:
		result.append({
			"id": actor.combat_id,
			"display_name": actor.display_name,
			"anatomy": actor.anatomy.duplicate(true),
			"injuries": actor.injuries.duplicate(true),
			# Serializable presentation identity; never embed loaded textures in replay data.
			"member_id": actor.source_member.id if actor.source_member != null else "",
			"portrait_path": (
				actor.source_member.portrait.resource_path
				if actor.source_member != null and actor.source_member.portrait != null else ""
			),
			"element_id": actor.element_id,
			"facing": battlefield.facing_of(actor) if battlefield != null else &"",
			"hp": actor.hp,
			"max_hp": actor.max_hp,
			"ap": actor.action_points,
			"max_ap": actor.max_action_points,
			# Clamped: a combatant admitted mid-session banks NEGATIVE charge (it is
			# `admission_delay` further from ready than a fresh one), and the roster plate
			# renders this straight as "CT %d". The delay is real; "CT -40" is not a reading.
			"charge": maxi(0, scheduler.charge_of(actor)) if scheduler != null else 0,
			"position": battlefield.position_of(actor) if battlefield != null else &"",
			"side": battlefield.side_of(actor) if battlefield != null else actor.side,
			"guarding": actor.guarding,
			"unused_ap_defense_bonus": actor.unused_ap_defense_bonus,
			"archetype_id": actor.archetype_id,
			"balance_band_id": actor.balance_band_id,
			"balance_effects": actor.balance_effects.duplicate(true),
			"defining_effects": actor.defining_effects.duplicate(true),
			"discovered_weakness_ids": actor.discovered_weakness_ids.duplicate(),
			"breath": actor.breath,
			"aftertones": actor.aftertones.duplicate(true),
			"tempo": actor.tempo,
			"discord_signatures_visible": _signatures_visible(actor),
			"exposed": _is_exposed_now(actor),
			"class_resource": _class_resource_of(actor).snapshot(),
			"impositions": actor.impositions.duplicate(true),
		})
	return result


func _tick_actor_aftertones() -> void:
	_check_holds()
	if duration_freeze_until_round >= round_number:
		return
	for actor: BattleActor in allies + enemies:
		if actor != null:
			var before := actor.aftertones.size()
			actor.tick_aftertones()
			spent_aftertones += maxi(0, before - actor.aftertones.size())
	_check_holds()


func _is_revealed(actor: BattleActor) -> bool:
	return actor != null and revealed_until_round >= round_number and actor.side == revealed_side


func _is_concealed(actor: BattleActor) -> bool:
	return actor != null and concealed_until_round >= round_number and actor.side == concealed_side


func _expire_temporary_effects() -> void:
	if thunderhead_hit_until_round > 0 and round_number > thunderhead_hit_until_round:
		thunderhead_hit_until_round = 0
		for unit in allies + enemies:
			unit.defining_effects.erase("hit")
	if range_bonus_until_round > 0 and round_number > range_bonus_until_round:
		range_bonus_until_round = 0
		for unit in allies:
			unit.defining_effects.erase("range_bonus")
	if not founding_anchor_restore.is_empty() and round_number > duration_freeze_until_round:
		for unit in allies + enemies:
			var prior: Variant = founding_anchor_restore.get(unit.combat_id, null)
			if not prior is Dictionary:
				continue
			var prior_values: Dictionary = prior as Dictionary
			for aftertone_index: int in unit.aftertones.size():
				var aftertone: Dictionary = unit.aftertones[aftertone_index]
				var key := "%s:%d:%d" % [
					String(aftertone.get("element", "")),
					int(aftertone.get("remaining_rounds", 0)),
					aftertone_index,
				]
				if prior_values.has(key):
					aftertone["anchored"] = bool(prior_values[key])
		founding_anchor_restore.clear()


func _aftertone_writes(write: Dictionary, fallback: Array[Dictionary]) -> Array[Dictionary]:
	var value: Variant = write.get("after", fallback)
	var result: Array[Dictionary] = []
	if value is Array:
		for entry: Variant in value as Array:
			if entry is Dictionary:
				result.append((entry as Dictionary).duplicate(true))
	return result


func _apply_triad_effect(actor: BattleActor, target: BattleActor, write: Dictionary) -> void:
	# RULINGS are PROVISIONAL; each Pandora effect id has a concrete live consumer here.
	var parameters: Dictionary = write.get("parameters", {})
	var effect_id := StringName(str(write.get("effect_id", "")))
	match effect_id:
		&"the_held_silence":
			apply_balance_effect(parameters, actor)
		&"cornerstone":
			duration_freeze_until_round = round_number + 1
			for unit in allies + enemies:
				var prior: Dictionary = {}
				# The freeze keeps existing tone durations and order stable until restore;
				# the index disambiguates equal element/duration pairs on the same unit.
				for aftertone_index: int in unit.aftertones.size():
					var aftertone: Dictionary = unit.aftertones[aftertone_index]
					var key := "%s:%d:%d" % [
						String(aftertone.get("element", "")),
						int(aftertone.get("remaining_rounds", 0)),
						aftertone_index,
					]
					prior[key] = bool(aftertone.get("anchored", false))
					aftertone["anchored"] = true
				founding_anchor_restore[unit.combat_id] = prior
		&"sealed_ground":
			for aftertone: Dictionary in actor.aftertones:
				aftertone["anchored"] = true
			var position := battlefield.describe_position(battlefield.position_of(actor)) if battlefield != null else {}
			if position.has("cell"):
				var cell: Vector2i = position["cell"]
				battlefield.set_cover(cell, true)
		&"the_rendering":
			var dead_enemies := 0
			for foe in enemies:
				if foe.hp <= 0:
					dead_enemies += 1
			var living_allies := _living(allies)
			var breath_each := int((dead_enemies + spent_aftertones) / maxi(1, living_allies.size()))
			for ally in living_allies:
				ally.breath += breath_each
		&"everything_burns_at_once":
			for unit in allies + enemies:
				unit.aftertones.clear()
		&"nothing_is_uncertain":
			for ally in allies:
				ally.defining_effects["hit"] = true
			thunderhead_hit_until_round = round_number
			if scheduler != null:
				scheduler.grant_extra_turn(actor)
		&"first_light":
			revealed_until_round = round_number
			revealed_side = actor.side
		&"unlisted":
			concealed_until_round = round_number
			concealed_side = actor.side
		&"the_mouth_opens":
			zone_boundaries_open_until_round = round_number
			range_bonus_until_round = round_number
			for ally in allies:
				ally.defining_effects["range_bonus"] = 1
		&"second_season":
			for ally in allies:
				for aftertone: Dictionary in ally.aftertones:
					aftertone["remaining_rounds"] = int(aftertone.get("remaining_rounds", 0)) + 1
		_:
			_emit_event(&"triad_effect_unhandled", actor, target, {"effect_id": String(effect_id)})


func _actor_by_id(id: String) -> BattleActor:
	for combatant in allies + enemies:
		if String(combatant.combat_id) == id:
			return combatant
	return null


func _living(group: Array[BattleActor]) -> Array[BattleActor]:
	var result: Array[BattleActor] = []
	for combatant in group:
		if combatant != null and combatant.is_alive():
			result.append(combatant)
	return result


## #223 class-resource seam. Attach from the PartyMember's patron; enemies and ad-hoc actors
## (no `source_member`) get the Null resource. An actor that already carries a non-null
## resource (restored from a save, or set by a test) keeps it.
func _attach_class_resources(group: Array[BattleActor]) -> void:
	for actor in group:
		if actor.class_resource == null:
			var patron: String = actor.source_member.patron if actor.source_member != null else ""
			actor.class_resource = ClassResourceRegistry.for_patron(patron)
		actor.class_resource.owner_id = actor.combat_id
		actor.class_resource.host = self


func _class_resource_of(actor: BattleActor) -> ClassResource:
	if actor == null:
		return NullClassResource.new()
	if actor.class_resource == null:
		actor.class_resource = NullClassResource.new()
	if actor.class_resource.host == null:
		actor.class_resource.host = self
	return actor.class_resource


## ---------------------------------------------------------------------------
## Fire substrate + authored effect cards (Ash Magistrate kit).
## Cell workings, Burning/Soaked impositions, Firebreak lines, delayed releases.
## ---------------------------------------------------------------------------

const _GRID_EFFECTS: Array[StringName] = [
	&"pull", &"fire_line", &"sentence_of_ash", &"crown_of_embers", &"verdict_by_fire",
	&"push", &"witness_light", &"noonday_revelation", &"term_of_daylight", &"noon_contract",
	&"turning_tide", &"great_confluence", &"wash_the_gears", &"floodgate",
	&"shroud", &"eclipse_procession", &"eclipse_feast",
]
const RESTORE_CELL_EFFECTS: Array[StringName] = [
	&"turning_tide", &"great_confluence", &"wash_the_gears", &"floodgate",
]
const NOONDAY_RADIUS := 2
const NOONDAY_CHECKPOINTS := 1
## Writes a cell cast keeps from Resolution: the caster's own costs and residue, never a
## creature write — the synthetic target is nobody.
const _CELL_CAST_WRITE_KINDS: Array[StringName] = [
	&"breath", &"aftertones", &"aftertone_spent", &"tempo", &"last_cast_element",
	&"soul_meter", &"tile_state",
]


## Shared gates every effect card may declare: known effect id, patron, Chord/Triad tier,
## Refrain allowance, Ledger capacity, grid capability.
func _query_effect_gate(actor: BattleActor, action: CombatAction, options: Dictionary) -> Dictionary:
	var payload := action.effect_payload
	if not action.effect_id.is_empty() and not _KNOWN_EFFECTS.has(action.effect_id):
		return _blocked(
			&"effect", "%s has an effect this battle cannot resolve." % action.display_name,
			{"type": &"known_effect", "effect_id": String(action.effect_id)},
		)
	var resource := _class_resource_of(actor)
	var required_patron := StringName(str(payload.get("requires_patron", "")))
	if not required_patron.is_empty() and resource.patron_id != required_patron:
		return _blocked(
			&"class_resource", "%s belongs to the %s kit." % [action.display_name, String(required_patron).capitalize()],
			{"type": &"patron", "patron": required_patron},
		)
	var required_tier := int(payload.get("requires_tier", 0))
	if required_tier >= 2:
		var breadth: StringName = &"triad" if required_tier >= 3 else &"chord"
		var caster_context: Dictionary = (options.get("caster_context", {}) as Dictionary).duplicate(true)
		if bool(payload.get("refrain_use", false)) and not caster_context.has("breath_tier"):
			caster_context["breath_tier"] = "refrain"
		var tier_gate := CastingGate.query_breadth(
			breadth, actor.attribute_value(&"harmony"), action.magnitude, caster_context
		)
		if not bool(tier_gate.get("allowed", false)):
			var unblock: Dictionary = (tier_gate.get("nearest_unblock", {}) as Dictionary).duplicate(true)
			unblock["tier"] = required_tier
			unblock["current_harmony"] = int(tier_gate.get("current_harmony", 0))
			unblock["required_harmony"] = int(tier_gate.get("required_harmony", 0))
			return _blocked(
				StringName(str(tier_gate.get("blocked_by", &"casting_gate"))),
				str(tier_gate.get("message", "%s needs a %s working." % [action.display_name, String(breadth)])),
				unblock,
			)
	if bool(payload.get("refrain_use", false)):
		if int(_refrain_uses.get(String(actor.combat_id), 0)) >= REFRAIN_USES_PER_BATTLE:
			return _blocked(
				&"refrain_spent", "%s has already spent this battle's Refrain." % actor.display_name,
				{"type": &"refrain", "uses": REFRAIN_USES_PER_BATTLE},
			)
	if bool(payload.get("ledger_entry", false)):
		if not (resource is PazzahLedger):
			return _blocked(
				&"class_resource", "%s files through the Pazzah Ledger." % action.display_name,
				{"type": &"patron", "patron": &"pazzah"},
			)
		if (resource as PazzahLedger).entries.size() >= PazzahLedger.MAX_ENTRIES:
			return _blocked(
				&"ledger_full", "The Ledger holds %d entries; wait for one to fire." % PazzahLedger.MAX_ENTRIES,
				{"type": &"ledger_capacity", "max": PazzahLedger.MAX_ENTRIES},
			)
	if payload.has("requires_jam_within"):
		var window := int(payload.get("requires_jam_within", 1))
		var log: Dictionary = _jam_log.get(String(actor.combat_id), {})
		if log.is_empty() or int(log.get("round", -999)) < round_number - window:
			return _blocked(
				&"jam_window", "%s needs a Jam that landed within the last checkpoint." % action.display_name,
				{"type": &"recent_jam", "checkpoints": window},
			)
	if action.targets_cells() or _GRID_EFFECTS.has(action.effect_id):
		if not bool(battlefield.capabilities().get("cells", false)):
			return _blocked(
				&"position", "%s needs a gridded battlefield." % action.display_name,
				{"type": &"cells"},
			)
	return _allowed()


## Creature-targeted effect geometry: payload range in Chebyshev cells, plus the pull rule
## (target exactly two cells away on a cardinal, middle cell free).
func _query_effect_target(actor: BattleActor, target: BattleActor, action: CombatAction) -> Dictionary:
	if not bool(battlefield.capabilities().get("cells", false)):
		return _allowed()
	var from: Variant = _actor_cell(actor)
	var to: Variant = _actor_cell(target)
	if not (from is Vector2i) or not (to is Vector2i):
		return _allowed()
	var delta: Vector2i = (to as Vector2i) - (from as Vector2i)
	var distance := maxi(absi(delta.x), absi(delta.y))
	if bool(action.effect_payload.get("self_only", false)) and target != actor:
		return _blocked(
			&"target", "%s prepares only its user." % action.display_name, {"type": &"self"},
		)
	if action.effect_id == EFFECT_OPEN_SEAM and not _open_seam_angle_ok(actor, target):
		return _blocked(
			&"facing", "%s needs the target's side or rear, or a Blindside Bite on a Blinded target." % action.display_name,
			{"type": &"side_or_rear"},
		)
	var range_cells := int(action.effect_payload.get("range", 0))
	if range_cells > 0 and distance > range_cells:
		return _blocked(
			&"blocked_by_range", "%s reaches %d cells; the target is %d away." % [action.display_name, range_cells, distance],
			{"type": &"range", "range": range_cells, "distance": distance},
		)
	if action.effect_id == EFFECT_SECOND_BREATH or action.effect_id == EFFECT_OPENED_SLUICE:
		if _breath_room(target) <= 0:
			return _blocked(
				&"no_effect", "%s has no Breath to restore." % target.display_name,
				{"type": &"breath_room"},
			)
		return _allowed()
	if action.effect_id == EFFECT_UNSEAT:
		if not target.guarding:
			return _blocked(
				&"no_response", "%s has no Guard to unseat." % target.display_name,
				{"type": &"martial_response"},
			)
		return _allowed()
	if action.effect_id == EFFECT_PUSH:
		var away: Vector2i = (to as Vector2i) + delta.sign()
		var push_cell := battlefield.cell_query(away)
		if not bool(push_cell.get("allowed", false)):
			return _blocked(
				&"push_destination", "There is no open cell to shove %s into." % target.display_name,
				{"type": &"open_cell", "cell": {"x": away.x, "y": away.y}},
			)
		return _allowed({"push_destination": away})
	if action.effect_id != EFFECT_PULL:
		return _allowed()
	var cardinal := (delta.x == 0) != (delta.y == 0)
	if not cardinal or distance != 2:
		return _blocked(
			&"pull_geometry", "%s needs an enemy exactly two cells away on a straight line." % action.display_name,
			{"type": &"cardinal_distance", "distance": 2},
		)
	var destination: Vector2i = (to as Vector2i) - delta.sign()
	var cell := battlefield.cell_query(destination)
	if not bool(cell.get("allowed", false)):
		return _blocked(
			&"pull_destination", "The cell between you is not open.",
			{"type": &"open_cell", "cell": {"x": destination.x, "y": destination.y}},
		)
	if not bool(action.effect_payload.get("allow_marked_destination", false)):
		if fire.is_burning_cell(destination) or _mark_cells().has(destination):
			return _blocked(
				&"pull_destination", "Only the Herd can drag someone onto a filed cell.",
				{"type": &"unmarked_cell", "cell": {"x": destination.x, "y": destination.y}},
			)
	return _allowed({"pull_destination": destination})


## Cell-targeted working: `options.cells` declares the shape; range, shape and LOS are checked
## per effect; a spell card then resolves fizzle/Breath/Soul against a synthetic empty target.
func _query_cell_action(
	actor: BattleActor, action: CombatAction, options: Dictionary, target: BattleActor = null
) -> Dictionary:
	var cells: Array[Vector2i] = FireField.cells_from_data(options.get("cells", []))
	if cells.is_empty():
		return _blocked(
			&"no_target", "%s needs target cells." % action.display_name,
			{"type": &"cells", "count": int(action.effect_payload.get("cell_count", 3))},
		)
	var origin: Variant = _actor_cell(actor)
	if not (origin is Vector2i):
		return _blocked(&"position", "%s is not standing on the grid." % actor.display_name, {"type": &"cells"})
	var range_cells := int(action.effect_payload.get("range", 0))
	var count := int(action.effect_payload.get("cell_count", 3))
	var distinct: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if not distinct.has(cell):
			distinct.append(cell)
	if distinct.size() != count:
		return _blocked(
			&"cell_count", "%s marks exactly %d distinct cells." % [action.display_name, count],
			{"type": &"cells", "count": count},
		)
	for cell: Vector2i in distinct:
		var delta: Vector2i = cell - (origin as Vector2i)
		var distance := maxi(absi(delta.x), absi(delta.y))
		if range_cells > 0 and distance > range_cells:
			return _blocked(
				&"blocked_by_range", "%s reaches %d cells." % [action.display_name, range_cells],
				{"type": &"range", "range": range_cells, "cell": {"x": cell.x, "y": cell.y}},
			)
		var legality := battlefield.cell_query(cell)
		# A fire line may run across, and a Crown mark may sit on, a combustible object's
		# footprint; never stone or other impassable ground.
		var across_timber := (
			action.effect_id in [EFFECT_FIRE_LINE, EFFECT_SENTENCE_OF_ASH, EFFECT_CROWN_OF_EMBERS, EFFECT_VERDICT_BY_FIRE]
			and MaterialField.is_combustible(material.object_at(cell))
		)
		if not bool(legality.get("in_bounds", false)) or (not bool(legality.get("passable", false)) and not across_timber):
			return _blocked(
				&"cell_illegal", "That cell cannot hold a working.",
				{"type": &"open_cell", "cell": {"x": cell.x, "y": cell.y}},
			)
	match action.effect_id:
		EFFECT_FIRE_LINE, EFFECT_SENTENCE_OF_ASH:
			if not FireField.is_cardinal_line(distinct):
				return _blocked(
					&"line_shape", "%s burns three cells in a straight, touching line." % action.display_name,
					{"type": &"cardinal_line", "count": count},
				)
		EFFECT_ECLIPSE, EFFECT_ECLIPSE_FEAST:
			if distinct[0] != (origin as Vector2i):
				return _blocked(
					&"target", "%s is centered on its caster." % action.display_name, {"type": &"self_cell"},
				)
		EFFECT_CROWN_OF_EMBERS, EFFECT_VERDICT_BY_FIRE, EFFECT_WITNESS_LIGHT, EFFECT_NOONDAY, \
		EFFECT_TERM_OF_DAYLIGHT, EFFECT_NOON_CONTRACT, EFFECT_SHROUD:
			for cell: Vector2i in distinct:
				var sight := battlefield.line_of_sight_to_cell(actor, cell)
				if not bool(sight.get("allowed", false)):
					return sight
	if RESTORE_CELL_EFFECTS.has(action.effect_id):
		var mode := _tide_mode(action, options)
		if mode == "A" and _refuge_recipients(actor, distinct[0], int(action.effect_payload.get("radius", 1)), int(action.effect_payload.get("recipients", 3))).is_empty():
			return _blocked(
				&"no_effect", "%s would restore nothing: no ally with Breath to fill is in the refuge." % action.display_name,
				{"type": &"breath_room"},
			)
	if bool(action.effect_payload.get("contract_target", false)):
		# A cell working that also binds a creature (Term of Daylight): the contract half needs a
		# living enemy at touch and a free Thread; the field half is the cells above.
		if target == null or not target.is_alive() or not enemies.has(target):
			return _blocked(&"no_target", "%s needs a living enemy to bind." % action.display_name, {"type": &"living_enemy"})
		var touch := battlefield.target_query(actor, target, &"melee")
		if not bool(touch.get("allowed", false)):
			return touch
		var threads := _threads_of(actor)
		if threads == null:
			return _blocked(&"class_resource", "%s binds through Izhakel's Threads." % action.display_name, {"type": &"patron", "patron": &"izhakel"})
		var daylight_gate := threads.query_daylight(target.combat_id)
		if not bool(daylight_gate.get("allowed", false)):
			return daylight_gate
	var result := {"cells": distinct}
	if action.spell:
		var cast := _resolve_cell_cast(actor, action, options)
		if not bool(cast.get("allowed", false)):
			return cast
		if RESTORE_CELL_EFFECTS.has(action.effect_id) and _tide_mode(action, options) == "A":
			result["allocations"] = _plan_restoration(
				actor, distinct[0], action, options, _paid_breath(cast["resolution"])
			)
		var soul_cost := 0.0
		for write: Dictionary in (cast["resolution"] as Dictionary).get("writes", []):
			if StringName(str(write.get("kind", ""))) == &"soul_meter":
				soul_cost = -float(write.get("delta", 0.0))
		result["resolution"] = cast["resolution"]
		result["context"] = cast["context"]
		result["soul_cost"] = soul_cost
		result["breath_cost"] = action.breath_cost
	return _allowed(result)


## Resolution context for a working with no creature target: the caster's own terms, an empty
## target, no to-hit. Same calculator as a strike, so fizzle/Breath/Soul rules stay in one place.
func _cell_cast_context(actor: BattleActor, action: CombatAction, options: Dictionary) -> Dictionary:
	var context := forecast_context(actor, actor, action, options)
	if context.is_empty():
		return context
	context["target"] = {
		"id": "", "hp": 0, "element_id": "", "alacrity": 0, "aftertones": [], "tempo": 0,
		"height": 0, "attunements": {},
	}
	context["target_tile"] = {}
	context["facing"] = {}
	context["height_advantage_steps"] = 0
	context["to_hit_enabled"] = false
	context["positioning"] = {
		"line_of_sight": _allowed(), "cover_bonus": 0, "flank_bonus": 0, "facing": {},
		"height_advantage_steps": 0,
	}
	return context


func _resolve_cell_cast(actor: BattleActor, action: CombatAction, options: Dictionary) -> Dictionary:
	var context := _cell_cast_context(actor, action, options)
	var resolution := Resolution.resolve(context)
	if not bool(resolution.get("allowed", false)):
		return resolution
	var kept: Array[Dictionary] = []
	for write: Dictionary in resolution.get("writes", []):
		if _CELL_CAST_WRITE_KINDS.has(StringName(str(write.get("kind", "")))):
			# Only the selected Note changes: suppress the legacy implicit Khor hold and
			# synthetic-target Aftertones for these explicit working-targeted cards.
			if action.effect_id in [EFFECT_HOLD_NOTE, EFFECT_ANCHOR, EFFECT_SEVER] and String(write.get("kind", "")) in ["aftertones", "aftertone_spent"]:
				continue
			kept.append(write)
	resolution["writes"] = kept
	resolution["damage"] = 0
	return _allowed({"context": context, "resolution": resolution})


func _apply_cell_action(actor: BattleActor, action: CombatAction, options: Dictionary) -> Dictionary:
	var cells: Array[Vector2i] = FireField.cells_from_data(options.get("_cells", options.get("cells", [])))
	var result := {
		"cells": FireField.cells_to_data(cells), "effect_id": action.effect_id, "fizzled": false,
	}
	var paid_breath := 0
	if action.spell:
		var resolution: Dictionary = options.get("_resolution", {})
		if resolution.is_empty():
			var cast := _resolve_cell_cast(actor, action, options)
			if not bool(cast.get("allowed", false)):
				result.merge(cast, true)
				return result
			resolution = cast["resolution"]
		paid_breath = _paid_breath(resolution)
		_apply_resolution_writes(actor, actor, resolution, true, &"cast")
		result["resolution"] = resolution
		if bool(resolution.get("fizzled", false)):
			_class_resource_of(actor).on_fizzle(resolution)
			result["fizzled"] = true
			result["message"] = "%s's %s fizzles." % [actor.display_name, action.display_name]
			return result
	var payload := action.effect_payload
	var owner := String(actor.combat_id)
	var anchor: Variant = _actor_cell(actor)
	var anchor_data := {"x": (anchor as Vector2i).x, "y": (anchor as Vector2i).y} if anchor is Vector2i else {}
	match action.effect_id:
		EFFECT_FIRE_LINE:
			result.merge(_create_fire_line(actor.combat_id, cells, String(action.id)), true)
			result["message"] = "%s lays a Firebreak." % actor.display_name
		EFFECT_SENTENCE_OF_ASH:
			var filed := (_class_resource_of(actor) as PazzahLedger).queue_effect(
				EFFECT_SENTENCE_OF_ASH, int(payload.get("delay_rounds", 2)),
				{"writes": [{
					"kind": "fire_line", "cells": FireField.cells_to_data(cells), "owner_id": owner,
					"label": String(action.id),
				}]},
			)
			result["filed"] = filed
			result["message"] = "%s files a Sentence of Ash." % actor.display_name
		EFFECT_CROWN_OF_EMBERS:
			var queued := enqueue_deferred({
				"source_id": owner,
				"label": String(action.id),
				"due_turn_of": owner,
				"effect": {"writes": [{
					"kind": "crown_release", "cells": FireField.cells_to_data(cells), "anchor": anchor_data,
					"power": int(payload.get("power", 18)), "tethered": true, "label": String(action.id),
				}]},
			})
			result["queued"] = bool(queued.get("allowed", false))
			result["message"] = "%s raises a Crown of Embers." % actor.display_name
		EFFECT_TURNING_TIDE, EFFECT_WASH_THE_GEARS, EFFECT_GREAT_CONFLUENCE, EFFECT_FLOODGATE:
			result.merge(_apply_refuge(actor, action, cells[0], options, paid_breath), true)
		EFFECT_WITNESS_LIGHT:
			result.merge(_create_light_field(actor.combat_id, cells[0]), true)
			result["message"] = "%s raises a Witness Light." % actor.display_name
		EFFECT_NOONDAY:
			result["revealed"] = _noonday(actor, cells[0])
			result["message"] = "%s calls a Noonday Revelation." % actor.display_name
		EFFECT_SHROUD:
			result.merge(_create_shroud(actor, cells[0], int(payload.get("radius", LightField.SHROUD_RADIUS)), LightField.SHROUD_CHECKPOINTS, false), true)
			result["message"] = "%s raises a Shroud." % actor.display_name
		EFFECT_ECLIPSE, EFFECT_ECLIPSE_FEAST:
			var eclipse := _create_shroud(actor, cells[0], int(payload.get("radius", LightField.ECLIPSE_RADIUS)), LightField.ECLIPSE_CHECKPOINTS, true)
			result.merge(eclipse, true)
			if action.effect_id == EFFECT_ECLIPSE_FEAST:
				_feast[String(actor.combat_id)] = int((eclipse.get("field", {}) as Dictionary).get("id", 0))
				result["feast_armed"] = true
			result["message"] = "%s leads an Eclipse Procession." % actor.display_name
		EFFECT_TERM_OF_DAYLIGHT:
			var field := _create_light_field(actor.combat_id, cells[0])
			result.merge(field, true)
			var bound_target := _actor_by_id(StringName(str(options.get("_target_id", ""))))
			var threads := _threads_of(actor)
			var field_id := int((field.get("field", {}) as Dictionary).get("id", 0))
			result["bound"] = (
				threads != null and bound_target != null and field_id > 0
				and threads.bind_daylight(bound_target.combat_id, field_id)
			)
			result["message"] = "%s binds a Term of Daylight." % actor.display_name
		EFFECT_NOON_CONTRACT:
			var revealed: Array[String] = _noonday(actor, cells[0])
			result["revealed"] = revealed
			result["triggered"] = _trigger_witness_contracts(actor, revealed)
			result["message"] = "%s calls the Noon Contract." % actor.display_name
		EFFECT_VERDICT_BY_FIRE:
			var filed := (_class_resource_of(actor) as PazzahLedger).queue_effect(
				EFFECT_VERDICT_BY_FIRE, int(payload.get("delay_rounds", 2)),
				{"writes": [{
					"kind": "crown_release", "cells": FireField.cells_to_data(cells), "anchor": anchor_data,
					"power": int(payload.get("power", 18)), "tethered": false, "label": String(action.id),
				}]},
			)
			result["filed"] = filed
			result["message"] = "%s files a Verdict by Fire." % actor.display_name
	return result


## Riders on a creature-targeted card, applied after the strike landed or missed.
func _apply_effect_after_attack(
	actor: BattleActor, target: BattleActor, action: CombatAction, result: Dictionary
) -> Dictionary:
	var resolution: Dictionary = result.get("resolution", {})
	var fizzled := bool(resolution.get("fizzled", false))
	var hit := bool(resolution.get("hit", true)) and not fizzled
	var out := {"hit": hit}
	match action.effect_id:
		EFFECT_BURNING_STRIKE:
			if hit:
				out["burning"] = _apply_burning(target, actor.combat_id)
		EFFECT_DOUSE:
			if hit:
				out["douse"] = _apply_douse(actor, target)
		EFFECT_SECOND_BREATH, EFFECT_OPENED_SLUICE:
			if not fizzled:
				var cap := int(action.effect_payload.get("restore_max", 6))
				out["restored"] = _restore_breath(actor, target, mini(cap, _paid_breath(resolution)))
		EFFECT_UNVEIL:
			if hit:
				# Reveal first so the payload records the veil it tore; Exposed then replaces it.
				out["revealed"] = _reveal_signature(actor, target)
				out["exposed"] = _apply_exposed(target, actor.combat_id, LightField.EXPOSED_CHECKPOINTS)
		EFFECT_VEIL:
			if hit:
				out["veiled"] = _apply_veiled(target, actor.combat_id)
		EFFECT_BLINDING_THROW:
			if hit:
				out["blinded"] = _apply_blinded(target, actor.combat_id)
		EFFECT_BLINDSIDE, EFFECT_BLINDSIDE_BITE:
			if not fizzled:
				_blindside[String(actor.combat_id)] = {
					"until_round": round_number + 1,
					"bite": action.effect_id == EFFECT_BLINDSIDE_BITE,
				}
				out["blindside"] = _blindside[String(actor.combat_id)].duplicate(true)
				_emit_event(&"blindside_armed", actor, null, out["blindside"])
		EFFECT_OPEN_SEAM:
			out["flanked"] = _bite_applies(actor, target)
			if _blindside.has(String(actor.combat_id)):
				# Consumed by the attempt, hit or miss.
				_blindside.erase(String(actor.combat_id))
				_emit_event(&"blindside_spent", actor, target, {"flanked": out["flanked"]})
		EFFECT_UNSEAT:
			if hit and target.guarding:
				target.guarding = false
				out["unseated"] = true
				_emit_event(&"unseated", actor, target, {})
		EFFECT_PUSH:
			if hit:
				var push := _query_effect_target(actor, target, action)
				if push.has("push_destination"):
					var away: Vector2i = push["push_destination"]
					var shoved := battlefield.displace(target, away)
					out["pushed"] = bool(shoved.get("allowed", false))
					if bool(shoved.get("allowed", false)):
						out["pushed_to"] = {"x": away.x, "y": away.y}
						_emit_event(&"combatant_pushed", actor, target, {"cell": out["pushed_to"]})
						out["hazard"] = _apply_hazard(target, away)
		EFFECT_PULL:
			if hit:
				var geometry := _query_effect_target(actor, target, action)
				if geometry.has("pull_destination"):
					var destination: Vector2i = geometry["pull_destination"]
					var moved := battlefield.displace(target, destination)
					out["pulled"] = bool(moved.get("allowed", false))
					if bool(moved.get("allowed", false)):
						out["pulled_to"] = {"x": destination.x, "y": destination.y}
						_emit_event(&"combatant_pulled", actor, target, {"cell": out["pulled_to"]})
						out["hazard"] = _apply_hazard(target, destination)
	return out


func _hazard_on_path(actor: BattleActor, path_cells: Array[Vector2i]) -> Dictionary:
	for cell: Vector2i in path_cells:
		if fire.is_burning_cell(cell):
			var hazard := _apply_hazard(actor, cell)
			if bool(hazard.get("applied", false)):
				return hazard
	return {}


## One hazard event per creature per round: 3 HP credited to the line's owner, then Burning.
func _apply_hazard(actor: BattleActor, cell: Vector2i) -> Dictionary:
	var line: Dictionary = fire.line_at(cell)
	if line.is_empty() or actor == null or not actor.is_alive():
		return {}
	if not fire.hazard_due(actor.combat_id, round_number):
		return {"applied": false, "reason": "already_this_round"}
	fire.mark_hazard(actor.combat_id, round_number)
	var owner_id := StringName(str(line.get("owner_id", "")))
	var source := _actor_by_id(owner_id)
	if source == null:
		source = actor
	var write := _materialize_write({"kind": "dot", "amount": FireField.HAZARD_DAMAGE}, actor)
	_apply_resolution_writes(source, actor, {"writes": [write]}, false, &"dot")
	var burning := _apply_burning(actor, owner_id)
	var payload := {
		"cell": {"x": cell.x, "y": cell.y}, "line_id": int(line.get("id", 0)),
		"damage": -int(write.get("delta", 0)), "burning": burning,
	}
	_emit_event(&"fire_hazard", source, actor, payload)
	payload["applied"] = true
	return payload


func _apply_burning(target: BattleActor, source_id: StringName) -> Dictionary:
	var outcome: Dictionary = FireField.apply_burning(target, source_id)
	if bool(outcome.get("applied", false)):
		_emit_event(&"burning_applied", _actor_by_id(source_id), target, outcome)
	return outcome


func _apply_douse(actor: BattleActor, target: BattleActor) -> Dictionary:
	var cleared: bool = FireField.clear_burning(target)
	FireField.apply_soaked(target)
	var outcome := {"cleared": cleared, "soaked": true}
	_emit_event(&"doused", actor, target, outcome)
	return outcome


## Creates a Firebreak over the still-legal cells; creatures already standing in it take the
## hazard at once.
func _create_fire_line(owner_id: StringName, cells: Array[Vector2i], label: String) -> Dictionary:
	var legal: Array[Vector2i] = []
	var occupants: Array[BattleActor] = []
	for cell: Vector2i in cells:
		var legality := battlefield.cell_query(cell)
		if not bool(legality.get("in_bounds", false)):
			continue
		# A line can run across a combustible object's footprint (the Khash packet), not
		# through other impassable ground.
		if not bool(legality.get("passable", false)) and material.object_at(cell).is_empty():
			continue
		legal.append(cell)
		var occupant := _actor_by_id(StringName(str(legality.get("occupant_id", ""))))
		if occupant != null and not occupants.has(occupant):
			occupants.append(occupant)
	var created: Dictionary = fire.create_line(owner_id, legal, round_number)
	if not bool(created.get("allowed", false)):
		return {"line": {}, "hazards": [], "skipped": FireField.cells_to_data(cells)}
	var line: Dictionary = created["line"]
	_emit_event(&"fire_line_created", _actor_by_id(owner_id), null, {
		"line": line, "cells": FireField.cells_to_data(legal), "label": label,
	})
	var hazards: Array[Dictionary] = []
	for occupant: BattleActor in occupants:
		var at: Variant = _actor_cell(occupant)
		if at is Vector2i and legal.has(at as Vector2i):
			hazards.append(_apply_hazard(occupant, at as Vector2i))
	var ignited: Array[String] = []
	for cell: Vector2i in legal:
		var row := material.object_at(cell)
		if not row.is_empty() and MaterialField.can_ignite(row):
			_thermal_hit_object(_actor_by_id(owner_id), String(row["id"]), 0)
			ignited.append(String(row["id"]))
	return {"line": line, "hazards": hazards, "ignited_objects": ignited}


## Fires a marked Crown: tether (caster alive and on the cast cell) when `tethered`, LOS
## revalidated from the anchor per cell, one hit per creature, Burning on hit.
func _release_crown(actor: BattleActor, write: Dictionary) -> void:
	var source := _actor_by_id(StringName(str(write.get("source_id", ""))))
	if source == null:
		source = actor
	var anchor_data: Dictionary = write.get("anchor", {})
	var anchor := Vector2i(int(anchor_data.get("x", 0)), int(anchor_data.get("y", 0)))
	var cells: Array[Vector2i] = FireField.cells_from_data(write.get("cells", []))
	var label := String(write.get("label", "crown_of_embers"))
	var base := {"cells": FireField.cells_to_data(cells), "anchor": anchor_data, "label": label}
	if bool(write.get("tethered", false)):
		var caster := _actor_by_id(StringName(str(write.get("source_id", ""))))
		var reason := &""
		if caster == null or not caster.is_alive():
			reason = &"caster_down"
		elif _actor_cell(caster) != anchor:
			reason = &"caster_moved"
		if not reason.is_empty():
			var interrupted := base.duplicate(true)
			interrupted["reason"] = reason
			_emit_event(&"crown_interrupted", source, null, interrupted)
			return
	var release := CombatAction.make(&"crown_release", label.capitalize(), CombatAction.Kind.ATTACK)
	release.element_id = &"khash"
	release.target_profile = &"ranged"
	var power := int(write.get("power", 18))
	var struck: Array[BattleActor] = []
	var struck_objects: Array[String] = []
	var object_hits: Array[Dictionary] = []
	var hits: Array[Dictionary] = []
	for cell: Vector2i in cells:
		var sight := battlefield.line_of_sight_between_cells(anchor, cell)
		if not bool(sight.get("allowed", false)):
			continue
		var legality := battlefield.cell_query(cell)
		var row := material.object_at(cell)
		if not row.is_empty() and not struck_objects.has(String(row["id"])):
			struck_objects.append(String(row["id"]))
			object_hits.append(_thermal_hit_object(source, String(row["id"]), int(write.get("object_damage", 9))))
		var occupant := _actor_by_id(StringName(str(legality.get("occupant_id", ""))))
		if occupant == null or not occupant.is_alive() or struck.has(occupant):
			continue
		struck.append(occupant)
		var resolved := _resolved_attack(source, occupant, release, {"power_override": power})
		if not bool(resolved.get("allowed", false)):
			continue
		_apply_resolution_writes(source, occupant, resolved, false, &"cast")
		var hit := bool(resolved.get("hit", true))
		var entry := {
			"target_id": String(occupant.combat_id), "cell": {"x": cell.x, "y": cell.y},
			"hit": hit, "damage": int(resolved.get("damage", 0)),
		}
		if hit:
			entry["burning"] = _apply_burning(occupant, source.combat_id)
		hits.append(entry)
	var released := base.duplicate(true)
	released["hits"] = hits
	released["object_hits"] = object_hits
	_emit_event(&"crown_released", source, null, released)


## Checkpoint ordering (the fire packet): snapshot who is Burning, resolve standing hazards,
## tick the snapshot's Burning, age Soaked, age lines.
func _fire_checkpoint(completed_round: int) -> void:
	var living := _living(allies) + _living(enemies)
	var burning_at_entry: Array[BattleActor] = []
	for actor: BattleActor in living:
		if FireField.is_burning(actor):
			burning_at_entry.append(actor)
	if not fire.is_empty():
		for actor: BattleActor in living:
			var at: Variant = _actor_cell(actor)
			if at is Vector2i and fire.is_burning_cell(at as Vector2i):
				_apply_hazard(actor, at as Vector2i)
	for actor: BattleActor in burning_at_entry:
		if not actor.is_alive() or not FireField.is_burning(actor):
			continue
		var source := _actor_by_id(FireField.burn_source_id(actor))
		if source == null:
			source = actor
		var write := _materialize_write({"kind": "dot", "amount": FireField.BURN_TICK_DAMAGE}, actor)
		_apply_resolution_writes(source, actor, {"writes": [write]}, false, &"dot")
		var remaining: int = FireField.consume_burn_tick(actor)
		_emit_event(&"burn_tick", source, actor, {
			"damage": -int(write.get("delta", 0)), "remaining_ticks": remaining, "round": completed_round,
		})
	for actor: BattleActor in living:
		if FireField.age_soaked(actor):
			_emit_event(&"soaked_expired", actor, null, {"round": completed_round})
	for line: Dictionary in fire.advance_checkpoint(_held_ids("line")):
		_emit_event(&"fire_line_expired", _actor_by_id(StringName(str(line.get("owner_id", "")))), null, {
			"line": line, "round": completed_round,
		})


# ─── Water: Breath restoration and refuges (Luth cards, Sluice Runner) ──────


## Breath the caster actually spent on this cast (Soul overreach is not Breath paid).
func _paid_breath(resolution: Dictionary) -> int:
	for write: Dictionary in resolution.get("writes", []):
		if StringName(str(write.get("kind", ""))) == &"breath":
			return maxi(int(write.get("before", 0)) - int(write.get("after", 0)), 0)
	return 0


func _breath_capacity(actor: BattleActor) -> int:
	if actor == null or actor.source_member == null:
		return 0
	return maxi(actor.source_member.breath_max, 0)


func _breath_room(actor: BattleActor) -> int:
	return maxi(_breath_capacity(actor) - actor.breath, 0) if actor != null else 0


## Restores up to `amount`, clamped by the recipient's capacity. Returns the Breath granted.
func _restore_breath(actor: BattleActor, target: BattleActor, amount: int) -> int:
	var granted := mini(maxi(amount, 0), _breath_room(target))
	if granted <= 0:
		return 0
	var write := _materialize_write({"kind": "breath", "amount": granted}, target)
	_apply_resolution_writes(target, target, {"writes": [write]}, false, &"cast")
	_emit_event(&"breath_restored", actor, target, {"amount": granted})
	return granted


func _tide_mode(action: CombatAction, options: Dictionary) -> String:
	return str(options.get("mode", action.effect_payload.get("mode", "B"))).to_upper()


## Other living allies inside the refuge with Breath to fill, nearest to the center first.
func _refuge_recipients(caster: BattleActor, center: Vector2i, radius: int, limit: int) -> Array[BattleActor]:
	var found: Array[BattleActor] = []
	for ally: BattleActor in _living(allies):
		if ally == caster or _breath_room(ally) <= 0:
			continue
		var at: Variant = _actor_cell(ally)
		if not (at is Vector2i):
			continue
		var delta: Vector2i = (at as Vector2i) - center
		if maxi(absi(delta.x), absi(delta.y)) <= radius:
			found.append(ally)
	found.sort_custom(func(a: BattleActor, b: BattleActor) -> bool:
		var da: Vector2i = (_actor_cell(a) as Vector2i) - center
		var db: Vector2i = (_actor_cell(b) as Vector2i) - center
		return maxi(absi(da.x), absi(da.y)) < maxi(absi(db.x), absi(db.y)))
	if found.size() > limit:
		found.resize(limit)
	return found


## One paid budget split among the refuge's recipients: authored `options.allocations`
## ({combat_id: amount}) when given, otherwise an even split; every share is clamped by the
## recipient's room and the total by min(budget, paid). Same function at forecast and commit.
func _plan_restoration(
	caster: BattleActor, center: Vector2i, action: CombatAction, options: Dictionary, paid: int
) -> Dictionary:
	var payload := action.effect_payload
	var recipients := _refuge_recipients(caster, center, int(payload.get("radius", 1)), int(payload.get("recipients", 3)))
	var budget := mini(int(payload.get("budget", 12)), paid)
	var plan := {}
	if recipients.is_empty() or budget <= 0:
		return plan
	var requested: Dictionary = options.get("allocations", {}) if options.get("allocations") is Dictionary else {}
	var remaining := budget
	if requested.is_empty():
		var share := budget / recipients.size()
		var spare := budget - share * recipients.size()
		for ally: BattleActor in recipients:
			var amount := mini(share + (1 if spare > 0 else 0), _breath_room(ally))
			if spare > 0:
				spare -= 1
			plan[String(ally.combat_id)] = amount
			remaining -= amount
		# Leftover from clamped shares flows to whoever still has room.
		for ally: BattleActor in recipients:
			if remaining <= 0:
				break
			var extra := mini(remaining, _breath_room(ally) - int(plan[String(ally.combat_id)]))
			plan[String(ally.combat_id)] = int(plan[String(ally.combat_id)]) + extra
			remaining -= extra
	else:
		for ally: BattleActor in recipients:
			var amount := mini(mini(int(requested.get(String(ally.combat_id), 0)), _breath_room(ally)), remaining)
			if amount > 0:
				plan[String(ally.combat_id)] = amount
				remaining -= amount
	return plan


## Turning Tide / Great Confluence commit. Mode A restores by the plan; mode B quenches the
## refuge (Burning ends, allies and quenched creatures are Soaked). Wash the Gears also Soaks
## enemies the caster's Jam cancelled this round; Floodgate discharges an armed Jam retry.
func _apply_refuge(
	actor: BattleActor, action: CombatAction, center: Vector2i, options: Dictionary, paid: int
) -> Dictionary:
	var payload := action.effect_payload
	var radius := int(payload.get("radius", 1))
	var mode := _tide_mode(action, options)
	var out := {"mode": mode, "center": LightField.cell_to_data(center)}
	var inside: Array[BattleActor] = []
	for creature: BattleActor in _living(allies) + _living(enemies):
		var at: Variant = _actor_cell(creature)
		if at is Vector2i:
			var delta: Vector2i = (at as Vector2i) - center
			if maxi(absi(delta.x), absi(delta.y)) <= radius:
				inside.append(creature)
	var restores_and_quenches := action.effect_id == EFFECT_GREAT_CONFLUENCE or action.effect_id == EFFECT_FLOODGATE
	if mode == "A" or restores_and_quenches:
		var plan := _plan_restoration(actor, center, action, options, paid)
		var restored := {}
		for id: String in plan:
			var ally := _actor_by_id(StringName(id))
			if ally != null:
				restored[id] = _restore_breath(actor, ally, int(plan[id]))
		out["restored"] = restored
	if mode == "B" or restores_and_quenches:
		var cancelled: Array = (_jam_log.get(String(actor.combat_id), {}) as Dictionary).get("targets", []) \
			if int((_jam_log.get(String(actor.combat_id), {}) as Dictionary).get("round", -1)) == round_number else []
		var soaked: Array[String] = []
		for creature: BattleActor in inside:
			var washed := action.effect_id == EFFECT_WASH_THE_GEARS and cancelled.has(String(creature.combat_id))
			if allies.has(creature) or FireField.is_burning(creature) or washed:
				_apply_douse(actor, creature)
				soaked.append(String(creature.combat_id))
		out["soaked"] = soaked
	if action.effect_id == EFFECT_FLOODGATE:
		out["discharged"] = _discharge_jam(actor, center, radius)
	return out


## Floodgate: an armed Jam retry fires now on the nearest living enemy in the refuge.
func _discharge_jam(actor: BattleActor, center: Vector2i, radius: int) -> Dictionary:
	var resource := _class_resource_of(actor)
	if not (resource is FickahRuleBreaker) or (resource as FickahRuleBreaker).jam_target_id.is_empty():
		return {}
	var breaker := resource as FickahRuleBreaker
	var nearest: BattleActor = null
	var nearest_distance := radius + 1
	for enemy: BattleActor in _living(enemies):
		var at: Variant = _actor_cell(enemy)
		if not (at is Vector2i):
			continue
		var delta: Vector2i = (at as Vector2i) - center
		var distance := maxi(absi(delta.x), absi(delta.y))
		if distance <= radius and distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	if nearest == null:
		return {"target_id": "", "allowed": false, "reason": "no_enemy_in_refuge"}
	var result := request_cancel(actor.combat_id, nearest.combat_id, &"any")
	breaker.jam_target_id = &""
	return {"target_id": String(nearest.combat_id), "allowed": bool(result.get("allowed", false)), "reason": String(result.get("blocked_by", &""))}


# ─── Light: Exposed / Veiled / Witness Light / Noonday ─────────────────────


func _threads_of(actor: BattleActor) -> IzhakelThreads:
	var resource := _class_resource_of(actor)
	return resource as IzhakelThreads if resource is IzhakelThreads else null


## Exposed, Lit, or standing inside a Witness Light: cover is worthless and signatures read.
func _is_exposed_now(actor: BattleActor) -> bool:
	if actor == null:
		return false
	if LightField.is_exposed(actor) or LightField.is_lit(actor):
		return true
	if light.is_empty():
		return false
	var at: Variant = _actor_cell(actor)
	return at is Vector2i and light.is_lit_cell(at as Vector2i)


## Revelation beats concealment; a Veil hides; otherwise the side-wide rule applies.
func _signatures_visible(actor: BattleActor) -> bool:
	if _is_exposed_now(actor):
		return true
	if LightField.is_veiled(actor):
		return false
	if not _friendly_shroud_over(actor).is_empty():
		return false
	return not (concealed_until_round >= round_number and actor.side == concealed_side)


func _apply_exposed(target: BattleActor, source_id: StringName, checkpoints: int) -> Dictionary:
	var outcome: Dictionary = LightField.apply_exposed(target, source_id, checkpoints)
	if bool(outcome.get("applied", false)):
		_emit_event(&"exposed_applied", _actor_by_id(source_id), target, outcome)
	return outcome


func _apply_veiled(target: BattleActor, source_id: StringName) -> Dictionary:
	var outcome: Dictionary = LightField.apply_veiled(target, source_id)
	if bool(outcome.get("applied", false)):
		_emit_event(&"veiled_applied", _actor_by_id(source_id), target, outcome)
	return outcome


func _apply_lit(target: BattleActor, source_id: StringName, field_id: int, checkpoints: int) -> Dictionary:
	var outcome: Dictionary = LightField.apply_lit(target, source_id, field_id, checkpoints)
	if bool(outcome.get("applied", false)):
		_emit_event(&"lit_applied", _actor_by_id(source_id), target, {"field_id": field_id})
	return outcome


## The information payoff: the target's Veil (if any) is torn and its casting signature —
## last element, Aftertones, discovered weaknesses — is published to the party.
func _reveal_signature(actor: BattleActor, target: BattleActor) -> Dictionary:
	if target == null:
		return {}
	var payload := {
		"target_id": String(target.combat_id),
		"was_veiled": LightField.clear_veiled(target),
		"last_cast_element": String(target.last_cast_element),
		"aftertones": target.aftertones.duplicate(true),
		"discovered_weakness_ids": target.discovered_weakness_ids.duplicate(),
	}
	_emit_event(&"signature_revealed", actor, target, payload)
	return payload


func _create_light_field(owner_id: StringName, center: Vector2i) -> Dictionary:
	var created: Dictionary = light.create_field(owner_id, center, LightField.FIELD_RADIUS, round_number)
	var field: Dictionary = created.get("field", {})
	_emit_event(&"light_field_created", _actor_by_id(owner_id), null, {"field": LightField._serialize_field(field)})
	return {"field": field}


## Instant sweep: every living creature within the radius and in sight of the center has its
## signature revealed and reads as Exposed for one checkpoint. Returns the revealed ids.
func _noonday(actor: BattleActor, center: Vector2i) -> Array[String]:
	var revealed: Array[String] = []
	for creature: BattleActor in _living(allies) + _living(enemies):
		var at: Variant = _actor_cell(creature)
		if not (at is Vector2i):
			continue
		var delta: Vector2i = (at as Vector2i) - center
		if maxi(absi(delta.x), absi(delta.y)) > NOONDAY_RADIUS:
			continue
		if not bool(battlefield.line_of_sight_between_cells(center, at as Vector2i).get("allowed", false)):
			continue
		_reveal_signature(actor, creature)
		_apply_exposed(creature, actor.combat_id, NOONDAY_CHECKPOINTS)
		revealed.append(String(creature.combat_id))
	_emit_event(&"noonday_revelation", actor, null, {
		"center": LightField.cell_to_data(center), "radius": NOONDAY_RADIUS, "revealed": revealed.duplicate(),
	})
	return revealed


## Noon Contract: Witness contracts on the revealed enemies pay out now and free their slot.
func _trigger_witness_contracts(actor: BattleActor, revealed: Array[String]) -> Array[String]:
	var threads := _threads_of(actor)
	if threads == null:
		return []
	var triggered: Array[String] = []
	for target_id: String in revealed:
		var target := _actor_by_id(StringName(target_id))
		if target == null or not enemies.has(target):
			continue
		for payoff: Dictionary in threads.release_witness(StringName(target_id)):
			for raw: Variant in payoff.get("writes", []):
				if not (raw is Dictionary):
					continue
				var write := _materialize_write(raw as Dictionary, target)
				_apply_resolution_writes(actor, target, {"writes": [write]}, true, &"thread")
			triggered.append(target_id)
			_emit_event(&"contract_triggered", actor, target, {"kind": "witness", "payoff": payoff})
	return triggered


func _light_checkpoint(completed_round: int) -> void:
	_eclipse_feast(completed_round)
	for creature: BattleActor in _living(allies) + _living(enemies):
		for imposition: String in [LightField.IMPOSITION_EXPOSED, LightField.IMPOSITION_VEILED, LightField.IMPOSITION_LIT, LightField.IMPOSITION_BLINDED]:
			if LightField.age(creature, imposition):
				_emit_event(&"imposition_expired", creature, null, {"imposition": imposition, "round": completed_round})
	for field: Dictionary in light.advance_checkpoint(_held_ids("field")):
		var expired_type: StringName = &"shroud_expired" if LightField.is_shroud(field) else &"light_field_expired"
		_emit_event(expired_type, _actor_by_id(StringName(str(field.get("owner_id", "")))), null, {
			"field": LightField._serialize_field(field), "round": completed_round,
		})
	for combat_id: String in _blindside.keys():
		if completed_round >= int((_blindside[combat_id] as Dictionary).get("until_round", 0)):
			_blindside.erase(combat_id)
			_emit_event(&"blindside_expired", _actor_by_id(StringName(combat_id)), null, {"round": completed_round})


## ---------------------------------------------------------------------------
## Material: timber and stone on the board (reaction matrix step 1: L2, H2, M4, Z6).
## ---------------------------------------------------------------------------


## Registers a physical object on a cell after `start()`. Its footprint blocks until ruined.
func place_material(id: String, cell: Vector2i, kind: String = MaterialField.KIND_TIMBER, label: String = "") -> Dictionary:
	var added: Dictionary = material.add_object(id, cell, kind, label)
	if bool(added.get("allowed", false)):
		_block_object_cell(cell, true)
		_emit_event(&"material_placed", null, null, {"object": added.get("object", {})})
	return added


func _block_object_cell(cell: Vector2i, blocked: bool) -> void:
	if battlefield != null and battlefield.has_method("set_cliff"):
		battlefield.call("set_cliff", cell, blocked)


func material_object(id: String) -> Dictionary:
	return material.object(id).duplicate(true)


## Object- and working-targeted casts: `options.object_id` (Kindle, Douse, Reclaim, Rot the
## Brace) or `options.line_id` (Sever on a Firebreak). Rejections spend nothing.
func _note_row(note: Dictionary) -> Dictionary:
	match String(note.get("kind", "")):
		"line":
			return fire.line_by_id(int(note.get("line_id", 0)))
		"field":
			return light.field_by_id(int(note.get("field_id", 0)))
		"aftertone":
			var target := _actor_by_id(String(note.get("target_id", "")))
			var index := int(note.get("index", -1))
			if target != null and index >= 0 and index < target.aftertones.size():
				return target.aftertones[index]
	return {}


func _note_in_reach(actor: BattleActor, note: Dictionary, reach: int = 4) -> bool:
	var origin: Variant = _actor_cell(actor)
	if not (origin is Vector2i):
		return false
	var row: Dictionary = _note_row(note)
	var cells: Array[Vector2i] = []
	match String(note.get("kind", "")):
		"line":
			cells = FireField.cells_from_data(row.get("cells", []))
		"field":
			if row.get("center") is Vector2i:
				cells.append(row["center"])
		"aftertone":
			var target := _actor_by_id(String(note.get("target_id", "")))
			var at: Variant = _actor_cell(target) if target != null else null
			if at is Vector2i:
				cells.append(at as Vector2i)
	for cell: Vector2i in cells:
		var delta: Vector2i = cell - (origin as Vector2i)
		if maxi(absi(delta.x), absi(delta.y)) <= reach:
			return true
	return false


func _query_note_action(actor: BattleActor, action: CombatAction, options: Dictionary) -> Dictionary:
	var note: Dictionary = {}
	if options.has("hold_of"):
		note = (_holds.get(String(options["hold_of"]), {}) as Dictionary).duplicate(true)
	elif options.get("aftertone") is Dictionary:
		var selected: Dictionary = options["aftertone"]
		note = {"kind": "aftertone", "target_id": String(selected.get("target_id", "")), "index": int(selected.get("index", -1))}
	elif options.has("line_id"):
		note = {"kind": "line", "line_id": int(options["line_id"])}
	elif options.has("field_id"):
		note = {"kind": "field", "field_id": int(options["field_id"])}
	var row: Dictionary = _note_row(note)
	if row.is_empty():
		return _blocked(&"no_target", "%s needs a living Note." % action.display_name, {"type": &"note"})
	var kind := String(note["kind"])
	if kind == "aftertone":
		var carrier := _actor_by_id(String(note["target_id"]))
		if not carrier.is_alive() or int(row.get("remaining_rounds", 0)) <= 0:
			return _blocked(&"ineligible_note", "That Aftertone has ended.", {"type": &"living_note"})
	if action.effect_id == EFFECT_ANCHOR and kind != "aftertone":
		return _blocked(&"not_aftertone", "Anchor only protects an Aftertone.", {"type": &"aftertone"})
	if not _note_in_reach(actor, note):
		return _blocked(&"blocked_by_range", "%s reaches 4 cells." % action.display_name, {"type": &"range", "range": 4})
	# Older Aftertones have no source id. Their carrier supplies legacy ownership; new
	# Resolution lays always record the caster, including lays on hostile creatures.
	var owner_id := String(row.get("owner_id", note.get("target_id", "")))
	var owner := _actor_by_id(owner_id)
	if action.effect_id == EFFECT_HOLD_NOTE:
		if owner != actor:
			return _blocked(&"not_owned", "Hold Note needs an owned Note.", {"type": &"owned_note"})
		if _holds.has(String(actor.combat_id)):
			return _blocked(&"sustain_slot", "Release the held Note first.", {"type": &"free_sustain_slot"})
		if kind == "field" and bool(row.get("moving", false)):
			return _blocked(&"ineligible_note", "This moving working is not an eligible Note.", {"type": &"eligible_note"})
	if action.effect_id == EFFECT_ANCHOR and (owner == null or owner.side != actor.side):
		return _blocked(&"not_friendly", "Anchor needs a friendly Aftertone.", {"type": &"friendly_aftertone"})
	note["anchored"] = bool(row.get("anchored", false)) or action.effect_id == EFFECT_ANCHOR
	note["held"] = bool(row.get("held", false)) or action.effect_id == EFFECT_HOLD_NOTE or _note_is_held(note)
	note["severable"] = true
	note["consumable"] = kind == "aftertone" and not bool(note["anchored"])
	if action.effect_id == EFFECT_HOLD_NOTE:
		note["upkeep"] = {"ap": 1, "ct": 30, "breath": 1, "timing": "turn_start"}
	var cast := _resolve_cell_cast(actor, action, options)
	if not bool(cast.get("allowed", false)):
		return cast
	return _allowed({"object": note, "resolution": cast["resolution"], "context": cast["context"]})


func _note_is_held(note: Dictionary) -> bool:
	for hold: Dictionary in _holds.values():
		if String(hold.get("kind", "")) != String(note.get("kind", "")):
			continue
		match String(note.get("kind", "")):
			"line":
				if int(hold.get("line_id", 0)) == int(note.get("line_id", 0)):
					return true
			"field":
				if int(hold.get("field_id", 0)) == int(note.get("field_id", 0)):
					return true
	return false


func _held_ids(kind: String) -> Array[int]:
	_check_holds()
	var ids: Array[int] = []
	for hold: Dictionary in _holds.values():
		if String(hold.get("kind", "")) == kind:
			ids.append(int(hold.get("%s_id" % kind, 0)))
	return ids


## Interruption rule (task 8, accepted 2026-09-19): a voice-blocking injury ends the injured
## actor's held Note through the ordinary release path. Upkeep already paid stays paid, the
## release settles once (`_holds` is the only ledger), and nothing else the actor owns —
## Aftertones, Soul, anchored fields, deferred entries — is touched. A minor injury never
## interrupts. Committed-but-unreleased actions keep their commit; the refusal only reaches
## the next voice-tagged query.
func _interrupt_voice(target: BattleActor) -> void:
	if target == null or CombatInjury.voice_block(target).is_empty():
		return
	release_hold(String(target.combat_id), "voice_lost")


## Declining future upkeep is an explicit, cost-free release; Jam does not call this.
func release_hold(holder_id: String, reason: String = "declined") -> bool:
	if not _holds.has(holder_id):
		return false
	var hold: Dictionary = _holds[holder_id]
	if String(hold.get("kind", "")) == "aftertone":
		var target := _actor_by_id(String(hold.get("target_id", "")))
		if target != null:
			for aftertone: Dictionary in target.aftertones:
				if String(aftertone.get("held_by", "")) == holder_id:
					aftertone["held"] = false
					aftertone.erase("held_by")
	_holds.erase(holder_id)
	_emit_event(&"hold_released", _actor_by_id(holder_id), null, {"note": hold.duplicate(true), "reason": reason})
	return true


func _check_holds(ended_reason: String = "ended") -> void:
	for holder_id: String in _holds.keys():
		var hold: Dictionary = _holds[holder_id]
		var holder := _actor_by_id(holder_id)
		if holder == null or not holder.is_alive():
			release_hold(holder_id, "holder_lost")
			continue
		if String(hold.get("kind", "")) == "aftertone":
			var target := _actor_by_id(String(hold.get("target_id", "")))
			var found := false
			if target != null and target.is_alive():
				for index: int in target.aftertones.size():
					if String(target.aftertones[index].get("held_by", "")) == holder_id:
						hold["index"] = index
						found = true
						break
			if not found:
				release_hold(holder_id, ended_reason)
				continue
		var row: Dictionary = _note_row(hold)
		if row.is_empty():
			release_hold(holder_id, ended_reason)
		elif not _note_in_reach(holder, hold):
			release_hold(holder_id, "out_of_reach")
		else:
			hold["anchored"] = bool(row.get("anchored", false))
			hold["consumable"] = String(hold.get("kind", "")) == "aftertone" and not bool(hold["anchored"])
	# Resolution snapshots its writes before applying HP. A lethal HP write can release a
	# hold before a later Aftertone write restores that old snapshot. Never resurrect its
	# held flag; legacy implicit holds have no held_by marker and remain unchanged.
	for carrier: BattleActor in allies + enemies:
		for aftertone: Dictionary in carrier.aftertones:
			var holder_id := String(aftertone.get("held_by", ""))
			if not holder_id.is_empty() and not _holds.has(holder_id):
				aftertone["held"] = false
				aftertone.erase("held_by")


func _pay_hold_upkeep(actor: BattleActor) -> void:
	_check_holds()
	var hold: Dictionary = _holds.get(String(actor.combat_id), {})
	if hold.is_empty() or bool(hold.get("upkeep_paid", false)):
		return
	var upkeep := CombatAction.new()
	upkeep.ap_cost = 1
	upkeep.ct_cost = 30
	if actor.breath < 1 or not bool(_can_afford(actor, upkeep).get("allowed", false)):
		release_hold(String(actor.combat_id), "upkeep_unpaid")
		return
	var payment: Dictionary = scheduler.commit(actor, upkeep)
	if not bool(payment.get("allowed", false)):
		release_hold(String(actor.combat_id), "upkeep_unpaid")
		return
	actor.breath -= 1
	hold["upkeep_paid"] = true
	scheduler.release(actor)
	_emit_event(&"hold_upkeep_paid", actor, null, {"breath": 1, "ap_cost": 1, "ct_cost": 30})


func _finish_hold_turn(actor: BattleActor) -> void:
	if _holds.has(String(actor.combat_id)):
		(_holds[String(actor.combat_id)] as Dictionary)["upkeep_paid"] = false


func _sever_note(actor: BattleActor, note: Dictionary) -> bool:
	var removed := false
	var target := _actor_by_id(String(note.get("target_id", "")))
	match String(note.get("kind", "")):
		"field":
			removed = light.remove_field(int(note.get("field_id", 0)))
		"aftertone":
			if target != null and not _note_row(note).is_empty():
				target.aftertones.remove_at(int(note["index"]))
				spent_aftertones += 1
				removed = true
	if removed:
		_check_holds("severed")
		_emit_event(&"note_severed", actor, target, {"note": note.duplicate(true)})
	return removed


func _query_object_action(actor: BattleActor, action: CombatAction, options: Dictionary) -> Dictionary:
	if action.effect_id in [EFFECT_HOLD_NOTE, EFFECT_ANCHOR] or (action.effect_id == EFFECT_SEVER and (options.has("aftertone") or options.has("hold_of"))):
		return _query_note_action(actor, action, options)
	if not bool(battlefield.capabilities().get("cells", false)):
		return _blocked(&"position", "%s needs a gridded battlefield." % action.display_name, {"type": &"cells"})
	var origin: Variant = _actor_cell(actor)
	if not (origin is Vector2i):
		return _blocked(&"position", "%s is not standing on the grid." % actor.display_name, {"type": &"cells"})
	var range_cells := int(action.effect_payload.get("range", 4))
	var preview := {}
	if action.effect_id == EFFECT_SEVER:
		var line: Dictionary = fire.line_by_id(int(options.get("line_id", 0)))
		if line.is_empty():
			return _blocked(&"no_target", "%s needs a working to end." % action.display_name, {"type": &"working"})
		var reachable := false
		for cell: Vector2i in FireField.cells_from_data(line.get("cells", [])):
			var delta: Vector2i = cell - (origin as Vector2i)
			if maxi(absi(delta.x), absi(delta.y)) <= range_cells:
				reachable = true
				break
		if not reachable:
			return _blocked(&"blocked_by_range", "%s reaches %d cells." % [action.display_name, range_cells], {"type": &"range", "range": range_cells})
		preview = {"kind": "line", "line_id": int(line.get("id", 0)), "cells": FireField.cells_to_data(FireField.cells_from_data(line.get("cells", [])))}
	else:
		var row := material.object(String(options.get("object_id", "")))
		if row.is_empty():
			return _blocked(&"no_target", "%s needs an object to work on." % action.display_name, {"type": &"object"})
		var cell: Vector2i = row.get("cell", Vector2i.ZERO)
		var delta: Vector2i = cell - (origin as Vector2i)
		if maxi(absi(delta.x), absi(delta.y)) > range_cells:
			return _blocked(&"blocked_by_range", "%s reaches %d cells." % [action.display_name, range_cells], {"type": &"range", "range": range_cells})
		var sight := battlefield.line_of_sight_to_cell(actor, cell)
		if not bool(sight.get("allowed", false)):
			return sight
		preview = {"kind": "object", "object_id": String(row["id"]), "cell": {"x": cell.x, "y": cell.y}}
		match action.effect_id:
			EFFECT_BURNING_STRIKE:
				if not MaterialField.is_combustible(row):
					return _blocked(&"no_effect", "%s is noncombustible; fire does nothing to it." % String(row["label"]), {"type": &"combustible"})
				if bool(row.get("ruined", false)):
					return _blocked(&"no_effect", "%s is already ruined." % String(row["label"]), {"type": &"intact_object"})
				preview["object_damage"] = int(action.effect_payload.get("object_damage", 3))
				preview["ignition_refusal"] = MaterialField.ignition_refusal(row)
			EFFECT_DOUSE:
				if not MaterialField.is_combustible(row) or bool(row.get("ruined", false)):
					return _blocked(&"no_effect", "%s cannot be wetted to any effect." % String(row["label"]), {"type": &"wettable"})
				preview["quenches"] = bool(row.get("burning", false))
			EFFECT_RECLAIM:
				var refusal := MaterialField.reclaim_refusal(row)
				if not refusal.is_empty():
					var why := "%s is burning: not yet a source." % String(row["label"]) if refusal == "burning" else "%s is not a source." % String(row["label"])
					return _blocked(&"not_a_source", why, {"type": &"source", "reason": refusal})
				preview["yield"] = mini(MaterialField.RECLAIM_YIELD, _breath_room(actor))
			EFFECT_ROT_THE_BRACE:
				if not MaterialField.is_combustible(row) or bool(row.get("ruined", false)):
					return _blocked(&"no_effect", "%s is not susceptible to rot." % String(row["label"]), {"type": &"susceptible"})
				preview["object_damage"] = int(action.effect_payload.get("object_damage", 9))
				preview["collapses"] = int(row.get("integrity", 0)) <= int(preview["object_damage"])
			_:
				return _blocked(&"no_effect", "%s does not work on objects." % action.display_name, {"type": &"object"})
	var result := {"object": preview}
	if action.spell:
		var cast := _resolve_cell_cast(actor, action, options)
		if not bool(cast.get("allowed", false)):
			return cast
		result["resolution"] = cast["resolution"]
		result["context"] = cast["context"]
	return _allowed(result)


func _apply_object_action(actor: BattleActor, action: CombatAction, options: Dictionary) -> Dictionary:
	var preview: Dictionary = options.get("_object", {})
	var result := {"object": preview.duplicate(true), "effect_id": action.effect_id, "fizzled": false}
	if action.spell:
		var resolution: Dictionary = options.get("_resolution", {})
		if resolution.is_empty():
			var cast := _resolve_cell_cast(actor, action, options)
			if not bool(cast.get("allowed", false)):
				result.merge(cast, true)
				return result
			resolution = cast["resolution"]
		_apply_resolution_writes(actor, actor, resolution, true, &"cast")
		result["resolution"] = resolution
		if bool(resolution.get("fizzled", false)):
			_class_resource_of(actor).on_fizzle(resolution)
			result["fizzled"] = true
			result["message"] = "%s's %s fizzles." % [actor.display_name, action.display_name]
			return result
	var object_id := String(preview.get("object_id", ""))
	match action.effect_id:
		EFFECT_BURNING_STRIKE:
			result["thermal"] = _thermal_hit_object(actor, object_id, int(preview.get("object_damage", 3)))
			result["message"] = "%s kindles %s." % [actor.display_name, String(material.object(object_id).get("label", object_id))]
		EFFECT_DOUSE:
			var doused: Dictionary = material.douse(object_id)
			_emit_event(&"object_doused", actor, null, {"object_id": object_id, "quenched": bool(doused.get("quenched", false))})
			result["doused"] = doused
			result["message"] = "%s douses %s." % [actor.display_name, String(material.object(object_id).get("label", object_id))]
		EFFECT_RECLAIM:
			var claimed: Dictionary = material.reclaim(object_id)
			var restored := _restore_breath(actor, actor, int(claimed.get("yield", 0))) if bool(claimed.get("applied", false)) else 0
			_emit_event(&"object_reclaimed", actor, null, {"object_id": object_id, "restored": restored})
			result["restored"] = restored
			result["message"] = "%s reclaims %s." % [actor.display_name, String(material.object(object_id).get("label", object_id))]
		EFFECT_ROT_THE_BRACE:
			var rotted: Dictionary = material.rot(object_id, int(preview.get("object_damage", 9)))
			_emit_event(&"object_damaged", actor, null, {"object_id": object_id, "damage": int(rotted.get("damage", 0)), "channel": "decay"})
			if bool(rotted.get("collapsed", false)):
				_collapse_object(object_id)
			result["rot"] = rotted
			result["message"] = "%s rots %s." % [actor.display_name, String(material.object(object_id).get("label", object_id))]
		EFFECT_SEVER:
			if String(preview.get("kind", "")) != "line":
				result["severed"] = _sever_note(actor, preview)
				return result
			var line_id := int(preview.get("line_id", 0))
			var line: Dictionary = fire.line_by_id(line_id)
			result["severed"] = fire.remove_line(line_id)
			_emit_event(&"line_severed", actor, null, {"line_id": line_id, "line": line.duplicate(true)})
			_check_holds("severed")
			result["message"] = "%s severs the Firebreak." % actor.display_name
		EFFECT_HOLD_NOTE:
			var hold: Dictionary = preview.duplicate(true)
			hold["since_round"] = round_number
			hold["upkeep_paid"] = false
			_holds[String(actor.combat_id)] = hold
			var note: Dictionary = _note_row(hold)
			if String(hold["kind"]) == "aftertone":
				note["held"] = true
				note["held_by"] = String(actor.combat_id)
			_emit_event(&"note_held", actor, null, {"note": preview.duplicate(true)})
		EFFECT_ANCHOR:
			var note: Dictionary = _note_row(preview)
			note["anchored"] = true
			_emit_event(&"aftertone_anchored", actor, _actor_by_id(String(preview["target_id"])), {"note": preview.duplicate(true)})
	return result


## Authored thermal integrity damage on an object, then eligible ignition (H2: Wet refuses
## ignition, the direct hit still lands). Emits one event per real change.
func _thermal_hit_object(source: BattleActor, object_id: String, damage: int) -> Dictionary:
	var source_id: StringName = source.combat_id if source != null else &""
	var hit: Dictionary = material.thermal_hit(object_id, damage, source_id)
	if int(hit.get("damage", 0)) > 0:
		_emit_event(&"object_damaged", source, null, {"object_id": object_id, "damage": int(hit["damage"]), "channel": "thermal"})
	if bool(hit.get("ignited", false)):
		_emit_event(&"object_ignited", source, null, {"object_id": object_id})
	elif bool(hit.get("applied", false)) and not String(hit.get("ignition_refusal", "")).is_empty():
		_emit_event(&"ignition_refused", source, null, {"object_id": object_id, "reason": String(hit["ignition_refusal"])})
	if bool(hit.get("collapsed", false)):
		_collapse_object(object_id)
	return hit


func _collapse_object(object_id: String) -> void:
	var row := material.object(object_id)
	if row.is_empty():
		return
	_block_object_cell(row.get("cell", Vector2i.ZERO), false)
	_emit_event(&"object_collapsed", null, null, {"object_id": object_id})


## Matrix checkpoint order for material: burn ticks, collapse, Wet countdown, then new
## eligibility (a covering fire line reignites timber whose Wet just ran out). Runs after the
## fire checkpoint, so a line that expired this checkpoint reignites nothing.
func _material_checkpoint(completed_round: int) -> void:
	if material.is_empty():
		return
	for event: Dictionary in material.advance_checkpoint():
		var object_id := String(event.get("object_id", ""))
		var type := StringName(str(event.get("type", "")))
		var payload := event.duplicate(true)
		payload["round"] = completed_round
		if type == &"object_collapsed":
			_collapse_object(object_id)
			continue
		_emit_event(type, _actor_by_id(StringName(str(material.object(object_id).get("burn_source_id", "")))), null, payload)
	if fire.is_empty():
		return
	for row: Dictionary in material.objects.values():
		var cell: Vector2i = row.get("cell", Vector2i.ZERO)
		if MaterialField.can_ignite(row) and fire.is_burning_cell(cell):
			var line: Dictionary = fire.line_at(cell)
			_thermal_hit_object(_actor_by_id(StringName(str(line.get("owner_id", "")))), String(row["id"]), 0)


## ---------------------------------------------------------------------------
## Vekh concealment: Shroud / Eclipse Procession fields, Blinded, Blindside, the Nightfeeder.
## ---------------------------------------------------------------------------


func _create_shroud(actor: BattleActor, center: Vector2i, radius: int, checkpoints: int, moving: bool) -> Dictionary:
	var created: Dictionary = light.create_shroud(actor.combat_id, center, radius, round_number, checkpoints, moving)
	_emit_event(&"shroud_raised", actor, null, {"field": LightField._serialize_field(created.get("field", {}))})
	return created


## A moving shroud (Eclipse Procession) is wherever its owner stands now.
func _shroud_center(field: Dictionary) -> Vector2i:
	if bool(field.get("moving", false)):
		var owner_cell: Variant = _actor_cell(_actor_by_id(StringName(str(field.get("owner_id", "")))))
		if owner_cell is Vector2i:
			return owner_cell as Vector2i
	return field.get("center", Vector2i.ZERO)


func _shroud_covers(field: Dictionary, cell: Vector2i) -> bool:
	var delta := cell - _shroud_center(field)
	return maxi(absi(delta.x), absi(delta.y)) <= int(field.get("radius", 0))


## The first shroud raised by the creature's own side that covers its cell, or `{}`.
func _friendly_shroud_over(actor: BattleActor) -> Dictionary:
	if actor == null or light.is_empty():
		return {}
	var at: Variant = _actor_cell(actor)
	if not (at is Vector2i):
		return {}
	for field: Dictionary in light.shrouds():
		var owner := _actor_by_id(StringName(str(field.get("owner_id", ""))))
		if owner == null or owner.side != actor.side:
			continue
		if _shroud_covers(field, at as Vector2i):
			return field
	return {}


func _light_snapshot() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for field: Dictionary in light.fields:
		if not LightField.is_shroud(field):
			out.append(LightField._serialize_field(field))
	return out


## Shrouds as the HUD should draw them: moving ones already re-centered on their owner.
func _shroud_snapshot() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for field: Dictionary in light.shrouds():
		var drawn := field.duplicate(true)
		drawn["center"] = _shroud_center(field)
		out.append(LightField._serialize_field(drawn))
	return out


func _apply_blinded(target: BattleActor, source_id: StringName) -> Dictionary:
	var outcome: Dictionary = LightField.apply_blinded(target, source_id)
	if bool(outcome.get("applied", false)):
		_emit_event(&"blinded_applied", _actor_by_id(source_id), target, outcome)
	return outcome


## Open Seam's angle: side or rear at commitment. With no facing on the board the angle is
## free. A Blindside Bite on a Blinded target waives it (the target is treated as flanked).
func _open_seam_angle_ok(actor: BattleActor, target: BattleActor) -> bool:
	if _bite_applies(actor, target):
		return true
	var facing: Dictionary = _positional_resolution_context(actor, target).get("facing", {})
	return StringName(str(facing.get("id", &"side"))) != &"front"


## A plain Blindside is consumed by the next authored working's commitment (Vekh P row); a
## Bite waits for an Open Seam, which spends it in `_apply_effect_after_attack`.
func _spend_blindside(actor: BattleActor, action: CombatAction) -> void:
	var armed: Dictionary = _blindside.get(String(actor.combat_id), {})
	if armed.is_empty() or bool(armed.get("bite", false)):
		return
	if action.effect_id in [EFFECT_BLINDSIDE, EFFECT_BLINDSIDE_BITE] or action.kind not in [CombatAction.Kind.ATTACK, CombatAction.Kind.CAST, CombatAction.Kind.DEFINING_STRIKE]:
		return
	_blindside.erase(String(actor.combat_id))
	_emit_event(&"blindside_spent", actor, null, {"action_id": String(action.id), "flanked": false})


func _bite_applies(actor: BattleActor, target: BattleActor) -> bool:
	if actor == null or target == null:
		return false
	var armed: Dictionary = _blindside.get(String(actor.combat_id), {})
	return bool(armed.get("bite", false)) and LightField.is_blinded(target)


func blindside_armed(actor: BattleActor) -> Dictionary:
	return (_blindside.get(String(actor.combat_id), {}) as Dictionary).duplicate(true) if actor != null else {}


## Nightfeeder T1 — Fed in the Dark: a Hunger tick cannot be traced to a Vhorr owner whose
## signatures are concealed by their OWN Veil or Shroud. Revelation (Exposed, Lit, a light
## field) always beats the concealment; a Veil or Shroud cast by someone else does not count.
func _fed_in_the_dark(source: BattleActor, entry: Dictionary) -> bool:
	if source == null or StringName(str(entry.get("label", ""))) != &"hunger_dot":
		return false
	if not (_class_resource_of(source) is VhorrHunger):
		return false
	if _is_exposed_now(source):
		return false
	var own_id := String(source.combat_id)
	if LightField.is_veiled(source):
		var veil: Dictionary = source.impositions.get(LightField.IMPOSITION_VEILED, {})
		if String(veil.get("source_id", "")) == own_id:
			return true
	var shroud := _friendly_shroud_over(source)
	return not shroud.is_empty() and String(shroud.get("owner_id", "")) == own_id


## Nightfeeder T3 — Eclipse Feast: before the checkpoint ages the field, every Hunger chain
## the caster owns on a creature standing inside the moving shroud ticks once more. A tick
## is a tick: current Hunger, capped by the resource, kill cause &"dot" (the refund pays).
func _eclipse_feast(completed_round: int) -> void:
	if _feast.is_empty():
		return
	for combat_id: String in _feast.keys():
		var caster := _actor_by_id(StringName(combat_id))
		var field: Dictionary = light.field_by_id(int(_feast[combat_id]))
		_feast.erase(combat_id)
		if caster == null or not caster.is_alive() or field.is_empty():
			continue
		var hunger := _class_resource_of(caster) as VhorrHunger
		if hunger == null:
			continue
		var fed: Array[String] = []
		for entry: Dictionary in _deferred.duplicate():
			if String(entry.get("source_id", "")) != combat_id or StringName(str(entry.get("label", ""))) != &"hunger_dot":
				continue
			for raw: Variant in (entry.get("effect", {}) as Dictionary).get("writes", []):
				if not (raw is Dictionary) or str((raw as Dictionary).get("kind", "")) != "dot":
					continue
				var target := _actor_by_id(StringName(str((raw as Dictionary).get("target_id", ""))))
				if target == null or not target.is_alive() or String(target.combat_id) in fed:
					continue
				var at: Variant = _actor_cell(target)
				if not (at is Vector2i) or not _shroud_covers(field, at as Vector2i):
					continue
				var write := _materialize_write({"kind": "dot", "target_id": String(target.combat_id), "amount": hunger.hunger}, target)
				_apply_resolution_writes(caster, target, {"writes": [write]}, true, &"dot")
				hunger.on_extra_tick(write)
				fed.append(String(target.combat_id))
				_emit_event(&"eclipse_feast_tick", caster, target, {"write": write.duplicate(true), "round": completed_round})
		if not _has_living(enemies):
			_finish(ResultState.VICTORY, &"slain")


## Filed-but-unfired cell workings, for the HUD's marks layer and the Herd's destination rule.
func _marks_snapshot() -> Array[Dictionary]:
	var marks: Array[Dictionary] = []
	for entry: Dictionary in _deferred:
		for raw: Variant in (entry.get("effect", {}) as Dictionary).get("writes", []):
			if not (raw is Dictionary):
				continue
			var write := raw as Dictionary
			var kind := StringName(str(write.get("kind", "")))
			if not _CELL_WRITE_KINDS.has(kind):
				continue
			marks.append({
				"entry_id": int(entry.get("id", 0)),
				"kind": String(kind),
				"label": String(write.get("label", entry.get("label", ""))),
				"source_id": String(entry.get("source_id", "")),
				"cells": FireField.cells_to_data(FireField.cells_from_data(write.get("cells", []))),
				"due_round": int(entry.get("due_round", -1)),
				"due_turn_of": String(entry.get("due_turn_of", "")),
			})
	return marks


func _mark_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for mark: Dictionary in _marks_snapshot():
		for cell: Vector2i in FireField.cells_from_data(mark.get("cells", [])):
			if not cells.has(cell):
				cells.append(cell)
	return cells


func _actor_cell(actor: BattleActor) -> Variant:
	if actor == null:
		return null
	return battlefield.cell_of(actor)


static func _kill_cause_for(action: CombatAction) -> StringName:
	match action.kind:
		CombatAction.Kind.CAST:
			return &"cast"
		CombatAction.Kind.DEFINING_STRIKE:
			return &"defining_strike"
		_:
			return &"attack"



# ─── Seam v2: deferred execution + cancellation (#223 follow-up) ───────────────────────────


## Queues an effect for a later scheduler boundary. `entry` carries `source_id`, `effect`
## (`{"writes": [...]}`), and ONE due term: `due_tick` / `delay_ticks` (charge-time clock,
## `scheduler.tick_count()`) or `due_round` / `delay_rounds` (AP rounds, `round_number`). The
## effect is applied by `_fire_due_deferred()` through `_apply_resolution_writes()` — no second
## executor. Returns the refusal shape or `{allowed, entry}`; the entry is also visible in
## `snapshot().deferred` so the unit plate can show what is pending.
func enqueue_deferred(entry: Dictionary) -> Dictionary:
	if state == State.FINISHED or state == State.IDLE:
		return _blocked(&"battle_not_live", "No live battle to defer into.", {})
	var source_id := StringName(str(entry.get("source_id", "")))
	if source_id.is_empty() or _actor_by_id(source_id) == null:
		return _blocked(&"unknown_source", "Deferred effects need a participating source.", {})
	var effect: Dictionary = entry.get("effect", {}) if entry.get("effect") is Dictionary else {}
	var writes: Variant = effect.get("writes", [])
	if not (writes is Array) or (writes as Array).is_empty():
		return _blocked(&"empty_effect", "A deferred effect needs at least one write.", {})
	var queued := entry.duplicate(true)
	var has_due := false
	if entry.has("delay_ticks"):
		queued["due_tick"] = scheduler.tick_count() + maxi(int(entry["delay_ticks"]), 0)
		has_due = true
	if entry.has("delay_rounds"):
		queued["due_round"] = round_number + maxi(int(entry["delay_rounds"]), 0)
		has_due = true
	if entry.has("due_tick") or entry.has("due_round") or entry.has("due_turn_of"):
		has_due = true
	if not has_due:
		return _blocked(&"no_due_term", "A deferred effect needs due_tick/delay_ticks or due_round/delay_rounds.", {})
	_deferred_sequence += 1
	queued["id"] = _deferred_sequence
	queued["queued_tick"] = scheduler.tick_count()
	queued["queued_round"] = round_number
	_deferred.append(queued)
	_emit_event(&"deferred_queued", _actor_by_id(source_id), null, {"entry": queued.duplicate(true)})
	return _allowed({"entry": queued.duplicate(true)})


func deferred_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in _deferred:
		out.append(entry.duplicate(true))
	return out


## Cancels what `target_id` has in flight on behalf of `requester_id`. `kind`: &"deferred" removes
## the target's queued deferred entries; &"committed" voids its committed-but-unresolved
## scheduler action (a charging Song under charge time) with no refund; &"any" does both. Emits
## `action_cancelled` with what was removed. Refuses with `nothing_to_cancel` when nothing was.
func request_cancel(requester_id: StringName, target_id: StringName, kind: StringName = &"any") -> Dictionary:
	var target := _actor_by_id(target_id)
	if target == null:
		return _blocked(&"unknown_target", "That combatant is not in this battle.", {})
	var cancelled: Array[Dictionary] = []
	var untraceable := 0
	if kind == &"deferred" or kind == &"any":
		var kept: Array[Dictionary] = []
		for entry: Dictionary in _deferred:
			if StringName(str(entry.get("source_id", ""))) == target_id:
				if _fed_in_the_dark(target, entry):
					# Nightfeeder T1: a concealed source cannot be named by the Jam.
					untraceable += 1
					kept.append(entry)
					continue
				cancelled.append(entry.duplicate(true))
				_class_resource_of(target).on_deferred_cancelled(entry.duplicate(true), requester_id)
			else:
				kept.append(entry)
		_deferred = kept
	if kind == &"committed" or kind == &"any":
		if _resolving and target == active_actor():
			# The target's action is mid-delivery and its commit is still unreleased.
			if kind == &"committed":
				return _blocked(&"resolving", "%s is mid-resolution; its commit cannot be voided now." % target.display_name, {"kind": "committed"})
		else:
			var voided := scheduler.cancel_committed(target, false)
			if bool(voided.get("allowed", false)):
				cancelled.append({"kind": "committed", "target_id": String(target_id), "ct_refunded": int(voided.get("ct_refunded", 0))})
	if cancelled.is_empty():
		if untraceable > 0:
			return _blocked(
				&"source_untraceable", "%s's Hunger cannot be traced while its source is concealed." % target.display_name,
				{"kind": String(kind), "untraceable": untraceable},
			)
		return _blocked(&"nothing_to_cancel", "%s has nothing in flight." % target.display_name, {"kind": String(kind)})
	var payload := {"requester_id": String(requester_id), "kind": String(kind), "cancelled": cancelled.duplicate(true)}
	var log: Dictionary = _jam_log.get(String(requester_id), {})
	if int(log.get("round", -1)) != round_number:
		log = {"round": round_number, "targets": []}
	if not (log["targets"] as Array).has(String(target_id)):
		(log["targets"] as Array).append(String(target_id))
	_jam_log[String(requester_id)] = log
	_emit_event(&"action_cancelled", _actor_by_id(requester_id), target, payload)
	return _allowed(payload)


func actor_by_id(combat_id: StringName) -> BattleActor:
	return _actor_by_id(combat_id)


func has_living_enemies() -> bool:
	return _has_living(enemies)


## `upcoming` is the actor whose turn is about to begin (null on an AP continuation), the
## third due term: `due_turn_of` fires at the start of that combatant's next scheduled turn.
func _deferred_is_due(entry: Dictionary, upcoming: BattleActor = null) -> bool:
	if entry.has("due_tick") and scheduler.tick_count() >= int(entry["due_tick"]):
		return true
	if entry.has("due_round") and round_number >= int(entry["due_round"]):
		return true
	if entry.has("due_turn_of") and upcoming != null and String(upcoming.combat_id) == str(entry["due_turn_of"]):
		return true
	return false


## Fires every due entry, oldest first, each through `_apply_resolution_writes()`. Fires even
## when the source is down — a Ledger entry outlives its author — and skips writes whose target
## has left the battle. Ends the battle if a fired write empties a side.
func _fire_due_deferred(upcoming: BattleActor = null) -> void:
	if _deferred.is_empty():
		return
	var pending: Array[Dictionary] = []
	var due: Array[Dictionary] = []
	for entry: Dictionary in _deferred:
		if _deferred_is_due(entry, upcoming):
			due.append(entry)
		else:
			pending.append(entry)
	_deferred = pending
	for entry: Dictionary in due:
		_apply_deferred_entry(entry)
	if not _has_living(allies):
		_finish(ResultState.DEFEAT, &"defeat")
	elif not _has_living(enemies):
		_finish(ResultState.VICTORY, &"slain")


func _apply_deferred_entry(entry: Dictionary) -> void:
	var source := _actor_by_id(StringName(str(entry.get("source_id", ""))))
	var applied: Array[Dictionary] = []
	var effect: Dictionary = entry.get("effect", {})
	for raw: Variant in effect.get("writes", []):
		if not (raw is Dictionary):
			continue
		var write := raw as Dictionary
		if _CELL_WRITE_KINDS.has(StringName(str(write.get("kind", "")))):
			# Cell workings address the board, not a combatant. They fire even if their source
			# is down (a filed Firebreak still ignites); the write itself decides tethers.
			var board_write := write.duplicate(true)
			board_write["source_id"] = String(entry.get("source_id", ""))
			var board_actor := source if source != null else _first_living(allies + enemies)
			if board_actor != null:
				_apply_resolution_writes(board_actor, board_actor, {"writes": [board_write]}, true, &"deferred")
				applied.append(board_write)
			continue
		var target := _actor_by_id(StringName(str(write.get("target_id", ""))))
		if target == null:
			continue
		var materialized := _materialize_write(write, target)
		# Breath writes address the recipient; damage still attributes its source.
		var actor := target if str(write.get("kind", "")) == "breath" or source == null else source
		_apply_resolution_writes(actor, target, {"writes": [materialized]}, true, &"deferred")
		applied.append(materialized)
	var fired := entry.duplicate(true)
	fired["applied"] = applied
	_emit_event(&"deferred_effect_fired", source, null, {"entry": fired.duplicate(true)})
	if source != null:
		_class_resource_of(source).on_deferred_fired(fired)


func _settle_due_breath_refunds() -> void:
	var pending: Array[Dictionary] = []
	var refunds: Array[Dictionary] = []
	for entry: Dictionary in _deferred:
		var writes: Array = (entry.get("effect", {}) as Dictionary).get("writes", [])
		var only_breath := not writes.is_empty()
		for raw: Variant in writes:
			if not raw is Dictionary or str(raw.get("kind", "")) != "breath":
				only_breath = false
				break
		if only_breath and _deferred_is_due(entry):
			refunds.append(entry)
		else:
			pending.append(entry)
	_deferred = pending
	for entry: Dictionary in refunds:
		_apply_deferred_entry(entry)


## Turns a queued write (`delta` or `amount`, no before/after) into the same shape Resolution
## emits, from LIVE state at fire time. `hp`/`dot` amounts are HP lost; `breath` is a gain;
## `soul_meter`/`tile_state` must already carry `after`.
func _materialize_write(write: Dictionary, target: BattleActor) -> Dictionary:
	var out := write.duplicate(true)
	out["target_id"] = String(target.combat_id)
	match StringName(str(write.get("kind", ""))):
		&"hp", &"dot":
			var loss := absi(int(write.get("amount", -int(write.get("delta", 0)))))
			out["before"] = target.hp
			out["after"] = maxi(target.hp - loss, 0)
			out["delta"] = int(out["after"]) - target.hp
		&"breath":
			var gain := int(write.get("amount", write.get("delta", 0)))
			out["before"] = target.breath
			out["after"] = maxi(target.breath + gain, 0)
			out["delta"] = int(out["after"]) - target.breath
	return out

## Model-level persistence for the additive `class_resources` save key (no schema bump).
## Keyed by combat id; Null resources are skipped.
func class_resources_to_dict() -> Dictionary:
	var result := {}
	for actor: BattleActor in allies + enemies:
		var resource := _class_resource_of(actor)
		if resource.is_null():
			continue
		result[String(actor.combat_id)] = resource.to_dict()
	# Seam v2: the deferred queue rides in this same dict under a reserved key (only when
	# non-empty), so the save format gains no top-level key and older saves restore an empty queue.
	if not _deferred.is_empty():
		result[DEFERRED_SAVE_KEY] = {"sequence": _deferred_sequence, "entries": deferred_entries()}
	if not fire.is_empty() or not fire.hazard_round.is_empty():
		result[FIRE_SAVE_KEY] = fire.to_dict()
	if not light.is_empty():
		result[LIGHT_SAVE_KEY] = light.to_dict()
	if not _jam_log.is_empty():
		result[JAMS_SAVE_KEY] = _jam_log.duplicate(true)
	if not _blindside.is_empty() or not _feast.is_empty():
		result[VEKH_SAVE_KEY] = {"blindside": _blindside.duplicate(true), "feast": _feast.duplicate(true)}
	if not material.is_empty():
		result[MATERIALS_SAVE_KEY] = material.to_dict()
	if not _holds.is_empty():
		result[HOLDS_SAVE_KEY] = _holds.duplicate(true)
	var impositions: Dictionary = {}
	for actor: BattleActor in allies + enemies:
		if not actor.impositions.is_empty():
			impositions[String(actor.combat_id)] = actor.impositions.duplicate(true)
	if not impositions.is_empty():
		result[IMPOSITIONS_SAVE_KEY] = impositions
	return result


func restore_class_resources(data: Dictionary) -> void:
	# Legacy saves have no holds; clear the current section before replacing it.
	for holder_id: String in _holds.keys():
		release_hold(holder_id, "restore")
	for actor: BattleActor in allies + enemies:
		var entry: Variant = data.get(String(actor.combat_id), null)
		if entry is Dictionary:
			actor.class_resource = ClassResourceRegistry.from_dict(entry)
			actor.class_resource.owner_id = actor.combat_id
			actor.class_resource.host = self
	var queue: Variant = data.get(DEFERRED_SAVE_KEY, {})
	if queue is Dictionary:
		_deferred.clear()
		for raw: Variant in (queue as Dictionary).get("entries", []):
			if raw is Dictionary:
				_deferred.append((raw as Dictionary).duplicate(true))
		_deferred_sequence = maxi(int((queue as Dictionary).get("sequence", 0)), _deferred_sequence)
	var fire_data: Variant = data.get(FIRE_SAVE_KEY, null)
	if fire_data is Dictionary:
		fire.from_dict(fire_data as Dictionary)
	var light_data: Variant = data.get(LIGHT_SAVE_KEY, null)
	if light_data is Dictionary:
		light.from_dict(light_data as Dictionary)
	var jams: Variant = data.get(JAMS_SAVE_KEY, null)
	if jams is Dictionary:
		_jam_log = (jams as Dictionary).duplicate(true)
	var materials: Variant = data.get(MATERIALS_SAVE_KEY, null)
	if materials is Dictionary:
		material.from_dict(materials as Dictionary)
		for row: Dictionary in material.objects.values():
			_block_object_cell(row.get("cell", Vector2i.ZERO), not bool(row.get("ruined", false)))
	var vekh: Variant = data.get(VEKH_SAVE_KEY, {})
	if vekh is Dictionary:
		_blindside = ((vekh as Dictionary).get("blindside", {}) as Dictionary).duplicate(true)
		_feast = ((vekh as Dictionary).get("feast", {}) as Dictionary).duplicate(true)
	var impositions: Variant = data.get(IMPOSITIONS_SAVE_KEY, {})
	if impositions is Dictionary:
		for actor: BattleActor in allies + enemies:
			var row: Variant = (impositions as Dictionary).get(String(actor.combat_id), null)
			if row is Dictionary:
				actor.impositions = (row as Dictionary).duplicate(true)
	var holds: Variant = data.get(HOLDS_SAVE_KEY, {})
	if holds is Dictionary:
		_holds = (holds as Dictionary).duplicate(true)
		for holder_id: String in _holds:
			var hold: Dictionary = _holds[holder_id]
			var note: Dictionary = _note_row(hold)
			if String(hold.get("kind", "")) == "aftertone" and not note.is_empty():
				note["held"] = true
				note["held_by"] = holder_id
	_check_holds()


## FR-802 (globals/stable_ids.gd). Builds `BattleActor.combat_id` from stable inputs only —
## `encounter_id` (if the caller has one), `archetype_id`, and the actor's ordinal position
## within its side's array — never from `get_instance_id()` or allocation order. Two runs with
## identical `ally_group`/`enemy_group`/`encounter_id` inputs therefore produce identical ids,
## and the trailing ordinal guarantees uniqueness even when two combatants share both
## `display_name` and `archetype_id` (e.g. two Bog Wights). Must run before
## `battlefield.setup()` (see `start()`) so the battlefield never sees an unassigned id.
func _assign_combat_ids(
	group: Array[BattleActor], prefix: StringName, encounter_id: StringName = &""
) -> void:
	for i in group.size():
		_assign_combat_id(group[i], prefix, encounter_id, i)


func _assign_combat_id(
	actor: BattleActor, prefix: StringName, encounter_id: StringName, ordinal: int
) -> void:
	# Set the side BEFORE the already-assigned check below. An actor reused across battles
	# keeps its combat_id and would otherwise skip the body entirely and end up with no
	# side, which reads to a scheduler as "on neither side" and drops it from the order.
	actor.side = prefix
	if not actor.combat_id.is_empty():
		return
	var parts: Array[String] = [String(prefix)]
	if not String(encounter_id).is_empty():
		parts.append(String(encounter_id))
	var archetype := String(actor.archetype_id)
	if not archetype.is_empty() and StableIds.is_valid(StableIds.ACTOR, archetype):
		parts.append(archetype)
	parts.append(str(ordinal))
	var candidate := "-".join(parts)
	var record := StableIds.actor(candidate)
	actor.combat_id = StringName(record.get("id", candidate))


func _has_living(group: Array[BattleActor]) -> bool:
	return _first_living(group) != null


func _living_count(group: Array[BattleActor]) -> int:
	var count := 0
	for actor in group:
		if actor.is_alive():
			count += 1
	return count


func _first_living(group: Array[BattleActor]) -> BattleActor:
	for actor in group:
		if actor.is_alive():
			return actor
	return null


func _next_living_index(group: Array[BattleActor], after: int) -> int:
	for i in range(after + 1, group.size()):
		if group[i].is_alive():
			return i
	return -1


static func _allowed(extra: Dictionary = {}) -> Dictionary:
	var result := {
		"allowed": true,
		"blocked_by": &"",
		"nearest_unblock": {},
		"message": "",
	}
	result.merge(extra, true)
	return result


static func _blocked(
	blocked_by: StringName, message: String, nearest_unblock: Dictionary
) -> Dictionary:
	return {
		"allowed": false,
		"blocked_by": blocked_by,
		"nearest_unblock": nearest_unblock.duplicate(true),
		"message": message,
	}
