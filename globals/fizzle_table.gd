class_name FizzleTable
extends Resource
## Tunable casting fizzle inputs.
##
## This resource is the seam between SkillCheck and Pandora. Issue #91 can
## generate the same Resource shape from the canonical data without changing
## the resolution service. Keys are lower-case breadth/magnitude names; strain
## keys are the integer step distance as strings.

@export var breadth_add: Dictionary = {
	"tone": 0.0,
	"chord": 5.0,
	"triad": 12.0,
}
@export var strain_add: Dictionary = {
	"0": 0.0,
	"1": 0.0,
	"2": 6.0,
	"3": 12.0,
	"4": 18.0,
}
@export var magnitude_multiplier: Dictionary = {
	"note": 0.5,
	"phrase": 1.0,
	"song": 1.75,
	"refrain": 2.75,
}
## Ratified calibration points. Pandora may replace or extend these entries;
## they are data rather than service-level special cases.
@export var sanity_readings: Dictionary = {}
