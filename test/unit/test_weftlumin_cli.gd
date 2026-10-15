extends GdUnitTestSuite
## E7.1 (#351): the Weftlumin headless CLI (`addons/weftlumin/tools/weftlumin.gd` → `cli.gd`,
## `pr.gd`). Each verb runs in-process against the Dom fixture package or a scratch package under
## `user://`, and is judged by its printed `WEFTLUMIN:` status line and report, not only the exit
## code. Nothing here writes `res://`, starts a process, or touches the network: the PR flow's
## runner is replaced by a recorder that fails the test if it is called.

const CliScript := preload("res://addons/weftlumin/tools/cli.gd")
const PrScript := preload("res://addons/weftlumin/tools/pr.gd")
const AdapterScript := preload("res://addons/weftlumin/shell/soul_meter_adapter.gd")
const FIXTURE := "res://test/fixtures/weftlumin/dom_scene_bake"
const FIXTURE_LOG := "res://test/fixtures/weftlumin/dom_scene_bake/commands.jsonl"
const OPEN_PRS := "res://test/fixtures/weftlumin/cli/open_prs.json"
const DOM := "res://world/starting_town.tscn"
const SCRATCH := "user://weftlumin_cli_test"
const PACKAGE := "dom-scene-bake"
## Every committed file a verb could plausibly write in report mode.
const GUARDED: Array[String] = [
	DOM, "res://canon/dom/locations/dom.json", "res://data/generated/location_index.json",
	"res://world/locations/dom.tres", "res://data.pandora",
]

var _executed: Array = []


func after_test() -> void:
	_remove_tree(SCRATCH)
	_remove_tree(OS.get_user_data_dir().path_join("weftlumin/pr").path_join(PACKAGE))
	_executed.clear()


# --- argument parsing and output ----------------------------------------------------------------


func test_usage_errors_exit_two_and_name_the_problem() -> void:
	for args: PackedStringArray in [
		PackedStringArray([]), PackedStringArray(["frobnicate"]), PackedStringArray(["bake"]),
		PackedStringArray(["bake", FIXTURE, "--wrote"]), PackedStringArray(["apply", SCRATCH]),
		PackedStringArray(["pr", FIXTURE, "--issue", "abc"]),
	]:
		var result: Dictionary = _run(args)
		assert_int(result["exit_code"]).override_failure_message(str(args)).is_equal(CliScript.EXIT_USAGE)
		assert_str(_status(result)).is_equal("WEFTLUMIN: %s usage exit=2" % (args[0] if not args.is_empty() else "?"))


func test_every_run_prints_one_report_line_and_one_status_line() -> void:
	var result: Dictionary = _run(PackedStringArray(["validate", FIXTURE, "--report", SCRATCH + "/validate.json"]))
	var lines: Array = result["lines"]
	assert_str(str(lines[lines.size() - 2])).starts_with(CliScript.REPORT_PREFIX)
	var printed: Variant = JSON.parse_string(str(lines[lines.size() - 2]).trim_prefix(CliScript.REPORT_PREFIX))
	assert_bool(printed is Dictionary).is_true()
	assert_str(str((printed as Dictionary)["verb"])).is_equal("validate")
	# --report writes the same report atomically.
	var written: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCRATCH + "/validate.json"))
	assert_bool(written is Dictionary).is_true()
	assert_str(JSON.stringify(written)).is_equal(JSON.stringify(printed))


# --- validate -----------------------------------------------------------------------------------


func test_validate_accepts_the_dom_fixture_package() -> void:
	var result: Dictionary = _run(PackedStringArray(["validate", FIXTURE]))
	assert_str(_status(result)).is_equal("WEFTLUMIN: validate ok exit=0")
	var report: Dictionary = result["report"]
	assert_str(report["package"]).is_equal(PACKAGE)
	assert_array(report["kinds"]).contains_exactly(["scenes"])
	assert_int(int((report["counts"] as Dictionary)["scenes"])).is_equal(16)
	assert_array(report["errors"]).is_empty()


func test_validate_reports_attributed_errors() -> void:
	_write(SCRATCH + "/broken/commands.jsonl", "\n".join([
		_line({"id": "A1", "kind": "scene", "op": "set_property", "target": {"scene": DOM, "node": "WoundLip"}}),
		"not json",
		_line({"id": "A2", "op": "undo", "target": {"command": "ZZZ"}}),
		_line({"id": "A1", "kind": "scene", "op": "set_property"}),
	]) + "\n")
	var result: Dictionary = _run(PackedStringArray(["validate", SCRATCH + "/broken"]))
	assert_str(_status(result)).is_equal("WEFTLUMIN: validate errors exit=1")
	var codes: Array = _codes(result["report"]["errors"])
	assert_array(codes).contains(["invalid_log_line", "dangling_bookkeeping", "duplicate_command_id"])
	var line_error: Dictionary = _first(result["report"]["errors"], "invalid_log_line")
	assert_int(int(line_error["line"])).is_equal(2)
	assert_str(str(line_error["file"])).ends_with("broken/commands.jsonl")
	var missing: Dictionary = _run(PackedStringArray(["validate", SCRATCH + "/nowhere"]))
	assert_array(_codes(missing["report"]["errors"])).contains(["missing_package"])


func test_validate_runs_document_kinds_against_canon() -> void:
	var dom: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://canon/dom/locations/dom.json"))
	dom["respawn_policy"] = "sometimes"
	_write(SCRATCH + "/places/locations/dom.json", JSON.stringify(dom))
	var result: Dictionary = _run(PackedStringArray(["validate", SCRATCH + "/places"]))
	assert_str(_status(result)).is_equal("WEFTLUMIN: validate errors exit=1")
	assert_array(result["report"]["kinds"]).contains_exactly(["locations"])
	var error: Dictionary = (result["report"]["errors"] as Array)[0]
	assert_str(str(error["file"])).ends_with("places/locations/dom.json")
	assert_str(str(error["field"])).is_equal("respawn_policy")


# --- apply --------------------------------------------------------------------------------------


func test_apply_replays_the_fixture_into_scratch_and_writes_no_res_file() -> void:
	var hashes: Dictionary = _hashes()
	var package: String = SCRATCH + "/" + PACKAGE
	var result: Dictionary = _run(PackedStringArray(["apply", package, FIXTURE_LOG]))
	assert_str(_status(result)).is_equal("WEFTLUMIN: apply ok exit=0")
	var report: Dictionary = result["report"]
	assert_array(report["replayed"]).has_size(1)
	assert_int(int(report["replayed"][0]["ops"])).is_equal(14)
	assert_str(str(report["replayed"][0]["scratch"])).is_equal(package + "/scratch/world/starting_town.tscn")
	# The scratch package now holds the log, and the replayed scene equals the bake's output.
	assert_str(FileAccess.get_file_as_string(package + "/commands.jsonl").split("\n")[0]).contains("01M4NECT3K000000TMQ5PNP8VK")
	var baked: Dictionary = WeftluminBake.bake_scene(DOM, _fixture_scene_commands())
	assert_str(FileAccess.get_file_as_string(package + "/scratch/world/starting_town.tscn")).is_equal(str(baked["text"]))
	assert_dict(_hashes()).is_equal(hashes)


func test_apply_refuses_a_package_inside_the_project_and_drifted_logs() -> void:
	var inside: Dictionary = _run(PackedStringArray(["apply", "res://test/fixtures/weftlumin/cli_scratch", FIXTURE_LOG]))
	assert_str(_status(inside)).is_equal("WEFTLUMIN: apply errors exit=1")
	assert_array(_codes(inside["report"]["errors"])).contains_exactly(["scratch_only"])
	assert_bool(DirAccess.dir_exists_absolute("res://test/fixtures/weftlumin/cli_scratch")).is_false()
	# A pre_state that no longer matches Dom stops the replay and writes nothing.
	var lines: PackedStringArray = FileAccess.get_file_as_string(FIXTURE_LOG).strip_edges().split("\n")
	var first: Dictionary = JSON.parse_string(lines[0])
	first["pre_state"] = {"value": [1.0, 2.0]}
	lines[0] = JSON.stringify(first)
	_write(SCRATCH + "/drift.jsonl", "\n".join(lines) + "\n")
	var drifted: Dictionary = _run(PackedStringArray(["apply", SCRATCH + "/drifted", SCRATCH + "/drift.jsonl"]))
	assert_str(_status(drifted)).is_equal("WEFTLUMIN: apply errors exit=1")
	assert_str(JSON.stringify(drifted["report"]["errors"])).contains("pre_state_drift")
	assert_bool(FileAccess.file_exists(SCRATCH + "/drifted/commands.jsonl")).is_false()


func test_apply_runs_logged_console_verbs_against_the_live_autoloads() -> void:
	var flag: String = "dom_cli_probe_seen"
	GameState.set_flag(flag, false)
	_write(SCRATCH + "/live.jsonl", _line({
		"id": "L1", "kind": "console", "op": "execute", "package": "live-probe",
		"params": {"command": "flag %s true" % flag}, "provenance": {"source": "cli", "actor": "test"},
	}) + "\n")
	var result: Dictionary = _run(PackedStringArray(["apply", SCRATCH + "/live", SCRATCH + "/live.jsonl"]))
	assert_str(_status(result)).is_equal("WEFTLUMIN: apply ok exit=0")
	assert_bool(bool(result["report"]["live"][0]["ok"])).is_true()
	assert_bool(GameState.get_flag(flag)).is_true()
	assert_array(result["report"]["replayed"]).is_empty()
	GameState.set_flag(flag, false)
	GameState.set_flag("dev_console_used", false)


# --- bake ---------------------------------------------------------------------------------------


func test_bake_reports_the_fixture_without_writing() -> void:
	var hashes: Dictionary = _hashes()
	var result: Dictionary = _run(PackedStringArray(["bake", FIXTURE]))
	assert_str(_status(result)).is_equal("WEFTLUMIN: bake ok exit=0")
	var report: Dictionary = result["report"]
	assert_str(report["schema"]).is_equal("weftlumin.bake.v1")
	assert_str(report["mode"]).is_equal("report")
	assert_array(report["planned"]).has_size(1)
	assert_str(report["planned"][0]["path"]).is_equal(DOM)
	assert_str(report["planned"][0]["action"]).is_equal("update")
	assert_int(int(report["planned"][0]["ops"])).is_equal(14)
	assert_array(report["written"]).is_empty()
	assert_array(report["refused_overlap"]).is_empty()
	assert_dict(report["lint"]).contains_keys(["errors", "warnings", "pot_delta"])
	assert_dict(_hashes()).is_equal(hashes)


func test_the_fixture_replay_is_deterministic() -> void:
	# The nightly fixture replay must produce identical output run after run.
	var first: Dictionary = _run(PackedStringArray(["bake", FIXTURE]))["report"]
	var second: Dictionary = _run(PackedStringArray(["bake", FIXTURE]))["report"]
	assert_str(JSON.stringify(second)).is_equal(JSON.stringify(first))
	_run(PackedStringArray(["apply", SCRATCH + "/one", FIXTURE_LOG]))
	_run(PackedStringArray(["apply", SCRATCH + "/two", FIXTURE_LOG]))
	assert_str(FileAccess.get_file_as_string(SCRATCH + "/two/scratch/world/starting_town.tscn")) \
		.is_equal(FileAccess.get_file_as_string(SCRATCH + "/one/scratch/world/starting_town.tscn"))


func test_bake_refuses_force_without_write_and_writes_nothing_on_lint_errors() -> void:
	var forced: Dictionary = _run(PackedStringArray(["bake", FIXTURE, "--force"]))
	assert_str(_status(forced)).is_equal("WEFTLUMIN: bake errors exit=1")
	assert_array(_codes(forced["report"]["errors"])).contains(["force_without_write"])
	# A package whose dialogue fails the [if /] lint is refused at --write before anything is baked.
	var hashes: Dictionary = _hashes()
	_copy(FIXTURE_LOG, SCRATCH + "/linty/commands.jsonl")
	_write(SCRATCH + "/linty/dialogue/probe.dialogue", "~ start\nNathan: Hello.\n- \"Ask\" [if GameState.get_flag(\"dom_probe_seen\")]\n=> END\n")
	var refused: Dictionary = _run(PackedStringArray(["bake", SCRATCH + "/linty", "--write"]))
	assert_str(_status(refused)).is_equal("WEFTLUMIN: bake errors exit=1")
	assert_array(_codes(refused["report"]["errors"])).contains_exactly(["lint_failed"])
	assert_array(refused["report"]["written"]).is_empty()
	assert_dict(_hashes()).is_equal(hashes)


func test_bake_plans_document_kinds_into_canon_and_artifacts() -> void:
	var hashes: Dictionary = _hashes()
	var dom: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://canon/dom/locations/dom.json"))
	dom["harmonic_accord"] = float(dom.get("harmonic_accord", 50.0)) - 1.0
	_write(SCRATCH + "/accord/locations/dom.json", JSON.stringify(dom))
	var result: Dictionary = _run(PackedStringArray(["bake", SCRATCH + "/accord"]))
	assert_str(_status(result)).is_equal("WEFTLUMIN: bake ok exit=0")
	var paths: Array = []
	for planned: Dictionary in result["report"]["planned"]:
		paths.append("%s %s" % [planned["action"], planned["path"]])
	assert_array(paths).contains(["update res://canon/dom/locations/dom.json", "update res://world/locations/dom.tres"])
	assert_array(result["report"]["written"]).is_empty()
	assert_dict(_hashes()).is_equal(hashes)


# --- regen --------------------------------------------------------------------------------------


func test_regen_report_mode_runs_every_drift_stage_and_writes_nothing() -> void:
	var hashes: Dictionary = _hashes()
	var result: Dictionary = _run(PackedStringArray(["regen"]))
	# Whether each stage is clean is the drift job's verdict (check_generated_data.sh in CI), not
	# this suite's: unrelated drift must not fail it. Here: it ran, ran every stage, wrote nothing.
	assert_str(_status(result)).is_not_equal("WEFTLUMIN: regen usage exit=2")
	var names: Array = []
	for stage: Dictionary in result["report"]["stages"]:
		names.append(stage["name"])
	assert_array(names).contains_exactly(["GLOOT-GEN", "CANON-SEED", "LOCATIONS-GEN", "ISO-SPRITE-GEN"])
	assert_array(result["report"]["regenerated"]).is_empty()
	assert_dict(_hashes()).is_equal(hashes)


# --- lint ---------------------------------------------------------------------------------------


func test_the_if_lint_port_matches_the_python_self_test_cases() -> void:
	# tools/lint_dialogue_conditions.py SELF_TEST_CASES, verbatim.
	var cases: Array = [
		['- "Text" [if GameState.get_flag("x") /]', ""],
		['- "Text" [if GameState.get_flag("x")]', "NOT_SELF_CLOSING"],
		['- "Text" [if a /] [#tag=X]', "CONDITION_NOT_LAST"],
		['- "Text" [if a', "UNCLOSED"],
		['- "Text" [#tag=X] [if a /]', ""],
		['\t- "Text" [if a]', "NOT_SELF_CLOSING"],
		['if GameState.get_flag("x"):', ""],
		["Speaker: he said [if] loudly", ""],
	]
	for case: Array in cases:
		var findings: Array[Dictionary] = CliScript.lint_dialogue_line("<self-test>", 1, str(case[0]))
		var actual: String = str(findings[0]["code"]) if not findings.is_empty() else ""
		assert_str(actual).override_failure_message("%s: expected %s, got %s" % [case[0], case[1], actual]).is_equal(str(case[1]))


func test_lint_reports_dialogue_flag_grammar_and_pot_delta() -> void:
	var dir: String = SCRATCH + "/lintable"
	_write(dir + "/dialogue/probe.dialogue", "\n".join([
		"~ start",
		"Nathan: The bell-house is shut at night.",
		"- \"Ask about the bell\" [if GameState.get_flag(\"BellRung\")]",
		"\tdo GameState.set_flag(\"dom_bell_asked\", true)",
		"- \"The Broken Muster\" [if true /]",
		"=> END",
	]) + "\n")
	_write(dir + "/commands.jsonl", _line({
		"id": "P1", "kind": "scene", "op": "set_property", "package": "lintable",
		"target": {"scene": DOM, "node": "BellHouseDoor"},
		"params": {"export": "locked_message", "value_text": "\"The bell-house is barred.\""}, "pre_state": {},
	}) + "\n")
	var result: Dictionary = _run(PackedStringArray(["lint", dir]))
	assert_str(_status(result)).is_equal("WEFTLUMIN: lint errors exit=1")
	var report: Dictionary = result["report"]
	assert_str(report["schema"]).is_equal("weftlumin.lint.v1")
	var codes: Array = _codes(report["lint_errors"])
	assert_array(codes).contains(["NOT_SELF_CLOSING", "flag_violates_grammar"])
	assert_int(int(_first(report["lint_errors"], "NOT_SELF_CLOSING")["line"])).is_equal(3)
	assert_str(str(_first(report["lint_errors"], "flag_violates_grammar")["field"])).is_equal("flag BellRung")
	assert_int(int(report["dialogue_conditions"])).is_equal(2)
	# New player-facing text that no POT holds; an existing msgid would not be listed.
	assert_array(report["pot_delta"]).contains(["The bell-house is barred.", "The bell-house is shut at night.", "Ask about the bell"])
	assert_array(report["pot_delta"]).not_contains(["The Broken Muster"])


func test_lint_of_the_dom_fixture_is_clean() -> void:
	var result: Dictionary = _run(PackedStringArray(["lint", FIXTURE]))
	assert_str(_status(result)).is_equal("WEFTLUMIN: lint ok exit=0")
	assert_array(result["report"]["lint_errors"]).is_empty()
	assert_array(result["report"]["pot_delta"]).is_empty()


func test_pot_msgids_reads_multiline_entries() -> void:
	_write(SCRATCH + "/probe.pot", "msgid \"\"\nmsgstr \"\"\n\nmsgid \"\"\n\"Two \"\n\"lines\"\nmsgstr \"\"\n\nmsgid \"Say \\\"hi\\\"\"\nmsgstr \"\"\n")
	var ids: Dictionary = CliScript.pot_msgids([SCRATCH + "/probe.pot"] as Array[String])
	assert_array(ids.keys()).contains_exactly_in_any_order(["Two lines", "Say \"hi\""])


# --- pr -----------------------------------------------------------------------------------------


func test_pr_is_a_dry_run_by_default_and_plans_the_flow() -> void:
	var hashes: Dictionary = _hashes()
	var result: Dictionary = _run(PackedStringArray(["pr", FIXTURE, "--issue", "351", "--draft", "--trailer", "Co-Authored-By: Example <x@example.com>"]))
	assert_str(_status(result)).is_equal("WEFTLUMIN: pr ok exit=0")
	assert_array(_executed).is_empty()
	var pr: Dictionary = result["report"]["pr"]
	assert_bool(bool(pr["dry_run"])).is_true()
	assert_str(pr["branch"]).is_equal("weftlumin/dom-scene-bake")
	assert_array(pr["changed_files"]).contains_exactly(["world/starting_town.tscn"])
	assert_array(pr["affected_tests"]).contains(["test/integration/test_starting_town.gd", "test/integration/test_field_room.gd"])
	assert_bool(bool((pr["overlap"] as Dictionary)["checked"])).is_false()
	var names: Array = []
	for step: Dictionary in pr["steps"]:
		names.append(step["name"])
	assert_array(names.slice(0, 2)).contains_exactly(["fetch", "worktree"])
	assert_array(pr["steps"][1]["args"]).contains(["origin/main"])
	assert_int(names.find("staged files")).is_greater(names.find("git add"))
	assert_int(names.find("staged files")).is_less(names.find("git commit"))
	assert_array(names).contains(["bake --write", "lint", "git commit", "git push", "gh pr create", "test test/integration/test_starting_town.gd"])
	assert_str(str(pr["steps"].back()["display"])).ends_with("--draft")
	assert_str(str(pr["body"])).contains("Closes #351")
	assert_str(str(pr["body"])).contains("weftlumin.bake.v1")
	assert_str(str(pr["commit_message"])).contains("Closes #351")
	assert_str(str(pr["commit_message"])).ends_with("Co-Authored-By: Example <x@example.com>\n")
	# Judge the argv that would run, not only the printed plan.
	for step: Dictionary in pr["steps"]:
		for arg: Variant in step["args"]:
			assert_bool(str(arg) in ["--label", "--milestone", "--assignee", "-l", "-m", "-a"]).override_failure_message(str(step["args"])).is_false()
	assert_dict(_hashes()).is_equal(hashes)


func test_pr_refuses_an_overlap_with_exit_three_unless_forced() -> void:
	var refused: Dictionary = _run(PackedStringArray(["pr", FIXTURE, "--open-prs", OPEN_PRS]))
	assert_int(refused["exit_code"]).is_equal(CliScript.EXIT_OVERLAP)
	assert_str(_status(refused)).is_equal("WEFTLUMIN: pr refused_overlap exit=3")
	var overlaps: Array = refused["report"]["refused_overlap"]
	# #305 shares Dom; #350 touches no planned file; #999 is this package's own branch.
	assert_array(overlaps).has_size(1)
	assert_int(int(overlaps[0]["pr"])).is_equal(305)
	assert_array(overlaps[0]["files"]).contains_exactly(["world/starting_town.tscn"])
	assert_array(refused["report"]["pr"]["steps"]).is_empty()
	var forced: Dictionary = _run(PackedStringArray(["pr", FIXTURE, "--open-prs", OPEN_PRS, "--force"]))
	assert_str(_status(forced)).is_equal("WEFTLUMIN: pr ok exit=0")
	assert_array(forced["report"]["refused_overlap"]).is_empty()
	assert_array(forced["report"]["pr"]["overlap"]["overlaps"]).has_size(1)
	assert_array(forced["report"]["pr"]["steps"]).is_not_empty()
	assert_array(_executed).is_empty()


func test_pr_execute_runs_the_plan_in_order_and_captures_the_url() -> void:
	var result: Dictionary = _run_execute(PackedStringArray(["world/starting_town.tscn"]), [])
	assert_str(_status(result)).is_equal("WEFTLUMIN: pr ok exit=0")
	var pr: Dictionary = result["report"]["pr"]
	var executed: Array = []
	for entry: Dictionary in pr["executed"]:
		executed.append(entry["step"])
		assert_bool(bool(entry["ok"])).override_failure_message(str(entry)).is_true()
	var planned: Array = []
	for step: Dictionary in pr["steps"]:
		planned.append(step["name"])
	assert_array(executed).is_equal(planned)
	assert_str(str(pr["url"])).is_equal("https://example.invalid/pull/1")
	assert_array(pr["staged_files"]).contains_exactly(["world/starting_town.tscn"])
	# The worktree is cut from the fetched remote base.
	assert_array(_executed[0][1]).contains(["fetch", "origin", "main"])
	assert_array(_executed[1][1]).contains(["origin/main"])


func test_pr_execute_ignores_a_stale_step_report() -> void:
	var scratch: String = OS.get_user_data_dir().path_join("weftlumin/pr").path_join(PACKAGE)
	DirAccess.make_dir_recursive_absolute(scratch)
	_write(scratch.path_join("bake.json"), JSON.stringify({"errors": [], "exit_code": 0}))
	# The bake step "crashes": it exits non-zero and writes no report of its own.
	var result: Dictionary = _run_execute(PackedStringArray(["world/starting_town.tscn"]), [], "bake")
	assert_str(_status(result)).is_equal("WEFTLUMIN: pr errors exit=1")
	assert_str(str(result["report"]["pr"]["executed"].back()["step"])).is_equal("bake --write")
	assert_bool(bool(result["report"]["pr"]["executed"].back()["ok"])).is_false()
	for call: Array in _executed:
		assert_bool("commit" in Array(call[1]) or "push" in Array(call[1])).override_failure_message(str(call)).is_false()


func test_pr_execute_refuses_an_overlap_in_the_staged_files_before_committing() -> void:
	# The plan names only Dom; regen staged data.pandora, which open PR #42 also changes.
	var open_prs: Array = [{"number": 42, "title": "data", "headRefName": "feat/data", "files": [{"path": "data.pandora"}]}]
	var result: Dictionary = _run_execute(PackedStringArray(["world/starting_town.tscn", "data.pandora"]), open_prs)
	assert_int(result["exit_code"]).is_equal(CliScript.EXIT_OVERLAP)
	assert_str(_status(result)).is_equal("WEFTLUMIN: pr refused_overlap exit=3")
	assert_int(int(result["report"]["refused_overlap"][0]["pr"])).is_equal(42)
	assert_str(str(result["report"]["pr"]["executed"].back()["step"])).is_equal("staged files")
	for call: Array in _executed:
		assert_bool("commit" in Array(call[1]) or "push" in Array(call[1])).override_failure_message(str(call)).is_false()


func test_a_package_id_or_hub_that_is_not_a_path_component_is_refused() -> void:
	_write(SCRATCH + "/escape/campaign.json", JSON.stringify({"schema": "weftlumin.package.v1", "id": "../escape", "hub": "../../..", "kinds": []}))
	var result: Dictionary = _run(PackedStringArray(["validate", SCRATCH + "/escape"]))
	assert_str(_status(result)).is_equal("WEFTLUMIN: validate errors exit=1")
	assert_array(_codes(result["report"]["errors"])).contains(["invalid_package_id", "invalid_hub"])
	var pr: Dictionary = _run(PackedStringArray(["pr", SCRATCH + "/escape"]))
	assert_array(pr["report"]["pr"]["steps"]).is_empty()


func test_apply_refuses_project_paths_spelled_through_user_or_absolute_paths() -> void:
	var root: String = ProjectSettings.globalize_path("res://").trim_suffix("/")
	var user: String = OS.get_user_data_dir()
	var ups: String = "../".repeat(user.split("/", false).size())
	for spelled: String in [root.path_join("test/fixtures/weftlumin/cli_scratch"), "user://" + ups + root.trim_prefix("/") + "/test/fixtures/weftlumin/cli_scratch"]:
		var result: Dictionary = _run(PackedStringArray(["apply", spelled, FIXTURE_LOG]))
		assert_array(_codes(result["report"]["errors"])).override_failure_message(spelled).contains_exactly(["scratch_only"])
	assert_bool(DirAccess.dir_exists_absolute("res://test/fixtures/weftlumin/cli_scratch")).is_false()


func test_pr_warns_when_the_open_pr_list_may_be_truncated() -> void:
	var listed: Array = []
	for number: int in PrScript.OPEN_PR_LIMIT:
		listed.append({"number": number + 1, "headRefName": "feat/%d" % number, "files": []})
	var crowded: Array = []
	for index: int in PrScript.GH_FILES_PER_PR:
		crowded.append({"path": "file_%d.gd" % index})
	listed[0]["files"] = crowded
	var warnings: Array[String] = PrScript.scan_truncation(listed)
	assert_int(warnings.size()).is_equal(2)
	assert_str(warnings[0]).contains("limit")
	assert_str(warnings[1]).contains("PR #1")
	assert_array(PrScript.scan_truncation([{"number": 1, "files": [{"path": "a"}]}])).is_empty()
	_write(SCRATCH + "/many_prs.json", JSON.stringify(listed))
	var result: Dictionary = _run(PackedStringArray(["pr", FIXTURE, "--open-prs", SCRATCH + "/many_prs.json"]))
	assert_array(result["report"]["pr"]["overlap"]["truncated"]).has_size(2)


func test_pr_body_stays_under_githubs_limit() -> void:
	var planned: Array = []
	for index: int in 3000:
		planned.append({"action": "update", "path": "res://canon/dom/characters/c_%d.json" % index, "kind": "characters", "padding": "x".repeat(40)})
	var report: Dictionary = {"package": "big", "summary": "lots", "planned": planned, "regenerated": [], "lint": {}}
	var body: String = PrScript.pr_body(report, "351")
	assert_int(body.length()).is_less_equal(PrScript.BODY_LIMIT)
	assert_str(body).contains("too long for a PR body")
	assert_str(body.strip_edges()).ends_with("Closes #351")
	var small: String = PrScript.pr_body({"package": "s", "summary": "", "planned": [], "regenerated": [], "lint": {}}, "")
	assert_str(small).contains("```json")


func test_pr_names_the_cleanup_when_a_worktree_is_left_over() -> void:
	DirAccess.make_dir_recursive_absolute(SCRATCH + "/wt")
	var dry: Dictionary = _run(PackedStringArray(["pr", FIXTURE, "--worktree", SCRATCH + "/wt"]))
	assert_str(str(dry["report"]["pr"].get("leftover", ""))).contains("git worktree remove --force")
	assert_str(str(dry["report"]["pr"].get("leftover", ""))).contains("git branch -D weftlumin/dom-scene-bake")
	# A failed step after the worktree exists says how to clean up before a rerun.
	var failed: Dictionary = _run_execute(PackedStringArray([]), [], "lint")
	assert_str(str(failed["report"]["errors"].back()["message"])).contains("git branch -D weftlumin/dom-scene-bake")


func test_pr_execute_stops_between_steps_once_cancelled() -> void:
	var marker: String = ProjectSettings.globalize_path(SCRATCH + "/run.cancel")
	var result: Dictionary = _run_execute(PackedStringArray(["world/starting_town.tscn"]), [], "", marker, "import")
	assert_str(_status(result)).is_equal("WEFTLUMIN: pr errors exit=1")
	assert_array(_codes(result["report"]["errors"])).contains(["pr_cancelled"])
	var executed: Array = []
	for entry: Dictionary in result["report"]["pr"]["executed"]:
		executed.append(entry["step"])
	assert_array(executed).contains_exactly(["fetch", "worktree", "import"])


func test_only_execute_launches_get_a_cancel_file() -> void:
	var report: String = SCRATCH + "/launch.json"
	assert_bool(Array(PrScript.launch_arguments(PackedStringArray(["pr", FIXTURE]), report)).has("--cancel-file")).is_false()
	var full: Array = Array(PrScript.launch_arguments(PackedStringArray(["pr", FIXTURE, "--execute"]), report))
	assert_str(str(full[full.find("--cancel-file") + 1])).is_equal(ProjectSettings.globalize_path(report) + ".cancel")


func test_the_kind_to_test_glob_map_is_the_adapters() -> void:
	var adapter: WeftluminGameAdapter = AdapterScript.new()
	var globs: Array[String] = adapter.affected_test_globs(["scenes", "quests", "encounters", "characters", "locations"] as Array[String])
	assert_array(globs).contains([
		"test/integration/test_starting_town.gd", "test/integration/test_field_room.gd", "test/integration/test_travel_*",
		"test/unit/test_quest_*", "test/unit/test_campaign_*", "test/unit/test_encounter_*", "test/unit/test_spawn_*",
		"test/unit/test_party_*", "test/unit/test_npc_*", "scripts/check_generated_data.sh",
	])
	var files: Array[String] = PrScript.expand_test_globs(["test/unit/test_spawn_*"] as Array[String])
	assert_array(files).contains(["test/unit/test_spawn_director.gd", "test/unit/test_spawn_math.gd"])
	for file: String in files:
		assert_str(file).ends_with(".gd")


# --- the in-game launcher ------------------------------------------------------------------------


func test_the_launcher_starts_a_detached_cli_and_polls_its_report() -> void:
	var report_path: String = SCRATCH + "/launched.json"
	DirAccess.make_dir_recursive_absolute(SCRATCH)
	var arguments: PackedStringArray = PrScript.launch_arguments(PackedStringArray(["validate", FIXTURE]), report_path)
	assert_array(Array(arguments)).contains(["--headless", "--script", PrScript.CLI_ENTRY, "--", "validate", FIXTURE, "--report"])
	var handle: Dictionary = PrScript.launch(PackedStringArray(["validate", FIXTURE]), report_path)
	assert_bool(bool(handle["ok"])).override_failure_message(str(handle["message"])).is_true()
	var state: Dictionary = PrScript.poll(handle)
	var deadline: int = Time.get_ticks_msec() + 120000
	while str(state["state"]) == "running" and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.25).timeout
		state = PrScript.poll(handle)
	assert_str(str(state["state"])).is_equal("done")
	assert_str(str((state["report"] as Dictionary)["verb"])).is_equal("validate")
	assert_int(int((state["report"] as Dictionary)["exit_code"])).is_equal(0)


func test_the_launcher_cancels_a_running_cli() -> void:
	var handle: Dictionary = PrScript.launch(PackedStringArray(["regen"]), SCRATCH + "/cancelled.json")
	assert_bool(bool(handle["ok"])).is_true()
	var cancelled: Dictionary = PrScript.cancel(handle)
	assert_bool(bool(cancelled["ok"])).is_true()
	assert_str(str(PrScript.poll(handle)["state"])).is_equal("cancelled")
	var deadline: int = Time.get_ticks_msec() + 10000
	while OS.is_process_running(int(handle["pid"])) and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.1).timeout
	assert_bool(OS.is_process_running(int(handle["pid"]))).is_false()


# --- helpers ------------------------------------------------------------------------------------


func _run(args: PackedStringArray) -> Dictionary:
	var cli: RefCounted = CliScript.new(AdapterScript.new())
	cli.set("echo", false)
	cli.set("runner", func(program: String, arguments: PackedStringArray) -> Dictionary:
		_executed.append([program, arguments])
		fail("The CLI tried to run %s %s during a test." % [program, " ".join(arguments)])
		return {"exit_code": 1, "output": ""}
	)
	return cli.call("run", args)


## `pr --execute` against a recording runner. Godot steps get a clean report unless their step
## name contains `fail_step`; `git diff --cached` lists `staged`; nothing real runs.
func _run_execute(staged: PackedStringArray, open_prs: Array, fail_step: String = "", cancel_file: String = "", cancel_after: String = "") -> Dictionary:
	_write(SCRATCH + "/open_prs.json", JSON.stringify(open_prs))
	var cli: RefCounted = CliScript.new(AdapterScript.new())
	cli.set("echo", false)
	cli.set("runner", func(program: String, arguments: PackedStringArray) -> Dictionary:
		_executed.append([program, arguments])
		if not cancel_after.is_empty() and arguments.has("--" + cancel_after if cancel_after == "import" else cancel_after):
			_write(cancel_file, "")
		var report_at: int = arguments.find("--report")
		if report_at >= 0:
			var verb: String = arguments[arguments.find("--") + 1]
			if not fail_step.is_empty() and verb.contains(fail_step):
				return {"exit_code": 134, "output": "crashed"}
			_write(arguments[report_at + 1], JSON.stringify({"errors": [], "exit_code": 0}))
		if arguments.has("--cached"):
			return {"exit_code": 0, "output": "\n".join(staged) + "\n"}
		if arguments.has("create"):
			return {"exit_code": 0, "output": "https://example.invalid/pull/1\n"}
		return {"exit_code": 0, "output": ""}
	)
	var args := PackedStringArray(["pr", FIXTURE, "--execute", "--open-prs", SCRATCH + "/open_prs.json", "--worktree", SCRATCH + "/wt"])
	if not cancel_file.is_empty():
		args.append_array(["--cancel-file", cancel_file])
	return cli.call("run", args)


func _status(result: Dictionary) -> String:
	var lines: Array = result["lines"]
	return str(lines.back()) if not lines.is_empty() else ""


func _codes(errors: Variant) -> Array:
	var codes: Array = []
	for error: Variant in errors:
		codes.append(str((error as Dictionary).get("code", "")))
	return codes


func _first(errors: Variant, code: String) -> Dictionary:
	for error: Variant in errors:
		if str((error as Dictionary).get("code", "")) == code:
			return error as Dictionary
	return {}


func _fixture_scene_commands() -> Array:
	var errors: Array[Dictionary] = []
	return WeftluminCommandBus.effective_stream(CliScript.load_log(FIXTURE_LOG, errors))


func _hashes() -> Dictionary:
	var hashes: Dictionary = {}
	for path: String in GUARDED:
		hashes[path] = FileAccess.get_sha256(path)
	return hashes


static func _line(data: Dictionary) -> String:
	var entry: Dictionary = {"schema": "weftlumin.command.v1", "ts": "2026-10-12 00:00:00Z", "package": "cli-test"}
	entry.merge(data, true)
	return JSON.stringify(entry)


static func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


static func _copy(from: String, to: String) -> void:
	_write(to, FileAccess.get_file_as_string(from))


static func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for directory: String in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(directory))
	for file: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
