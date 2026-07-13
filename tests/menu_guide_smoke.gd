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
	if not _check(menu.guide_overlay.operation_text.text.contains("W / A / S / D") and menu.guide_overlay.operation_text.text.contains("Space"), "Operation guide is missing the actual controls"):
		return
	if not _check(menu.guide_overlay.item_text.text.contains("Shield Potion") and menu.guide_overlay.item_text.text.contains("Wings") and menu.guide_overlay.item_text.text.contains("Tianlao"), "Item guide is incomplete"):
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

	print("MENU_GUIDE_SMOKE_OK controls items responsive_close")
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
