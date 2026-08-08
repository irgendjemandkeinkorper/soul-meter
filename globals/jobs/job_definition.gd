class_name JobDefinition
extends Resource
## One row of the `jobs` table (issue #141, Elemental Architecture Section III).
##
## SCHEMA ONLY. Pandora owns the authored rows; this is the runtime shape they are
## generated into (res://data/generated/tactical_tables.json via
## tools/generate_tactical_tables.gd). Nothing here writes back to Pandora.
##
## CANON BOUNDARY: the naming of combat disciplines is settled in
## docs/prd-amendment-tactical-layer.md §9.1 (DECIDED 2026-08-05: combat disciplines,
## Patron remains the class) and the vault amendment is tracked as GitHub #132.
## No job is named in code. This file describes the shape of a job, never a job.

## The element ids a job may bind to are exactly ElementWheel.ORDER. An empty
## element_id means "unaligned" — a discipline that draws on no element.
@export var id: String = ""
@export var display_name: String = ""
## Tier is the advancement rank within a discipline line; 1 is the entry rank.
@export var tier: int = 1
@export var element_id: StringName = &""
## FK into `jobs`. Empty means the job has no prerequisite.
@export var requires_job_id: String = ""
## Per-level growth contributions. Balance values are owner-authored content and
## are deliberately not defaulted to anything meaningful here.
@export var growth_hp: float = 0.0
@export var growth_mp: float = 0.0
@export var growth_spd: float = 0.0
## Bridge to the lore vault (see CLAUDE.md: Pandora owns game data, the vault owns prose).
@export var vault_id: String = ""


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"tier": tier,
		"element_id": String(element_id),
		"requires_job_id": requires_job_id,
		"growth_hp": growth_hp,
		"growth_mp": growth_mp,
		"growth_spd": growth_spd,
		"vault_id": vault_id,
	}


static func from_dict(data: Dictionary) -> JobDefinition:
	var job := JobDefinition.new()
	job.id = str(data.get("id", ""))
	job.display_name = str(data.get("display_name", ""))
	job.tier = int(data.get("tier", 1))
	job.element_id = StringName(str(data.get("element_id", "")))
	job.requires_job_id = str(data.get("requires_job_id", ""))
	job.growth_hp = float(data.get("growth_hp", 0.0))
	job.growth_mp = float(data.get("growth_mp", 0.0))
	job.growth_spd = float(data.get("growth_spd", 0.0))
	job.vault_id = str(data.get("vault_id", ""))
	return job
