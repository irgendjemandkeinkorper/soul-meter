extends Node
## Renown — a second, faction-independent consequence ledger: how known
## (reputation) or notorious (infamy) the player is in general, regardless of
## any single faction's opinion (globals/reputation.gd covers that axis).
## Same append-only rule: nothing writes to the log except gain_reputation()/
## gain_infamy(), and nothing but combat feeds either — dialogue, quests, and
## other choices do too (see dialogue/iris_illepah.dialogue for an infamy
## example). Consumers: ui/screens/tavern.gd gates some recruits on a minimum
## reputation() or infamy(), the way a faction can gate a dialogue line.
##
## Deliberately separate from the Soul Gauge (GameState.soul_meter) — the
## vault's systems/magic-system.md floats an unresolved idea to rework the
## Gauge itself into a public karma meter, which it flags as contradicting
## current canon. This system doesn't touch the Gauge and isn't that proposal.
##
## ---------------------------------------------------------------------------
## YOTHMERU (RFC-0007, docs/architecture-dramgid.md §3.7)
##
## Renown now carries the two Yothmeru axes as well:
##
##   Karma — signed, −1000..1000, seven tiers. NEW, so nothing depended on it
##           before: the RFC's `base × Doctrine scale` multiplier is live here.
##   Fame  — unsigned, 0..1000, five tiers. §3.7 defines it as
##           `reputation + infamy` (less any extreme-tier decay), so it is a
##           DERIVED read over the meters that already existed.
##
## Why Reputation and Infamy are NOT scaled by Decorum, though RFC-0007 §4
## scales the Fame shift: the two shipped recruit gates read those raw totals
## (rep ≥ 10 for Korrath Ninefold, infamy ≥ 8 for Maura Greyfen, see
## GameState._make_member). DRAMGID point-buys attributes 2..5
## (DramgidSchema.ATTRIBUTE_FLOOR/ATTRIBUTE_CAP), so the RFC's `/10` divisor can
## only ever produce 0.2×..0.5× — every authored grant in the game would shrink
## and both gates would flip. §3.7's own closing clause ("existing totals/API
## untouched so tavern gates keep working") and owner ruling 7 ("no existing
## recruit gate flips") forbid that. So the Decorum-scaled figure is COMPUTED
## AND RECORDED on every event as `RenownEvent.fame_shift`, giving the §6
## numeric pass real data to rule on, without moving a live total. Owner ruling
## 9 in the note decides whether Fame switches over to it.

signal renown_changed(kind: StringName, total: float, event: RenownEvent)

## RFC-0007 §3. Tier floors are inclusive and read low to high, so the ladders
## partition their range with no gap and no overlap; the RFC's written ranges
## share their endpoints ("−250 to −50", "−50 to 50"), and the lower bound wins.
const KARMA_MIN := -1000.0
const KARMA_MAX := 1000.0
const KARMA_TIER_NAMES: PackedStringArray = [
	"Damned", "Cruel", "Troubled", "Uncertain", "Upright", "Virtuous", "Exalted",
]
const KARMA_TIER_FLOORS: PackedFloat64Array = [
	-1000.0, -600.0, -250.0, -50.0, 50.0, 250.0, 600.0,
]
## Index of "Uncertain" — the neutral rung RFC-0007 §6 measures Sway/Bellow from.
const KARMA_NEUTRAL_TIER := 3

const FAME_MIN := 0.0
const FAME_MAX := 1000.0
const FAME_TIER_NAMES: PackedStringArray = [
	"Unknown", "Whispered", "Known", "Renowned", "Legendary",
]
const FAME_TIER_FLOORS: PackedFloat64Array = [0.0, 50.0, 200.0, 450.0, 750.0]

## PROVISIONAL (docs/architecture-dramgid.md §6 owns the number; owner ruling 7
## adopts RFC-0007 as written until then). RFC-0007 §4 writes both shift formulas
## over a /10 divisor and annotates it "Doctrine or Decorum of 10 = 1.0x". That
## baseline is unreachable under DRAMGID's 2..5 point-buy, so this divisor makes
## every multiplier 0.2×..0.5×. Implemented as the RFC writes it rather than
## silently rescaled — see owner ruling 9.
const ATTRIBUTE_SCALE_DIVISOR := 10.0

## PROVISIONAL magnitude, live mechanism. RFC-0007 §5: only the extreme tiers
## decay, by "a fixed percentage of the excess, per week", asymptotically, never
## crossing back past the boundary. §6 assigns the percentage to the numeric
## pass; what F3a owes is the mechanism, so the fraction lives behind one name.
const DECAY_FRACTION_PER_WEEK := 0.10
const DAYS_PER_WEEK := 7

## Actor recorded on decay rows. Decay is the world forgetting, not an act.
const DECAY_ACTOR := "world"

var _log: Array[RenownEvent] = []
var _next_order: int = 0
var _reputation: float = 0.0
var _infamy: float = 0.0
var _karma: float = 0.0
## Accumulated Legendary-tier Fame decay — always ≤ 0. Kept as its own term so
## decaying Fame never edits the Reputation/Infamy totals the gates read.
var _fame_decay: float = 0.0
## Derived cache: kind -> array of events. Speeds up why().
var _events_by_kind: Dictionary = {}
var _last_decayed_day: int = -1


func _ready() -> void:
	# WorldClock is registered after this autoload in project.godot, so its node
	# does not exist yet at _ready(). Defer by one frame rather than reordering
	# the autoload list, which save/load ordering depends on.
	_connect_world_clock.call_deferred()


## `witness_factor` (RFC-0007 §4) is how publicly the act landed: 1.0 for an
## ordinary witnessed act, 0.0 for one nobody sees. It scales the recorded
## `fame_shift` only — the Reputation total itself is the authored value, see
## the header.
func gain_reputation(
	actor: String,
	delta: float,
	cause: String,
	scene: String = "",
	witness_factor: float = 1.0
) -> RenownEvent:
	return _record(actor, &"reputation", delta, cause, scene, witness_factor)


func gain_infamy(
	actor: String,
	delta: float,
	cause: String,
	scene: String = "",
	witness_factor: float = 1.0
) -> RenownEvent:
	return _record(actor, &"infamy", delta, cause, scene, witness_factor)


## Yothmeru's signed axis. Unlike the two meters above, the RFC's multiplier is
## live here: `base` is what the author wrote and the Karma total moves by
## `base × Doctrine / ATTRIBUTE_SCALE_DIVISOR`, read off the protagonist at
## write time. Both figures are recorded on the event.
func gain_karma(actor: String, base: float, cause: String, scene: String = "") -> RenownEvent:
	return _record(actor, &"karma", base, cause, scene, 1.0)


func reputation() -> float:
	return _reputation


func infamy() -> float:
	return _infamy


func karma_total() -> float:
	return _karma


## §3.7: Fame is Reputation plus Infamy — magnitude only, independent of Karma's
## sign — less any Legendary-tier decay. Clamped to the RFC's range.
func fame() -> float:
	return clampf(_reputation + _infamy + _fame_decay, FAME_MIN, FAME_MAX)


## The tier name a sheet or NPC shows instead of the raw score (RFC-0007 §3's
## display model: "Upright / Renowned", not "+180 / 610").
func karma_tier() -> String:
	return KARMA_TIER_NAMES[karma_tier_index()]


func fame_tier() -> String:
	return FAME_TIER_NAMES[_tier_index(fame(), FAME_TIER_FLOORS)]


## 0..6 into KARMA_TIER_NAMES. For the Sway/Bellow modifier use
## karma_tier_offset(), which is the value RFC-0007 §6 actually specifies.
func karma_tier_index() -> int:
	return _tier_index(karma_total(), KARMA_TIER_FLOORS)


## RFC-0007 §6 (RULE.TIER_INDEXED_SKILLS): signed distance from Uncertain —
## Uncertain 0, Upright/Troubled ±1, Virtuous/Cruel ±2, Exalted/Damned ±3.
## Positive for good Karma. `SkillCheck.karma_bonus()` multiplies this by the
## skill's karma direction, so Sway gains from good Karma and Bellow from bad.
func karma_tier_offset() -> int:
	return karma_tier_index() - KARMA_NEUTRAL_TIER


func fame_tier_index() -> int:
	return _tier_index(fame(), FAME_TIER_FLOORS)


## The most recent reasons behind one meter, newest first — same shape as
## Reputation.why().
func why(kind: StringName, limit: int = 5) -> Array[RenownEvent]:
	var events: Array[RenownEvent] = _events_by_kind.get(kind, [] as Array[RenownEvent])
	var out: Array[RenownEvent] = []
	var total := events.size()
	var count := mini(limit, total)
	for i in range(count):
		out.append(events[total - 1 - i].copy())
	return out


## The whole append-only log, newest first. This is a read-only derived query;
## limit <= 0 returns every event. Yields COPIES — see ReputationEvent.copy().
func history(limit: int = 0) -> Array[RenownEvent]:
	var out: Array[RenownEvent] = []
	var total: int = _log.size()
	var count: int = total if limit <= 0 else mini(limit, total)
	for index: int in range(count):
		out.append(_log[total - 1 - index].copy())
	return out


func _record(
	actor: String,
	kind: StringName,
	base: float,
	cause: String,
	scene: String,
	witness_factor: float
) -> RenownEvent:
	var e := RenownEvent.new()
	e.actor = actor
	e.kind = kind
	e.base = base
	e.witness_factor = witness_factor
	# Karma is the one axis whose multiplier is live — see the header for why the
	# other two record their scaled figure instead of applying it.
	e.applied = base * _attribute_scale(DramgidSchema.ATTR_DOCTRINE) if kind == &"karma" else base
	e.delta = e.applied
	e.fame_shift = (
		absf(base) * witness_factor * _attribute_scale(DramgidSchema.ATTR_DECORUM)
	)
	e.cause = cause
	e.scene = scene if not scene.is_empty() else _current_scene_id()
	e.at = int(Time.get_unix_time_from_system())
	e.order = _next_order
	_next_order += 1
	_log.append(e)
	_index(e)
	_apply(e)

	# Copies for the same reason as Reputation.record() — see its comment.
	renown_changed.emit(kind, total(kind), e.copy())
	return e.copy()


## The running total for one meter. `fame` is derived rather than stored, so it
## answers here too — a consumer that just wants "the number that moved" does
## not need to know which axis is a sum and which is a ledger.
func total(kind: StringName) -> float:
	match kind:
		&"infamy":
			return _infamy
		&"karma":
			return _karma
		&"fame":
			return fame()
		_:
			return _reputation


func _index(e: RenownEvent) -> void:
	if not _events_by_kind.has(e.kind):
		_events_by_kind[e.kind] = [] as Array[RenownEvent]
	var kind_events: Array[RenownEvent] = _events_by_kind[e.kind]
	kind_events.append(e)


## The one place a stored event moves a running total, so replaying the log on
## load and appending a new event cannot drift apart.
func _apply(e: RenownEvent) -> void:
	match e.kind:
		&"infamy":
			_infamy += e.delta
		&"karma":
			_karma = clampf(_karma + e.delta, KARMA_MIN, KARMA_MAX)
		&"fame":
			# Only decay writes this kind, and only downward.
			_fame_decay += e.delta
		_:
			_reputation += e.delta


## Which rung of a ladder a score sits on. Floors are inclusive and ascending,
## so this walks down to the first floor at or below the score.
func _tier_index(score: float, floors: PackedFloat64Array) -> int:
	var index := 0
	for i: int in range(floors.size()):
		if score >= floors[i]:
			index = i
	return index


## The governing attribute's multiplier, read off the protagonist at write time.
## A missing protagonist (a bare test harness, or a write before New Game) scales
## by 1.0 rather than zeroing the act — an unrecorded consequence is worse than
## an unscaled one.
func _attribute_scale(attribute_id: StringName) -> float:
	var state: Node = get_node_or_null(^"/root/GameState")
	if state == null or not state.has_method("protagonist"):
		return 1.0
	var member: PartyMember = state.call("protagonist")
	if member == null:
		return 1.0
	# Doctrine is a NEW attribute with no legacy name, so a character who has not
	# been through the v7→v8 migration yet has no value for it and would read 0 —
	# which would freeze Karma at zero rather than scale it. Owner ruling 5 sets
	# migrated characters to the floor, so read the floor for them too.
	var value := maxi(member.attribute_value(attribute_id), DramgidSchema.ATTRIBUTE_FLOOR)
	return float(value) / ATTRIBUTE_SCALE_DIVISOR


# --- extreme-tier decay (RFC-0007 §5) ---------------------------------------


func _connect_world_clock() -> void:
	var clock: Node = get_node_or_null(^"/root/WorldClock")
	if clock == null or not clock.has_signal("day_changed"):
		return
	if not clock.is_connected("day_changed", _on_day_changed):
		clock.connect("day_changed", _on_day_changed)


func _on_day_changed(_previous_day: int, current_day: int) -> void:
	decay_one_day(current_day)


## Drift the extreme tiers back toward their nearer boundary by one day's share
## of DECAY_FRACTION_PER_WEEK. Asymptotic by construction: a fixed fraction of
## the excess is removed, so the score approaches the boundary without ever
## reaching or crossing it, and a score outside the extreme tiers never moves.
##
## Public and day-indexed rather than private and unconditional so the caller
## proves a day actually passed. `day` guards against a double-tick; pass -1 to
## force one (tools and tests). NEVER call this from a timer (§3.7).
func decay_one_day(day: int) -> void:
	if day >= 0:
		if day == _last_decayed_day:
			return
		_last_decayed_day = day

	var per_day := 1.0 - pow(1.0 - DECAY_FRACTION_PER_WEEK, 1.0 / float(DAYS_PER_WEEK))

	var karma_boundary := _extreme_boundary(karma_total(), KARMA_TIER_FLOORS)
	if not is_nan(karma_boundary):
		var karma_excess := karma_total() - karma_boundary
		if not is_zero_approx(karma_excess):
			_record_decay(
				&"karma",
				-karma_excess * per_day,
				"Yothmeru decay — %s drifts toward %d" % [karma_tier(), int(karma_boundary)]
			)

	# Fame only has one extreme tier (Legendary); its boundary is the top floor.
	if fame_tier_index() == FAME_TIER_FLOORS.size() - 1:
		var fame_excess := fame() - FAME_TIER_FLOORS[FAME_TIER_FLOORS.size() - 1]
		if not is_zero_approx(fame_excess):
			_record_decay(
				&"fame",
				-fame_excess * per_day,
				"Yothmeru decay — Legendary fades toward Renowned"
			)


## The boundary an extreme-tier score drifts toward, or NAN when the score is not
## in an extreme tier. Only the bottom and top rungs decay (RFC-0007 §5); every
## other tier is permanent and does not erode offscreen. Fame's bottom rung
## (Unknown) is not extreme, which is why decay_one_day() tests Fame against the
## top rung directly instead of calling this.
func _extreme_boundary(score: float, floors: PackedFloat64Array) -> float:
	var index := _tier_index(score, floors)
	if index == 0 and floors.size() > 1:
		# The bottom rung drifts UP to the floor of the rung above it.
		return floors[1]
	if index == floors.size() - 1:
		return floors[index]
	return NAN


func _record_decay(kind: StringName, delta: float, cause: String) -> void:
	var e := RenownEvent.new()
	e.actor = DECAY_ACTOR
	e.kind = kind
	e.base = delta
	e.applied = delta
	e.delta = delta
	e.witness_factor = 0.0
	e.cause = cause
	e.scene = _current_scene_id()
	e.at = int(Time.get_unix_time_from_system())
	e.order = _next_order
	_next_order += 1
	_log.append(e)
	_index(e)
	_apply(e)
	renown_changed.emit(kind, total(kind), e.copy())


func to_dict() -> Dictionary:
	var rows: Array[Dictionary] = []
	for e in _log:
		rows.append(e.to_dict())
	# `last_decayed_day` is the only Yothmeru state that is not derivable from the
	# log: without it, loading a save on the same world day would decay twice.
	return {"log": rows, "next_order": _next_order, "last_decayed_day": _last_decayed_day}


func from_dict(d: Dictionary) -> void:
	_log.clear()
	_reputation = 0.0
	_infamy = 0.0
	_karma = 0.0
	_fame_decay = 0.0
	_events_by_kind.clear()
	for row in d.get("log", []):
		_log.append(RenownEvent.from_dict(row))
	_next_order = int(d.get("next_order", _log.size()))
	_last_decayed_day = int(d.get("last_decayed_day", -1))
	# Replaying through the same _index/_apply the write path uses is what keeps
	# a loaded total identical to the one that was saved.
	for e in _log:
		_index(e)
		_apply(e)


func _current_scene_id() -> String:
	var cur := get_tree().current_scene
	return cur.scene_file_path if cur != null else ""
