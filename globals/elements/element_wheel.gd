class_name ElementWheel
extends RefCounted

## The fixed circular order used by every element distance calculation.
const ORDER: Array[StringName] = [
	&"suul", &"bloei", &"aqua", &"khor", &"terra",
	&"daar", &"molm", &"scor", &"nul", &"strom",
]


static func normalize(value: Variant) -> StringName:
	return StringName(str(value).to_lower())


static func index_of(element: Variant) -> int:
	return ORDER.find(normalize(element))


static func distance(first: Variant, second: Variant) -> int:
	var first_index := index_of(first)
	var second_index := index_of(second)
	if first_index < 0 or second_index < 0:
		return -1
	var clockwise := absi(first_index - second_index)
	return mini(clockwise, ORDER.size() - clockwise)


static func span(elements: Array[StringName]) -> int:
	var indices: Array[int] = []
	for element in elements:
		var index := index_of(element)
		if index < 0 or indices.has(index):
			return -1
		indices.append(index)
	if indices.size() < 2:
		return 0
	indices.sort()

	var largest_gap := 0
	for index in range(indices.size()):
		var current := indices[index]
		var next := indices[(index + 1) % indices.size()]
		var gap := next - current if next > current else next + ORDER.size() - current
		largest_gap = maxi(largest_gap, gap)
	return ORDER.size() - largest_gap


static func contains_opposed_pair(elements: Array[StringName]) -> bool:
	for first_index in range(elements.size()):
		for second_index in range(first_index + 1, elements.size()):
			if distance(elements[first_index], elements[second_index]) == 5:
				return true
	return false
