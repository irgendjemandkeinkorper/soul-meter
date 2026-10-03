extends GdUnitTestSuite
## Steam seam (globals/steam_service.gd, issue #299). A fake backend stands in
## for the GodotSteam singleton, and fresh ledger instances stand in for the
## autoloads, so nothing here touches Steam or shared game state.

const ServiceScript := preload("res://globals/steam_service.gd")
const ReputationScript := preload("res://globals/reputation.gd")
const RenownScript := preload("res://globals/renown.gd")
const SaveGameScript := preload("res://globals/save_game.gd")

const BROKEN_MUSTER := "res://quests/dorthkor_road.tres"
const UNANSWERED_ROAR := "res://quests/main/the_unanswered_roar.tres"
const COMPANION_QUEST := "res://quests/serai_lun_mirror_line.tres"
const UNRELATED_QUEST := "res://quests/loamroot_sprigs.tres"


class FakeSteam:
	extends RefCounted
	var achieved: Dictionary = {}
	var set_calls: Array[String] = []
	var store_calls: int = 0
	var refuse_writes: bool = false

	func getAchievement(api_name: String) -> Dictionary:
		return {"ret": true, "achieved": achieved.has(api_name)}

	func setAchievement(api_name: String) -> bool:
		if refuse_writes:
			return false
		set_calls.append(api_name)
		achieved[api_name] = true
		return true

	func storeStats() -> bool:
		store_calls += 1
		return true


class FakeQuestSystem:
	extends Node
	signal quest_completed(quest: Resource)
	var completed: Array[Resource] = []

	func is_quest_completed(quest: Resource) -> bool:
		return completed.has(quest)


## Untyped on purpose: none of these scripts has a `class_name` — see test_reputation.gd.
var service
var reputation
var renown
var quests: FakeQuestSystem
var steam: FakeSteam


func before_test() -> void:
	service = auto_free(ServiceScript.new())
	reputation = auto_free(ReputationScript.new())
	renown = auto_free(RenownScript.new())
	quests = auto_free(FakeQuestSystem.new())
	steam = FakeSteam.new()
	service.set_backend(steam)
	service.bind(reputation, renown, quests)


func _complete(path: String) -> void:
	quests.quest_completed.emit(load(path))


func test_table_defines_five_unique_neutral_ids() -> void:
	var ids: Array[StringName] = SteamAchievements.ids()
	assert_int(ids.size()).is_equal(5)
	var seen: Dictionary = {}
	for id: StringName in ids:
		assert_bool(seen.has(id)).is_false()
		seen[id] = true
		assert_str(String(id)).starts_with("ACH_")


func test_table_quest_paths_resolve_to_quest_resources() -> void:
	for row: Dictionary in SteamAchievements.TABLE:
		if row["trigger"] != SteamAchievements.TRIGGER_QUEST_COMPLETED:
			continue
		for path: String in row["quests"]:
			assert_bool(ResourceLoader.exists(path)).is_true()
			assert_object(load(path)).is_instanceof(Quest)


func test_broken_muster_completion_unlocks_once() -> void:
	_complete(BROKEN_MUSTER)
	_complete(BROKEN_MUSTER)
	assert_array(steam.set_calls).is_equal(["ACH_01"])
	assert_int(steam.store_calls).is_equal(1)


func test_unanswered_roar_completion_unlocks_once() -> void:
	_complete(UNANSWERED_ROAR)
	_complete(UNANSWERED_ROAR)
	assert_array(steam.set_calls).is_equal(["ACH_02"])


func test_any_companion_quest_unlocks_once() -> void:
	_complete(COMPANION_QUEST)
	_complete("res://quests/maura_greyfen_name_and_deed.tres")
	assert_array(steam.set_calls).is_equal(["ACH_03"])


func test_unrelated_quest_unlocks_nothing() -> void:
	_complete(UNRELATED_QUEST)
	assert_array(steam.set_calls).is_empty()


func test_faction_reaching_warm_band_unlocks_once() -> void:
	reputation.record("player", "iron-companies", ReputationScript.BAND_WARM - 1.0, "below", "test")
	assert_array(steam.set_calls).is_empty()
	reputation.record("player", "iron-companies", 1.0, "reaches warm", "test")
	reputation.record("player", "the-registry", ReputationScript.BAND_WARM, "second faction", "test")
	assert_array(steam.set_calls).is_equal(["ACH_04"])


func test_negative_standing_does_not_unlock() -> void:
	reputation.record("player", "iron-companies", -50.0, "hostile", "test")
	assert_array(steam.set_calls).is_empty()


func test_fame_reaching_whispered_unlocks_once() -> void:
	var whispered: float = RenownScript.FAME_TIER_FLOORS[1]
	renown.gain_reputation("player", whispered - 1.0, "below", "test")
	assert_array(steam.set_calls).is_empty()
	renown.gain_infamy("player", 1.0, "fame is reputation plus infamy", "test")
	renown.gain_reputation("player", 5.0, "again", "test")
	assert_array(steam.set_calls).is_equal(["ACH_05"])


func test_already_achieved_on_steam_is_not_written_again() -> void:
	steam.achieved["ACH_01"] = true
	_complete(BROKEN_MUSTER)
	assert_array(steam.set_calls).is_empty()
	assert_int(steam.store_calls).is_equal(0)


func test_unlock_reports_and_signals_only_the_first_time() -> void:
	var seen: Array[StringName] = []
	service.achievement_unlocked.connect(func(id: StringName) -> void: seen.append(id))
	assert_bool(service.unlock(&"ACH_01")).is_true()
	assert_bool(service.unlock(&"ACH_01")).is_false()
	assert_array(seen).is_equal([&"ACH_01"])


func test_unknown_id_is_rejected() -> void:
	assert_bool(service.unlock(&"ACH_99")).is_false()
	assert_array(steam.set_calls).is_empty()


func test_refused_write_is_retried_on_the_next_trigger() -> void:
	steam.refuse_writes = true
	assert_bool(service.unlock(&"ACH_02")).is_false()
	steam.refuse_writes = false
	assert_bool(service.unlock(&"ACH_02")).is_true()


func test_without_backend_everything_is_a_no_op() -> void:
	service.set_backend(null)
	assert_bool(service.is_available()).is_false()
	_complete(BROKEN_MUSTER)
	reputation.record("player", "iron-companies", 100.0, "allied", "test")
	renown.gain_reputation("player", 500.0, "famous", "test")
	service.resync()
	assert_bool(service.unlock(&"ACH_01")).is_false()
	assert_array(steam.set_calls).is_empty()


func test_headless_runtime_has_no_steam_singleton_and_autoload_is_inert() -> void:
	# CI and development machines run without GodotSteam: the real autoload must
	# exist, hold no backend, and refuse unlocks without error.
	assert_bool(Engine.has_singleton("Steam")).is_false()
	var autoload: Node = get_tree().root.get_node_or_null("SteamService")
	assert_object(autoload).is_not_null()
	assert_bool(autoload.is_available()).is_false()
	assert_bool(autoload.unlock(&"ACH_01")).is_false()
	assert_bool(autoload.is_processing()).is_false()


func test_resync_catches_up_state_restored_without_signals() -> void:
	# A load rebuilds ledgers and quest pools without replaying their signals.
	service.set_backend(null)
	reputation.record("player", "ssae-seeders", ReputationScript.BAND_WARM, "earned offline", "test")
	renown.gain_reputation("player", RenownScript.FAME_TIER_FLOORS[1], "earned offline", "test")
	quests.completed.append(load(UNANSWERED_ROAR))
	service.set_backend(steam)
	service.resync()
	service.resync()
	assert_array(steam.set_calls).contains_exactly_in_any_order(["ACH_02", "ACH_04", "ACH_05"])


func test_rebinding_drops_the_previous_sources() -> void:
	var other: FakeQuestSystem = auto_free(FakeQuestSystem.new())
	service.bind(reputation, renown, other)
	_complete(BROKEN_MUSTER)
	assert_array(steam.set_calls).is_empty()
	other.quest_completed.emit(load(BROKEN_MUSTER))
	assert_array(steam.set_calls).is_equal(["ACH_01"])


func test_cloud_patterns_cover_every_save_file_and_no_temp_file() -> void:
	# The Auto-Cloud rows in docs/steam-integration.md mirror these patterns, so
	# if SaveGame ever moves or renames a file this fails before cloud saves
	# silently stop syncing.
	var saves = auto_free(SaveGameScript.new())
	var synced: Array[String] = [SaveGameScript.SAVE_PATH, SaveGameScript.BACKUP_PATH]
	for slot: int in range(1, SaveGameScript.MANUAL_SLOT_COUNT + 1):
		var slot_path: String = saves.manual_slot_path(slot)
		synced.append(slot_path)
		synced.append(slot_path + ".bak")
	for path: String in synced:
		assert_bool(_matches_cloud_pattern(path)) \
			.override_failure_message("not covered by CLOUD_SAVE_PATTERNS: %s" % path) \
			.is_true()
	assert_bool(_matches_cloud_pattern(SaveGameScript.TEMP_PATH)).is_false()
	assert_bool(_matches_cloud_pattern("user://settings.cfg")).is_false()


func _matches_cloud_pattern(user_path: String) -> bool:
	assert_str(user_path).starts_with("user://")
	# Auto-Cloud matches against the file name inside the configured directory.
	var relative := user_path.trim_prefix("user://")
	assert_bool(relative.contains("/")).is_false()
	for pattern: String in ServiceScript.CLOUD_SAVE_PATTERNS:
		if relative.match(pattern):
			return true
	return false


func test_provisional_app_id_is_unset_until_the_owner_supplies_one() -> void:
	# 0 defers to the Steam client / steam_appid.txt; no id is committed.
	assert_int(ServiceScript.PROVISIONAL_APP_ID).is_equal(0)


func test_upload_script_reads_ids_and_credentials_from_the_environment() -> void:
	var source := FileAccess.get_file_as_string("res://tools/steam_upload.sh")
	assert_str(source).contains("set -euo pipefail")
	for variable: String in ["STEAM_APP_ID", "STEAM_DEPOT_ID", "STEAM_USERNAME"]:
		assert_str(source).contains(variable)
	for template: String in ["app_build.vdf.template", "depot_build.vdf.template"]:
		var vdf := FileAccess.get_file_as_string("res://tools/steam/" + template)
		assert_str(vdf).contains("@STEAM_DEPOT_ID@")
		# No literal numeric id may be committed in a template.
		var literal_id := RegEx.create_from_string("\"(AppID|DepotID)\"\\s+\"\\d")
		assert_object(literal_id.search(vdf)).is_null()
