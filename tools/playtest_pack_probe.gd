extends SceneTree
## Proves an exported pack carries every dialogue the repo ships. Run by
## `scripts/build_playtest.sh` and the CI Windows packaging job against the exported pack:
##
##   SOUL_METER_PACK_PROBE_LIST=/abs/list.txt \
##   godot --headless --main-pack SoulMeter.pck -s /abs/path/tools/playtest_pack_probe.gd
##
## Run it from an EMPTY working directory: with a `project.godot` in the current directory, `res://`
## resolves against that project instead of the pack and every check passes falsely.
##
## The list holds one repo-relative path per line (`dialogue/council_elder.dialogue`). A release
## export without the Dialogue Manager importer (`--recovery-mode` disables editor plugins) drops
## every `.dialogue` resource and the game still boots to its menu, so a boot smoke cannot see it.
## That shipped in the CI Windows artifact until 2026-11-20.
##
## Expected noise after the PACK PROBE line: Godot still loads `run/main_scene` in `-s` mode,
## without the autoload members it references, so it logs parse errors for `main_menu.gd`
## (`LOAD_GAME`, `SETTINGS`, sometimes `Screen`). Only the PACK PROBE line and the exit status
## count. A real boot of the same pack (`--main-pack ... --quit-after 300`) parses the menu cleanly.

const LIST_ENV := "SOUL_METER_PACK_PROBE_LIST"


func _init() -> void:
	var list_path := OS.get_environment(LIST_ENV)
	if list_path.is_empty() or not FileAccess.file_exists(list_path):
		print("PACK PROBE: %s must name an existing list file" % LIST_ENV)
		quit(2)
		return
	var expected := PackedStringArray()
	for line: String in FileAccess.get_file_as_string(list_path).split("\n", false):
		var relative := line.strip_edges()
		if not relative.is_empty():
			expected.append(relative)
	var missing := PackedStringArray()
	for relative: String in expected:
		var path := "res://" + relative
		var resource: Resource = load(path) if ResourceLoader.exists(path) else null
		if resource == null:
			missing.append(relative)
	print("PACK PROBE: %d/%d expected resources load" % [expected.size() - missing.size(), expected.size()])
	for relative: String in missing:
		print("PACK PROBE: missing %s" % relative)
	quit(0 if missing.is_empty() and not expected.is_empty() else 1)
