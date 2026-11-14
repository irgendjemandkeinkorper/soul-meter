class_name CommandIcons
extends RefCounted
## The glyph on a combat command tile (owner 2026-11-02, item 33 follow-up: "abilities behind
## icons with a hover tooltip"). Placeholder glyphs from the #298 icon set, still under the
## owner's art review: a spell or weapon art with a tone shows its Wheel tone, and every other
## command shows its battle-command glyph by kind. The chargen ability tiles (PR #563) use the
## same rule; the two can share this table once both stacks land.

const ELEMENT_ICON := "res://assets/icons/png/64/elements/%s.png"
const COMMAND_ICON := "res://assets/icons/png/64/commands/%s.png"


static func for_action(action: CombatAction) -> Texture2D:
	if action == null:
		return null
	var tone := String(action.element_id)
	if not tone.is_empty() and ResourceLoader.exists(ELEMENT_ICON % tone):
		return load(ELEMENT_ICON % tone) as Texture2D
	return load(COMMAND_ICON % glyph_for(action)) as Texture2D


## The command glyph's file name for an action without a tone icon.
static func glyph_for(action: CombatAction) -> String:
	if not action.class_resource_action.is_empty():
		# A class command spends the class's own resource: the focus glyph, not a weapon.
		return "focus"
	match action.kind:
		CombatAction.Kind.GUARD:
			return "guard"
		CombatAction.Kind.STABILIZE:
			return "focus" if action.id == &"focus" else "stabilize"
		CombatAction.Kind.DEFINING_STRIKE:
			return "definition"
		CombatAction.Kind.CAST:
			return "cast"
		CombatAction.Kind.MOVE:
			return "move"
		CombatAction.Kind.PASS:
			return "speak" if action.verb == CombatAction.Verb.SPEECH else "end-turn"
		CombatAction.Kind.RESOLUTION:
			match action.verb:
				CombatAction.Verb.SPEECH:
					return "speak"
				CombatAction.Verb.ITEM:
					return "item"
			return "stabilize"
	if action.id == &"paradox":
		return "paradox"
	return "strike" if action.target_profile == &"melee" else "target"
