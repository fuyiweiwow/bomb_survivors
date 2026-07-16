extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1152, 648)
	var packed := load("res://scenes/menu/main_menu.tscn") as PackedScene
	var menu = packed.instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame

	if not _check(menu.guide_button != null and menu.guide_button.text == "Game Guide", "Main menu did not create the English game guide button"):
		return
	menu.guide_button.pressed.emit()
	await process_frame
	if not _check(menu.guide_overlay.visible and menu.guide_overlay.guide_tabs.get_tab_count() == 2, "Game guide did not open with two pages"):
		return
	if not _check(menu.guide_overlay.operation_text.text.contains("W / A / S / D") and menu.guide_overlay.operation_text.text.contains("Space") and menu.guide_overlay.operation_text.text.contains("Duel Controls"), "Operation guide is missing the actual controls"):
		return
	if not _check(menu.guide_overlay.operation_text.text.contains("occupies one complete logical tile") and menu.guide_overlay.operation_text.text.contains("damages the complete logical tile"), "Operation guide is missing the occupancy or full-tile blast rules"):
		return
	if not _check(menu.guide_overlay.operation_text.text.contains("player has 3 HP") and menu.guide_overlay.operation_text.text.contains("regular AI has 1 HP") and menu.guide_overlay.operation_text.text.contains("hits remove 1 HP"), "Operation guide is missing the player, AI, or damage health rules"):
		return
	var expected_item_ids := ["speed", "bomb", "range", "shield", "detonator", "glue", "shield_potion", "invincible_star", "dummy", "oil_barrel", "rock", "wings", "football_shoes", "prison", "duel"]
	if not _check(menu.guide_overlay.item_icon_ids == expected_item_ids, "Item guide icon list is incomplete"):
		return
	var item_label_texts: Array[String] = []
	for label in menu.guide_overlay.item_list.find_children("*", "Label", true, false):
		item_label_texts.append(str(label.text))
	if not _check(item_label_texts.has("Prison") and not item_label_texts.has("Tianlao"), "Item guide did not use the English Prison display name"):
		return
	var has_smart_football_rule := false
	for label_text in item_label_texts:
		if label_text.contains("visible ground enemy within 6 cells") and label_text.contains("without a safe landing cell"):
			has_smart_football_rule = true
			break
	if not _check(has_smart_football_rule, "Item guide is missing the smart and safe Football Shoes rules"):
		return
	for renderer in menu.guide_overlay.item_icon_renderers:
		if not _check(renderer.icon_viewport != null and is_instance_valid(renderer.icon_model) and renderer.icon_model.get_child_count() > 1, "Item guide did not render a game model icon"):
			return
	if not _check(menu.guide_overlay.item_list != null, "Item guide descriptions were not created"):
		return
	if not _check(_panel_is_inside_viewport(menu), "Game guide exceeds the desktop viewport"):
		return

	root.size = Vector2i(640, 480)
	await process_frame
	await process_frame
	if not _check(_panel_is_inside_viewport(menu), "Game guide exceeds the scaled compact viewport"):
		return
	menu._hide_guide()
	if not _check(not menu.guide_overlay.visible, "Game guide did not return to the main menu"):
		return

	print("MENU_GUIDE_SMOKE_OK controls shared_3d_item_icons items responsive_close")
	quit(0)

func _panel_is_inside_viewport(menu: Control) -> bool:
	var panel_rect: Rect2 = menu.guide_overlay.guide_panel.get_global_rect()
	var viewport_rect: Rect2 = menu.get_viewport_rect()
	return viewport_rect.encloses(panel_rect) and panel_rect.size.x > 0.0 and panel_rect.size.y > 0.0

func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
