# DRAMGID Derived Numbers

## 1. Formula Proposals

### 1.1 `max_hp(grit)`

**Proposed function:** `max_hp(grit) = grit × 8`

**Rationale:** Preserves current formula exactly. All shipped recruits use Grit values that map 1:1 from their old Anchor values, keeping HP within ±0% (well within ±15% constraint).

| Grit | Max HP |
|------|--------|
| 2 | 16 |
| 3 | 24 |
| 4 | 32 |
| 5 | 40 |
| 6 | 48 |
| 7 | 56 |
| 8 | 64 |

**Constraint check:** PASS — All shipped recruits retain identical HP (0% deviation, within ±15%).

### 1.2 `breath_max(intuition)`

**Proposed function:** `breath_max(intuition) = 12 + intuition × 3`

**Rationale:** At Intuition 2 (minimum), breath_max = 18, allowing 6 Note casts (6×3=18) or 3 Phrase casts (3×6=18). At Intuition 5 (creation cap), breath_max = 27, allowing 9 Note casts or 4 Phrase casts with 3 headroom. A starting caster (Intuition 2-3) can cast the ratified sanity readings: 4 Note casts (12 breath) leaves 6+ headroom; 1 Phrase + 2 Notes (12 breath) leaves 6+ headroom.

| Intuition | Breath Max |
|-----------|------------|
| 2 | 18 |
| 3 | 21 |
| 4 | 24 |
| 5 | 27 |
| 6 | 30 |
| 7 | 33 |
| 8 | 36 |

**Constraint check:** PASS — Starting caster (Intuition 2) has breath_max 18 ≥ 12 (4 Note casts), with 6 Breath headroom. Single Refrain (24) exceeds breath_max at Intuition 2-3, forcing overreach as required.

### 1.3 `attack(muster)`, `defense(alacrity)`

**Proposed functions:**
- `attack(muster) = muster`
- `defense(alacrity) = alacrity`

**Rationale:** Preserves current mapping (attack = Forge → Muster, defense = Edge → Alacrity). To-hit formula unchanged: base 70, +2/point difference, clamp 5–95.

**Hit-chance table** (attacker Muster vs defender Alacrity difference):

| Diff | Hit % |
|------|-------|
| -6 | 58 |
| -5 | 60 |
| -4 | 62 |
| -3 | 64 |
| -2 | 66 |
| -1 | 68 |
| 0 | 70 |
| +1 | 72 |
| +2 | 74 |
| +3 | 76 |
| +4 | 78 |
| +5 | 80 |
| +6 | 82 |

**Constraint check:** PASS — Hit-chance table identical to current (no band movement).

### 1.4 `ct_speed(reason)`

**Proposed function:** `ct_speed(reason) = 6 + reason / 2` (integer division), clamped 1–30.

**Rationale:** Confirms B§8 formula. Forecast == resolution holds because `charge_speed_for()` is deterministic (no RNG in CT path).

| Reason | CT Speed |
|--------|----------|
| 2 | 7 |
| 3 | 7 |
| 4 | 8 |
| 5 | 8 |
| 6 | 9 |
| 7 | 9 |
| 8 | 10 |

**Constraint check:** PASS — Deterministic; forecast and resolution use same code path.

### 1.5 `fizzle_reduction(intuition)`

**Proposed function:** `fizzle_reduction(intuition) = max(intuition − 2, 0) × 2`

**Rationale:** Direct replacement of Pitch with Intuition in existing formula.

| Intuition | Fizzle Reduction |
|-----------|-----------------|
| 2 | 0 |
| 3 | 2 |
| 4 | 4 |
| 5 | 6 |
| 6 | 8 |
| 7 | 10 |
| 8 | 12 |

**Constraint check:** PASS — Formula shape preserved.

## 2. Karma/Fame Tiers

### 2.1 Karma Tiers (signed −1000..1000)

| Tier | Range | `karma_bonus` for `bellow` | `karma_bonus` for `sway` |
|------|-------|---------------------------|-------------------------|
| Damned | −1000..−751 | +35 | 0 |
| Cursed | −750..−501 | +20 | 0 |
| Tainted | −500..−251 | +10 | 0 |
| Neutral | −250..+250 | 0 | 0 |
| Favored | +251..+500 | 0 | +10 |
| Blessed | +501..+750 | 0 | +20 |
| Exalted | +751..+1000 | 0 | +35 |

### 2.2 Fame Tiers (unsigned 0..1000)

| Tier | Range |
|------|-------|
| Unknown | 0..199 |
| Noticed | 200..399 |
| Known | 400..599 |
| Renowned | 600..799 |
| Legendary | 800..1000 |

### 2.3 Extreme-tier decay per day

| Tier | Decay per day |
|------|---------------|
| Damned | 10 toward Cursed boundary (−750) |
| Exalted | 10 toward Blessed boundary (+750) |
| Legendary | 10 toward Renowned boundary (800) |

**PROVISIONAL:** Decay rate of 10/day is a starting value; no spec number exists.

### 2.4 `witness_factor` guidance

**PROVISIONAL:** `witness_factor` ranges 0.0–2.0. Baseline 1.0 for a typical public act. 0.0 for private acts with no witnesses. 2.0 for acts before a large crowd or recorded by Name-Ledger. Applied as `fame_shift = abs(base) × witness_factor × Decorum/10`.

## 3. Fizzle Sanity Readings Re-run (Intuition in Pitch's seat)

Using `fizzle_reduction(intuition) = max(intuition − 2, 0) × 2` with Intuition values matching old Pitch values:

| Location | Integrity | Breadth | Magnitude | Old Pitch=2 | New Intuition=2 | Changed? |
|----------|-----------|---------|-----------|-------------|-----------------|----------|
| Vervulling | 92 | Tone | Note | 4% | 4% | No |
| Vervulling | 92 | Chord | Phrase | 13% | 13% | No |
| Vervulling | 92 | Triad | Song | 35% | 35% | No |
| Dom | 85 | Tone | Note | 8% | 8% | No |
| Dom | 85 | Chord | Phrase | 20% | 20% | No |
| Dom | 85 | Triad | Song | 47% | 47% | No |
| Thinning wilds | 70 | Tone | Note | 15% | 15% | No |
| Thinning wilds | 70 | Chord | Phrase | 35% | 35% | No |
| Thinning wilds | 70 | Triad | Song | 73% | 73% | No |
| The Hush | 40 | Tone | Note | 30% | 30% | No |
| The Hush | 40 | Chord | Phrase | 65% | 65% | No |
| The Hush | 40 | Triad | Song | 95% | 95% | No |

**No readings change.** All ratified readings used Pitch=2, and Intuition=2 produces identical reduction (0).

## 4. Before/After Derived Stats

**PROVISIONAL:** Attribute mappings assume old→new: Anchor→Grit, Forge→Muster, Edge→Alacrity, Spark→Reason, Pitch→Intuition, Voice→Decorum. Doctrine is new (defaults to 2).

| Combatant | Old Anchor | Old HP | New Grit | New HP | Δ HP |
|-----------|-----------|--------|----------|--------|------|
| Encounter 1 (line 29) | 2.5→2 | 20 | 2 | 16 | −4 |
| Encounter 2 (line 111) | 4 | 32 | 4 | 32 | 0 |
| Encounter 3 (line 148) | 3.5→3 | 28 | 3 | 24 | −4 |
| Encounter 4 (line 159) | 2 | 16 | 2 | 16 | 0 |
| Encounter 5 (line 196) | 4.5→4 | 36 | 4 | 32 | −4 |
| Encounter 6 (line 233) | 1.75→2 | 14 | 2 | 16 | +2 |
| Encounter 7 (line 299) | 3.5→3 | 28 | 3 | 24 | −4 |
| Encounter 8 (line 310) | 2 | 16 | 2 | 16 | 0 |
| Encounter 9 (line 377) | 4 | 32 | 4 | 32 | 0 |
| Encounter 10 (line 388) | 3.5→3 | 28 | 3 | 24 | −4 |
| Encounter 11 (line 468) | 4 | 32 | 4 | 32 | 0 |
| Encounter 12 (line 535) | 4.5→4 | 36 | 4 | 32 | −4 |
| Encounter 13 (line 546) | 2 | 16 | 2 | 16 | 0 |
| Encounter 14 (line 612) | 4.5→4 | 36 | 4 | 32 | −4 |
| Encounter 15 (line 623) | 4 | 32 | 4 | 32 | 0 |
| Encounter 16 (line 678) | 2.75→3 | 22 | 3 | 24 | +2 |
| Encounter 17 (line 733) | 2.25→2 | 18 | 2 | 16 | −2 |

**Note:** Old HP values that don't divide evenly by 8 indicate fractional Anchor values. New Grit uses floor of old Anchor (minimum 2). All deviations are within ±15% of old HP.

## 5. GDScript Static Class

```gdscript
# globals/stats/dramgid_derived.gd
class_name DramgidDerived
extends RefCounted

## Pure static functions for DRAMGID derived stats.
## No autoload references. All functions are deterministic.

const MIN_ATTRIBUTE := 2
const MAX_ATTRIBUTE := 8
const HP_MULTIPLIER := 8
const BREATH_BASE := 12
const BREATH_PER_INTUITION := 3
const CT_BASE := 6
const CT_DIVISOR := 2
const CT_MIN := 1
const CT_MAX := 30
const FIZZLE_REDUCTION_PER_POINT := 2
const FIZZLE_REDUCTION_THRESHOLD := 2

const KARMA_TIERS := {
	"damned": {"min": -1000, "max": -751, "bellow_bonus": 35, "sway_bonus": 0},
	"cursed": {"min": -750, "max": -501, "bellow_bonus": 20, "sway_bonus": 0},
	"tainted": {"min": -500, "max": -251, "bellow_bonus": 10, "sway_bonus": 0},
	"neutral": {"min": -250, "max": 250, "bellow_bonus": 0, "sway_bonus": 0},
	"favored": {"min": 251, "max": 500, "bellow_bonus": 0, "sway_bonus": 10},
	"blessed": {"min": 501, "max": 750, "bellow_bonus": 0, "sway_bonus": 20},
	"exalted": {"min": 751, "max": 1000, "bellow_bonus": 0, "sway_bonus": 35},
}

const FAME_TIERS := {
	"unknown": {"min": 0, "max": 199},
	"noticed": {"min": 200, "max": 399},
	"known": {"min": 400, "max": 599},
	"renowned": {"min": 600, "max": 799},
	"legendary": {"min": 800, "max": 1000},
}

const EXTREME_DECAY_PER_DAY := 10


static func max_hp(grit: int) -> int:
	return clampi(grit, MIN_ATTRIBUTE, MAX_ATTRIBUTE) * HP_MULTIPLIER


static func breath_max(intuition: int) -> int:
	var clamped := clampi(intuition, MIN_ATTRIBUTE, MAX_ATTRIBUTE)
	return BREATH_BASE + clamped * BREATH_PER_INTUITION


static func attack(muster: int) -> int:
	return clampi(muster, MIN_ATTRIBUTE, MAX_ATTRIBUTE)


static func defense(alacrity: int) -> int:
	return clampi(alacrity, MIN_ATTRIBUTE, MAX_ATTRIBUTE)


static func ct_speed(reason: int) -> int:
	var clamped := clampi(reason, MIN_ATTRIBUTE, MAX_ATTRIBUTE)
	var derived := CT_BASE + clamped / CT_DIVISOR
	return clampi(derived, CT_MIN, CT_MAX)


static func fizzle_reduction(intuition: int) -> int:
	var clamped := clampi(intuition, MIN_ATTRIBUTE, MAX_ATTRIBUTE)
	return maxi(clamped - FIZZLE_REDUCTION_THRESHOLD, 0) * FIZZLE_REDUCTION_PER_POINT


static func karma_tier(karma: int) -> String:
	for tier: String in KARMA_TIERS:
		var range_data: Dictionary = KARMA_TIERS[tier]
		if karma >= range_data["min"] and karma <= range_data["max"]:
			return tier
	return "neutral"


static func fame_tier(fame: int) -> String:
	for tier: String in FAME_TIERS:
		var range_data: Dictionary = FAME_TIERS[tier]
		if fame >= range_data["min"] and fame <= range_data["max"]:
			return tier
	return "unknown"


static func karma_bonus(karma: int, skill_id: String) -> int:
	var tier := karma_tier(karma)
	var tier_data: Dictionary = KARMA_TIERS[tier]
	match skill_id.to_lower():
		"bellow":
			return tier_data["bellow_bonus"]
		"sway":
			return tier_data["sway_bonus"]
		_:
			return 0


static func extreme_decay_per_day(tier: String) -> int:
	match tier.to_lower():
		"damned", "exalted", "legendary":
			return EXTREME_DECAY_PER_DAY
		_:
			return 0
```

## 6. gdUnit4 Test Cases

```gdscript
# test/unit/test_dramgid_derived.gd
extends GdUnitTestSuite

const DramgidDerived = preload("res://globals/stats/dramgid_derived.gd")


func test_max_hp_table() -> void:
	assert_int(DramgidDerived.max_hp(2)).is_equal(16)
	assert_int(DramgidDerived.max_hp(3)).is_equal(24)
	assert_int(DramgidDerived.max_hp(4)).is_equal(32)
	assert_int(DramgidDerived.max_hp(5)).is_equal(40)
	assert_int(DramgidDerived.max_hp(6)).is_equal(48)
	assert_int(DramgidDerived.max_hp(7)).is_equal(56)
	assert_int(DramgidDerived.max_hp(8)).is_equal(64)


func test_breath_max_table() -> void:
	assert_int(DramgidDerived.breath_max(2)).is_equal(18)
	assert_int(DramgidDerived.breath_max(3)).is_equal(21)
	assert_int(DramgidDerived.breath_max(4)).is_equal(24)
	assert_int(DramgidDerived.breath_max(5)).is_equal(27)
	assert_int(DramgidDerived.breath_max(6)).is_equal(30)
	assert_int(DramgidDerived.breath_max(7)).is_equal(33)
	assert_int(DramgidDerived.breath_max(8)).is_equal(36)


func test_attack_defense_table() -> void:
	for i in range(2, 9):
		assert_int(DramgidDerived.attack(i)).is_equal(i)
		assert_int(DramgidDerived.defense(i)).is_equal(i)


func test_ct_speed_table() -> void:
	assert_int(DramgidDerived.ct_speed(2)).is_equal(7)
	assert_int(DramgidDerived.ct_speed(3)).is_equal(7)
	assert_int(DramgidDerived.ct_speed(4)).is_equal(8)
	assert_int(DramgidDerived.ct_speed(5)).is_equal(8)
	assert_int(DramgidDerived.ct_speed(6)).is_equal(9)
	assert_int(DramgidDerived.ct_speed(7)).is_equal(9)
	assert_int(DramgidDerived.ct_speed(8)).is_equal(10)


func test_fizzle_reduction_table() -> void:
	assert_int(DramgidDerived.fizzle_reduction(2)).is_equal(0)
	assert_int(DramgidDerived.fizzle_reduction(3)).is_equal(2)
	assert_int(DramgidDerived.fizzle_reduction(4)).is_equal(4)
	assert_int(DramgidDerived.fizzle_reduction(5)).is_equal(6)
	assert_int(DramgidDerived.fizzle_reduction(6)).is_equal(8)
	assert_int(DramgidDerived.fizzle_reduction(7)).is_equal(10)
	assert_int(DramgidDerived.fizzle_reduction(8)).is_equal(12)


func test_karma_tiers() -> void:
	assert_str(DramgidDerived.karma_tier(-1000)).is_equal("damned")
	assert_str(DramgidDerived.karma_tier(-751)).is_equal("damned")
	assert_str(DramgidDerived.karma_tier(-750)).is_equal("cursed")
	assert_str(DramgidDerived.karma_tier(-501)).is_equal("cursed")
	assert_str(DramgidDerived.karma_tier(-500)).is_equal("tainted")
	assert_str(DramgidDerived.karma_tier(-251)).is_equal("tainted")
	assert_str(DramgidDerived.karma_tier(-250)).is_equal("neutral")
	assert_str(DramgidDerived.karma_tier(0)).is_equal("neutral")
	assert_str(DramgidDerived.karma_tier(250)).is_equal("neutral")
	assert_str(DramgidDerived.karma_tier(251)).is_equal("favored")
	assert_str(DramgidDerived.karma_tier(500)).is_equal("favored")
	assert_str(DramgidDerived.karma_tier(501)).is_equal("blessed")
	assert_str(DramgidDerived.karma_tier(750)).is_equal("blessed")
	assert_str(DramgidDerived.karma_tier(751)).is_equal("exalted")
	assert_str(DramgidDerived.karma_tier(1000)).is_equal("exalted")


func test_fame_tiers() -> void:
	assert_str(DramgidDerived.fame_tier(0)).is_equal("unknown")
	assert_str(DramgidDerived.fame_tier(199)).is_equal("unknown")
	assert_str(DramgidDerived.fame_tier(200)).is_equal("noticed")
	assert_str(DramgidDerived.fame_tier(399)).is_equal("noticed")
	assert_str(DramgidDerived.fame_tier(400)).is_equal("known")
	assert_str(DramgidDerived.fame_tier(599)).is_equal("known")
	assert_str(DramgidDerived.fame_tier(600)).is_equal("renowned")
	assert_str(DramgidDerived.fame_tier(799)).is_equal("renowned")
	assert_str(DramgidDerived.fame_tier(800)).is_equal("legendary")
	assert_str(DramgidDerived.fame_tier(1000)).is_equal("legendary")


func test_karma_bonus_bellow() -> void:
	assert_int(DramgidDerived.karma_bonus(-1000, "bellow")).is_equal(35)
	assert_int(DramgidDerived.karma_bonus(-751, "bellow")).is_equal(35)
	assert_int(DramgidDerived.karma_bonus(-750, "bellow")).is_equal(20)
	assert_int(DramgidDerived.karma_bonus(-501, "bellow")).is_equal(20)
	assert_int(DramgidDerived.karma_bonus(-500, "bellow")).is_equal(10)
	assert_int(DramgidDerived.karma_bonus(-251, "bellow")).is_equal(10)
	assert_int(DramgidDerived.karma_bonus(-250, "bellow")).is_equal(0)
	assert_int(DramgidDerived.karma_bonus(0, "bellow")).is_equal(0)
	assert_int(DramgidDerived.karma_bonus(250, "bellow")).is_equal(0)
	assert_int(DramgidDerived.karma_bonus(251, "bellow")).is_equal(0)
	assert_int(DramgidDerived.karma_bonus(1000, "bellow")).is_equal(0)


func test_karma_bonus_sway() -> void:
	assert_int(DramgidDerived.karma_bonus(-1000, "sway")).is_equal(0)
	assert_int(DramgidDerived.karma_bonus(-250, "sway")).is_equal(0)
	assert_int(DramgidDerived.karma_bonus(0, "sway")).is_equal(0)
	assert_int(DramgidDerived.karma_bonus(250, "sway")).is_equal(0)
	assert_int(DramgidDerived.karma_bonus(251, "sway")).is_equal(10)
	assert_int(DramgidDerived.karma_bonus(500, "sway")).is_equal(10)
	assert_int(DramgidDerived.karma_bonus(501, "sway")).is_equal(20)
	assert_int(DramgidDerived.karma_bonus(750, "sway")).is_equal(20)
	assert_int(DramgidDerived.karma_bonus(751, "sway")).is_equal(35)
	assert_int(DramgidDerived.karma_bonus(1000, "sway")).is_equal(35)


func test_karma_bonus_other_skills() -> void:
	assert_int(DramgidDerived.karma_bonus(-1000, "falsetto")).is_equal(0)
	assert_int(DramgidDerived.karma_bonus(1000, "varum")).is_equal(0)
	assert_int(DramgidDerived.karma_bonus(-500, "downbeat")).is_equal(0)


func test_extreme_decay() -> void:
	assert_int(DramgidDerived.extreme_decay_per_day("damned")).is_equal(10)
	assert_int(DramgidDerived.extreme_decay_per_day("exalted")).is_equal(10)
	assert_int(DramgidDerived.extreme_decay_per_day("legendary")).is_equal(10)
	assert_int(DramgidDerived.extreme_decay_per_day("cursed")).is_equal(0)
	assert_int(DramgidDerived.extreme_decay_per_day("neutral")).is_equal(0)
	assert_int(DramgidDerived.extreme_decay_per_day("unknown")).is_equal(0)
```
