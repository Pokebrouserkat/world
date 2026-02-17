extends Control

## SandboxMenu - Quick tools panel for sandbox mode
## Toggle with the sandbox button (next to pause), only visible in sandbox mode

signal closed

var is_open: bool = false
var _noclip_enabled: bool = false

var button_texture: Texture2D = preload("res://graphics/button.png")

# UI elements created in code
var panel: NinePatchRect
var vbox: VBoxContainer
var title_label: Label
var dawn_button: Button
var day_button: Button
var dusk_button: Button
var night_button: Button
var tp_label: Label
var coord_container: HBoxContainer
var x_input: LineEdit
var y_input: LineEdit
var teleport_button: Button
var leave_mine_button: Button
var noclip_button: Button
var status_label: Label
var close_button: Button


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
    btn.add_theme_stylebox_override("disabled", _make_button_style(Color(0.5, 0.5, 0.5)))


func _ready() -> void:
    add_to_group("sandbox_menu")
    visible = false
    mouse_filter = Control.MOUSE_FILTER_STOP
    process_mode = Node.PROCESS_MODE_ALWAYS

    # Full-screen layout
    set_anchors_preset(Control.PRESET_FULL_RECT)

    # Semi-transparent background
    var bg = ColorRect.new()
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0, 0, 0, 0.5)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)

    # Panel (NinePatchRect centered)
    var window_tex = preload("res://graphics/windowtileset.png")
    panel = NinePatchRect.new()
    panel.process_mode = Node.PROCESS_MODE_ALWAYS
    panel.texture = window_tex
    panel.patch_margin_left = 16
    panel.patch_margin_right = 16
    panel.patch_margin_top = 16
    panel.patch_margin_bottom = 16
    panel.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
    panel.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
    panel.anchor_left = 0.5
    panel.anchor_top = 0.5
    panel.anchor_right = 0.5
    panel.anchor_bottom = 0.5
    panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
    panel.grow_vertical = Control.GROW_DIRECTION_BOTH
    add_child(panel)

    # VBoxContainer inside panel — use fit content so panel auto-sizes
    vbox = VBoxContainer.new()
    vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    vbox.offset_left = 10.0
    vbox.offset_top = 10.0
    vbox.offset_right = -10.0
    vbox.offset_bottom = -10.0
    panel.add_child(vbox)

    # Title
    title_label = Label.new()
    title_label.text = "Sandbox Tools"
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title_label)

    # --- Time section ---
    var time_label = Label.new()
    time_label.text = "Set Time"
    time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(time_label)

    var time_row1 = HBoxContainer.new()
    vbox.add_child(time_row1)
    dawn_button = Button.new()
    dawn_button.text = "Dawn"
    dawn_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    dawn_button.pressed.connect(_on_time_pressed.bind(0.0))
    time_row1.add_child(dawn_button)
    day_button = Button.new()
    day_button.text = "Day"
    day_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    day_button.pressed.connect(_on_time_pressed.bind(0.15))
    time_row1.add_child(day_button)

    var time_row2 = HBoxContainer.new()
    vbox.add_child(time_row2)
    dusk_button = Button.new()
    dusk_button.text = "Dusk"
    dusk_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    dusk_button.pressed.connect(_on_time_pressed.bind(0.55))
    time_row2.add_child(dusk_button)
    night_button = Button.new()
    night_button.text = "Night"
    night_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    night_button.pressed.connect(_on_time_pressed.bind(0.70))
    time_row2.add_child(night_button)

    # Separator
    vbox.add_child(HSeparator.new())

    # --- Teleport section (hidden in mines) ---
    tp_label = Label.new()
    tp_label.text = "Teleport"
    tp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(tp_label)

    coord_container = HBoxContainer.new()
    vbox.add_child(coord_container)

    x_input = LineEdit.new()
    x_input.placeholder_text = "X"
    x_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    x_input.add_theme_stylebox_override("normal", _make_button_style())
    x_input.add_theme_stylebox_override("focus", _make_button_style(Color(1.1, 1.1, 1.1)))
    coord_container.add_child(x_input)

    y_input = LineEdit.new()
    y_input.placeholder_text = "Y"
    y_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    y_input.add_theme_stylebox_override("normal", _make_button_style())
    y_input.add_theme_stylebox_override("focus", _make_button_style(Color(1.1, 1.1, 1.1)))
    coord_container.add_child(y_input)

    teleport_button = Button.new()
    teleport_button.text = "Go"
    teleport_button.pressed.connect(_on_teleport_pressed)
    vbox.add_child(teleport_button)

    # --- Leave mine button (hidden on surface) ---
    leave_mine_button = Button.new()
    leave_mine_button.text = "Leave Mine"
    leave_mine_button.pressed.connect(_on_leave_mine_pressed)
    vbox.add_child(leave_mine_button)

    # Separator
    vbox.add_child(HSeparator.new())

    # --- Noclip toggle ---
    noclip_button = Button.new()
    noclip_button.text = "Noclip: OFF"
    noclip_button.pressed.connect(_on_noclip_pressed)
    vbox.add_child(noclip_button)

    # Separator
    vbox.add_child(HSeparator.new())

    # Status label
    status_label = Label.new()
    status_label.text = ""
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(status_label)

    # Close button
    close_button = Button.new()
    close_button.text = "Close"
    close_button.pressed.connect(close)
    vbox.add_child(close_button)

    # Style all buttons
    for btn in [dawn_button, day_button, dusk_button, night_button, teleport_button, leave_mine_button, noclip_button, close_button]:
        _style_button(btn)

    # Connect sandbox button (sibling node) and hide both if not sandbox
    await get_tree().process_frame
    var sandbox_button = get_parent().get_node_or_null("SandboxButton")
    if sandbox_button:
        if GameMode.is_sandbox():
            sandbox_button.pressed.connect(open)
        else:
            sandbox_button.visible = false


func _update_layout() -> void:
    var world = get_tree().get_first_node_in_group("world")
    var in_mine = world and world.player_in_mine

    # Show teleport OR leave mine, not both
    tp_label.visible = not in_mine
    coord_container.visible = not in_mine
    teleport_button.visible = not in_mine
    leave_mine_button.visible = in_mine

    # Update noclip button text
    noclip_button.text = "Noclip: ON" if _noclip_enabled else "Noclip: OFF"

    # Size panel to fit content
    await get_tree().process_frame
    var content_height = vbox.get_combined_minimum_size().y + 20.0  # +20 for padding
    var half_h = content_height / 2.0
    panel.offset_top = -half_h
    panel.offset_bottom = half_h
    panel.offset_left = -120.0
    panel.offset_right = 120.0


func _input(event: InputEvent) -> void:
    if not is_open:
        return
    # ESC to close
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        close()
        get_viewport().set_input_as_handled()
        return
    # Click outside panel to close
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var mouse_pos = event.global_position
        if panel and not panel.get_global_rect().has_point(mouse_pos):
            close()
            get_viewport().set_input_as_handled()


func open() -> void:
    if is_open:
        return
    is_open = true
    visible = true
    get_tree().paused = true
    status_label.text = ""
    # Pre-fill coordinates with current player tile position
    var player = _get_local_player()
    if player:
        var tile_pos = Vector2i((player.global_position / 16.0).floor())
        x_input.text = str(tile_pos.x)
        y_input.text = str(tile_pos.y)
    _update_layout()


func close() -> void:
    if not is_open:
        return
    is_open = false
    visible = false
    get_tree().paused = false
    closed.emit()


func _on_time_pressed(time_ratio: float) -> void:
    var world = get_tree().get_first_node_in_group("world")
    if world:
        world.game_time = time_ratio * world.DAY_LENGTH
        var names = {0.0: "Dawn", 0.15: "Day", 0.55: "Dusk", 0.70: "Night"}
        status_label.text = "Time set to %s" % names.get(time_ratio, "???")


func _on_teleport_pressed() -> void:
    var x_text = x_input.text.strip_edges()
    var y_text = y_input.text.strip_edges()
    if not x_text.is_valid_int() or not y_text.is_valid_int():
        status_label.text = "Enter valid coordinates"
        return
    var x = x_text.to_int()
    var y = y_text.to_int()
    var player = _get_local_player()
    if not player:
        status_label.text = "No player found"
        return

    # Exit mine first if player is in one, to avoid corrupting mine state
    var world = get_tree().get_first_node_in_group("world")
    if world and world.player_in_mine:
        close()
        world.exit_mine()
        # Reopen after mine exit so teleport can proceed
        open()

    # Center on tile (tile * 16 + 8 for center)
    player.global_position = Vector2(x * 16.0 + 8.0, y * 16.0 + 8.0)
    status_label.text = "Teleported to %d, %d" % [x, y]


func _on_leave_mine_pressed() -> void:
    var world = get_tree().get_first_node_in_group("world")
    if world and world.player_in_mine:
        close()
        world.exit_mine()
        status_label.text = ""


func _on_noclip_pressed() -> void:
    _noclip_enabled = not _noclip_enabled
    var player = _get_local_player()
    if player:
        if _noclip_enabled:
            player.collision_mask = 0
        else:
            player.collision_mask = 1
    noclip_button.text = "Noclip: ON" if _noclip_enabled else "Noclip: OFF"
    status_label.text = "Noclip %s" % ("enabled" if _noclip_enabled else "disabled")


func _get_local_player() -> CharacterBody2D:
    var players = get_tree().get_nodes_in_group("player")
    for player in players:
        if player.is_local_player():
            return player
    return null
