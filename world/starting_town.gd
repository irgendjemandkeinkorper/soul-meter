extends Node2D
## Runtime presentation seam for Dom's placeholder facades.
## The old kit assemblies remain named in the scene so art can be inspected and
## swapped without losing the existing node wiring, but only Facade renders.

const BUILDING_NAMES := [
	"TrialHall",
	"RegistryArchive",
	"BellHouse",
	"RiverShrine",
	"IronCompaniesBarracks",
	"LowerMarket",
	"ItemShop",
	"EquipmentShop",
	"TownHall",
	"ChefsHouse",
	"PlayersHouse",
	"FourArmsTavern",
]


func _ready() -> void:
	for building_name: String in BUILDING_NAMES:
		var building := get_node_or_null(building_name) as Node2D
		if building == null:
			push_error("Starting town is missing building '%s'." % building_name)
			continue
		for child: Node in building.get_children():
			if child is Sprite2D and child.name != "Facade":
				child.visible = false
