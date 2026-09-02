class_name ClassResourceRegistry
extends RefCounted
## Patron id → ClassResource factory. B1–B10 each add one line to `_FACTORIES`.
##
## `PartyMember.patron` is the display form ("Maiiam", "Ofshütje"); `normalize_patron()` folds
## it to the vault's kebab id so content and code agree on one key. Unknown or empty patrons
## get `NullClassResource` — never null.

const PATRON_IDS: Array[StringName] = [
	&"maiiam", &"haeren", &"kero", &"stuid", &"vhorr",
	&"vicoar", &"ofshutje", &"pazzah", &"fickah", &"izhakel",
]

## Patron id → script. Classes without an implementation yet resolve to Null (they are listed
## in PATRON_IDS so the roster is visible; B1–B10 fill this table).
const _FACTORIES: Dictionary = {
	&"kero": preload("res://globals/combat/class_resources/ironbrand_scars.gd"),
	&"stuid": preload("res://globals/combat/class_resources/stuid_clarity.gd"),
	&"pazzah": preload("res://globals/combat/class_resources/pazzah_ledger.gd"),
	&"fickah": preload("res://globals/combat/class_resources/fickah_rule_breaker.gd"),
	&"ofshutje": preload("res://globals/combat/class_resources/ofshutje_attribution.gd"),
	&"izhakel": preload("res://globals/combat/class_resources/izhakel_threads.gd"),
}


static func normalize_patron(patron: Variant) -> StringName:
	var text := str(patron).strip_edges().to_lower()
	# Fold the one diacritic the vault uses in a patron name (Ofshütje → ofshutje).
	text = text.replace("ü", "u").replace("ö", "o").replace("ä", "a").replace("é", "e")
	return StringName(text)


static func is_known_patron(patron_id: StringName) -> bool:
	return PATRON_IDS.has(patron_id)


static func for_patron(patron: Variant) -> ClassResource:
	var patron_id := normalize_patron(patron)
	var script: GDScript = _FACTORIES.get(patron_id, null)
	var resource: ClassResource = script.new() if script != null else NullClassResource.new()
	resource.patron_id = patron_id if is_known_patron(patron_id) else &""
	return resource


## Rebuilds a resource from `ClassResource.to_dict()` output.
static func from_dict(data: Dictionary) -> ClassResource:
	var resource := for_patron(data.get("patron_id", ""))
	resource.from_dict(data)
	return resource
