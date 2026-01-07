extends Node

var crafting_window: Control = null
var quit_dialog: ConfirmationDialog = null


func _ready() -> void:
	await get_tree().process_frame
	crafting_window = get_tree().get_first_node_in_group("crafting_window")
	_create_quit_dialog()


func _create_quit_dialog() -> void:
	quit_dialog = ConfirmationDialog.new()
	quit_dialog.title = "Quit Game"
	quit_dialog.dialog_text = "Are you sure you want to quit?"
	quit_dialog.ok_button_text = "Quit"
	quit_dialog.cancel_button_text = "Cancel"
	quit_dialog.confirmed.connect(_on_quit_confirmed)
	quit_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	add_child(quit_dialog)


func _on_quit_confirmed() -> void:
	get_tree().quit()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# CMD+W on macOS (meta key is Command)
		if event.keycode == KEY_W and event.meta_pressed:
			get_viewport().set_input_as_handled()
			_handle_close_action()


func _handle_close_action() -> void:
	# First check if crafting window is open
	if crafting_window and crafting_window.is_open:
		crafting_window.close()
	else:
		# Show quit confirmation
		quit_dialog.popup_centered()
