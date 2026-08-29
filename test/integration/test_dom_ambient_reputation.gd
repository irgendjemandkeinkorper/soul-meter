extends GdUnitTestSuite

const DIALOGUE_PATH := "res://dialogue/dom_townsfolk.dialogue"
const SPEAKER_CASES: Array[Dictionary] = [
	{
		"title": "dom_droma_flintjaw",
		"hostile": "The Companies have you marked cold. State your business from there.",
		"warm": "The Companies speak warmly of you. Cross at the near brace.",
	},
	{
		"title": "dom_edda_broadmark",
		"hostile": "The Companies give your name no weight. Edda does the same.",
		"warm": "The Companies give your name weight. Edda will hear you first.",
	},
	{
		"title": "dom_ressa_ironmouth",
		"hostile": "The Companies distrust your name. Ressa keeps the hot tongs between you and the rack.",
		"warm": "The Companies trust your name. Ressa clears the sparks when you step to the rack.",
	},
]

var _reputation_before: Dictionary


func before_test() -> void:
	_reputation_before = Reputation.to_dict()


func after_test() -> void:
	Reputation.from_dict(_reputation_before)


func test_each_speaker_switches_between_hostile_and_warm_acknowledgements() -> void:
	var resource: DialogueResource = load(DIALOGUE_PATH)
	assert_object(resource).is_not_null()
	for speaker_case: Dictionary in SPEAKER_CASES:
		_set_iron_companies_standing(Reputation.BAND_HOSTILE)
		var hostile_lines: PackedStringArray = await _lines_for_title(
			resource, String(speaker_case["title"])
		)
		assert_array(hostile_lines).contains(String(speaker_case["hostile"]))
		assert_array(hostile_lines).not_contains(String(speaker_case["warm"]))

		_set_iron_companies_standing(Reputation.BAND_WARM)
		var warm_lines: PackedStringArray = await _lines_for_title(
			resource, String(speaker_case["title"])
		)
		assert_array(warm_lines).contains(String(speaker_case["warm"]))
		assert_array(warm_lines).not_contains(String(speaker_case["hostile"]))


func _lines_for_title(resource: DialogueResource, title: String) -> PackedStringArray:
	var texts := PackedStringArray()
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, title)
	while line != null:
		texts.append(line.text)
		if line.next_id.is_empty():
			break
		line = await DialogueManager.get_next_dialogue_line(resource, line.next_id)
	return texts


func _set_iron_companies_standing(delta: float) -> void:
	Reputation.from_dict({
		"log": [{
			"actor": "test",
			"faction": "iron-companies",
			"delta": delta,
			"cause": "Test band setup",
			"scene": "test",
			"at": 0,
			"order": 0,
		}],
		"next_order": 1,
	})
