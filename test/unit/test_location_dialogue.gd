extends GdUnitTestSuite
## C25 (#262): hand-authored ambient dialogue per new location lives in `dialogue/locations/`
## under the generated title scheme. `NpcRoster.dialogue_route()` prefers the authored file per
## title; the generated `<town>_townsfolk.dialogue` (tools/generate_gloot.gd owns it, never
## hand-edited) stays the fallback for any title the authored file does not carry.

const PROVISIONAL_HEADER := "# PROVISIONAL — CANON REVIEW REQUIRED"
## The C25 towns: every roster NPC of each must have an authored title.
const AUTHORED_SCENES: Dictionary = {
	"kesselford": "res://world/kesselford.tscn",
	"ashlaren": "res://world/ashlaren.tscn",
	"long_verge": "res://world/long_verge.tscn",
	"hollowmere": "res://world/hollowmere.tscn",
}
## Ambient talk only: quest-bearing dialogue belongs to the quest files (C10–C19), and nothing
## here may write state or roll a check.
const FORBIDDEN_TOKENS: Array[String] = [
	"QuestRegistry.", "GameState.", "check(", "SkillCheck", "Renown.", "\nset ", "\ndo ", "\nemit ",
]


func test_route_prefers_the_authored_file_only_for_titles_it_carries() -> void:
	var row := NpcRoster.get_npc("hollowmere-watcher")
	assert_dict(row).is_not_empty()
	var generated := str(row.get("dialogue", {}).get("path", ""))
	var authored := NpcRoster.location_dialogue_path("hollowmere")
	assert_str(authored).is_equal("res://dialogue/locations/hollowmere.dialogue")
	assert_str(NpcRoster.dialogue_route("hollowmere", generated, "hollowmere_hollowmere_watcher")) \
		.is_equal(authored)
	# A title the authored file lacks falls back to the generated placeholder.
	assert_str(NpcRoster.dialogue_route("hollowmere", generated, "hollowmere_nobody")).is_equal(generated)
	assert_str(NpcRoster.dialogue_route("hollowmere", generated, "")).is_equal(generated)
	# Dom has no authored location file: its townsfolk keep the generated route.
	var dom_generated := "res://dialogue/dom_townsfolk.dialogue"
	assert_bool(ResourceLoader.exists(NpcRoster.location_dialogue_path("dom"))).is_false()
	assert_str(NpcRoster.dialogue_route("dom", dom_generated, "dom_aela_quietforge")).is_equal(dom_generated)


func test_every_authored_location_file_covers_its_roster_with_ambient_lines_only() -> void:
	for town: String in AUTHORED_SCENES:
		var path := NpcRoster.location_dialogue_path(town)
		assert_bool(ResourceLoader.exists(path)).override_failure_message("missing %s" % path).is_true()
		if not ResourceLoader.exists(path):
			continue
		var resource := load(path) as DialogueResource
		assert_object(resource).override_failure_message("%s does not import" % path).is_not_null()
		var source := FileAccess.get_file_as_string(path)
		assert_bool(source.begins_with(PROVISIONAL_HEADER)) \
			.override_failure_message("%s must open with the PROVISIONAL header" % path).is_true()
		for token: String in FORBIDDEN_TOKENS:
			assert_bool(source.contains(token)) \
				.override_failure_message("%s carries forbidden token %s" % [path, token.strip_edges()]) \
				.is_false()
		var blocks := _title_blocks(source)
		var roster := _roster(town)
		var expected_titles: Array[String] = []
		for npc_id: String in roster:
			var row: Dictionary = roster[npc_id]
			var dialogue: Dictionary = row["dialogue"]
			var title := str(dialogue["title"])
			expected_titles.append(title)
			assert_bool(blocks.has(title)) \
				.override_failure_message("%s lacks the title for %s" % [path, npc_id]).is_true()
			if not blocks.has(title):
				continue
			var speaker := str(row["display_name"])
			var block: String = blocks[title]
			# Band-gated greetings are the canon hostile/warm lines verbatim, so the dialogue and
			# the character document never disagree.
			for band: String in ["hostile", "warm"]:
				var canon_line := str(dialogue.get(band, ""))
				if not canon_line.is_empty():
					assert_bool(block.contains("%s: %s" % [speaker, canon_line])) \
						.override_failure_message("%s: %s's canon %s line is missing" % [path, npc_id, band]) \
						.is_true()
			var spoken := 0
			var responses := 0
			for raw_line: String in block.split("\n"):
				var line := raw_line.strip_edges()
				if line.is_empty() or line.begins_with("#"):
					continue
				if line.begins_with("- "):
					responses += 1
				elif line.begins_with("=>"):
					assert_str(line).override_failure_message("%s: only '=> END' jumps" % title).is_equal("=> END")
				elif line.begins_with("if ") or line.begins_with("elif ") or line == "else":
					if line != "else":
						assert_bool(line.contains("Reputation.band(")) \
							.override_failure_message("%s: conditions gate only on Reputation.band" % title).is_true()
				else:
					var colon := line.find(": ")
					assert_int(colon).override_failure_message("%s: not a dialogue line: %s" % [title, line]).is_greater(0)
					if colon > 0:
						assert_str(line.substr(0, colon)) \
							.override_failure_message("%s: wrong speaker on '%s'" % [title, line]).is_equal(speaker)
					spoken += 1
			assert_int(spoken).override_failure_message("%s: fewer than three spoken lines" % title).is_greater_equal(3)
			assert_int(responses).override_failure_message("%s: fewer than two responses" % title).is_greater_equal(2)
			# The imported resource resolves the title and opens on the speaker's own line.
			var first: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, title)
			assert_object(first).override_failure_message("%s: title does not resolve" % title).is_not_null()
			if first != null:
				assert_str(first.character).is_equal(speaker)
		for title: String in blocks:
			assert_bool(expected_titles.has(title)) \
				.override_failure_message("%s carries a title no %s roster NPC owns: %s" % [path, town, title]) \
				.is_true()


func test_spawned_townsfolk_talk_from_the_authored_file() -> void:
	for town: String in AUTHORED_SCENES:
		var authored := NpcRoster.location_dialogue_path(town)
		if not ResourceLoader.exists(authored):
			continue  # covered (and failed) by the coverage test above
		var runner := scene_runner(str(AUTHORED_SCENES[town]))
		await runner.simulate_frames(5)
		var spawned: Array[Node] = []
		_collect_group_members(runner.scene(), &"generated_townsfolk", spawned)
		assert_int(spawned.size()).override_failure_message("%s spawned nobody" % town).is_greater_equal(1)
		var source := FileAccess.get_file_as_string(authored)
		for node: Node in spawned:
			var npc := node as NPC
			assert_object(npc).is_not_null()
			if npc == null:
				continue
			assert_str(npc.dialogue_path) \
				.override_failure_message("%s should talk from the authored file" % npc.name).is_equal(authored)
			assert_bool(source.contains("\n~ %s\n" % npc.dialogue_start)) \
				.override_failure_message("%s's title %s is not in %s" % [npc.name, npc.dialogue_start, authored]) \
				.is_true()


func _roster(town: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(NpcRoster.roster_path(town)))
	assert_bool(parsed is Dictionary).is_true()
	if not parsed is Dictionary:
		return {}
	return (parsed as Dictionary).get("npcs", {})


## Source text per `~ title`, keyed by title.
func _title_blocks(source: String) -> Dictionary:
	var blocks: Dictionary = {}
	var current := ""
	for line: String in source.split("\n"):
		if line.begins_with("~ "):
			current = line.substr(2).strip_edges()
			blocks[current] = ""
		elif not current.is_empty():
			blocks[current] = str(blocks[current]) + line + "\n"
	return blocks


func _collect_group_members(node: Node, group: StringName, found: Array[Node]) -> void:
	if node.is_in_group(group):
		found.append(node)
	for child: Node in node.get_children():
		_collect_group_members(child, group, found)
