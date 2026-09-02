class_name HaerenNameLedger
extends ClassResource
## Haeren — River-Mother: Name-Ledger. Recording a fallen or saved ally's name refunds Gauge;
## each name is recorded once per battle.

const SOUL_REFUND := 1.0 # PROVISIONAL — B11 owns tuning.

var recorded_names: Array[String] = []
var pending_soul_refunds: float = 0.0


func record_name(name: String, _saved: bool) -> bool:
	var normalized := name.strip_edges()
	if normalized.is_empty() or recorded_names.has(normalized):
		return false
	recorded_names.append(normalized)
	pending_soul_refunds += SOUL_REFUND
	return true


func snapshot() -> Dictionary:
	return {
		"patron_id": String(patron_id),
		"label": "Names Remembered",
		"value": recorded_names.size(),
		"max": "per battle",
		"pending_soul_refunds": pending_soul_refunds,
	}


func to_dict() -> Dictionary:
	var data: Dictionary = super.to_dict()
	data["recorded_names"] = recorded_names.duplicate()
	data["pending_soul_refunds"] = pending_soul_refunds
	return data


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	recorded_names.clear()
	for value: Variant in data.get("recorded_names", []):
		var name := str(value).strip_edges()
		if not name.is_empty() and not recorded_names.has(name):
			recorded_names.append(name)
	pending_soul_refunds = maxf(float(data.get("pending_soul_refunds", 0.0)), 0.0)
