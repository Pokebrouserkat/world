extends Control

## PauseMenu - Game pause menu with multiplayer and save file management
## Opened/closed with ESC key

signal resumed

var is_open: bool = false

var button_texture: Texture2D = preload("res://graphics/button.png")

# UI elements
@onready var title_label: Label = $Panel/VBoxContainer/Title
@onready var panel: NinePatchRect = $Panel
@onready var resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var multiplayer_section: VBoxContainer = $Panel/VBoxContainer/MultiplayerSection
@onready var host_button: Button = $Panel/VBoxContainer/MultiplayerSection/HostButton
@onready var join_container: HBoxContainer = $Panel/VBoxContainer/MultiplayerSection/JoinContainer
@onready var ip_input: LineEdit = $Panel/VBoxContainer/MultiplayerSection/JoinContainer/IPInput
@onready var join_button: Button = $Panel/VBoxContainer/MultiplayerSection/JoinContainer/JoinButton
@onready var disconnect_button: Button = $Panel/VBoxContainer/MultiplayerSection/DisconnectButton
@onready var status_label: Label = $Panel/VBoxContainer/MultiplayerSection/StatusLabel
@onready var save_section: VBoxContainer = $Panel/VBoxContainer/SaveSection
@onready var save_button: Button = $Panel/VBoxContainer/SaveSection/SaveButton
@onready var load_button: Button = $Panel/VBoxContainer/SaveSection/LoadButton
@onready var main_menu_button: Button = $Panel/VBoxContainer/MainMenuButton
@onready var quit_button: Button = $Panel/VBoxContainer/QuitButton


func _make_button_style(modulate_color: Color = Color.WHITE) -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	style.texture = button_texture
	style.texture_margin_left = 4
	style.texture_margin_right = 4
	style.texture_margin_top = 4
	style.texture_margin_bottom = 4
	style.modulate_color = modulate_color
	return style


func _style_buttons() -> void:
	var buttons: Array[Button] = [
		resume_button, host_button, join_button, disconnect_button,
		save_button, load_button, main_menu_button, quit_button
	]
	for btn in buttons:
		btn.add_theme_stylebox_override("normal", _make_button_style())
		btn.add_theme_stylebox_override("hover", _make_button_style(Color(1.2, 1.2, 1.2)))
		btn.add_theme_stylebox_override("pressed", _make_button_style(Color(0.8, 0.8, 0.8)))
		btn.add_theme_stylebox_override("disabled", _make_button_style(Color(0.5, 0.5, 0.5)))

	# Style the IP input field too
	var input_style = _make_button_style()
	ip_input.add_theme_stylebox_override("normal", input_style)
	ip_input.add_theme_stylebox_override("focus", _make_button_style(Color(1.1, 1.1, 1.1)))


func _ready() -> void:
	add_to_group("pause_menu")
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Connect button signals
	resume_button.pressed.connect(_on_resume_pressed)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)
	ip_input.text_submitted.connect(_on_ip_submitted)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Connect network signals
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)

	# Set default IP
	ip_input.text = "127.0.0.1"

	# Apply button styling
	_style_buttons()

	# Connect pause button if it exists (sibling node)
	await get_tree().process_frame
	var pause_button = get_parent().get_node_or_null("PauseButton")
	if pause_button:
		pause_button.pressed.connect(open)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# Don't intercept Escape if another window is open - let them handle it
		var furnace = get_tree().get_first_node_in_group("furnace_inventory")
		var box = get_tree().get_first_node_in_group("box_inventory")
		var crafting = get_tree().get_first_node_in_group("crafting_window")
		if (furnace and furnace.is_open) or (box and box.is_open) or (crafting and crafting.is_open):
			return

		if is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()

	# Handle clicks while paused (buttons don't receive GUI input properly when paused)
	if is_open and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = event.global_position
		if quit_button.get_global_rect().has_point(mouse_pos):
			_on_quit_pressed()
			return
		elif resume_button.get_global_rect().has_point(mouse_pos):
			_on_resume_pressed()
			get_viewport().set_input_as_handled()
		elif save_button.get_global_rect().has_point(mouse_pos):
			_on_save_pressed()
			get_viewport().set_input_as_handled()
		elif load_button.get_global_rect().has_point(mouse_pos):
			_on_load_pressed()
			get_viewport().set_input_as_handled()
		elif host_button.visible and host_button.get_global_rect().has_point(mouse_pos):
			_on_host_pressed()
			get_viewport().set_input_as_handled()
		elif join_button.visible and join_button.get_global_rect().has_point(mouse_pos):
			_on_join_pressed()
			get_viewport().set_input_as_handled()
		elif disconnect_button.visible and disconnect_button.get_global_rect().has_point(mouse_pos):
			_on_disconnect_pressed()
			get_viewport().set_input_as_handled()
		elif main_menu_button.get_global_rect().has_point(mouse_pos):
			_on_main_menu_pressed()
			return
		elif panel and not panel.get_global_rect().has_point(mouse_pos):
			# Click outside panel to close
			close()
			get_viewport().set_input_as_handled()


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	get_tree().paused = true
	title_label.text = "Paused (Sandbox)" if GameMode.is_sandbox() else "Paused"
	_update_ui()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_tree().paused = false
	resumed.emit()


func _on_resume_pressed() -> void:
	close()


func _on_host_pressed() -> void:
	var error = NetworkManager.host_game()
	if error == OK:
		status_label.text = "Hosting on port %d" % NetworkManager.DEFAULT_PORT
	else:
		status_label.text = "Failed to host: %s" % error_string(error)
	_update_ui()


func _on_join_pressed() -> void:
	var ip = ip_input.text.strip_edges()
	if ip.is_empty():
		status_label.text = "Enter IP address"
		return

	var error = NetworkManager.join_game(ip)
	if error == OK:
		status_label.text = "Connecting to %s..." % ip
	else:
		status_label.text = "Failed to connect: %s" % error_string(error)
	_update_ui()


func _on_ip_submitted(_text: String) -> void:
	_on_join_pressed()


func _on_disconnect_pressed() -> void:
	NetworkManager.disconnect_game()
	status_label.text = "Disconnected"
	_update_ui()


func _on_save_pressed() -> void:
	if SaveManager.save_game():
		status_label.text = "Game saved!"
	else:
		status_label.text = "Save failed!"


func _on_load_pressed() -> void:
	if SaveManager.load_game():
		status_label.text = "Game loaded!"
		close()
	else:
		status_label.text = "Load failed!"


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_player_connected(peer_id: int) -> void:
	if is_open:
		var count = NetworkManager.get_connected_peers().size()
		status_label.text = "%d player(s) connected" % count


func _on_player_disconnected(peer_id: int) -> void:
	if is_open:
		var count = NetworkManager.get_connected_peers().size()
		status_label.text = "%d player(s) connected" % count


func _on_connection_succeeded() -> void:
	status_label.text = "Connected!"
	_update_ui()


func _on_connection_failed() -> void:
	status_label.text = "Connection failed"
	_update_ui()


func _on_server_disconnected() -> void:
	status_label.text = "Server disconnected"
	_update_ui()


func _update_ui() -> void:
	var connected = NetworkManager.is_connected_to_game()
	host_button.visible = not connected
	join_container.visible = not connected
	disconnect_button.visible = connected

	# Only host can save/load in multiplayer
	var can_save = not connected or NetworkManager.is_host()
	save_button.disabled = not can_save
	load_button.disabled = not can_save

	# Update status label based on connection state
	if connected:
		if NetworkManager.is_host():
			status_label.text = "Hosting (%d players)" % NetworkManager.get_connected_peers().size()
		else:
			status_label.text = "Connected as client"
	else:
		# Show save status when not connected
		_update_save_status()


func _update_save_status() -> void:
	var last_save = SaveManager.get_last_save_time()
	if last_save == 0:
		if SaveManager.has_save_file():
			status_label.text = "Save file exists"
		else:
			status_label.text = "No save file"
	else:
		var now = Time.get_unix_time_from_system()
		var elapsed = now - last_save
		if elapsed < 60:
			status_label.text = "Saved just now"
		elif elapsed < 3600:
			var minutes = int(elapsed / 60)
			status_label.text = "Saved %d min ago" % minutes
		else:
			var hours = int(elapsed / 3600)
			status_label.text = "Saved %d hr ago" % hours
