class_name DialogueLedgerEcho
extends RefCounted
## Ledger events a conversation already showed the player on its ledger strip (U1, owner
## 2026-11-01: "effects land on the line"). The field's ConsequenceNotices consume these
## keys when they flush after the conversation, so the same event is not announced twice.
## Keys are the ledger identity `"<ledger>:<order>"`; `order` is monotonic within one ledger.

## A key nobody consumes (no notices in the scene) must not pile up for a whole session.
const MAX_KEYS := 256

static var _shown: Dictionary = {}


static func key_for(event: RefCounted) -> String:
	if event == null:
		return ""
	var ledger := "renown" if event is RenownEvent else "reputation"
	return "%s:%d" % [ledger, int(event.get("order"))]


static func mark(event: RefCounted) -> void:
	var key := key_for(event)
	if key.is_empty():
		return
	if _shown.size() >= MAX_KEYS:
		_shown.clear()
	_shown[key] = true


## True once per marked key: the notice for it should be skipped.
static func consume(key: String) -> bool:
	return not key.is_empty() and _shown.erase(key)


static func clear() -> void:
	_shown.clear()
