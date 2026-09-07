class_name ChargenSteps
extends RefCounted
## The wizard's leaves, in canon order (docs/architecture-chargen-dramgid.md §7.1/§7.3;
## mono `character-creation.md` §Chargen Flow, with Flaw folded into Identity).
##
## The screen builds one page per entry and asks ChargenBuild.validate(id) for the gate,
## so adding or reordering a leaf is a data edit plus one page builder. Copy keeps the
## Registry's "Form 7" voice.

const STEPS: Array[Dictionary] = [
	{"id": &"ancestry", "name": "Ancestry", "title": "1. ANCESTRY",
		"registry_note": "Declare the lineage under which this person is to be indexed.",
		"illustration_title": "ILLUMINATED LINEAGE"},
	{"id": &"discipline", "name": "Discipline", "title": "2. DISCIPLINE",
		"registry_note": "Record how the body moves before any god takes notice of it.",
		"illustration_title": "THE FIRST SEAL"},
	{"id": &"patron", "name": "Patron", "title": "3. PATRON",
		"registry_note": "Record the patronage, its Kit, and the resource the applicant will answer to.",
		"illustration_title": "THE SECOND SEAL"},
	{"id": &"elements", "name": "Elements", "title": "4. ELEMENTS",
		"registry_note": "Enter major and minor affinities; opposing Clash marks invalidate this leaf.",
		"illustration_title": "THE WHEEL OF TEN"},
	{"id": &"attributes", "name": "Attributes", "title": "5. ATTRIBUTES",
		"registry_note": "Distribute the sanctioned twenty-two points; no measure may exceed five.",
		"illustration_title": "THE SEVEN MEASURES"},
	{"id": &"background", "name": "Background", "title": "6. BACKGROUND",
		"registry_note": "Record the history the applicant admits to, and the trades it left behind.",
		"illustration_title": "THE THIRD SEAL"},
	{"id": &"skills", "name": "Skills", "title": "7. SKILLS",
		"registry_note": "Spend the creation pool; the clerk prices each step by where it lands.",
		"illustration_title": "THE CLERK'S ABACUS"},
	{"id": &"identity", "name": "Identity", "title": "8. FLAW, NAME, AND LIKENESS",
		"registry_note": "Affix a likeness, enter the public name, and note any admitted complication.",
		"illustration_title": "PORTRAIT OF RECORD"},
	{"id": &"summary", "name": "Summary", "title": "9. THE COMPLETED FORM 7",
		"registry_note": "Review every leaf before the Registry stamp is struck.",
		"illustration_title": "READY FOR THE SEAL"},
]


static func count() -> int:
	return STEPS.size()


static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for step: Dictionary in STEPS:
		result.append(step["id"])
	return result


static func index_of(step_id: StringName) -> int:
	for index in STEPS.size():
		if STEPS[index]["id"] == step_id:
			return index
	return -1


static func at(index: int) -> Dictionary:
	return STEPS[index] if index >= 0 and index < STEPS.size() else {}


static func by_id(step_id: StringName) -> Dictionary:
	return at(index_of(step_id))
