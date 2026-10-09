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
## Model of a thorough run (an ASSUMPTION the packet states): quests are spread evenly
## across the five set pieces in their authored `order`, the Broken Muster milestone
## lands right after the third set piece, and the party fights each set piece once.

const QUEST_REGISTRY := "res://globals/quest_registry.gd"
const ENCOUNTER_DIRECTORY := "res://canon/dom/encounters"
const CHARACTER_DIRECTORY := "res://canon/dom/characters"
const SPAWN_TABLE_DIRECTORY := "res://canon/dom/spawn_tables"
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
	print("== Wild kills to gain ONE level (unscaled / scaled) ==")
	var wild := _wild_archetypes()
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
	for file: String in DirAccess.get_files_at(ENCOUNTER_DIRECTORY):
		if not file.ends_with(".json"):
			continue
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ENCOUNTER_DIRECTORY.path_join(file)))
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


func _wild_archetypes() -> Dictionary:
	var wild := {}
	for file: String in DirAccess.get_files_at(SPAWN_TABLE_DIRECTORY):
		if not file.ends_with(".json"):
			continue
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SPAWN_TABLE_DIRECTORY.path_join(file)))
		for slot: Dictionary in data.get("slots", []):
			for entry: Dictionary in slot.get("entries", []):
				if entry.has("archetype_id"):
					wild[str(entry.archetype_id)] = _attributes(str(entry.archetype_id))
	return wild


func _attributes(archetype: String) -> Vector2i:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CHARACTER_DIRECTORY.path_join(archetype + ".json")))
	var stats: Dictionary = data.stats
	return Vector2i(int(stats.get("grit", 0)), int(stats.get("muster", 0)))
