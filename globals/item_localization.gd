class_name ItemLocalization
extends RefCounted
## Resolves generated item translation keys while keeping Pandora's English text
## available when a locale has no translation yet.


static func key_for(prototype_id: String, field: String) -> String:
	var normalized_id := prototype_id.strip_edges().to_upper().replace("/", "_").replace("-", "_")
	var suffix := "NAME" if field == "name" else "DESC"
	return "ITEM_%s_%s" % [normalized_id, suffix]


static func text(prototype_id: String, field: String, fallback: String) -> String:
	var key := key_for(prototype_id, field)
	var translated := TranslationServer.translate(key)
	return with_fallback(translated, key, fallback)


static func with_fallback(translated: String, key: String, fallback: String) -> String:
	if translated.is_empty() or translated == key:
		return fallback
	return translated
