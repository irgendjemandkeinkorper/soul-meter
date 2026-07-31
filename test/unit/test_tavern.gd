extends GdUnitTestSuite

const TavernScript := preload("res://ui/screens/tavern.gd")

func test_format_recruit_subtext() -> void:
	var formatted := TavernScript.format_recruit_subtext("Ghorr", "River-Mother (Haeren)", 28, 32)
	assert_str(formatted).is_equal("Ghorr  •  River-Mother (Haeren)  •  HP 28/32")


func test_get_lock_reason_text_no_requirements() -> void:
	# Locked reason should be empty if requirements are met
	var reason := TavernScript.get_lock_reason_text(0.0, 10.0, 0.0, 5.0)
	assert_str(reason).is_empty()


func test_get_lock_reason_text_reputation_gate() -> void:
	# Locked reason when min reputation is not met
	var reason := TavernScript.get_lock_reason_text(10.0, 4.0, 0.0, 5.0)
	assert_str(reason).is_equal("Won't talk to you yet — needs Renown 10 (you have 4).")


func test_get_lock_reason_text_infamy_gate() -> void:
	# Locked reason when min infamy is not met
	var reason := TavernScript.get_lock_reason_text(0.0, 10.0, 8.0, 3.0)
	assert_str(reason).is_equal("Doesn't trust anyone this clean — needs Infamy 8 (you have 3).")


func test_get_lock_reason_text_both_gates_reputation_first() -> void:
	# Locked reason check when both are unmet, usually reputation takes precedence in get_lock_reason_text order
	var reason := TavernScript.get_lock_reason_text(10.0, 4.0, 8.0, 3.0)
	assert_str(reason).is_equal("Won't talk to you yet — needs Renown 10 (you have 4).")
