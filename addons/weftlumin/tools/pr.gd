extends RefCounted
## The `pr` subcommand (E7.1, `docs/architecture-in-game-editor.md` §4.13) and the detached
## launcher the in-game **Bake & PR** surface uses.
##
## `pr <package_dir> [--issue N] [--draft] [--force] [--execute] [--open-prs FILE]
##    [--worktree DIR] [--trailer TEXT]... [--base BRANCH]`
##
## **Dry run by default.** Without `--execute` it validates, bakes in report mode, lints, picks
## the affected tests from the host's kind → test-glob map, scans for overlapping open PRs, and
## prints the exact plan: worktree branch `weftlumin/<package id>`, the bake `--write` inside that
## worktree, lint, the affected tests, the commit, the push, and `gh pr create` whose body is the
## bake report plus `Closes #N`. It runs no process and touches no network or GitHub: the
## overlap scan reads `--open-prs FILE` (the JSON of `gh pr list --json number,title,headRefName,files`)
## or reports itself unchecked. `--execute` runs the plan, fetching the open PRs with `gh` first.
##
## **Overlap refusal.** A planned file that an open PR also changes is refused unless `--force`:
## the bake report's `refused_overlap` lists each PR and the shared files, and the exit code is 3.
## This is the local equivalent of `jules-merge-conflicts.yml`'s overlap scan, which needs a PR
## number and runs in CI after the PR exists.
##
## **Never decided here** (the issue's "do not decide"): labels, milestones and assignees are never
## set; commit trailers are only the `--trailer` values given, verbatim.

const BRANCH_PREFIX := "weftlumin/"
const CLI_ENTRY := "res://addons/weftlumin/tools/weftlumin.gd"
const DEFAULT_BASE := "main"
const TEST_RUNNER := "scripts/test.sh"
const DRIFT_STAGE := "scripts/check_generated_data.sh"

var cli: RefCounted = null


func _init(owner: RefCounted = null) -> void:
	cli = owner


# --- pr ---------------------------------------------------------------------------------------


func run(package: Dictionary, options: Dictionary) -> Dictionary:
	var execute: bool = options.has("--execute")
	var force: bool = options.has("--force")
	var issue: String = str(options.get("--issue", ""))
	var base: String = str(options.get("--base", DEFAULT_BASE))
	var report: Dictionary = cli.call("bake", package, false, false)
	report["mode"] = "pr-execute" if execute else "pr-dry-run"
	var pr: Dictionary = {
		"dry_run": not execute, "branch": BRANCH_PREFIX + str(package["id"]), "base": base,
		"issue": issue, "draft": options.has("--draft"), "worktree": "", "changed_files": [],
		"affected_tests": [], "overlap": {"checked": false, "source": "", "open_prs": 0},
		"steps": [], "executed": [], "url": "",
	}
	report["pr"] = pr
	if not (report["errors"] as Array).is_empty() or int((report["lint"] as Dictionary).get("errors", 0)) > 0:
		if (report["errors"] as Array).is_empty():
			(report["errors"] as Array).append(cli.call("attributed", str(package["dir"]), "lint", "a clean lint", "lint_failed", "The package has lint errors; no PR."))
		_say("pr %s: refused before planning (%d error(s))" % [package["id"], (report["errors"] as Array).size()])
		return report
	var changed: Array[String] = changed_files(report)
	pr["changed_files"] = changed
	var kind_ids: Array[String] = []
	kind_ids.assign(package["kinds"])
	var globs: Array[String] = cli.get("adapter").affected_test_globs(kind_ids)
	pr["affected_tests"] = expand_test_globs(globs)
	pr["drift_stage"] = globs.has(DRIFT_STAGE)
	pr["regen"] = not (report.get("regenerated", []) as Array).is_empty()

	var open_prs: Variant = null
	if options.has("--open-prs"):
		var path: String = str(options["--open-prs"])
		open_prs = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		if not open_prs is Array:
			(report["errors"] as Array).append(cli.call("attributed", path, "$", "a JSON array of open PRs", "invalid_open_prs", "%s is not a gh pr list JSON array." % path))
			return report
		pr["overlap"] = {"checked": true, "source": path, "open_prs": (open_prs as Array).size()}
	elif execute:
		var listed: Dictionary = cli.call("execute", "gh", PackedStringArray([
			"pr", "list", "--state", "open", "--base", base, "--limit", "200", "--json", "number,title,headRefName,files",
		]))
		open_prs = JSON.parse_string(str(listed.get("output", ""))) if int(listed.get("exit_code", 1)) == 0 else null
		if not open_prs is Array:
			(report["errors"] as Array).append(cli.call("attributed", "gh pr list", "$", "the open PRs", "overlap_scan_failed", "Could not list open PRs: %s" % str(listed.get("output", "")).strip_edges()))
			return report
		pr["overlap"] = {"checked": true, "source": "gh pr list", "open_prs": (open_prs as Array).size()}
	if open_prs is Array:
		var overlaps: Array[Dictionary] = overlapping(changed, open_prs as Array, str(pr["branch"]))
		pr["overlap"]["overlaps"] = overlaps
		if not overlaps.is_empty() and not force:
			report["refused_overlap"] = overlaps
			_say("pr %s: refused_overlap — %d open PR(s) touch the same files; pass --force to open anyway" % [package["id"], overlaps.size()])
			for overlap: Dictionary in overlaps:
				_say("  #%s %s: %s" % [overlap["pr"], overlap["branch"], ", ".join(PackedStringArray(overlap["files"]))])
			return report
	else:
		_say("pr %s: overlap not checked (dry run; pass --open-prs FILE, or --execute to ask gh)" % package["id"])

	var worktree: String = str(options.get("--worktree", default_worktree(str(package["id"]))))
	pr["worktree"] = worktree
	var body: String = pr_body(report, issue)
	var message: String = commit_message(package, report, issue, options.get("--trailer", []) as Array)
	pr["body"] = body
	pr["commit_message"] = message
	var steps: Array[Dictionary] = plan_steps(package, pr, worktree)
	pr["steps"] = steps
	_say("pr %s: %s plan, branch %s, %d changed file(s), %d affected test file(s)" % [
		package["id"], "executing" if execute else "dry-run", pr["branch"], changed.size(), (pr["affected_tests"] as Array).size(),
	])
	for step: Dictionary in steps:
		_say("  %s %s" % ["$" if execute else "would run:", step["display"]])
	if not execute:
		return report
	_execute(report, steps, worktree, body, message)
	return report


func _execute(report: Dictionary, steps: Array[Dictionary], worktree: String, body: String, message: String) -> void:
	var pr: Dictionary = report["pr"]
	var scratch: String = OS.get_user_data_dir().path_join("weftlumin").path_join("pr").path_join(str(report["package"]))
	DirAccess.make_dir_recursive_absolute(scratch)
	cli.call("write_text_atomically", scratch.path_join("body.md"), body)
	cli.call("write_text_atomically", scratch.path_join("commit.txt"), message)
	for step: Dictionary in steps:
		var arguments: PackedStringArray = PackedStringArray(step["args"])
		for index: int in arguments.size():
			arguments[index] = arguments[index].replace("{scratch}", scratch)
		var result: Dictionary = cli.call("execute", str(step["program"]), arguments)
		var ok: bool = int(result.get("exit_code", 1)) == 0
		if step.has("report"):
			# A Godot step is judged by the report it writes, not its exit code (teardown aborts).
			var written: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(step["report"]).replace("{scratch}", scratch)))
			ok = written is Dictionary and ((written as Dictionary).get("errors", []) as Array).is_empty() \
				and int((written as Dictionary).get("exit_code", 1)) == 0
		(pr["executed"] as Array).append({"step": step["name"], "ok": ok})
		_say("  %s %s" % ["ok" if ok else "FAILED", step["name"]])
		if not ok:
			(report["errors"] as Array).append(cli.call("attributed", worktree, step["name"], "a successful step", "pr_step_failed",
				"%s failed: %s" % [step["display"], str(result.get("output", "")).strip_edges().right(2000)]))
			return
		if step["name"] == "gh pr create":
			pr["url"] = str(result.get("output", "")).strip_edges()


## The ordered plan. Each step: `{name, program, args, display}`; Godot steps add `report`.
func plan_steps(package: Dictionary, pr: Dictionary, worktree: String) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	var repo: String = ProjectSettings.globalize_path("res://").trim_suffix("/")
	var godot: String = OS.get_executable_path()
	var package_dir: String = ProjectSettings.globalize_path(str(package["dir"]))
	var branch: String = pr["branch"]
	steps.append(_step("worktree", "git", ["-C", repo, "worktree", "add", "-b", branch, worktree, str(pr["base"])]))
	steps.append(_step("import", godot, ["--headless", "--path", worktree, "--import"]))
	var bake: Dictionary = _step("bake --write", godot, [
		"--headless", "--path", worktree, "--script", CLI_ENTRY, "--", "bake", package_dir, "--write", "--report", "{scratch}/bake.json",
	])
	bake["report"] = "{scratch}/bake.json"
	steps.append(bake)
	var lint: Dictionary = _step("lint", godot, [
		"--headless", "--path", worktree, "--script", CLI_ENTRY, "--", "lint", package_dir, "--report", "{scratch}/lint.json",
	])
	lint["report"] = "{scratch}/lint.json"
	if bool(pr.get("regen", false)):
		var regen: Dictionary = _step("regen --write", godot, [
			"--headless", "--path", worktree, "--script", CLI_ENTRY, "--", "regen", "--write", "--report", "{scratch}/regen.json",
		])
		regen["report"] = "{scratch}/regen.json"
		steps.append(regen)
	steps.append(lint)
	for test: String in pr["affected_tests"]:
		steps.append(_step("test " + test, "bash", ["-c", 'cd "$1" && GODOT_BIN="$2" bash %s -a "$3"' % TEST_RUNNER, "weftlumin-pr", worktree, godot, test]))
	if bool(pr.get("drift_stage", false)):
		steps.append(_step("drift stages", "bash", ["-c", 'cd "$1" && GODOT_BIN="$2" bash %s' % DRIFT_STAGE, "weftlumin-pr", worktree, godot]))
	steps.append(_step("git add", "git", ["-C", worktree, "add", "-A"]))
	steps.append(_step("git commit", "git", ["-C", worktree, "commit", "-F", "{scratch}/commit.txt"]))
	steps.append(_step("git push", "git", ["-C", worktree, "push", "-u", "origin", branch]))
	var create: Array = ["-c", 'cd "$1" && shift && exec gh "$@"', "weftlumin-pr", worktree,
		"pr", "create", "--base", str(pr["base"]), "--head", branch, "--title", pr_title(package), "--body-file", "{scratch}/body.md"]
	if bool(pr["draft"]):
		create.append("--draft")
	var gh: Dictionary = _step("gh pr create", "bash", create)
	gh["display"] = "gh pr create --base %s --head %s --title %s --body-file {scratch}/body.md%s" % [
		pr["base"], branch, JSON.stringify(pr_title(package)), " --draft" if bool(pr["draft"]) else "",
	]
	steps.append(gh)
	return steps


static func _step(name: String, program: String, args: Array) -> Dictionary:
	var shown: PackedStringArray = [program.get_file()]
	for arg: Variant in args:
		var text: String = str(arg)
		shown.append(text if not text.contains(" ") else JSON.stringify(text))
	return {"name": name, "program": program, "args": args, "display": " ".join(shown)}


## Repository-relative files the bake would create or change, sorted.
static func changed_files(report: Dictionary) -> Array[String]:
	var found: Dictionary = {}
	for planned: Dictionary in report.get("planned", []):
		if str(planned.get("action", "")) in ["create", "update"]:
			found[str(planned.get("target", planned.get("path", ""))).trim_prefix("res://")] = true
	for path: Variant in report.get("regenerated", []):
		found[str(path).trim_prefix("res://")] = true
	var files: Array[String] = []
	for path: String in found:
		files.append(path)
	files.sort()
	return files


## Open PRs (gh `--json number,title,headRefName,files`) sharing a changed file, skipping this
## package's own branch. `[{pr, title, branch, files}]`.
static func overlapping(changed: Array[String], open_prs: Array, own_branch: String) -> Array[Dictionary]:
	var overlaps: Array[Dictionary] = []
	for value: Variant in open_prs:
		if not value is Dictionary:
			continue
		var open_pr: Dictionary = value
		if str(open_pr.get("headRefName", "")) == own_branch:
			continue
		var shared: Array[String] = []
		for file: Variant in open_pr.get("files", []):
			var path: String = str((file as Dictionary).get("path", "")) if file is Dictionary else str(file)
			if path in changed and path not in shared:
				shared.append(path)
		if not shared.is_empty():
			shared.sort()
			overlaps.append({
				"pr": int(open_pr.get("number", 0)), "title": str(open_pr.get("title", "")),
				"branch": str(open_pr.get("headRefName", "")), "files": shared,
			})
	return overlaps


## Test files matching the host's globs (`test/unit/test_quest_*`, or a file path), sorted.
## Globs with no `*` and no match, such as a drift script, are dropped here.
static func expand_test_globs(globs: Array[String]) -> Array[String]:
	var found: Dictionary = {}
	for glob: String in globs:
		var directory: String = "res://" + glob.get_base_dir()
		var pattern: String = glob.get_file()
		if not DirAccess.dir_exists_absolute(directory):
			continue
		for filename: String in DirAccess.get_files_at(directory):
			if filename.get_extension() == "gd" and filename.match(pattern if pattern.ends_with(".gd") or pattern.ends_with("*") else pattern + ".gd"):
				found[glob.get_base_dir().path_join(filename)] = true
	var files: Array[String] = []
	for path: String in found:
		files.append(path)
	files.sort()
	return files


static func default_worktree(package_id: String) -> String:
	var repo: String = ProjectSettings.globalize_path("res://").trim_suffix("/")
	return repo.get_base_dir().path_join("%s-weftlumin-%s" % [repo.get_file(), package_id])


static func pr_title(package: Dictionary) -> String:
	return "Weftlumin: %s" % str(package.get("title", package.get("id", "")))


## The PR body: the bake report (summary, planned and regenerated files, lint, POT delta) and
## the report JSON, then `Closes #N` when an issue is given.
static func pr_body(report: Dictionary, issue: String) -> String:
	var lines: Array[String] = [
		"Weftlumin bake of package `%s`." % report.get("package", ""), "",
		"**Summary:** %s" % report.get("summary", ""), "", "### Planned", "",
	]
	for planned: Dictionary in report.get("planned", []):
		lines.append("- %s `%s` (%s)" % [planned.get("action", ""), planned.get("path", ""), planned.get("kind", "")])
	if not (report.get("regenerated", []) as Array).is_empty():
		lines.append_array(["", "### Regenerated", ""])
		for path: Variant in report["regenerated"]:
			lines.append("- `%s`" % path)
	var lint: Dictionary = report.get("lint", {})
	lines.append_array(["", "### Lint", "", "%d error(s), %d warning(s)." % [int(lint.get("errors", 0)), int(lint.get("warnings", 0))]])
	var delta: Array = lint.get("pot_delta", [])
	if not delta.is_empty():
		lines.append_array(["", "POT delta (not yet in the translation template):", ""])
		for text: Variant in delta:
			lines.append("- %s" % JSON.stringify(str(text)))
	var shown: Dictionary = report.duplicate(true)
	shown.erase("pr")
	lines.append_array(["", "<details><summary>weftlumin.bake.v1 report</summary>", "", "```json", JSON.stringify(shown, "  ", false), "```", "", "</details>"])
	if not issue.is_empty():
		lines.append_array(["", "Closes #%s" % issue])
	return "\n".join(lines) + "\n"


static func commit_message(package: Dictionary, report: Dictionary, issue: String, trailers: Array) -> String:
	var lines: Array[String] = ["Weftlumin bake: %s" % package.get("id", ""), "", str(report.get("summary", ""))]
	if not issue.is_empty():
		lines.append_array(["", "Closes #%s" % issue])
	if not trailers.is_empty():
		lines.append("")
		for trailer: Variant in trailers:
			lines.append(str(trailer))
	return "\n".join(lines) + "\n"


func _say(text: String) -> void:
	cli.call("_say", text)


# --- detached launcher (the in-game Bake & PR surface) ----------------------------------------


## Start the CLI as a detached headless Godot (`OS.create_process`, never `OS.execute`, which would
## block the main thread for the whole run). Debug builds only. `report_path` is where the CLI
## writes its report; a stale one is removed first. `{ok, pid, report_path, arguments, message}`.
static func launch(arguments: PackedStringArray, report_path: String) -> Dictionary:
	var handle: Dictionary = {"ok": false, "pid": -1, "report_path": report_path, "arguments": PackedStringArray(), "message": ""}
	if not OS.is_debug_build():
		handle["message"] = "Bake & PR runs only in debug builds."
		return handle
	var report: String = ProjectSettings.globalize_path(report_path)
	if FileAccess.file_exists(report):
		DirAccess.remove_absolute(report)
	var full: PackedStringArray = launch_arguments(arguments, report)
	handle["arguments"] = full
	var pid: int = OS.create_process(OS.get_executable_path(), full)
	handle["pid"] = pid
	handle["ok"] = pid > 0
	if pid <= 0:
		handle["message"] = "Could not start %s." % OS.get_executable_path()
	return handle


static func launch_arguments(arguments: PackedStringArray, report_path: String) -> PackedStringArray:
	var full: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://").trim_suffix("/"), "--script", CLI_ENTRY, "--"]
	full.append_array(arguments)
	full.append_array(["--report", ProjectSettings.globalize_path(report_path)])
	return full


## `{state: running | done | failed | cancelled, report}`. A report file means done (judged by its
## contents, not the process exit code); a process gone without one means failed.
static func poll(handle: Dictionary) -> Dictionary:
	if bool(handle.get("cancelled", false)):
		return {"state": "cancelled", "report": {}}
	var report_path: String = ProjectSettings.globalize_path(str(handle.get("report_path", "")))
	if FileAccess.file_exists(report_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(report_path))
		if parsed is Dictionary:
			return {"state": "done", "report": parsed}
	var pid: int = int(handle.get("pid", -1))
	if pid > 0 and OS.is_process_running(pid):
		return {"state": "running", "report": {}}
	return {"state": "failed", "report": {}}


## Stop a launched run. The handle is marked cancelled even if the process already ended.
static func cancel(handle: Dictionary) -> Dictionary:
	var pid: int = int(handle.get("pid", -1))
	var killed: Error = OS.kill(pid) if pid > 0 and OS.is_process_running(pid) else OK
	handle["cancelled"] = true
	return {"ok": killed == OK, "state": "cancelled"}
