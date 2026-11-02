class_name PropScale
extends RefCounted
## Dressing props sized against the 112 px adult (lived-in maps M2, owner 2026-11-02: "all
## interiors", and every new greeble). A prop's height class says how tall it stands in the
## world; its scale is the class height over the opaque height of its texture, so a bucket
## always reads knee-low beside a person whatever size its master was painted at.

const ADULT_PX := 112.0
## On-screen height at camera zoom 1, by class. PROVISIONAL: tuned by eye on Kesselford.
const HEIGHT_PX := {
	"small": 24.0,
	"knee": 42.0,
	"waist": 64.0,
	"head": 108.0,
	"tall": 150.0,
}
## Ground decals: an export spans 512x256 px; this many px of world width per decal.
const GROUND_WIDTH_PX := {
	"patch": 300.0,
	"strip": 260.0,
	"small": 170.0,
}


static func height_px(height_class: String) -> float:
	return float(HEIGHT_PX.get(height_class, HEIGHT_PX["knee"]))


## Scale for a standing sprite whose opaque content is `content_height` px tall.
static func standing_scale(content_height: float, height_class: String) -> float:
	if content_height <= 0.0:
		return 1.0
	return height_px(height_class) / content_height


## Scale for a 512 px-wide ground decal of the given footprint kind.
static func ground_scale(kind: String) -> float:
	return float(GROUND_WIDTH_PX.get(kind, GROUND_WIDTH_PX["patch"])) / 512.0
