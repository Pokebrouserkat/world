extends Node

var crafting_window: Control = null
var box_inventory: Control = null


func _ready() -> void:
	await get_tree().process_frame
	crafting_window = get_tree().get_first_node_in_group("crafting_window")
	box_inventory = get_tree().get_first_node_in_group("box_inventory")

	# Auto-load save file if it exists (single player only)
	if not NetworkManager.is_connected_to_game() and SaveManager.has_save_file():
		# Wait another frame to ensure player is fully initialized
		await get_tree().process_frame
		SaveManager.load_game()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# CMD+W on macOS (meta key is Command) - close open windows
		if event.keycode == KEY_W and event.meta_pressed:
			if crafting_window and crafting_window.is_open:
				crafting_window.close()
				get_viewport().set_input_as_handled()
			elif box_inventory and box_inventory.is_open:
				box_inventory.close()
				get_viewport().set_input_as_handled()
