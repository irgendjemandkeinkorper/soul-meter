extends Node

func _ready() -> void:
	if OS.get_environment("SM_ELEV").is_empty():
		return
	_run.call_deferred()

func _run() -> void:
	for path: String in ["res://world/starting_town.tscn", "res://world/dorthkor_road.tscn", "res://world/test_room.tscn", "res://world/interiors/lower_trial_hall.tscn", "res://world/kesselford.tscn"]:
		var root := (load(path) as PackedScene).instantiate()
		var counts := {}
		var layers := 0
		for node: Node in root.find_children("*", "TileMapLayer", true, false):
			var layer := node as TileMapLayer
			if layer.get_script() == null or not String(layer.get_script().resource_path).ends_with("combat_terrain_layer.gd"):
				continue
			layers += 1
			if layer.tile_set == null or layer.tile_set.get_custom_data_layer_by_name(&"elevation") < 0:
				counts["no_elevation_layer"] = true
				continue
			for cell: Vector2i in layer.get_used_cells():
				var data := layer.get_cell_tile_data(cell)
				if data == null:
					continue
				var e: Variant = data.get_custom_data(&"elevation")
				if e is int and e != 0:
					counts[e] = int(counts.get(e, 0)) + 1
		print("ELEV %s terrain_layers=%d raised=%s" % [path.get_file(), layers, counts])
		root.free()
	get_tree().quit()
