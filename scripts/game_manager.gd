extends Node

var crafting_window: Control = null
var box_inventory: Control = null
var furnace_inventory: Control = null
var pause_menu: Control = null
var _quit_dialog: ConfirmationDialog = null


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
				pass  # Pause menu has its own quit button
			else:
				_show_quit_dialog()
			get_viewport().set_input_as_handled()


func _show_quit_dialog() -> void:
	if _quit_dialog and is_instance_valid(_quit_dialog):
		return  # Already showing

	_quit_dialog = ConfirmationDialog.new()
	_quit_dialog.dialog_text = "Save and quit?"
	_quit_dialog.ok_button_text = "Quit"
	_quit_dialog.cancel_button_text = "Cancel"
	_quit_dialog.confirmed.connect(_on_quit_confirmed)
	_quit_dialog.canceled.connect(_on_quit_canceled)
	add_child(_quit_dialog)
	_quit_dialog.popup_centered()


func _on_quit_confirmed() -> void:
	SaveManager.save_game()
	get_tree().quit()


func _on_quit_canceled() -> void:
	if _quit_dialog and is_instance_valid(_quit_dialog):
		_quit_dialog.queue_free()
		_quit_dialog = null
