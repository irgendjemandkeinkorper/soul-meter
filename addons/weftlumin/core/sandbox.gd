class_name WeftluminSandbox
extends RefCounted
## The single owner of "run this without it counting" (`docs/architecture-in-game-editor.md`
## §4.5.6).
##
## Two debug labs each grew their own copy of arm/restore. Both are correct today and their
## comments explain why in detail — which is the problem: the same hard-won reasoning had to be
## rediscovered twice, and a third tool would have rediscovered it a third time, or not.
##
## **The owner never enumerates surfaces itself.** It asks a registered surface to capture and to
## restore, so anything a later wave adds to the host's runtime state — spawn slots in E4.1, say
## — is covered without touching this file. That rule is why the labs' earlier five-surface
## snapshots silently missed four, letting the Zhavar, the quest pools, the tactical roster and
## the world clock escape every sandbox.
##
## **LIFO only.** Two holders at once is unsafe even when each is internally correct: they
## restore in whatever order they happen to end, and the second restore reinstates the first
## holder's dirty state after that holder already cleaned up. A different owner is refused; the
## same owner re-arming is a restart.

## Refusals use the project's standard shape: `{allowed, blocked_by, nearest_unblock, message}`.
const _HELD := &"sandbox_owner"
const _NOT_ARMED := &"sandbox_state"

signal armed(owner_id: StringName)
signal disarmed(owner_id: StringName)

static var _shared: WeftluminSandbox = null

var _surfaces: Array[Dictionary] = []
var _session_begin: Callable = Callable()
var _session_end: Callable = Callable()
var _owner: StringName = &""
var _snapshots: Dictionary = {}
var _armed: bool = false


## The one sandbox every tool in a process shares.
##
## Ownership is only meaningful if it is global: two tools each holding their own instance would
## both believe they were the sole owner, which is precisely the non-LIFO restore this class
## exists to prevent.
static func shared() -> WeftluminSandbox:
	if _shared == null:
		_shared = WeftluminSandbox.new()
	return _shared


## Test seam. Static state outlives a test case, and a suite that armed the shared sandbox would
## otherwise hand the next suite a held sandbox and an unbalanced suppression bracket.
static func reset_shared() -> void:
	_shared = null


## `capture` is `() -> Variant`; `restore` is `(Variant) -> bool`, returning false to warn.
## Surfaces restore in registration order, so register the broadest one first.
##
## Re-registering an id replaces it rather than adding a second copy, which is what makes
## `add_default_surfaces()` safe to call from every tool that uses the shared sandbox.
func add_surface(id: StringName, capture: Callable, restore: Callable) -> void:
	var entry: Dictionary = {"id": id, "capture": capture, "restore": restore}
	for index in _surfaces.size():
		if _surfaces[index]["id"] == id:
			_surfaces[index] = entry
			return
	_surfaces.append(entry)


## Bracketing hooks the host uses to suppress side effects for the length of a session — in this
## game, `SaveGame.begin_runtime_sandbox()` / `end_runtime_sandbox()`, which refuse to *stage* an
## autosave rather than dropping it at flush. Suppression rather than restore-ordering is what
## keeps sandbox state off the player's disk: a request staged during a session flushes on the
## next idle frame, after the session already ended, and would flush unsuppressed.
func add_session_hooks(begin: Callable, end: Callable) -> void:
	_session_begin = begin
	_session_end = end


## The two surfaces every host of this game needs, registered in one place so a second tool
## cannot get them subtly different. Passed in rather than reached for, so core stays free of
## host names.
##
## `runtime_owner` must expose `capture_runtime_state()` / `restore_runtime_state(s)` and the
## `begin_runtime_sandbox()` / `end_runtime_sandbox()` pair. `rng_owner` must expose a
## `random_number_generator`.
func add_default_surfaces(runtime_owner: Object, rng_owner: Object) -> void:
	add_surface(
		&"runtime",
		func() -> Variant: return runtime_owner.call("capture_runtime_state"),
		func(snapshot: Variant) -> bool: return bool(
			runtime_owner.call("restore_runtime_state", snapshot)
		),
	)
	# Deliberately separate from the runtime snapshot: the host serializes reroll usage, not the
	# generator's position, so a session that consumed random numbers would permanently shift
	# the randomness later campaign skill checks draw from.
	add_surface(
		&"rng",
		func() -> Variant:
			var generator: RandomNumberGenerator = rng_owner.get("random_number_generator")
			return {"seed": generator.seed, "state": generator.state},
		func(snapshot: Variant) -> bool:
			var generator: RandomNumberGenerator = rng_owner.get("random_number_generator")
			var data: Dictionary = snapshot as Dictionary if snapshot is Dictionary else {}
			# Seed FIRST: assigning seed resets state, so the reverse order discards the
			# restored position. Restoring state alone leaves the generator's observable seed
			# reading as the session's, misreporting where the campaign's randomness came from.
			generator.seed = int(data.get("seed", generator.seed))
			generator.state = int(data.get("state", generator.state))
			return true,
	)
	add_session_hooks(
		func() -> void: runtime_owner.call("begin_runtime_sandbox"),
		func() -> void: runtime_owner.call("end_runtime_sandbox"),
	)


func is_armed() -> bool:
	return _armed


func owner() -> StringName:
	return _owner


## True while a DIFFERENT owner holds the sandbox — the question a tool asks before offering to
## start a session it would not be allowed to start.
func held_by_other(owner_id: StringName) -> bool:
	return _armed and _owner != owner_id


## Capture the host's reversible state under `owner_id`.
##
## Restore-then-capture is an unconditional pair. Restore is a no-op when nothing is armed,
## while capture must still happen for a restarted session whose previous snapshot was already
## disarmed — which is exactly the case a plain `if not armed` guard gets wrong.
func arm(owner_id: StringName) -> Dictionary:
	if owner_id.is_empty():
		return _blocked(_HELD, &"named_owner", "A sandbox session needs an owner id.")
	if held_by_other(owner_id):
		return _blocked(
			_HELD,
			&"disarm",
			"The sandbox is held by %s. End that session first." % String(_owner),
		)
	var restarting: bool = _armed
	_restore_all()
	for surface: Dictionary in _surfaces:
		_snapshots[surface["id"]] = (surface["capture"] as Callable).call()
	if not restarting and _session_begin.is_valid():
		_session_begin.call()
	_armed = true
	_owner = owner_id
	armed.emit(owner_id)
	return _allowed({"owner": String(owner_id), "restarted": restarting})


## Restore exactly once, then clear.
##
## An armed snapshot that outlives its session is worse than the leak it was added to stop: the
## tool's controls stay available after the session ends, so a later restart or shutdown would
## roll back progress the player legitimately earned after returning to normal play. Containment
## is scoped to the session, never left standing.
func disarm() -> Dictionary:
	if not _armed:
		return _blocked(_NOT_ARMED, &"arm", "No sandbox session is armed.")
	var ending_owner: StringName = _owner
	var failures: PackedStringArray = _restore_all()
	if _session_end.is_valid():
		_session_end.call()
	disarmed.emit(ending_owner)
	if not failures.is_empty():
		return _blocked(
			_NOT_ARMED,
			&"restorable_state",
			"The sandbox could not restore: %s." % ", ".join(failures),
		)
	return _allowed({"owner": String(ending_owner)})


func _restore_all() -> PackedStringArray:
	var failures := PackedStringArray()
	if not _armed:
		return failures
	_armed = false
	_owner = &""
	for surface: Dictionary in _surfaces:
		var id: StringName = surface["id"]
		if not _snapshots.has(id):
			continue
		if not bool((surface["restore"] as Callable).call(_snapshots[id])):
			failures.append(String(id))
	_snapshots.clear()
	return failures


static func _allowed(extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"allowed": true, "blocked_by": &"", "nearest_unblock": &"", "message": ""
	}
	result.merge(extra, true)
	return result


static func _blocked(by: StringName, unblock: StringName, message: String) -> Dictionary:
	return {
		"allowed": false, "blocked_by": by, "nearest_unblock": unblock, "message": message
	}
