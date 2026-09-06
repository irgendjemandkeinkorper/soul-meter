class_name ClassCatalog
extends RefCounted
## The ten patron classes as chargen/sheet data (docs/architecture-chargen-dramgid.md §6).
##
## Read-only, PROVISIONAL until Pandora `Classes` carries these columns and a generator
## emits them. Copy is lifted from mono `04-world/systems/ten-patron-classes.md` one-liners
## and is marked for canon review, the same rule the recruit bios follow.
##
## Vocabulary (owner ruling R4): `patron` is the deity DISPLAY name ("Kero") — the roster's
## convention, what `GameState.has_party_patron()` compares and what
## `ClassResourceRegistry.normalize_patron()` folds; `patron_id` is the registry's kebab id;
## `id` is the class id ("ironbrand") that `PartyMember.class_id` stores.
##
## `kit_skills` names the ARMS skill(s) the Kit trains (`DramgidSchema.ARMS_SKILL_IDS`);
## more than one entry means the class card offers a choice (Ironbrand: greatsword or
## spiked gauntlet). `retired_disciplines` / `watch_disciplines` mirror the 3x10
## compatibility sheet recorded in ten-patron-classes.md (2026-08-07): Threadwalker x
## Chordblade is retired outright; the two watch cells are allowed with a note.

const ALL: Array[Dictionary] = [
	{
		"id": "mirrorblade", "name": "Mirrorblade", "patron": "Maiiam", "patron_id": "maiiam",
		"role": "Duelist", "vault_id": "maiiam",
		"kit": "Paired balanced daggers, Mirrorwalking footwork.", "kit_skills": ["keen"],
		"resource": "Balance",
		"resource_blurb": "Alternate strike and guard, advance and withdraw, to stay Balanced; spam one side and you go Unbalanced.",
		"signature": "Reflection",
		"signature_blurb": "Once per encounter, redirect an incoming spell effect back at its caster at reduced power.",
		"suggested_major": "vekh", "suggested_minor": "tham", "chord": "The Deep",
		"retired_disciplines": [], "watch_disciplines": [], "notes": "",
	},
	{
		"id": "river-mother", "name": "River-Mother", "patron": "Haeren", "patron_id": "haeren",
		"role": "Support", "vault_id": "haeren",
		"kit": "Water harp, net-and-whip, hospice tools doubling as battlefield medicine.", "kit_skills": ["reach"],
		"resource": "The Name-Ledger",
		"resource_blurb": "Recording a fallen or saved ally's name mid-fight refunds Soul Gauge.",
		"signature": "Last Washing",
		"signature_blurb": "When an ally hits 0 HP, spend a Ledger entry to stabilize them instead of a normal death save.",
		"suggested_major": "luth", "suggested_minor": "vel", "chord": "The Green Tide",
		"retired_disciplines": [], "watch_disciplines": [], "notes": "",
	},
	{
		"id": "ironbrand", "name": "Ironbrand", "patron": "Kero", "patron_id": "kero",
		"role": "Berserker", "vault_id": "kero",
		"kit": "Greatsword or spiked gauntlet, ritual branding.", "kit_skills": ["heft", "grip"],
		"resource": "Scars",
		"resource_blurb": "Taking damage banks Scars; spend them to buy guaranteed-hit or guaranteed-crit windows.",
		"signature": "Debt of Arms",
		"signature_blurb": "Trade a chunk of your own current HP for a massive damage or buff spike on yourself or an ally.",
		"suggested_major": "khash", "suggested_minor": "mozh", "chord": "Ashfire",
		"retired_disciplines": [], "watch_disciplines": [], "notes": "",
	},
	{
		"id": "lensbearer", "name": "Lensbearer", "patron": "Stuid", "patron_id": "stuid",
		"role": "Buffer/Debuffer", "vault_id": "stuid",
		"kit": "Quarterstaff, precision monocle.", "kit_skills": ["reach"],
		"resource": "Fading",
		"resource_blurb": "A slowly-depleting personal stat, burned for guaranteed information: true fizzle, hidden resistances, a trap.",
		"signature": "Sacred Clarity",
		"signature_blurb": "Force a target's next action to be telegraphed to the whole party, at Fading cost.",
		"suggested_major": "sul", "suggested_minor": "vel", "chord": "Verdance",
		"retired_disciplines": [], "watch_disciplines": [], "notes": "",
	},
	{
		"id": "husk-bearer", "name": "Husk-bearer", "patron": "Vhorr", "patron_id": "vhorr",
		"role": "DoT controller", "vault_id": "vhorr",
		"kit": "Cleaver or sickle, gut-lute.", "kit_skills": ["keen"],
		"resource": "The Table",
		"resource_blurb": "Every damage-over-time tick you have active stacks Hunger; the more that is dying, the harder you hit.",
		"signature": "Nothing Wasted",
		"signature_blurb": "Any kill from a DoT you applied refunds Gauge proportional to the ticks dealt.",
		"suggested_major": "mozh", "suggested_minor": "vekh", "chord": "The Grave",
		"retired_disciplines": [], "watch_disciplines": [], "notes": "",
	},
	{
		"id": "flamebinder", "name": "Flamebinder", "patron": "Vicoar", "patron_id": "vicoar",
		"role": "Artificer", "vault_id": "vicoar",
		"kit": "War pick, deployable kinetic-sculpture constructs.", "kit_skills": ["heft"],
		"resource": "Instructive Failure",
		"resource_blurb": "A failed cast banks a token; spend it to guarantee your next cast of that spell.",
		"signature": "Second Casting",
		"signature_blurb": "Once per encounter, spend two banked tokens to turn a fizzle into a success after the fact.",
		"suggested_major": "tham", "suggested_minor": "khor", "chord": "The Ringing Stone",
		"retired_disciplines": [], "watch_disciplines": [], "notes": "",
	},
	{
		"id": "stormbearer", "name": "Stormbearer", "patron": "Ofshütje", "patron_id": "ofshutje",
		"role": "Skirmisher", "vault_id": "ofshutje",
		"kit": "Greatclub, cloud-drum call-and-response attacks.", "kit_skills": ["heft"],
		"resource": "Attribution",
		"resource_blurb": "Your biggest effects fire semi-randomly off a hidden table; the floor is strong, the ceiling unpredictable.",
		"signature": "Tuned Thunder",
		"signature_blurb": "Whenever an ability crits it chains into a second, random effect.",
		"suggested_major": "zhur", "suggested_minor": "sul", "chord": "The Levin",
		"retired_disciplines": [], "watch_disciplines": [], "notes": "",
	},
	{
		"id": "oathclock", "name": "Oathclock", "patron": "Pazzah", "patron_id": "pazzah",
		"role": "Controller", "vault_id": "pazzah",
		"kit": "Halberd, pendulum bell — a metronome weapon doubling as a Song-timing tool.", "kit_skills": ["reach"],
		"resource": "The Ledger",
		"resource_blurb": "Queue a debuff, a damage-over-time or a trap to trigger N turns from now, no matter what happens between.",
		"signature": "Sequenced Verdict",
		"signature_blurb": "Bank a devastating delayed effect that resolves on a fixed future turn regardless of the target's preparation.",
		"suggested_major": "zhem", "suggested_minor": "khash", "chord": "Emberquiet",
		"retired_disciplines": [], "watch_disciplines": ["hushwarden"],
		"notes": "Oathclock x Hushwarden stacks a queue against a tax — allowed, under watch.",
	},
	{
		"id": "locksmirk", "name": "Locksmirk", "patron": "Fickah", "patron_id": "fickah",
		"role": "Trickster", "vault_id": "fickah",
		"kit": "Blowgun, trap poetry, lockpicking-as-combat.", "kit_skills": ["loose"],
		"resource": "Rule-breaker",
		"resource_blurb": "Fickah casters never reach 0% fizzle, Mastery included; in exchange, a unique action no other class gets.",
		"signature": "Jam the Gears",
		"signature_blurb": "Force-break an enemy's in-progress Song or Refrain outright, at a Gauge cost.",
		"suggested_major": "", "suggested_minor": "", "chord": "",
		"retired_disciplines": [], "watch_disciplines": ["hushwarden"],
		"notes": "Genuinely flexible: no suggested elements. Never reaches 0% fizzle. Locksmirk x Hushwarden compounds two fizzle effects — allowed, under watch.",
	},
	{
		"id": "threadwalker", "name": "Threadwalker", "patron": "Izhakel", "patron_id": "izhakel",
		"role": "Summoner/Debuffer", "vault_id": "izhakel",
		"kit": "Whip-dagger, glass chimes that passively reveal enemy resource pools.", "kit_skills": ["keen"],
		"resource": "Threads",
		"resource_blurb": "Bind a hidden Contract to a target; violating it triggers a payoff later.",
		"signature": "The Unspoken Term",
		"signature_blurb": "Bind up to three Threads across the field and cash them in on your own terms.",
		"suggested_major": "vekh", "suggested_minor": "mozh", "chord": "The Grave",
		"retired_disciplines": ["chordblade"], "watch_disciplines": [],
		"notes": "Threadwalker x Chordblade is retired (2026-08-07): reach is identical under every Discipline, so none can grant or withhold it.",
	},
]


static func ids() -> PackedStringArray:
	var result := PackedStringArray()
	for entry: Dictionary in ALL:
		result.append(str(entry["id"]))
	return result


static func by_id(class_id: String) -> Dictionary:
	for entry: Dictionary in ALL:
		if str(entry["id"]) == class_id:
			return entry
	return {}


## Deity display name for a class id ("ironbrand" → "Kero"); "" when unknown.
static func patron_for(class_id: String) -> String:
	return str(by_id(class_id).get("patron", ""))


## Accepts either vocabulary — a class id ("ironbrand"), a deity display name ("Kero",
## "Ofshütje") or a registry id ("ofshutje") — and returns the class row. Used by the v8
## migration and by anything that meets a pre-ruling save.
static func class_for_patron_value(value: String) -> Dictionary:
	var needle := value.strip_edges().to_lower().replace("ü", "u")
	if needle.is_empty():
		return {}
	for entry: Dictionary in ALL:
		if str(entry["id"]) == needle:
			return entry
		if str(entry["patron"]).to_lower().replace("ü", "u") == needle:
			return entry
		if str(entry["patron_id"]) == needle:
			return entry
	return {}


## The display string the roster uses ("Ironbrand (Kero)").
static func display_class(class_id: String) -> String:
	var entry := by_id(class_id)
	if entry.is_empty():
		return ""
	return "%s (%s)" % [entry["name"], entry["patron"]]


static func default_kit_skill(class_id: String) -> String:
	var kit_skills: Array = by_id(class_id).get("kit_skills", [])
	return str(kit_skills[0]) if not kit_skills.is_empty() else ""


static func offers_kit_choice(class_id: String) -> bool:
	return (by_id(class_id).get("kit_skills", []) as Array).size() > 1


static func is_retired_pairing(class_id: String, discipline_id: String) -> bool:
	return discipline_id in (by_id(class_id).get("retired_disciplines", []) as Array)


static func is_watch_pairing(class_id: String, discipline_id: String) -> bool:
	return discipline_id in (by_id(class_id).get("watch_disciplines", []) as Array)
