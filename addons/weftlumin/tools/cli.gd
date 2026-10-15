extends RefCounted
## The body of the Weftlumin headless CLI (E7.1, `docs/architecture-in-game-editor.md` §4.13).
## `tools/weftlumin.gd` loads this inside `_initialize()`, so the project's autoloads exist; tests
## construct it directly and call `run()`.
##
## Same code path as the UI: scene command logs go through `WeftluminCommandBus.replay()` inside
## `WeftluminBake`, and game-specific work (kinds, contracts, lint, regen, live verbs, the
## kind → test-glob map) goes through the host's `WeftluminGameAdapter`. The core knows nothing
## about Soul Meter.
##
## **Package directory.** `<dir>/campaign.json` is the optional manifest (`weftlumin.package.v1`,
## the generalised campaign envelope of §4.2); `<dir>/commands.jsonl` is the scene command log;
## a kind with a `subdir` reads `<dir>/<subdir>/*.<ext>`; `<dir>/dialogue/**/*.dialogue` is linted.
## Without a manifest the id comes from the log (else the directory name) and the kinds are the
## ones present.
##
## **Writes.** Nothing under `res://` is written unless the verb's write flag is given (`bake
## --write`, `regen --write`; `pr --execute` writes only inside its own worktree). `apply` writes
## scratch only, and refuses a package directory inside the project. `--report <path>` writes the
## report JSON atomically wherever it is pointed.
##
## **Output.** Human lines, then `WEFTLUMIN-REPORT <compact JSON>`, then `WEFTLUMIN: <verb>
## <status> exit=<code>`. Judge those lines (or the `--report` file), not the process exit code.

const PrScript := preload("res://addons/weftlumin/tools/pr.gd")

const CLI_SCHEMA := "weftlumin.cli.v1"
const LINT_SCHEMA := "weftlumin.lint.v1"
const EXIT_OK := 0
const EXIT_ERRORS := 1
const EXIT_USAGE := 2
const EXIT_OVERLAP := 3
const VERBS: Array[String] = ["validate", "apply", "bake", "regen", "lint", "pr", "help"]
## Flags that take a value; every other `--flag` is a switch.
const VALUE_FLAGS: Array[String] = ["--report", "--issue", "--open-prs", "--worktree", "--trailer", "--adapter", "--base", "--cancel-file"]
const SWITCHES: Array[String] = ["--write", "--force", "--draft", "--execute", "--quiet"]
const MANIFEST_FILE := "campaign.json"
const LOG_FILE := "commands.jsonl"
const DIALOGUE_DIR := "dialogue"
const SCRATCH_DIR := "scratch"
const SCENE_COMMAND_KIND := "scene"
const SCENES_KIND := "scenes"
## The bootstrap's adapter path first (where the authoring adapter will live), then the shell's
## host bridge, which is today's Soul Meter adapter.
const ADAPTER_PATHS: Array[String] = [
	"res://weftlumin/soul_meter_adapter.gd", "res://addons/weftlumin/shell/soul_meter_adapter.gd",
]
const REPORT_PREFIX := "WEFTLUMIN-REPORT "
const STATUS_PREFIX := "WEFTLUMIN: "
const IF_TAG := "\\[if\\b"

var adapter: WeftluminGameAdapter = null
## Printed output, also kept for tests.
var lines: Array[String] = []
## When false nothing is printed (tests read `lines`).
var echo: bool = true
## The PR flow's process runner, swappable by tests: `(program, args) -> {exit_code, output}`.
var runner: Callable = Callable()


func _init(host: WeftluminGameAdapter = null) -> void:
	adapter = host


# --- entry ------------------------------------------------------------------------------------


## Run one subcommand. `{exit_code, report, lines}`.
func run(args: PackedStringArray) -> Dictionary:
	var parsed: Dictionary = parse_args(args)
	var verb: String = str(parsed.get("verb", ""))
	var report: Dictionary = {}
	var code: int = EXIT_OK
	if not (parsed["errors"] as Array).is_empty():
		for message: String in parsed["errors"]:
			_say("usage: " + message)
		_usage()
		return _finish(verb, {"schema": CLI_SCHEMA, "verb": verb, "errors": parsed["errors"]}, EXIT_USAGE, parsed)
	if verb == "help":
		_usage()
		return _finish(verb, {"schema": CLI_SCHEMA, "verb": verb, "errors": []}, EXIT_OK, parsed)
	if adapter == null:
		adapter = resolve_adapter(str(parsed["options"].get("--adapter", "")))
	var positional: Array = parsed["positional"]
	var options: Dictionary = parsed["options"]
	match verb:
		"validate":
			report = validate(load_package(positional[0]))
		"apply":
			report = apply(positional[0], positional[1])
		"bake":
			report = bake(load_package(positional[0]), options.has("--write"), options.has("--force"))
		"regen":
			report = regen(options.has("--write"))
		"lint":
			report = lint(load_package(positional[0]))
		"pr":
			report = PrScript.new(self).run(load_package(positional[0]), options)
	code = exit_code_for(verb, report)
	return _finish(verb, report, code, parsed)


static func parse_args(args: PackedStringArray) -> Dictionary:
	var errors: Array[String] = []
	var positional: Array[String] = []
	var options: Dictionary = {}
	var index: int = 0
	while index < args.size():
		var arg: String = args[index]
		if arg in VALUE_FLAGS:
			if index + 1 >= args.size():
				errors.append("%s needs a value" % arg)
				break
			if arg == "--trailer":
				if not options.has(arg):
					options[arg] = []
				(options[arg] as Array).append(args[index + 1])
			else:
				options[arg] = args[index + 1]
			index += 2
			continue
		if arg in SWITCHES:
			options[arg] = true
		elif arg.begins_with("--"):
			errors.append("unknown option %s" % arg)
		else:
			positional.append(arg)
		index += 1
	var verb: String = positional.pop_front() if not positional.is_empty() else ""
	var needed: Dictionary = {"validate": 1, "apply": 2, "bake": 1, "regen": 0, "lint": 1, "pr": 1, "help": 0}
	if verb.is_empty():
		errors.append("no subcommand")
	elif verb not in VERBS:
		errors.append("unknown subcommand %s" % verb)
	elif positional.size() != int(needed[verb]):
		errors.append("%s takes %d argument(s), got %d" % [verb, needed[verb], positional.size()])
	if options.has("--issue") and not str(options["--issue"]).is_valid_int():
		errors.append("--issue takes an issue number")
	return {"verb": verb, "positional": positional, "options": options, "errors": errors}


static func resolve_adapter(path: String = "") -> WeftluminGameAdapter:
	var candidates: Array[String] = [path] if not path.is_empty() else ADAPTER_PATHS
	for candidate: String in candidates:
		if not ResourceLoader.exists(candidate):
			continue
		var script := load(candidate) as GDScript
		var instance: Variant = script.new() if script != null else null
		if instance is WeftluminGameAdapter:
			return instance as WeftluminGameAdapter
	return WeftluminGameAdapter.new()


static func exit_code_for(verb: String, report: Dictionary) -> int:
	if not (report.get("refused_overlap", []) as Array).is_empty():
		return EXIT_OVERLAP
	if not (report.get("errors", []) as Array).is_empty():
		return EXIT_ERRORS
	if verb == "lint" and not (report.get("lint_errors", []) as Array).is_empty():
		return EXIT_ERRORS
	return EXIT_OK


func _finish(verb: String, report: Dictionary, code: int, parsed: Dictionary) -> Dictionary:
	report["exit_code"] = code
	var report_path: String = str((parsed.get("options", {}) as Dictionary).get("--report", ""))
	if not report_path.is_empty():
		var written: Error = write_text_atomically(report_path, JSON.stringify(report, "  ", false) + "\n")
		if written != OK:
			_say("could not write the report to %s (error %d)" % [report_path, written])
	var status: String = ["ok", "errors", "usage", "refused_overlap"][code] if code <= EXIT_OVERLAP else "failed"
	_say(REPORT_PREFIX + JSON.stringify(report, "", false))
	_say("%s%s %s exit=%d" % [STATUS_PREFIX, verb if not verb.is_empty() else "?", status, code])
	return {"exit_code": code, "report": report, "lines": lines.duplicate()}


func _usage() -> void:
	_say("godot --headless --path . --script addons/weftlumin/tools/weftlumin.gd -- <subcommand> [args]")
	_say("  validate <package_dir> | apply <package_dir> <commands.jsonl> | bake <package_dir> [--write] [--force]")
	_say("  regen [--write] | lint <package_dir> | pr <package_dir> [--issue N] [--draft] [--force] [--execute]")
	_say("  every subcommand: --report <path>; pr: --open-prs <file.json> --worktree <dir> --trailer <text> --base <branch>")


func _say(text: String) -> void:
	lines.append(text)
	if echo:
		print(text)


# --- package ----------------------------------------------------------------------------------


## A package directory, loaded tolerantly: `{dir, id, hub, title, manifest, manifest_present,
## kinds, log_path, log_entries, documents, dialogue, errors}`.
func load_package(path: String) -> Dictionary:
	var dir: String = normalise_path(path)
	var errors: Array[Dictionary] = []
	var package: Dictionary = {
		"dir": dir, "id": "", "hub": "", "title": "", "manifest": {}, "manifest_present": false,
		"kinds": [], "log_path": "", "log_entries": [], "documents": {}, "dialogue": {}, "errors": errors,
	}
	if not DirAccess.dir_exists_absolute(dir):
		errors.append(attributed(dir, "$", "a package directory", "missing_package", "No package directory at %s." % dir))
		return package
	var manifest_path: String = dir.path_join(MANIFEST_FILE)
	var manifest: Dictionary = {}
	if FileAccess.file_exists(manifest_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if parsed is Dictionary:
			manifest = parsed
			package["manifest_present"] = true
		else:
			errors.append(attributed(manifest_path, "$", "one JSON object", "invalid_manifest", "%s is not a JSON object." % manifest_path))
	var log_path: String = dir.path_join(LOG_FILE)
	if FileAccess.file_exists(log_path):
		package["log_path"] = log_path
		package["log_entries"] = load_log(log_path, errors)
	var documents: Dictionary = {}
	var inferred: Array[String] = []
	if not (package["log_entries"] as Array).is_empty() or FileAccess.file_exists(log_path):
		inferred.append(SCENES_KIND)
	for kind: WeftluminKind in _kinds():
		if kind.subdir.is_empty():
			continue
		var kind_dir: String = dir.path_join(kind.subdir)
		if not DirAccess.dir_exists_absolute(kind_dir):
			continue
		inferred.append(String(kind.id))
		var loaded: Array[Dictionary] = []
		var filenames: PackedStringArray = DirAccess.get_files_at(kind_dir)
		filenames.sort()
		for filename: String in filenames:
			if filename.get_extension().to_lower() != kind.ext:
				continue
			var file_path: String = kind_dir.path_join(filename)
			var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(file_path))
			if document is Dictionary:
				var row: Dictionary = document
				row["$file"] = file_path
				loaded.append(row)
			else:
				errors.append(attributed(file_path, "$", "one JSON object", "invalid_document", "%s is not a JSON object." % file_path))
		documents[String(kind.id)] = loaded
	package["documents"] = documents
	package["dialogue"] = _dialogue_sources(dir.path_join(DIALOGUE_DIR))
	var log_package: String = ""
	for entry: Dictionary in package["log_entries"]:
		log_package = str(entry.get("package", ""))
		if not log_package.is_empty():
			break
	package["id"] = str(manifest.get("id", log_package if not log_package.is_empty() else dir.trim_suffix("/").get_file()))
	package["hub"] = str(manifest.get("hub", ""))
	# Both become path components (scratch dirs, worktree, `canon/<hub>/`); refuse anything else.
	if not is_package_token(str(package["id"])):
		errors.append(attributed(manifest_path, "id", "lowercase letters, digits, '-' or '_'", "invalid_package_id",
			"Package id %s is not a plain path component." % JSON.stringify(package["id"])))
	if not str(package["hub"]).is_empty() and not is_package_token(str(package["hub"])):
		errors.append(attributed(manifest_path, "hub", "lowercase letters, digits, '-' or '_'", "invalid_hub",
			"Hub %s is not a plain path component." % JSON.stringify(package["hub"])))
	package["title"] = str(manifest.get("title", package["id"]))
	if not package["manifest_present"]:
		manifest = {"schema": WeftluminPackage.SCHEMA, "id": package["id"], "kinds": inferred}
	package["manifest"] = manifest
	var declared: Variant = manifest.get("kinds", inferred)
	var kinds: Array[String] = []
	if declared is Array:
		for value: Variant in declared:
			kinds.append(str(value))
	package["kinds"] = kinds
	return package


## One JSON object per non-empty line; malformed lines become attributed errors with `line`.
static func load_log(path: String, errors: Array[Dictionary]) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var line_number: int = 0
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		line_number += 1
		if line.strip_edges().is_empty():
			continue
		var json := JSON.new()
		var parsed: Variant = json.data if json.parse(line) == OK else null
		if parsed is Dictionary:
			entries.append(parsed as Dictionary)
		else:
			var error: Dictionary = attributed(path, "$", "one JSON object per line", "invalid_log_line", "Line %d is not a JSON object." % line_number)
			error["line"] = line_number
			errors.append(error)
	return entries


## `res://`, `user://` and absolute paths are kept (an absolute path inside the project becomes
## `res://`); a relative path is project-relative.
static func normalise_path(path: String) -> String:
	var value: String = path.strip_edges()
	if value.begins_with("res://") or value.begins_with("user://"):
		return value.trim_suffix("/") if value.length() > 7 else value
	if not value.is_absolute_path():
		return "res://" + value.trim_prefix("./").trim_suffix("/")
	var root: String = ProjectSettings.globalize_path("res://").trim_suffix("/")
	var simplified: String = value.simplify_path().trim_suffix("/")
	if simplified == root or simplified.begins_with(root + "/"):
		return "res://" + simplified.substr(root.length() + 1)
	return simplified


## True for any path that lands in the project once `user://`, `..` and symlinks are resolved.
static func is_inside_project(path: String) -> bool:
	var value: String = normalise_path(path)
	if value.begins_with("res://"):
		return true
	var root: String = resolve_links(ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/"))
	var resolved: String = resolve_links(ProjectSettings.globalize_path(value).simplify_path().trim_suffix("/"))
	return resolved == root or resolved.begins_with(root + "/")


## `path` with every existing symlinked component replaced by its target (bounded, so a link
## loop cannot hang). Components that do not exist yet are kept as written.
static func resolve_links(path: String) -> String:
	var resolved: String = path
	for _hop: int in 32:
		var changed: bool = false
		var prefix: String = ""
		var parts: PackedStringArray = resolved.split("/", false)
		for index: int in parts.size():
			var parent: String = prefix if not prefix.is_empty() else ("/" if resolved.begins_with("/") else "")
			prefix = parent.path_join(parts[index]) if not parent.is_empty() else parts[index]
			var dir := DirAccess.open(parent if not parent.is_empty() else ".")
			if dir == null or not dir.is_link(parts[index]):
				continue
			var target: String = dir.read_link(parts[index])
			if not target.is_absolute_path():
				target = parent.path_join(target)
			var rest: PackedStringArray = parts.slice(index + 1)
			resolved = (target.path_join("/".join(rest)) if not rest.is_empty() else target).simplify_path()
			changed = true
			break
		if not changed:
			return resolved
	return resolved


static func is_package_token(value: String) -> bool:
	if value.is_empty():
		return false
	for character: String in value:
		if not (character in "abcdefghijklmnopqrstuvwxyz0123456789-_"):
			return false
	return true


func _kinds() -> Array[WeftluminKind]:
	return adapter.cli_kinds() if adapter != null else []


func _kind(kind_id: String) -> WeftluminKind:
	for kind: WeftluminKind in _kinds():
		if String(kind.id) == kind_id:
			return kind
	return null


static func _dialogue_sources(root: String) -> Dictionary:
	var sources: Dictionary = {}
	var pending: Array[String] = [root]
	while not pending.is_empty():
		var directory: String = pending.pop_back()
		if not DirAccess.dir_exists_absolute(directory):
			continue
		for child: String in DirAccess.get_directories_at(directory):
			pending.append(directory.path_join(child))
		for filename: String in DirAccess.get_files_at(directory):
			if filename.get_extension() == "dialogue":
				var path: String = directory.path_join(filename)
				sources[path] = FileAccess.get_file_as_string(path)
	return sources


# --- validate ---------------------------------------------------------------------------------


func validate(package: Dictionary) -> Dictionary:
	var errors: Array[Dictionary] = []
	errors.append_array(package["errors"])
	var report: Dictionary = {
		"schema": CLI_SCHEMA, "verb": "validate", "package": package["id"], "dir": package["dir"],
		"kinds": package["kinds"], "counts": {}, "errors": errors, "warnings": [],
	}
	if not DirAccess.dir_exists_absolute(str(package["dir"])):
		_say("validate: no package at %s" % package["dir"])
		return report
	var known: Array[StringName] = []
	for kind: WeftluminKind in _kinds():
		known.append(kind.id)
	var manifest_check := WeftluminPackage.new()
	manifest_check.manifest = (package["manifest"] as Dictionary).duplicate(true)
	manifest_check.source = str(package["dir"]).path_join(MANIFEST_FILE) if package["manifest_present"] else str(package["dir"])
	manifest_check.validate_manifest(known, errors)
	var counts: Dictionary = report["counts"]
	for kind_id: String in package["kinds"]:
		var kind: WeftluminKind = _kind(kind_id)
		if kind == null:
			continue
		var documents: Array[Dictionary] = []
		if kind_id == SCENES_KIND:
			documents.assign(package["log_entries"])
			errors.append_array(validate_log(documents, str(package["log_path"])))
		else:
			documents.assign((package["documents"] as Dictionary).get(kind_id, []))
		counts[kind_id] = documents.size()
		errors.append_array(adapter.validate_package_documents(kind, documents, package))
	_say("validate %s: %d kind(s), %d error(s)" % [package["id"], (package["kinds"] as Array).size(), errors.size()])
	for error: Dictionary in errors:
		_say("  ERROR %s [%s] %s: %s" % [error.get("file", ""), error.get("field", ""), error.get("code", ""), error.get("message", "")])
	return report


## Every log entry is a well-formed `weftlumin.command.v1` entry (bookkeeping included), ids are
## unique, and every undo/redo names an earlier command.
static func validate_log(entries: Array[Dictionary], path: String) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	var seen: Dictionary = {}
	for index: int in entries.size():
		var data: Dictionary = entries[index]
		var field: String = "commands[%d]" % index
		if str(data.get("schema", WeftluminCommand.SCHEMA)) != WeftluminCommand.SCHEMA:
			errors.append(attributed(path, field + ".schema", WeftluminCommand.SCHEMA, "unsupported_command_schema", "Entry %d is not %s." % [index, WeftluminCommand.SCHEMA]))
			continue
		var command: WeftluminCommand = WeftluminCommand.from_dict(data)
		var problems: PackedStringArray = command.validation_errors()
		if not problems.is_empty():
			errors.append(attributed(path, field, "a well-formed command", "invalid_command", "; ".join(problems)))
			continue
		if command.is_bookkeeping():
			if not seen.has(command.referenced_command_id()):
				errors.append(attributed(path, field + ".target.command", "an earlier command id", "dangling_bookkeeping",
					"%s names %s, which no earlier entry has." % [command.op, command.referenced_command_id()]))
		elif seen.has(command.id):
			errors.append(attributed(path, field + ".id", "a unique command id", "duplicate_command_id", "Command id %s repeats." % command.id))
		seen[command.id] = true
	return errors


# --- apply ------------------------------------------------------------------------------------


## Replay `log_path` (after the package's own log) onto fresh out-of-tree scene instances, run
## logged live-state verbs against the live autoloads, and on success write the combined log and
## the replayed scenes as scratch under the package directory. Never inside the project.
func apply(package_path: String, log_path: String) -> Dictionary:
	var dir: String = normalise_path(package_path)
	var source: String = normalise_path(log_path)
	var errors: Array[Dictionary] = []
	var report: Dictionary = {
		"schema": CLI_SCHEMA, "verb": "apply", "package": "", "dir": dir, "log": source,
		"replayed": [], "live": [], "skipped_ops": 0, "written": [], "errors": errors,
	}
	if is_inside_project(dir):
		errors.append(attributed(dir, "$", "a scratch package directory outside the project (user:// or elsewhere)", "scratch_only",
			"apply writes scratch; %s is inside the project. Use bake --write to change res://." % dir))
		_say("apply: refused, %s is inside the project" % dir)
		return report
	if not FileAccess.file_exists(source):
		errors.append(attributed(source, "$", "a command log", "missing_log", "No command log at %s." % source))
		return report
	var entries: Array[Dictionary] = []
	var existing: String = dir.path_join(LOG_FILE)
	if FileAccess.file_exists(existing):
		entries.append_array(load_log(existing, errors))
	var incoming: Array[Dictionary] = load_log(source, errors)
	entries.append_array(incoming)
	errors.append_array(validate_log(entries, source))
	if not errors.is_empty():
		return report
	var package_id: String = ""
	for entry: Dictionary in entries:
		package_id = str(entry.get("package", ""))
		if not package_id.is_empty():
			break
	report["package"] = package_id if not package_id.is_empty() else dir.get_file()
	var scene_entries: Array[Dictionary] = []
	var live_entries: Array[Dictionary] = []
	for data: Dictionary in WeftluminCommandBus.effective_stream(entries):
		if str(data.get("kind", "")) == SCENE_COMMAND_KIND:
			scene_entries.append(data)
		else:
			live_entries.append(data)
	var scratch: String = dir.path_join(SCRATCH_DIR)
	var baked: Dictionary = WeftluminBake.bake(scene_entries, scratch, true, true, {"package": report["package"]})
	errors.append_array(baked["errors"])
	for planned: Dictionary in baked["planned"]:
		(report["replayed"] as Array).append({"scene": planned["path"], "ops": planned["ops"], "scratch": planned["target"]})
	(report["written"] as Array).append_array(baked["written"])
	for data: Dictionary in live_entries:
		var outcome: Dictionary = adapter.run_live_verb(data)
		var row: Dictionary = {
			"id": str(data.get("id", "")), "kind": str(data.get("kind", "")), "op": str(data.get("op", "")),
			"ok": bool(outcome.get("ok", false)), "output": outcome.get("output", []),
		}
		(report["live"] as Array).append(row)
		if not bool(outcome.get("handled", false)):
			errors.append(attributed(source, "commands[%s]" % row["id"], "a scene command or a host live-state verb", "unknown_kind",
				"No replay handler or live verb for %s/%s." % [row["kind"], row["op"]]))
	if errors.is_empty():
		var text: String = ""
		for entry: Dictionary in entries:
			text += JSON.stringify(entry, "", true) + "\n"
		var written: Error = write_text_atomically(existing, text)
		if written != OK:
			errors.append(attributed(existing, "$", "a writable scratch log", "write_failed", "Writing failed (error %d)." % written))
		else:
			(report["written"] as Array).append(existing)
	_say("apply %s: %d scene op(s) replayed in %d scene(s), %d live verb(s), %d written, %d error(s)" % [
		report["package"], scene_entries.size(), (report["replayed"] as Array).size(),
		live_entries.size(), (report["written"] as Array).size(), errors.size(),
	])
	for error: Dictionary in errors:
		_say("  ERROR %s [%s] %s: %s" % [error.get("file", ""), error.get("field", ""), error.get("code", ""), error.get("message", "")])
	return report


# --- bake -------------------------------------------------------------------------------------


## The `weftlumin.bake.v1` report for the whole package (scene log + document kinds), with the
## lint section filled. `write` writes only when the whole report-mode pass is clean.
func bake(package: Dictionary, write: bool, force: bool) -> Dictionary:
	var report: Dictionary = bake_pass(package, false, force)
	if force and not write:
		(report["errors"] as Array).append(WeftluminBake._attributed("", "force", "--write", "force_without_write", "--force applies only with --write."))
	if write and (report["errors"] as Array).is_empty():
		if int((report["lint"] as Dictionary).get("errors", 0)) > 0:
			(report["errors"] as Array).append(attributed(str(package["dir"]), "lint", "a clean lint", "lint_failed", "The package has lint errors; nothing was written."))
		else:
			var lint_section: Dictionary = report["lint"]
			report = bake_pass(package, true, force)
			report["lint"] = lint_section
	_say("bake %s (%s): %s" % [package["id"], report["mode"], report["summary"]])
	for planned: Dictionary in report["planned"]:
		_say("  %s %s %s%s" % [planned.get("action", ""), planned.get("kind", ""), planned.get("path", ""),
			" (%d ops)" % int(planned["ops"]) if planned.has("ops") else ""])
	for path: String in report["written"]:
		_say("  wrote %s" % path)
	for error: Dictionary in report["errors"]:
		_say("  ERROR %s [%s] %s: %s" % [error.get("file", ""), error.get("field", ""), error.get("code", ""), error.get("message", "")])
	return report


func bake_pass(package: Dictionary, write: bool, force: bool) -> Dictionary:
	var validation: Dictionary = validate_quietly(package)
	var report: Dictionary = {
		"schema": WeftluminBake.SCHEMA, "package": package["id"], "mode": "write" if write else "report",
		"planned": [], "written": [], "regenerated": [],
		"lint": {"errors": 0, "warnings": 0, "pot_delta": []},
		"refused_overlap": [], "errors": [], "summary": "",
	}
	var errors: Array = report["errors"]
	errors.append_array(validation["errors"])
	var linted: Dictionary = lint_quietly(package)
	report["lint"] = {
		"errors": (linted["lint_errors"] as Array).size(), "warnings": (linted["warnings"] as Array).size(),
		"pot_delta": linted["pot_delta"],
	}
	if not errors.is_empty():
		report["summary"] = "refused: %d validation error(s); nothing baked" % errors.size()
		return report
	var parts: Array[String] = []
	for kind_id: String in package["kinds"]:
		var kind: WeftluminKind = _kind(kind_id)
		if kind == null:
			continue
		var section: Dictionary = {}
		if kind_id == SCENES_KIND:
			var entries: Array = package["log_entries"]
			var validators: Array = []
			validators.assign(adapter.scene_bake_validators())
			# WeftluminBake refuses --force without --write, so the report pass of a forced bake
			# runs unforced and drops only the stale-target refusals --force will override.
			section = WeftluminBake.bake(entries, "res://", write, force and write, {"package": package["id"], "validators": validators})
			if force and not write:
				var kept: Array = []
				for error: Dictionary in section.get("errors", []):
					if str(error.get("code", "")) != "stale_target":
						kept.append(error)
				section["errors"] = kept
			report["skipped_ops"] = section.get("skipped_ops", 0)
			report["normalized"] = section.get("normalized", [])
		else:
			var documents: Array[Dictionary] = []
			documents.assign((package["documents"] as Dictionary).get(kind_id, []))
			section = adapter.bake_package_documents(kind, documents, package, write, force)
		if section.is_empty():
			parts.append("%s: no bake" % kind_id)
			continue
		for key: String in ["planned", "written", "regenerated", "errors"]:
			(report[key] as Array).append_array(section.get(key, []))
		parts.append("%s: %s" % [kind_id, section.get("summary", "")])
	report["summary"] = "; ".join(parts) if not parts.is_empty() else "nothing to bake"
	return report


# --- regen ------------------------------------------------------------------------------------


func regen(write: bool) -> Dictionary:
	var result: Dictionary = adapter.regen(write)
	var report: Dictionary = {
		"schema": CLI_SCHEMA, "verb": "regen", "mode": "write" if write else "report",
		"stages": result.get("stages", []), "regenerated": result.get("regenerated", []), "errors": [],
	}
	(report["errors"] as Array).append_array(result.get("errors", []))
	for stage: Dictionary in report["stages"]:
		_say("regen %s: %s %s" % [stage.get("name", ""), "ok" if bool(stage.get("ok", false)) else "FAILED", stage.get("message", "")])
		if not bool(stage.get("ok", false)):
			(report["errors"] as Array).append(attributed(str(stage.get("name", "")), "$", "a clean stage", "regen_stage_failed", str(stage.get("message", ""))))
	if (report["stages"] as Array).is_empty():
		_say("regen: the host adapter declares no regeneration stages")
	return report


# --- lint -------------------------------------------------------------------------------------


func lint(package: Dictionary) -> Dictionary:
	var report: Dictionary = lint_quietly(package)
	_say("lint %s: %d error(s), %d warning(s), %d POT delta string(s), %d response condition(s) in %d dialogue file(s)" % [
		package["id"], (report["lint_errors"] as Array).size(), (report["warnings"] as Array).size(),
		(report["pot_delta"] as Array).size(), int(report["dialogue_conditions"]), (package["dialogue"] as Dictionary).size(),
	])
	for finding: Dictionary in report["lint_errors"]:
		_say("  ERROR %s:%s %s: %s" % [finding.get("file", ""), finding.get("line", ""), finding.get("code", ""), finding.get("message", "")])
	for finding: Dictionary in report["warnings"]:
		_say("  warning %s:%s %s: %s" % [finding.get("file", ""), finding.get("line", ""), finding.get("code", ""), finding.get("message", "")])
	for text: String in report["pot_delta"]:
		_say("  POT delta: %s" % text)
	return report


## `{schema, package, lint_errors, warnings, pot_delta, dialogue_conditions, errors}`. `errors`
## holds only package-loading errors; findings are `lint_errors` so a bake can count them.
func lint_quietly(package: Dictionary) -> Dictionary:
	var findings: Array[Dictionary] = []
	var conditions: int = 0
	var sources: Dictionary = package["dialogue"]
	var paths: Array = sources.keys()
	paths.sort()
	var tag := RegEx.create_from_string(IF_TAG)
	for path: String in paths:
		var line_number: int = 0
		for line: String in str(sources[path]).split("\n"):
			line_number += 1
			if is_response_line(line):
				conditions += tag.search_all(line).size()
			findings.append_array(lint_dialogue_line(path, line_number, line))
	var warnings: Array[Dictionary] = []
	var host: Dictionary = adapter.lint_package(package) if adapter != null else {}
	findings.append_array(host.get("errors", []))
	warnings.append_array(host.get("warnings", []))
	return {
		"schema": LINT_SCHEMA, "verb": "lint", "package": package["id"], "lint_errors": findings,
		"warnings": warnings, "pot_delta": pot_delta(package), "dialogue_conditions": conditions,
		"errors": (package["errors"] as Array).duplicate(),
	}


func validate_quietly(package: Dictionary) -> Dictionary:
	var was: bool = echo
	var kept: int = lines.size()
	echo = false
	var report: Dictionary = validate(package)
	echo = was
	lines.resize(kept)
	return report


# --- the [if /] lint (port of tools/lint_dialogue_conditions.py) ------------------------------


## A Dialogue Manager response line starts with `-` after optional indentation.
static func is_response_line(line: String) -> bool:
	var stripped: String = line.strip_edges(true, false)
	return stripped.begins_with("- ") or stripped == "-"


## `NOT_SELF_CLOSING` (`[if expr]` silently no-ops), `CONDITION_NOT_LAST` (another tag follows
## the condition), `UNCLOSED` (no `]`). Same rules and codes as the Python lint, which CI runs
## before Godot exists.
static func lint_dialogue_line(path: String, line_number: int, line: String) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if not is_response_line(line):
		return findings
	for found: RegExMatch in RegEx.create_from_string(IF_TAG).search_all(line):
		var start: int = found.get_start()
		var close: int = line.find("]", start)
		if close == -1:
			findings.append(_lint_finding("UNCLOSED", path, line_number, line.substr(start).strip_edges(), "an [if tag has no closing bracket"))
			continue
		var tag: String = line.substr(start, close + 1 - start)
		if not tag.ends_with("/]"):
			findings.append(_lint_finding("NOT_SELF_CLOSING", path, line_number, tag,
				"condition is missing the trailing '/' and will silently no-op; the choice always shows"))
			continue
		var trailing: String = line.substr(close + 1).strip_edges()
		if not trailing.is_empty():
			findings.append(_lint_finding("CONDITION_NOT_LAST", path, line_number, tag,
				"the condition must close the response line, but '%s' follows it" % trailing))
	return findings


static func _lint_finding(code: String, path: String, line_number: int, tag: String, message: String) -> Dictionary:
	return {
		"file": path, "field": "line %d" % line_number, "expected": "[if expr /] closing the response line",
		"code": code, "message": message, "line": line_number, "tag": tag, "severity": "error",
	}


# --- POT delta --------------------------------------------------------------------------------


## Player-facing strings the package adds that no POT the host lists contains (sorted, unique):
## dialogue lines and responses (or their `[ID:…]` static ids) and string values the scene log
## sets on the host's player-facing keys. Reported, never written: POT regeneration stays an
## editor-machine chore (§9).
func pot_delta(package: Dictionary) -> Array[String]:
	var pot_paths: Array[String] = []
	var keys: Array[String] = []
	if adapter != null:
		pot_paths = adapter.pot_files()
		keys = adapter.player_facing_keys()
	var known: Dictionary = pot_msgids(pot_paths)
	var candidates: Dictionary = {}
	for path: String in package["dialogue"]:
		for text: String in dialogue_strings(str((package["dialogue"] as Dictionary)[path])):
			candidates[text] = true
	for data: Dictionary in WeftluminCommandBus.effective_stream(package["log_entries"]):
		if str(data.get("op", "")) != "set_property":
			continue
		var params: Dictionary = data.get("params", {}) as Dictionary if data.get("params") is Dictionary else {}
		var key: String = str(params.get("key", params.get("export", "")))
		if key not in keys:
			continue
		var value: Variant = params.get("value")
		if params.has("value_text"):
			value = str_to_var(str(params["value_text"]))
		if value is String and not str(value).strip_edges().is_empty():
			candidates[str(value)] = true
	var delta: Array[String] = []
	for text: String in candidates:
		if not known.has(text):
			delta.append(text)
	delta.sort()
	return delta


## Every non-empty msgid in the given `.pot`/`.po` files (the acceptance gate's parser).
static func pot_msgids(paths: Array[String]) -> Dictionary:
	var ids: Dictionary = {}
	for path: String in paths:
		if not FileAccess.file_exists(path):
			continue
		var current: Array[String] = []
		var open: bool = false
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			if line.begins_with("msgid "):
				_flush_msgid(ids, current, open)
				current = [_po_unquote(line.substr(6))]
				open = true
			elif line.begins_with("msgid_plural ") or line.begins_with("msgstr") or line.strip_edges().is_empty():
				_flush_msgid(ids, current, open)
				current = []
				open = false
			elif open and line.begins_with("\""):
				current.append(_po_unquote(line))
		_flush_msgid(ids, current, open)
	return ids


static func _flush_msgid(ids: Dictionary, parts: Array[String], open: bool) -> void:
	var text: String = "".join(parts)
	if open and not text.is_empty():
		ids[text] = true


static func _po_unquote(value: String) -> String:
	var text: String = value.strip_edges()
	if text.length() >= 2 and text.begins_with("\"") and text.ends_with("\""):
		text = text.substr(1, text.length() - 2)
	return text.c_unescape()


## The translatable text of a `.dialogue` file, heuristically: dialogue lines (speaker removed)
## and responses, without tags, conditions or jumps; a line with `[ID:x]` contributes `x`.
## Titles, jumps, mutations, conditions, comments and imports contribute nothing.
static func dialogue_strings(source: String) -> Array[String]:
	var found: Array[String] = []
	var tags := RegEx.create_from_string("\\[[^\\]]*\\]")
	var static_id := RegEx.create_from_string("\\[ID:([^\\]]+)\\]")
	var skipped: Array[String] = ["#", "~", "=>", "=><", "do ", "do!", "set ", "if ", "elif ", "else", "import ", "using ", "while ", "match ", "when "]
	for raw: String in source.split("\n"):
		var line: String = raw.strip_edges()
		if line.is_empty():
			continue
		var skip: bool = false
		for prefix: String in skipped:
			skip = skip or line.begins_with(prefix)
		if skip:
			continue
		if line.begins_with("- "):
			line = line.substr(2).strip_edges()
		var identified: RegExMatch = static_id.search(line)
		if identified != null:
			found.append(identified.get_string(1).strip_edges())
			continue
		var jump: int = line.find("=>")
		if jump >= 0:
			line = line.left(jump)
		line = tags.sub(line, "", true).strip_edges()
		var colon: int = line.find(": ")
		if colon > 0 and colon < 48 and not line.left(colon).contains("\"") and not line.left(colon).contains("{"):
			line = line.substr(colon + 2).strip_edges()
		if line.length() >= 2 and line.begins_with("\"") and line.ends_with("\""):
			line = line.substr(1, line.length() - 2)
		if not line.is_empty():
			found.append(line)
	return found


# --- shared -----------------------------------------------------------------------------------


static func attributed(file: String, field: String, expected: String, code: String, message: String) -> Dictionary:
	return {"file": file, "field": field, "expected": expected, "code": code, "message": message}


static func write_text_atomically(path: String, text: String) -> Error:
	var target: String = path if path.begins_with("res://") or path.begins_with("user://") or path.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(path)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	if directory_error != OK and not DirAccess.dir_exists_absolute(target.get_base_dir()):
		return directory_error
	var temporary: String = target + ".weftlumin-tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return DirAccess.rename_absolute(temporary, target)


## Run a process through `runner` (tests swap it) or `OS.execute`. `{exit_code, output}`.
func execute(program: String, arguments: PackedStringArray) -> Dictionary:
	if runner.is_valid():
		return runner.call(program, arguments)
	var output: Array = []
	var code: int = OS.execute(program, arguments, output, true)
	return {"exit_code": code, "output": "".join(PackedStringArray(output))}
