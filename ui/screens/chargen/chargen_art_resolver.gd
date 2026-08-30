class_name ChargenArtResolver
extends RefCounted
## Resolves optional painterly character-creation art without exposing missing
## resources to the UI. Portraits fall back to the likeness's existing field sprite;
## ancestry art returns an empty marker so the page can show its styled text panel.

const UnitArtScript := preload("res://globals/unit_art.gd")

const PORTRAIT_PATTERN := "res://assets/generated/portraits/player/%s.png"
const ANCESTRY_PATTERN := "res://assets/generated/chargen/ancestry_%s.png"


## ResourceLoader.exists follows export remapping (FileAccess alone misses
## imported textures inside a PCK); FileAccess keeps unimported files (tests,
## fresh drops) resolvable in the editor.
static func _art_exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


static func portrait_path(likeness_id: String, pattern: String = PORTRAIT_PATTERN) -> String:
	var generated_path := pattern % likeness_id
	if _art_exists(generated_path):
		return generated_path
	# Gallery likeness ids map to a paired crowd field sprite; legacy ids WERE
	# unit ids and fall through unchanged.
	return UnitArtScript.texture_path(ChargenData.likeness_fallback_unit(likeness_id))


## Loads the portrait as a texture, falling through to the paired field sprite
## when the generated plate exists but cannot load as a texture (gate r1 ruling:
## existence is not validity). UI consumers use this, never load() a path
## themselves, so a corrupt plate can never blank the gallery or the member.
static func portrait_texture(likeness_id: String, pattern: String = PORTRAIT_PATTERN) -> Texture2D:
	var generated_path := pattern % likeness_id
	if _art_exists(generated_path):
		var generated: Resource = load(generated_path)
		if generated is Texture2D:
			return generated as Texture2D
	var fallback_path: String = UnitArtScript.texture_path(
		ChargenData.likeness_fallback_unit(likeness_id)
	)
	if _art_exists(fallback_path):
		var fallback: Resource = load(fallback_path)
		if fallback is Texture2D:
			return fallback as Texture2D
	return null


static func ancestry_path(ancestry_id: String, pattern: String = ANCESTRY_PATTERN) -> String:
	var generated_path := pattern % ancestry_id
	return generated_path if _art_exists(generated_path) else ""
