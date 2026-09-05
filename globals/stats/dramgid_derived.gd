class_name DramgidDerived
extends RefCounted
## Transitional derived-stat formulas. DeepSeek's numeric freeze replaces these.

const DramgidSchemaScript := preload("res://globals/stats/dramgid_schema.gd")


static func max_hp(grit: int) -> int:
	return grit * 8


static func attack(muster: int) -> int:
	return muster


static func defense(alacrity: int) -> int:
	return alacrity


static func breath_max(_intuition: int) -> int:
	return 15


static func recompute(member: PartyMember) -> void:
	member.max_hp = max_hp(member.attribute_value(DramgidSchemaScript.ATTR_GRIT))
	member.attack = attack(member.attribute_value(DramgidSchemaScript.ATTR_MUSTER))
	member.defense = defense(member.attribute_value(DramgidSchemaScript.ATTR_ALACRITY))
	member.breath_max = breath_max(member.attribute_value(DramgidSchemaScript.ATTR_INTUITION))
	member.hp = clampi(member.hp, 0, member.max_hp)
	member.breath = clampi(member.breath, 0, member.breath_max)
