extends Node
## Thin Steamworks seam (autoload `SteamService`, issue #299).
##
## Systems layer: it only reads downward — the Reputation and Renown ledgers and
## the QuestSystem — through their existing signals, and never writes to them.
## Nothing in the game depends on this node.
##
## GodotSteam is NOT vendored. The owner installs it (docs/steam-integration.md);
## it then registers an engine singleton named "Steam". This script looks that
## singleton up at runtime and talks to it only through `Object.call()`, so it
## parses and runs with the addon absent: every public method is then a no-op
## and the game, the editor and CI behave exactly as before.
##
## Steam Cloud needs no code: Auto-Cloud is configured on the partner site
## against the files SaveGame already writes (see the doc and
## CLOUD_SAVE_PATTERNS below).

## Emitted the first time this session an achievement is newly set on Steam.
signal achievement_unlocked(api_id: StringName)

const SINGLETON_NAME := "Steam"
## GodotSteam's steamInitEx() status for success (k_ESteamAPIInitResult_OK).
const INIT_STATUS_OK := 0
## PROVISIONAL: the owner has not created the Steamworks app yet, so there is
## no app id. 0 means "ask the Steam client" — it reads `steam_appid.txt` next
## to the executable (git-ignored) or, for installed copies, the launching
## client. Once the owner has an id, either keep 0 and ship `steam_appid.txt`
## for development only, or set the id here (and in STEAM_APP_ID for
## tools/steam_upload.sh). See docs/steam-integration.md, "App id".
const PROVISIONAL_APP_ID: int = 0
## Steam Auto-Cloud file patterns, relative to the `user://` directory, that
## the partner-site rows in docs/steam-integration.md must mirror. They cover
## exactly what SaveGame writes (`chapter_one.save`, `chapter_one.slotN.save`,
## and each file's `.bak`); `.tmp` in-flight writes are deliberately excluded.
## test_steam_service.gd checks them against SaveGame's real paths.
const CLOUD_SAVE_PATTERNS: PackedStringArray = [
	"chapter_one*.save",
	"chapter_one*.save.bak",
]

var _backend: Object = null
var _reputation: Node = null
var _renown: Node = null
var _quest_system: Node = null
## api_id -> true once known to be achieved; makes every unlock idempotent
## without asking Steam again.
var _unlocked: Dictionary = {}


func _ready() -> void:
	set_process(false)
	if Engine.has_singleton(SINGLETON_NAME):
		var singleton: Object = Engine.get_singleton(SINGLETON_NAME)
		if _initialize(singleton):
			set_backend(singleton)
			set_process(true)
	bind(
		get_node_or_null("/root/Reputation"),
		get_node_or_null("/root/Renown"),
		get_node_or_null("/root/QuestSystem")
	)
	var save_game: Node = get_node_or_null("/root/SaveGame")
	if save_game != null and save_game.has_signal("loaded"):
		save_game.connect("loaded", resync)


func _process(_delta: float) -> void:
	if _backend != null:
		_backend.call("run_callbacks")


## True when a Steam backend is attached and achievements can be written.
func is_available() -> bool:
	return _backend != null


## Attaches an already-initialised Steam backend: the GodotSteam singleton in
## production, a fake in tests. Pass null to detach.
func set_backend(backend: Object) -> void:
	_backend = backend
	_unlocked.clear()


## Subscribes (read-only) to the sources the achievement table keys on. Any
## argument may be null. Safe to call again with different sources.
func bind(reputation: Node, renown: Node, quest_system: Node) -> void:
	_rebind(_reputation, reputation, "reputation_changed", _on_reputation_changed)
	_rebind(_renown, renown, "renown_changed", _on_renown_changed)
	_rebind(_quest_system, quest_system, "quest_completed", _on_quest_completed)
	_reputation = reputation
	_renown = renown
	_quest_system = quest_system


## Unlocks one achievement. Returns true only when this call newly set it on
## Steam; false when Steam is absent, the id is unknown, it was already
## achieved, or Steam refused the write.
func unlock(api_id: StringName) -> bool:
	if _backend == null or not SteamAchievements.ids().has(api_id):
		return false
	if _unlocked.has(api_id):
		return false
	var name := String(api_id)
	var state: Variant = _backend.call("getAchievement", name)
	if state is Dictionary and bool((state as Dictionary).get("achieved", false)):
		_unlocked[api_id] = true
		return false
	if not bool(_backend.call("setAchievement", name)):
		push_warning("SteamService: Steam refused achievement %s" % name)
		return false
	_backend.call("storeStats")
	_unlocked[api_id] = true
	achievement_unlocked.emit(api_id)
	return true


## Re-evaluates every table row against current state. Loading a save restores
## the ledgers and quest pools without replaying their signals, so progress
## earned while Steam was unavailable is caught up here.
func resync() -> void:
	if _backend == null:
		return
	for row: Dictionary in SteamAchievements.TABLE:
		if _row_met(row):
			unlock(row["id"] as StringName)


func _initialize(singleton: Object) -> bool:
	if not singleton.has_method("steamInitEx"):
		push_warning("SteamService: Steam singleton has no steamInitEx(); achievements disabled")
		return false
	# With PROVISIONAL_APP_ID at 0 the call takes no arguments and the app id
	# comes from the Steam client (or steam_appid.txt in development). GodotSteam
	# 4.12+ (Godot 4.3 and later) declares steamInitEx(app_id, embed_callbacks);
	# confirm the signature against the installed build before setting the id.
	var result: Variant
	if PROVISIONAL_APP_ID > 0:
		result = singleton.call("steamInitEx", PROVISIONAL_APP_ID)
	else:
		result = singleton.call("steamInitEx")
	if result is Dictionary and int((result as Dictionary).get("status", -1)) == INIT_STATUS_OK:
		return true
	# Not launched through Steam, client not running, or app not owned: play on.
	print("SteamService: Steam unavailable (%s); achievements disabled" % str(result))
	return false


func _rebind(previous: Node, next: Node, signal_name: String, handler: Callable) -> void:
	if previous != null and is_instance_valid(previous) and previous.is_connected(signal_name, handler):
		previous.disconnect(signal_name, handler)
	if next != null and next.has_signal(signal_name):
		next.connect(signal_name, handler)


func _on_reputation_changed(_faction: String, _standing: float, _event: Variant) -> void:
	_evaluate(SteamAchievements.TRIGGER_REPUTATION_BAND)


func _on_renown_changed(_kind: StringName, _total: float, _event: Variant) -> void:
	_evaluate(SteamAchievements.TRIGGER_FAME_TIER)


func _on_quest_completed(quest: Resource) -> void:
	if _backend == null or quest == null:
		return
	for row: Dictionary in SteamAchievements.TABLE:
		if (
			row["trigger"] == SteamAchievements.TRIGGER_QUEST_COMPLETED
			and (row["quests"] as Array).has(quest.resource_path)
		):
			unlock(row["id"] as StringName)


func _evaluate(trigger: StringName) -> void:
	if _backend == null:
		return
	for row: Dictionary in SteamAchievements.TABLE:
		if row["trigger"] == trigger and _row_met(row):
			unlock(row["id"] as StringName)


func _row_met(row: Dictionary) -> bool:
	match row["trigger"]:
		SteamAchievements.TRIGGER_REPUTATION_BAND:
			if _reputation == null:
				return false
			var standings: Dictionary = _reputation.call("all_standings")
			for faction: Variant in standings:
				if bool(_reputation.call("band_at_least", str(faction), row["band"])):
					return true
			return false
		SteamAchievements.TRIGGER_FAME_TIER:
			return (
				_renown != null
				and int(_renown.call("fame_tier_index")) >= int(row["tier_index"])
			)
		SteamAchievements.TRIGGER_QUEST_COMPLETED:
			if _quest_system == null or not _quest_system.has_method("is_quest_completed"):
				return false
			for path: Variant in row["quests"] as Array:
				var quest: Resource = load(str(path))
				if quest != null and bool(_quest_system.call("is_quest_completed", quest)):
					return true
			return false
	return false
