class_name ChargenArtResolver
extends RefCounted
## Resolves optional painterly character-creation art without exposing missing
## resources to the UI. Portraits fall back to the likeness's existing field sprite;
## ancestry art returns an empty marker so the page can show its styled text panel.

const UnitArtScript := preload("res://globals/unit_art.gd")

const PORTRAIT_PATTERN := "res://assets/generated/portraits/player/%s.png"
const ANCESTRY_PATTERN := "res://assets/generated/chargen/ancestry_%s.png"


static func portrait_path(likeness_id: String, pattern: String = PORTRAIT_PATTERN) -> String:
	var generated_path := pattern % likeness_id
	if FileAccess.file_exists(generated_path):
		return generated_path
	# Gallery likeness ids map to a paired crowd field sprite; legacy ids WERE
	# unit ids and fall through unchanged.
	return UnitArtScript.texture_path(ChargenData.likeness_fallback_unit(likeness_id))


static func ancestry_path(ancestry_id: String, pattern: String = ANCESTRY_PATTERN) -> String:
	var generated_path := pattern % ancestry_id
	return generated_path if FileAccess.file_exists(generated_path) else ""
