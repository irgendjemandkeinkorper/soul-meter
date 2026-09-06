extends GdUnitTestSuite
## ClassCatalog — the ten patron classes as data (docs/architecture-chargen-dramgid.md §6).


func test_ten_classes_with_registry_patrons_and_arms_kits() -> void:
	assert_int(ClassCatalog.ALL.size()).is_equal(10)
	for entry: Dictionary in ClassCatalog.ALL:
		var class_id := str(entry["id"])
		assert_bool(ClassResourceRegistry.PATRON_IDS.has(StringName(str(entry["patron_id"])))).is_true()
		assert_bool(ClassResourceRegistry.for_patron(str(entry["patron"])).patron_id == StringName(str(entry["patron_id"]))).is_true()
		var kit_skills: Array = entry["kit_skills"]
		assert_bool(kit_skills.size() >= 1).is_true()
		for skill_id in kit_skills:
			assert_bool(DramgidSchema.is_arms_skill(str(skill_id))).is_true()
		assert_bool(ChargenData.is_valid_element_pair(
			str(entry["suggested_major"]), str(entry["suggested_minor"]))).is_true()
		for key in ["resource", "signature", "kit", "role", "name"]:
			assert_str(str(entry[key])).is_not_empty()
		assert_str(ClassCatalog.display_class(class_id)).is_equal("%s (%s)" % [entry["name"], entry["patron"]])


func test_ironbrand_is_the_one_kit_with_a_weapon_choice() -> void:
	var choosers := 0
	for entry: Dictionary in ClassCatalog.ALL:
		if ClassCatalog.offers_kit_choice(str(entry["id"])):
			choosers += 1
			assert_str(str(entry["id"])).is_equal("ironbrand")
	assert_int(choosers).is_equal(1)
	assert_str(ClassCatalog.default_kit_skill("ironbrand")).is_equal("heft")


func test_threadwalker_x_chordblade_is_retired_and_watch_cells_are_allowed() -> void:
	assert_bool(ClassCatalog.is_retired_pairing("threadwalker", "chordblade")).is_true()
	assert_bool(ClassCatalog.is_retired_pairing("threadwalker", "hushwarden")).is_false()
	assert_bool(ClassCatalog.is_watch_pairing("oathclock", "hushwarden")).is_true()
	assert_bool(ClassCatalog.is_watch_pairing("locksmirk", "hushwarden")).is_true()
	assert_bool(ClassCatalog.is_retired_pairing("locksmirk", "hushwarden")).is_false()


func test_class_for_patron_value_accepts_every_vocabulary() -> void:
	assert_str(str(ClassCatalog.class_for_patron_value("ironbrand")["id"])).is_equal("ironbrand")
	assert_str(str(ClassCatalog.class_for_patron_value("Kero")["id"])).is_equal("ironbrand")
	assert_str(str(ClassCatalog.class_for_patron_value("kero")["id"])).is_equal("ironbrand")
	assert_str(str(ClassCatalog.class_for_patron_value("Ofshütje")["id"])).is_equal("stormbearer")
	assert_str(str(ClassCatalog.class_for_patron_value("ofshutje")["id"])).is_equal("stormbearer")
	assert_bool(ClassCatalog.class_for_patron_value("").is_empty()).is_true()
	assert_bool(ClassCatalog.class_for_patron_value("nobody").is_empty()).is_true()
	assert_str(ClassCatalog.patron_for("locksmirk")).is_equal("Fickah")
