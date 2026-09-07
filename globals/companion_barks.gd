class_name CompanionBarks
extends RefCounted
## Companion reactions to the protagonist hollowing and coming back (#286).
##
## `cosmology/souls.md` ("Reaching zero", ratified 2026-08-07) is explicit about
## why this surface exists at all: the husked "are not in pain and that is the
## horror of it — the people who love them can see there is no one home to be in
## pain." The hollowed protagonist has stopped volunteering, so they cannot
## narrate their own state. Somebody who travels with them has to.
##
## This is DATA, deliberately a read-only GDScript registry: one authored line
## per companion per transition. `ui/hud/consequence_notices.gd` is the only
## consumer, and it speaks exactly ONE of these lines per transition — a chorus
## would read as spectacle, and the vault's version of this moment is quiet.

## The two transitions `GameState.hollowing_state_changed` reports.
const HOLLOWED := &"hollowed"
const RETURNED := &"returned"

const OCCASIONS: Array[StringName] = [HOLLOWED, RETURNED]

## companion id -> occasion -> the single line that companion says.
##
## Canon constraints these lines are written against: recovery is done TO the
## husked by people who refuse to stop treating them as someone; it is never
## complete; and a soul brought back "never reads as bright again". So no
## RETURNED line celebrates, and none of them promises the price was refunded.
const BARKS: Dictionary = {
	# The River-Mother's whole discipline is the Name-Ledger, which restores a
	# Gauge by making a soul remembered. She is the one who says the name.
	"wyneth-hallow-tide": {
		HOLLOWED: "I have your name. I am keeping it until you want it back.",
		RETURNED: "There you are. I did not stop saying it, and I am not going to.",
	},
	# Vhorr's Husk-bearer has seen this arrive at the end of a rope before.
	"maura-greyfen": {
		HOLLOWED: "Don't look away from them. Looking away is how it finishes.",
		RETURNED: "Some of you came back. We work with the part that did.",
	},
	# The Mirrorblade reads the absence as a break in a line she was matching.
	"serai-lun": {
		HOLLOWED: "Your line went slack. I have been matching it for a year — I would know.",
		RETURNED: "Slower than it was. Still yours. I will take the slower one.",
	},
	# The Lensbearer's instinct is to write it down before it can be denied.
	"old-grumbrand": {
		HOLLOWED: "Filed under things I will argue about later. Keep walking.",
		RETURNED: "Amended. Same entry, thinner ink. I am not striking the old one.",
	},
	# The Locksmirk deflects, badly, which is her tell.
	"ressa-quickfingers": {
		HOLLOWED: "Say something rude. Anything. Go on — no? Fine. Fine.",
		RETURNED: "That was the worst company I have ever kept. Don't do it again.",
	},
	# The Ironbrand answers a hollowing the way he answers everything: posture.
	"korrath-ninefold": {
		HOLLOWED: "Stand at my shoulder. I will hold the side you have stopped watching.",
		RETURNED: "Back on your own shoulder, then. I kept it warm.",
	},
}


static func has_line(companion_id: String, occasion: StringName) -> bool:
	return not line(companion_id, occasion).is_empty()


static func line(companion_id: String, occasion: StringName) -> String:
	if not BARKS.has(companion_id):
		return ""
	var lines: Dictionary = BARKS[companion_id]
	return str(lines.get(occasion, ""))


## The one companion who speaks, and what they say.
##
## Returns {} when nobody in the party has an authored line for the occasion —
## a hollowing with no witness is SILENT on purpose. Canon makes being witnessed
## the whole mechanism of recovery, so travelling alone into the state should
## not produce a line from nowhere.
##
## Party order is the player's own tavern ordering, so the speaker is
## deterministic and legible rather than random.
static func speaker(companions: Array[PartyMember], occasion: StringName) -> Dictionary:
	for member: PartyMember in companions:
		if member == null:
			continue
		var spoken := line(member.id, occasion)
		if spoken.is_empty():
			continue
		return {
			"companion_id": member.id,
			"display_name": member.display_name,
			"line": spoken,
		}
	return {}


## The occasion name for a `hollowing_state_changed(active)` payload.
static func occasion_for(active: bool) -> StringName:
	return HOLLOWED if active else RETURNED


static func bark_count() -> int:
	return BARKS.size()
