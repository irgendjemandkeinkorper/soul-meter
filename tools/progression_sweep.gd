extends SceneTree
## Chapter 1 progression sweep — owner ruling 2026-10-09 (level cap + scaled kill XP).
##
## Canonical invocation:
##   godot --headless --path . --script res://tools/progression_sweep.gd
##
## READ-ONLY. It prints the tables `docs/progression-bound-packet.md` is written from:
## the Chapter 1 XP budget, the level a thorough non-grinding run reaches (which fits
## `XpCurve.CHAPTER_LEVEL_CAP`), and how many wild kills one level costs with and
## without kill-XP scaling. It changes nothing.
##
## Pure and deterministic, like `tools/enemy_curve_sweep.gd`. No autoload is referenced:
## quests are counted from QuestRegistry's constants, set pieces and wild spawns are
## read from canon, and every number comes from `Advancement` itself.
##
## Canon is read from every `canon/<hub>/`, not Dom alone (C1–C4 / #238–#241 gave each location
## its own ambient spawn table): set pieces from each hub's `encounters/`, spawn tables from each
## hub's `spawn_tables/` (the walk `SpawnDirector.load_tables()` makes at runtime, mirrored rather
## than called because that script needs the autoloads), and an archetype's stats from whichever
## hub's `characters/` holds it.
##
## Model of a thorough run (an ASSUMPTION the packet states): quests are spread evenly
## across the five set pieces in their authored `order`, the Broken Muster milestone
## lands right after the third set piece, and the party fights each set piece once.

const QUEST_REGISTRY := "res://globals/quest_registry.gd"
const CANON_ROOT := "res://canon"
const ENCOUNTER_DIRECTORY := "encounters"
const CHARACTER_DIRECTORY := "characters"
const SPAWN_TABLE_DIRECTORY := "spawn_tables"
## The one schema `SpawnDirector` loads; a table of any other schema is skipped there and here.
const SPAWN_TABLE_SCHEMA := "weftlumin.spawn_table.v1"
## `QuestRegistry` grants exactly one authored milestone today (`broken-muster`).
const MILESTONES_AFTER_SET_PIECE := 3


func _initialize() -> void:
	var registry: GDScript = load(QUEST_REGISTRY)
	var quest_count: int = (registry.ALL_QUESTS as Array).size()
	var stub_count: int = (registry.STUB_SIDE_QUESTS as Array).size()
	var set_pieces := _set_pieces()
	print("== Chapter 1 XP budget ==")
	print("quests (ALL_QUESTS)          %d x %d = %d" % [quest_count, XpCurve.XP_PER_QUEST, quest_count * XpCurve.XP_PER_QUEST])
	print("suspended stubs (pay today)  %d x %d = %d" % [stub_count, XpCurve.XP_PER_QUEST, stub_count * XpCurve.XP_PER_QUEST])
	for piece: Dictionary in set_pieces:
		print("set piece %-22s foe levels %s  base XP %d" % [piece.id, str(piece.levels), piece.base])
	print("milestone: one level's XP at the member's level, after set piece %d" % MILESTONES_AFTER_SET_PIECE)
	print("")
	print("== Thorough run, no wild fighting (cap %d) ==" % XpCurve.CHAPTER_LEVEL_CAP)
	for with_stubs: bool in [false, true]:
		for scaled: bool in [false, true]:
			var run := _thorough_run(quest_count + (stub_count if with_stubs else 0), set_pieces, scaled)
			print("stubs %-5s scaled kills %-5s -> level %d (+%d XP toward next)" % [with_stubs, scaled, run.x, run.y])
	print("")
	var tables := _spawn_tables()
	print("== Ambient spawn tables (every canon/<hub>/spawn_tables the game loads) ==")
	for table: Dictionary in tables:
		print("%-32s %-30s archetypes %s" % [table.id, table.scene_path, str(table.archetypes)])
	print("")
	print("== Wild kills to gain ONE level (unscaled / scaled) ==")
	var wild := _wild_archetypes(tables)
	var header := "level  "
	for archetype: String in wild:
		header += "%-28s" % archetype
	print(header)
	for level: int in range(1, XpCurve.CHAPTER_LEVEL_CAP):
		var row := "%-7d" % level
		for archetype: String in wild:
			var foe: Vector2i = wild[archetype]
			var need := XpCurve.xp_for_next_level(level)
			var flat := ceili(float(need) / XpCurve.xp_for_defeated(foe.x, foe.y))
			var scaled := ceili(float(need) / XpCurve.kill_xp_for(level, foe.x, foe.y))
			row += "%-28s" % ("%d / %d (foe L%d)" % [flat, scaled, XpCurve.enemy_level(foe.x, foe.y)])
		print(row)
	quit()


## Returns Vector2i(level reached, XP banked toward the next).
func _thorough_run(quests: int, set_pieces: Array[Dictionary], scaled: bool) -> Vector2i:
	var member := PartyMember.new()
	member.level = 1
	var chunks := set_pieces.size() + 1
	var paid := 0
	for index: int in chunks:
		var share := (quests * (index + 1)) / chunks - paid
		paid += share
		XpCurve.award_xp(member, share * XpCurve.XP_PER_QUEST)
		if index >= set_pieces.size():
			break
		var piece: Dictionary = set_pieces[index]
		for foe: Vector2i in piece.foes:
			var amount := XpCurve.kill_xp_for(member.level, foe.x, foe.y) if scaled else XpCurve.xp_for_defeated(foe.x, foe.y)
			XpCurve.award_xp(member, amount)
		if index + 1 == MILESTONES_AFTER_SET_PIECE:
			XpCurve.award_xp(member, XpCurve.milestone_xp(member))
	return Vector2i(member.level, member.xp)


func _set_pieces() -> Array[Dictionary]:
	var pieces: Array[Dictionary] = []
	for path: String in _canon_files(ENCOUNTER_DIRECTORY):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var foes: Array[Vector2i] = []
		var levels: Array[int] = []
		var base := 0
		for archetype: Variant in data.get("archetype_ids", []):
			var foe := _attributes(str(archetype))
			foes.append(foe)
			levels.append(XpCurve.enemy_level(foe.x, foe.y))
			base += XpCurve.xp_for_defeated(foe.x, foe.y)
		pieces.append({"id": str(data.id), "order": int(data.get("order", 0)), "foes": foes, "levels": levels, "base": base})
	pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.order < b.order)
	return pieces


## Every ambient spawn table under `canon/<hub>/spawn_tables/`, flattened to
## `{id, scene_path, archetypes}` in id order.
func _spawn_tables() -> Array[Dictionary]:
	var tables: Array[Dictionary] = []
	for path: String in _canon_files(SPAWN_TABLE_DIRECTORY):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary or str((parsed as Dictionary).get("schema", "")) != SPAWN_TABLE_SCHEMA:
			push_error("Spawn table '%s' is not a %s object; skipped." % [path, SPAWN_TABLE_SCHEMA])
			continue
		var table: Dictionary = parsed
		var archetypes: Array[String] = []
		for slot: Dictionary in table.get("slots", []):
			for entry: Dictionary in slot.get("entries", []):
				var archetype := str(entry.get("archetype_id", ""))
				if not archetype.is_empty() and not archetypes.has(archetype):
					archetypes.append(archetype)
		archetypes.sort()
		tables.append({"id": str(table.get("id", path.get_file())), "scene_path": str(table.get("scene_path", "")), "archetypes": archetypes})
	tables.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	return tables


## archetype id -> (grit, muster) for every archetype any table can roll, in id order.
func _wild_archetypes(tables: Array[Dictionary]) -> Dictionary:
	var ids: Array[String] = []
	for table: Dictionary in tables:
		for archetype: String in table.archetypes:
			if not ids.has(archetype):
				ids.append(archetype)
	ids.sort()
	var wild := {}
	for archetype: String in ids:
		wild[archetype] = _attributes(archetype)
	return wild


func _attributes(archetype: String) -> Vector2i:
	var path := _character_path(archetype)
	if path.is_empty():
		push_error("No canon/<hub>/characters/%s.json; the archetype counts as (0, 0)." % archetype)
		return Vector2i.ZERO
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var stats: Dictionary = data.stats
	return Vector2i(int(stats.get("grit", 0)), int(stats.get("muster", 0)))


## The canon character file for `archetype`, from whichever hub holds it; "" when none does.
func _character_path(archetype: String) -> String:
	for hub: String in _hubs():
		var path := CANON_ROOT.path_join(hub).path_join(CHARACTER_DIRECTORY).path_join(archetype + ".json")
		if FileAccess.file_exists(path):
			return path
	return ""


## Every `canon/<hub>/<subdirectory>/*.json`, hubs and files in name order.
func _canon_files(subdirectory: String) -> Array[String]:
	var paths: Array[String] = []
	for hub: String in _hubs():
		var directory := CANON_ROOT.path_join(hub).path_join(subdirectory)
		if not DirAccess.dir_exists_absolute(directory):
			continue
		var files := DirAccess.get_files_at(directory)
		files.sort()
		for file: String in files:
			if file.ends_with(".json"):
				paths.append(directory.path_join(file))
	return paths


func _hubs() -> PackedStringArray:
	var hubs := DirAccess.get_directories_at(CANON_ROOT)
	hubs.sort()
	return hubs
