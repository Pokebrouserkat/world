extends GdUnitTestSuite

## Tests for CraftingWindow to prevent regressions

var crafting_window_scene: PackedScene = preload("res://scenes/crafting_window.tscn")


func test_click_outside_closes_window() -> void:
	# Test that clicking outside the panel closes the crafting window
	var window = auto_free(crafting_window_scene.instantiate())
	add_child(window)

	await get_tree().process_frame  # Let it initialize

	# Open the window
	window.open()
	assert_that(window.is_open).is_true()

	# Simulate click outside panel (at 0,0 which should be outside)
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.global_position = Vector2(0, 0)

	window._input(click_event)

	assert_that(window.is_open).is_false()


func test_click_inside_keeps_window_open() -> void:
	# Test that clicking inside the panel keeps window open
	var window = auto_free(crafting_window_scene.instantiate())
	add_child(window)

	await get_tree().process_frame

	window.open()
	assert_that(window.is_open).is_true()

	# Get panel center position
	var panel = window.panel
	var panel_center = panel.get_global_rect().get_center()

	# Simulate click inside panel
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.global_position = panel_center

	window._input(click_event)

	assert_that(window.is_open).is_true()


func test_c_key_toggles_window() -> void:
	# Test that C key opens and closes the window
	var window = auto_free(crafting_window_scene.instantiate())
	add_child(window)

	await get_tree().process_frame

	assert_that(window.is_open).is_false()

	# Simulate C press to open
	var c_event = InputEventKey.new()
	c_event.keycode = KEY_C
	c_event.pressed = true

	window._input(c_event)
	assert_that(window.is_open).is_true()

	# Simulate C press to close
	window._input(c_event)
	assert_that(window.is_open).is_false()


func test_escape_closes_when_open() -> void:
	# Test that ESC closes the window when open
	var window = auto_free(crafting_window_scene.instantiate())
	add_child(window)

	await get_tree().process_frame

	window.open()
	assert_that(window.is_open).is_true()

	# Simulate ESC press
	var esc_event = InputEventKey.new()
	esc_event.keycode = KEY_ESCAPE
	esc_event.pressed = true

	window._input(esc_event)

	assert_that(window.is_open).is_false()
