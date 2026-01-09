extends GdUnitTestSuite

## Tests for PauseMenu to prevent regressions

var pause_menu_scene: PackedScene = preload("res://scenes/pause_menu.tscn")


func test_click_outside_closes_menu() -> void:
	# Test that clicking outside the panel closes the pause menu
	var pause_menu = auto_free(pause_menu_scene.instantiate())
	add_child(pause_menu)

	# Open the menu
	pause_menu.open()
	assert_that(pause_menu.is_open).is_true()

	# Simulate click outside panel (at 0,0 which should be outside)
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.global_position = Vector2(0, 0)  # Outside panel

	pause_menu._input(click_event)

	assert_that(pause_menu.is_open).is_false()


func test_click_inside_keeps_menu_open() -> void:
	# Test that clicking inside the panel keeps menu open
	var pause_menu = auto_free(pause_menu_scene.instantiate())
	add_child(pause_menu)

	# Open the menu
	pause_menu.open()
	assert_that(pause_menu.is_open).is_true()

	# Get panel center position (should be inside)
	var panel = pause_menu.panel
	var panel_center = panel.get_global_rect().get_center()

	# Simulate click inside panel
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.global_position = panel_center

	pause_menu._input(click_event)

	# Menu should still be open
	assert_that(pause_menu.is_open).is_true()


func test_escape_toggles_menu() -> void:
	# Test that ESC key opens and closes the menu
	var pause_menu = auto_free(pause_menu_scene.instantiate())
	add_child(pause_menu)

	assert_that(pause_menu.is_open).is_false()

	# Simulate ESC press to open
	var esc_event = InputEventKey.new()
	esc_event.keycode = KEY_ESCAPE
	esc_event.pressed = true

	pause_menu._input(esc_event)
	assert_that(pause_menu.is_open).is_true()

	# Simulate ESC press to close
	pause_menu._input(esc_event)
	assert_that(pause_menu.is_open).is_false()


func test_right_click_outside_closes_menu() -> void:
	# Test that right-clicking outside also closes the menu
	var pause_menu = auto_free(pause_menu_scene.instantiate())
	add_child(pause_menu)

	pause_menu.open()
	assert_that(pause_menu.is_open).is_true()

	# Simulate right click outside panel
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_RIGHT
	click_event.pressed = true
	click_event.global_position = Vector2(0, 0)

	pause_menu._input(click_event)

	assert_that(pause_menu.is_open).is_false()


func test_click_when_closed_does_nothing() -> void:
	# Test that clicking when menu is closed doesn't cause errors
	var pause_menu = auto_free(pause_menu_scene.instantiate())
	add_child(pause_menu)

	assert_that(pause_menu.is_open).is_false()

	# Simulate click while closed - should not crash or change state
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.global_position = Vector2(0, 0)

	pause_menu._input(click_event)

	assert_that(pause_menu.is_open).is_false()
