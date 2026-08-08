extends Node
## seed_element_matrix.gd — idempotent Pandora migration for the element
## interaction table (#136), the ratified wheel-distance gamble curve.
##
## AUTHORED DATA ONLY. This seeds the *multipliers*; it never enumerates the
## 100 ordered element pairs. The topology is derived from `ElementWheel.ORDER`
## by tools/generate_element_matrix.gd, so a rebalance touches these rows and
## nothing else.
##
## TWO AXES, TWO TABLES, DELIBERATELY SEPARATE (see docs/prd-amendment-tactical-layer.md
## §9.2 and the vault's systems/magic-system.md §"Target relation — the gamble curve"):
##   - axis "target": wheel distance from the working's element to the TARGET's
##     attunement. Prices damage, adds fizzle percentage points, and charges Soul
##     on failure. This is the resolve-time axis.
##   - axis "caster": wheel distance from the working's element to the CASTER's
##     attunement. Prices the CHORD bonus only. This is a compose-time axis and
##     it must never be looked up in the target table, nor the reverse.
##
## The caster-side composition-span ladder (`strain_add` / `var_cost`) lives in
## the Fizzle Tables root and CompositionResolver and is NOT touched here. It
## measures a different thing (span between composed elements, no target), and
## sharing a number between it and these rows is the exact bug #136 exists to
## prevent.
##
## Values are PROVISIONAL (GitHub #133, second tuning pass tracked in
## docs/prd-amendment-tactical-layer.md §1.1). The SHAPE is canon.
##
## Run: GODOT_BIN=~/.local/bin/godot bash scripts/seed_element_matrix.sh

const ROOT_NAME := "Element Relations"
const VAULT_ID := "magic-system"
const RELATION_PROPERTIES := [
	["Display Name", "string"],
	["Vault Id", "string"],
	["Relation Id", "string"],
	["Axis", "string"],
	["Distance", "int"],
	["Damage Multiplier", "float"],
	["Fizzle Add", "float"],
	["Soul On Failure", "int"],
	["Provisional", "bool"],
]

## [entity name, relation id, axis, distance, damage x, fizzle +pp, soul on failure]
const RELATION_ROWS := [
	# --- resolve-time axis: distance to the TARGET's attunement ---
	["Same", "same", "target", 0, 0.5, 0.0, 0],
	["Neighbour", "neighbour", "target", 1, 0.75, 3.0, 0],
	["Neutral (2 Steps)", "neutral", "target", 2, 1.0, 6.0, 1],
	["Neutral (3 Steps)", "neutral", "target", 3, 1.1, 9.0, 2],
	["Neutral (4 Steps)", "neutral", "target", 4, 1.2, 12.0, 3],
	["Clash (Opposed)", "clash", "target", 5, 1.35, 15.0, 5],
	# --- compose-time axis: distance to the CASTER's attunement ---
	# Only adjacency is priced. The rest are authored as explicit identities so
	# the caster table is total over 0..5 and can never silently fall through to
	# the target table.
	["Caster Same", "none", "caster", 0, 1.0, 0.0, 0],
	["Caster Chord", "chord", "caster", 1, 1.15, 0.0, 0],
	["Caster Neutral (2 Steps)", "none", "caster", 2, 1.0, 0.0, 0],
	["Caster Neutral (3 Steps)", "none", "caster", 3, 1.0, 0.0, 0],
	["Caster Neutral (4 Steps)", "none", "caster", 4, 1.0, 0.0, 0],
	["Caster Opposed", "none", "caster", 5, 1.0, 0.0, 0],
]


func _ready() -> void:
	await get_tree().process_frame
	if not Pandora.is_loaded():
		Pandora.load_data()
	_seed_relations()
	Pandora.save_data()
	print("ELEMENT-MATRIX-SEED: %d element relation rows present." % RELATION_ROWS.size())
	get_tree().quit()


func _seed_relations() -> void:
	var root := _ensure_root(ROOT_NAME, RELATION_PROPERTIES)
	for row: Array in RELATION_ROWS:
		_upsert(
			root,
			row[0],
			{
				"Display Name": row[0],
				"Vault Id": VAULT_ID,
				"Relation Id": row[1],
				"Axis": row[2],
				"Distance": row[3],
				"Damage Multiplier": row[4],
				"Fizzle Add": row[5],
				"Soul On Failure": row[6],
				"Provisional": true,
			}
		)


func _ensure_root(root_name: String, properties: Array) -> PandoraCategory:
	var root: PandoraCategory = null
	for candidate: PandoraCategory in Pandora.get_all_roots():
		if candidate.get_entity_name() == root_name:
			root = candidate
			break
	if root == null:
		root = Pandora.create_category(root_name)
	for property_spec: Array in properties:
		if not root.has_entity_property(property_spec[0]):
			Pandora.create_property(root, property_spec[0], property_spec[1])
	return root


func _upsert(root: PandoraCategory, entity_name: String, values: Dictionary) -> void:
	var entity: PandoraEntity = null
	for candidate: PandoraEntity in Pandora.get_all_entities(root):
		if not candidate is PandoraCategory and candidate.get_entity_name() == entity_name:
			entity = candidate
			break
	if entity == null:
		entity = Pandora.create_entity(entity_name, root)
	for property_name: String in values:
		var property := entity.get_entity_property(property_name)
		if property != null:
			property.set_default_value(values[property_name])
