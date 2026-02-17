extends Node

var crafting_window: Control = null
var box_inventory: Control = null
var furnace_inventory: Control = null
var pause_menu: Control = null
var _quit_dialog: Control = null

var window_bg: Texture2D = preload("res://graphics/windowtileset.png")
var button_texture: Texture2D = preload("res://graphics/button.png")


func _ready() -> void:
	await get_tree().process_frame
	crafting_window = get_tree().get_first_node_in_group("crafting_window")
	box_inventory = get_tree().get_first_node_in_group("box_inventory")
	furnace_inventory = get_tree().get_first_node_in_group("furnace_inventory")
	pause_menu = get_tree().get_first_node_in_group("pause_menu")

	# Auto-load save file if it exists (single player only)
	if not NetworkManager.is_connected_to_game() and SaveManager.has_save_file():
		# Wait another frame to ensure player is fully initialized
		await get_tree().process_frame
		SaveManager.load_game()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# CMD+W on macOS (meta key is Command) - close open windows or quit
		if event.keycode == KEY_W and event.meta_pressed:
			if crafting_window and crafting_window.is_open:
				crafting_window.close()
			elif box_inventory and box_inventory.is_open:
				box_inventory.close()
			elif furnace_inventory and furnace_inventory.is_open:
				furnace_inventory.close()
			elif pause_menu and pause_menu.is_open:
				pass  # Pause menu handles its own close
			else:
				_show_quit_dialog()
			get_viewport().set_input_as_handled()

	# Handle clicks on quit dialog
	if _quit_dialog and is_instance_valid(_quit_dialog) and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = event.global_position
		var quit_btn = _quit_dialog.get_node("Panel/VBox/HBox/QuitButton")
		var cancel_btn = _quit_dialog.get_node("Panel/VBox/HBox/CancelButton")
		var panel = _quit_dialog.get_node("Panel")
		if quit_btn.get_global_rect().has_point(mouse_pos):
			_on_quit_confirmed()
			get_viewport().set_input_as_handled()
		elif cancel_btn.get_global_rect().has_point(mouse_pos):
			_on_quit_canceled()
			get_viewport().set_input_as_handled()
		elif not panel.get_global_rect().has_point(mouse_pos):
			_on_quit_canceled()
			get_viewport().set_input_as_handled()


func _make_button_style(modulate_color: Color = Color.WHITE) -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	style.texture = button_texture
	style.texture_margin_left = 4
	style.texture_margin_right = 4
	style.texture_margin_top = 4
	style.texture_margin_bottom = 4
	style.modulate_color = modulate_color
	return style


func _style_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _make_button_style())
	btn.add_theme_stylebox_override("hover", _make_button_style(Color(1.2, 1.2, 1.2)))
	btn.add_theme_stylebox_override("pressed", _make_button_style(Color(0.8, 0.8, 0.8)))


func _show_quit_dialog() -> void:
	if _quit_dialog and is_instance_valid(_quit_dialog):
		return

	# Full-screen overlay
	_quit_dialog = Control.new()
	_quit_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_quit_dialog.mouse_filter = Control.MOUSE_FILTER_STOP

	# Dim background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.5)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quit_dialog.add_child(bg)

	# 9-patch panel
	var panel = NinePatchRect.new()
	panel.name = "Panel"
	panel.texture = window_bg
	panel.patch_margin_left = 16
	panel.patch_margin_right = 16
	panel.patch_margin_top = 16
	panel.patch_margin_bottom = 16
	panel.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	panel.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(140, 60)
	panel.size = Vector2(140, 60)
	panel.position = -panel.size / 2
	_quit_dialog.add_child(panel)

	# VBox for label + buttons
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.position = Vector2(12, 10)
	vbox.size = Vector2(116, 40)
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var label = Label.new()
	label.text = "Save and quit?"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	var hbox = HBoxContainer.new()
	hbox.name = "HBox"
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	var quit_btn = Button.new()
	quit_btn.name = "QuitButton"
	quit_btn.text = "Quit"
	quit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(quit_btn)
	quit_btn.pressed.connect(_on_quit_confirmed)
	hbox.add_child(quit_btn)

	var cancel_btn = Button.new()
	cancel_btn.name = "CancelButton"
	cancel_btn.text = "Cancel"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(cancel_btn)
	cancel_btn.pressed.connect(_on_quit_canceled)
	hbox.add_child(cancel_btn)

	get_tree().root.add_child(_quit_dialog)


func _on_quit_confirmed() -> void:
	SaveManager.save_game()
	get_tree().quit()


func _on_quit_canceled() -> void:
	if _quit_dialog and is_instance_valid(_quit_dialog):
		_quit_dialog.queue_free()
		_quit_dialog = null
