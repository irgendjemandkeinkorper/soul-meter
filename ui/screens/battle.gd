extends Screen
## Standalone combat shell for a fight with no live field (tools and tests). It hosts a
## FieldHUD over an opaque backdrop and puts it in combat; the HUD's own bar carries the
## command grid, message window and turn controls. On a live field GameFlow never opens
## this: the field's own HUD grows its combat parts instead (owner 2026-11-01).

const FIELD_HUD_SCENE := preload("res://ui/hud/field_hud.tscn")
## Above UIManager (layer 10) so the hosted HUD draws over this shell's backdrop.
const HUD_LAYER := 11

var hud: FieldHUD


func _build() -> void:
	# CombatOverlay draws the fight on the live field underneath the HUD. Only
	# standalone tests/tools that start Battle without a session need a backdrop.
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = DS.VOID_1
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.visible = not Battle.session_active
	add_child(backdrop)
	hud = FIELD_HUD_SCENE.instantiate() as FieldHUD
	hud.name = "FieldHUD"
	hud.layer = HUD_LAYER
	add_child(hud)
	hud.enter_combat(Battle._current_field_map() if Battle.session_active else null)


func battle_interface() -> BattleInterface:
	return hud.battle_interface if is_instance_valid(hud) else null


func combat_bar() -> CombatBar:
	return hud.combat_bar if is_instance_valid(hud) else null


func outcome_shown() -> bool:
	var bar := combat_bar()
	return bar != null and bar.outcome_shown()


# --- legacy narration formatters (unit-tested; no live caller) ----------------------------


static func format_attack(
	player_name: String,
	enemy_name: String,
	enemy_hp_before: int,
	enemy_hp_after: int,
	enemy_max_hp: int,
	player_hp_before: int,
	player_hp_after: int,
	player_max_hp: int
) -> String:
	var dmg_to_enemy := enemy_hp_before - enemy_hp_after
	var lines: Array[String] = []

	lines.append("%s attacks %s, dealing %d damage (%s HP: %d/%d)." % [
		player_name, enemy_name, dmg_to_enemy, enemy_name, enemy_hp_after, enemy_max_hp
	])

	if enemy_hp_after <= 0:
		lines.append("%s is defeated." % enemy_name)
	else:
		var dmg_to_player := player_hp_before - player_hp_after
		lines.append("%s counterattacks, dealing %d damage (%s HP: %d/%d)." % [
			enemy_name, dmg_to_player, player_name, player_hp_after, player_max_hp
		])
		if player_hp_after <= 0:
			lines.append("%s falls. The fight is over." % player_name)

	return "\n".join(lines)


static func format_defend(
	player_name: String,
	enemy_name: String,
	player_hp_before: int,
	player_hp_after: int,
	player_max_hp: int,
	enemy_attack: int,
	player_defense: int
) -> String:
	var dmg_taken := player_hp_before - player_hp_after
	var unmitigated := maxi(1, enemy_attack - player_defense)
	var mitigated_amount := unmitigated - dmg_taken

	var lines: Array[String] = []
	lines.append("%s braces! Mitigates incoming damage from %s." % [player_name, enemy_name])

	if mitigated_amount > 0:
		lines.append("%s takes %d damage (blocked %d) (%s HP: %d/%d)." % [
			player_name, dmg_taken, mitigated_amount, player_name, player_hp_after, player_max_hp
		])
	else:
		lines.append("%s takes %d damage (mitigated to minimum) (%s HP: %d/%d)." % [
			player_name, dmg_taken, player_name, player_hp_after, player_max_hp
		])

	if player_hp_after <= 0:
		lines.append("%s falls. The fight is over." % player_name)

	return "\n".join(lines)
