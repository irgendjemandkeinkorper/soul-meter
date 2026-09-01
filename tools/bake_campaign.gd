extends SceneTree

## Campaign quest bake tool.
##
## Run directly:
##   godot --headless --path . --script res://tools/bake_campaign.gd -- \
##     --package user://campaigns/<id> --target res://quests/campaigns/<id>
##
## The default is reporting-only: it validates the package and prints the files
## it would create. Pass --write to create resources. Existing resources are
## always refused unless --force is also explicit, keeping tools from silently
## writing over canon.

const SCHEMA := "soul_meter.campaign_bake.v1"
const CANONIZATION_REQUIRED := (
	"NOT CANON: baked quest resources carry id = 0. Before use as committed content, "
	+ "manually assign a committed id and add the quest resource to QuestRegistry.ALL_QUESTS."
)


func _initialize() -> void:
	var options: Dictionary = parse_arguments(OS.get_cmdline_user_args())
	var argument_errors: Array = options.get("errors", [])
	if not argument_errors.is_empty():
		var invalid_report: Dictionary = {
			"schema": SCHEMA,
			"canonization_required": CANONIZATION_REQUIRED,
			"mode": "reporting",
			"package": str(options.get("package", "")),
			"target": str(options.get("target", "")),
			"planned": [],
			"written": [],
			"errors": argument_errors,
			"summary": {"planned": 0, "written": 0, "errors": argument_errors.size()},
		}
		print(JSON.stringify(invalid_report, "  ", false))
		quit(2)
		return
	var write: bool = bool(options.get("write", false))
	var report: Dictionary = bake_package(
		str(options["package"]), str(options["target"]), write, bool(options.get("force", false))
	)
	print(JSON.stringify(report, "  ", false))
	quit(exit_code_for_report(report, write))


static func parse_arguments(arguments: PackedStringArray) -> Dictionary:
	var options: Dictionary = {
		"package": "",
		"target": "",
		"write": false,
		"force": false,
		"errors": [],
	}
	var index: int = 0
	while index < arguments.size():
		var argument: String = arguments[index]
		if argument == "--write":
			options["write"] = true
		elif argument == "--force":
			options["force"] = true
		elif argument in ["--package", "--target"]:
			if index + 1 >= arguments.size():
				(options["errors"] as Array).append(_argument_error(argument, "path value"))
			else:
				index += 1
				options[argument.trim_prefix("--")] = arguments[index]
		elif argument.begins_with("--package="):
			options["package"] = argument.trim_prefix("--package=")
		elif argument.begins_with("--target="):
			options["target"] = argument.trim_prefix("--target=")
		else:
			(options["errors"] as Array).append(_argument_error(argument, "known option"))
		index += 1
	if str(options["package"]).is_empty():
		(options["errors"] as Array).append(_argument_error("--package", "non-empty package path"))
	if str(options["target"]).is_empty():
		(options["errors"] as Array).append(_argument_error("--target", "non-empty target path"))
	if bool(options["force"]) and not bool(options["write"]):
		(options["errors"] as Array).append(_argument_error("--force", "--write to be set"))
	return options


static func bake_package(
	package_path: String, target_path: String, write: bool = false, force: bool = false
) -> Dictionary:
	var load_result: Dictionary = CampaignQuestLoader.load_package(package_path, false)
	var errors: Array[Dictionary] = []
	for load_error: Dictionary in load_result.get("errors", []):
		errors.append(load_error.duplicate(true))
	var planned: Array[Dictionary] = []
	var written: Array[String] = []
	var outputs: Dictionary = {}

	for entry: Dictionary in load_result.get("quest_entries", []):
		var quest_id: String = str(entry["quest_id"])
		var relative_path: String = _relative_tres_path(quest_id)
		if relative_path.is_empty():
			errors.append(_error(
				str(entry["file"]), "quest_id", "safe relative resource path",
				"unsafe_output_path", "Quest id cannot be mapped to a safe .tres path."
			))
			continue
		var output_path: String = target_path.path_join(relative_path)
		if outputs.has(output_path):
			errors.append(_error(
				str(entry["file"]), "quest_id", "unique target resource path",
				"duplicate_target", "More than one quest maps to %s." % output_path
			))
			continue
		outputs[output_path] = true
		planned.append({
			"source": entry["file"],
			"quest_id": quest_id,
			"identity": entry["identity"],
			"output": output_path,
		})

		if FileAccess.file_exists(output_path) and not force:
			errors.append(_error(
				output_path, "target", "absent file or explicit --force",
				"target_exists", "Refusing to overwrite an existing quest resource."
			))
			continue
		if not write:
			continue
		var parent_path: String = output_path.get_base_dir()
		var directory_error: Error = DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(parent_path)
		)
		if directory_error != OK:
			errors.append(_error(
				output_path, "target", "writable directory", "target_directory_failed",
				"Could not create target directory (error %d)." % directory_error
			))
			continue
		var quest: DomSideQuest = (entry["quest"] as DomSideQuest).duplicate(true) as DomSideQuest
		quest.id = 0
		var save_error: Error = ResourceSaver.save(quest, output_path)
		if save_error != OK:
			errors.append(_error(
				output_path, "target", "writable .tres resource", "resource_save_failed",
				"ResourceSaver failed with error %d." % save_error
			))
			continue
		written.append(output_path)

	return {
		"schema": SCHEMA,
		"canonization_required": CANONIZATION_REQUIRED,
		"mode": "writing" if write else "reporting",
		"package": package_path,
		"target": target_path,
		"campaign": load_result.get("campaign", {}),
		"planned": planned,
		"written": written,
		"errors": errors,
		"summary": {
			"loaded": (load_result.get("quests", []) as Array).size(),
			"planned": planned.size(),
			"written": written.size(),
			"errors": errors.size(),
		},
	}


static func exit_code_for_report(report: Dictionary, write: bool) -> int:
	if not write:
		return 0
	return 1 if not (report.get("errors", []) as Array).is_empty() else 0


static func _relative_tres_path(quest_id: String) -> String:
	var encoded_segments: PackedStringArray = []
	for segment: String in quest_id.split("/", false):
		if segment.is_empty():
			return ""
		var encoded: String = segment.replace("%", "%25").replace(":", "%3A")
		if encoded == ".":
			encoded = "%2E"
		elif encoded == "..":
			encoded = "%2E%2E"
		encoded_segments.append(encoded)
	if encoded_segments.is_empty():
		return ""
	return "/".join(encoded_segments) + ".tres"


static func _argument_error(argument: String, expected: String) -> Dictionary:
	return _error(
		"<arguments>", argument, expected, "invalid_argument",
		"Invalid or incomplete command-line argument '%s'." % argument
	)


static func _error(
	file_path: String, field: String, expected: String, code: String, message: String
) -> Dictionary:
	return {
		"file": file_path,
		"field": field,
		"expected": expected,
		"code": code,
		"message": message,
	}
