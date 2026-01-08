extends Control

## NetworkUI - Simple LAN multiplayer connection interface
## Shows Host/Join buttons, allows entering IP address

@onready var host_button: Button = $Panel/VBoxContainer/HostButton
@onready var join_container: HBoxContainer = $Panel/VBoxContainer/JoinContainer
@onready var ip_input: LineEdit = $Panel/VBoxContainer/JoinContainer/IPInput
@onready var join_button: Button = $Panel/VBoxContainer/JoinContainer/JoinButton
@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel
@onready var disconnect_button: Button = $Panel/VBoxContainer/DisconnectButton


func _ready() -> void:
    # Connect UI signals
    host_button.pressed.connect(_on_host_pressed)
    join_button.pressed.connect(_on_join_pressed)
    disconnect_button.pressed.connect(_on_disconnect_pressed)
    ip_input.text_submitted.connect(_on_ip_submitted)

    # Connect network signals
    NetworkManager.player_connected.connect(_on_player_connected)
    NetworkManager.player_disconnected.connect(_on_player_disconnected)
    NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
    NetworkManager.connection_failed.connect(_on_connection_failed)
    NetworkManager.server_disconnected.connect(_on_server_disconnected)

    # Set default IP
    ip_input.text = "127.0.0.1"

    # Initial state
    _update_ui()


func _input(event: InputEvent) -> void:
    # Toggle visibility with ESC (only when connected)
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        if NetworkManager.is_connected_to_game():
            visible = not visible
        else:
            visible = true


func _on_host_pressed() -> void:
    var error = NetworkManager.host_game()
    if error == OK:
        status_label.text = "Hosting on port %d" % NetworkManager.DEFAULT_PORT
        _update_ui()
    else:
        status_label.text = "Failed to host: %s" % error_string(error)


func _on_join_pressed() -> void:
    var ip = ip_input.text.strip_edges()
    if ip.is_empty():
        status_label.text = "Enter IP address"
        return

    var error = NetworkManager.join_game(ip)
    if error == OK:
        status_label.text = "Connecting to %s..." % ip
        _update_ui()
    else:
        status_label.text = "Failed to connect: %s" % error_string(error)


func _on_ip_submitted(_text: String) -> void:
    _on_join_pressed()


func _on_disconnect_pressed() -> void:
    NetworkManager.disconnect_game()
    status_label.text = "Disconnected"
    _update_ui()


func _on_player_connected(peer_id: int) -> void:
    var count = NetworkManager.get_connected_peers().size()
    status_label.text = "%d player(s) connected" % count


func _on_player_disconnected(peer_id: int) -> void:
    var count = NetworkManager.get_connected_peers().size()
    status_label.text = "%d player(s) connected" % count


func _on_connection_succeeded() -> void:
    status_label.text = "Connected!"
    _update_ui()
    # Auto-hide after successful connection
    await get_tree().create_timer(1.0).timeout
    visible = false


func _on_connection_failed() -> void:
    status_label.text = "Connection failed"
    _update_ui()


func _on_server_disconnected() -> void:
    status_label.text = "Server disconnected"
    _update_ui()
    visible = true


func _update_ui() -> void:
    var connected = NetworkManager.is_connected_to_game()
    host_button.visible = not connected
    join_container.visible = not connected
    disconnect_button.visible = connected

    if connected:
        if NetworkManager.is_host():
            status_label.text = "Hosting (%d players)" % NetworkManager.get_connected_peers().size()
        else:
            status_label.text = "Connected as client"
