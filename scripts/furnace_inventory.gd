extends Control

signal closed

var hotbar: Node = null
var world: Node = null
var is_open: bool = false
var current_furnace_pos: Vector2i = Vector2i.ZERO

# UI elements
var panel: NinePatchRect = null
var title_label: Label = null
var input_slot: TextureButton = null
var output_slot: TextureButton = null
var fuel_slot: TextureButton = null
var input_icon: TextureRect = null
var output_icon: TextureRect = null
var fuel_icon: TextureRect = null
var input_stack_label: Label = null
var output_stack_label: Label = null
var fuel_stack_label: Label = null
var arrow_icon: TextureRect = null
var fuel_label: Label = null
var progress_bar_bg: ColorRect = null
var progress_bar_fill: ColorRect = null
var progress_label: Label = null

# Textures
var slot_texture: Texture2D = preload("res://graphics/itemslot.png")
var window_bg: Texture2D = preload("res://graphics/windowtileset.png")
var arrow_texture: Texture2D = preload("res://graphics/arrow.png")

# Smelting state - stored per furnace in world.gd
const SMELT_TIME: float = 30.0

# Smelting recipes: input_id -> output_id
const SMELT_RECIPES: Dictionary = {
    "iron_ore": "iron",
    "gold_ore": "gold"
}

# Fuel values: how many smelts one item provides
const FUEL_VALUES: Dictionary = {
    "coal": 5.0,
    "wood": 0.05
}

# Drag state
var dragging: bool = false
var drag_from_input: bool = false
var drag_from_output: bool = false
var drag_from_fuel: bool = false
var drag_from_hotbar_slot: int = -1
var drag_preview: TextureRect = null


func _ready() -> void:
    add_to_group("furnace_inventory")
    visible = false
    mouse_filter = Control.MOUSE_FILTER_STOP

    _create_ui()

    await get_tree().process_frame
    hotbar = get_tree().get_first_node_in_group("hotbar")
    world = get_tree().get_first_node_in_group("world")


func _create_ui() -> void:
    var slot_size = 32  # 2x scale for readability
    var border = 12
    var arrow_width = 24
    var progress_height = 12
    var title_height = 16
    var fuel_label_height = 12
    var spacing = 4

    var slot_row_width = slot_size * 2 + arrow_width
    var panel_width = slot_row_width + border * 2
    var panel_height = border + title_height + spacing + slot_size + spacing + fuel_label_height + slot_size + spacing + progress_height + border

    # Main panel
    panel = NinePatchRect.new()
    panel.texture = window_bg
    panel.patch_margin_left = 16
    panel.patch_margin_right = 16
    panel.patch_margin_top = 16
    panel.patch_margin_bottom = 16
    panel.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
    panel.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
    panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.custom_minimum_size = Vector2(panel_width, panel_height)
    panel.size = Vector2(panel_width, panel_height)
    panel.position = -panel.size / 2
    add_child(panel)

    var y_cursor = border

    # Title label
    title_label = Label.new()
    title_label.text = "Furnace"
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.position = Vector2(0, y_cursor)
    title_label.size = Vector2(panel_width, title_height)
    title_label.add_theme_font_size_override("font_size", 12)
    title_label.add_theme_color_override("font_color", Color.WHITE)
    title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(title_label)
    y_cursor += title_height + spacing

    # === Row 1: Input slot + arrow + output slot ===
    var row1_y = y_cursor

    # Input slot (left)
    input_slot = TextureButton.new()
    input_slot.texture_normal = slot_texture
    input_slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    input_slot.ignore_texture_size = true
    input_slot.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
    input_slot.custom_minimum_size = Vector2(slot_size, slot_size)
    input_slot.size = Vector2(slot_size, slot_size)
    input_slot.position = Vector2(border, row1_y)
    panel.add_child(input_slot)

    input_icon = TextureRect.new()
    input_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    input_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
    input_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    input_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
    input_slot.add_child(input_icon)

    input_stack_label = Label.new()
    input_stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    input_stack_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
    input_stack_label.set_anchors_preset(Control.PRESET_FULL_RECT)
    input_stack_label.add_theme_font_size_override("font_size", 10)
    input_stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    input_slot.add_child(input_stack_label)

    # Arrow between slots
    arrow_icon = TextureRect.new()
    arrow_icon.texture = arrow_texture
    arrow_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    arrow_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
    arrow_icon.position = Vector2(border + slot_size, row1_y)
    arrow_icon.size = Vector2(arrow_width, slot_size)
    arrow_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(arrow_icon)

    # Output slot (right)
    output_slot = TextureButton.new()
    output_slot.texture_normal = slot_texture
    output_slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    output_slot.ignore_texture_size = true
    output_slot.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
    output_slot.custom_minimum_size = Vector2(slot_size, slot_size)
    output_slot.size = Vector2(slot_size, slot_size)
    output_slot.position = Vector2(border + slot_size + arrow_width, row1_y)
    panel.add_child(output_slot)

    output_icon = TextureRect.new()
    output_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    output_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
    output_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    output_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
    output_slot.add_child(output_icon)

    output_stack_label = Label.new()
    output_stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    output_stack_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
    output_stack_label.set_anchors_preset(Control.PRESET_FULL_RECT)
    output_stack_label.add_theme_font_size_override("font_size", 10)
    output_stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    output_slot.add_child(output_stack_label)

    y_cursor += slot_size + spacing

    # === Row 2: Fuel label + fuel slot (below input slot) ===
    fuel_label = Label.new()
    fuel_label.text = "Fuel"
    fuel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    fuel_label.position = Vector2(0, y_cursor)
    fuel_label.size = Vector2(panel_width, fuel_label_height)
    fuel_label.add_theme_font_size_override("font_size", 10)
    fuel_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
    fuel_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(fuel_label)
    y_cursor += fuel_label_height

    fuel_slot = TextureButton.new()
    fuel_slot.texture_normal = slot_texture
    fuel_slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    fuel_slot.ignore_texture_size = true
    fuel_slot.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
    fuel_slot.custom_minimum_size = Vector2(slot_size, slot_size)
    fuel_slot.size = Vector2(slot_size, slot_size)
    fuel_slot.position = Vector2(border, y_cursor)
    panel.add_child(fuel_slot)

    fuel_icon = TextureRect.new()
    fuel_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    fuel_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
    fuel_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    fuel_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
    fuel_slot.add_child(fuel_icon)

    fuel_stack_label = Label.new()
    fuel_stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    fuel_stack_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
    fuel_stack_label.set_anchors_preset(Control.PRESET_FULL_RECT)
    fuel_stack_label.add_theme_font_size_override("font_size", 10)
    fuel_stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    fuel_slot.add_child(fuel_stack_label)

    y_cursor += slot_size + spacing

    # === Progress bar (full width) ===
    progress_bar_bg = ColorRect.new()
    progress_bar_bg.color = Color(0.2, 0.2, 0.2, 1.0)
    progress_bar_bg.position = Vector2(border, y_cursor)
    progress_bar_bg.size = Vector2(slot_row_width, progress_height)
    panel.add_child(progress_bar_bg)

    progress_bar_fill = ColorRect.new()
    progress_bar_fill.color = Color(0.8, 0.5, 0.2, 1.0)  # Orange for smelting
    progress_bar_fill.position = Vector2(border, y_cursor)
    progress_bar_fill.size = Vector2(0, progress_height)
    panel.add_child(progress_bar_fill)

    progress_label = Label.new()
    progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    progress_label.position = Vector2(border, y_cursor)
    progress_label.size = Vector2(slot_row_width, progress_height)
    progress_label.add_theme_font_size_override("font_size", 10)
    progress_label.add_theme_color_override("font_color", Color.WHITE)
    panel.add_child(progress_label)


func _process(delta: float) -> void:
    if not is_open or not world:
        return

    var state = world.get_furnace_state(current_furnace_pos)

    # Update smelting progress if there's input and room for output
    var smelt_output_id = _get_smelt_output(state.input_item)
    if smelt_output_id != "":
        var can_output = state.output_item == null or (state.output_item.item_id == smelt_output_id and state.output_item.quantity < 99)
        if can_output:
            # Check fuel
            if state.get("fuel_level", 0.0) <= 0.0:
                _try_consume_fuel(state)

            if state.get("fuel_level", 0.0) > 0.0:
                # Consume fuel proportionally
                state.fuel_level -= delta / SMELT_TIME
                state.smelt_progress += delta

                if state.smelt_progress >= SMELT_TIME:
                    # Smelting complete
                    state.smelt_progress = 0.0
                    state.input_item.quantity -= 1
                    if state.input_item.quantity <= 0:
                        state.input_item = null

                    if state.output_item == null:
                        state.output_item = Item.create(smelt_output_id, 1)
                    else:
                        state.output_item.quantity += 1

                    world.set_furnace_state(current_furnace_pos, state)
            # else: no fuel, smelting pauses (progress doesn't reset)
    else:
        state.smelt_progress = 0.0

    _update_ui(state)


func _get_smelt_output(input_item) -> String:
    if input_item == null:
        return ""
    return SMELT_RECIPES.get(input_item.item_id, "")


func _is_smeltable(item_id: String) -> bool:
    return SMELT_RECIPES.has(item_id)


func _is_fuel(item_id: String) -> bool:
    return FUEL_VALUES.has(item_id)


func _get_fuel_value(item_id: String) -> float:
    return FUEL_VALUES.get(item_id, 0.0)


func _try_consume_fuel(state: Dictionary) -> void:
    var fuel_item = state.get("fuel_item")
    if fuel_item == null:
        return
    var fuel_value = _get_fuel_value(fuel_item.item_id)
    if fuel_value <= 0.0:
        return
    state.fuel_level = fuel_value
    fuel_item.quantity -= 1
    if fuel_item.quantity <= 0:
        state.fuel_item = null


func _update_ui(state: Dictionary) -> void:
    # Update input slot
    if state.input_item != null:
        input_icon.texture = state.input_item.texture
        input_stack_label.text = str(state.input_item.quantity) if state.input_item.quantity > 1 else ""
    else:
        input_icon.texture = null
        input_stack_label.text = ""

    # Update output slot
    if state.output_item != null:
        output_icon.texture = state.output_item.texture
        output_stack_label.text = str(state.output_item.quantity) if state.output_item.quantity > 1 else ""
    else:
        output_icon.texture = null
        output_stack_label.text = ""

    # Update fuel slot
    var fuel_item = state.get("fuel_item")
    if fuel_item != null:
        fuel_icon.texture = fuel_item.texture
        fuel_stack_label.text = str(fuel_item.quantity) if fuel_item.quantity > 1 else ""
    else:
        fuel_icon.texture = null
        fuel_stack_label.text = ""

    # Update progress bar
    var smelt_out = _get_smelt_output(state.input_item)
    var is_smelting = smelt_out != ""
    var can_output = state.output_item == null or (is_smelting and state.output_item.item_id == smelt_out and state.output_item.quantity < 99)
    var has_fuel = state.get("fuel_level", 0.0) > 0.0 or (state.get("fuel_item") != null and _get_fuel_value(state.fuel_item.item_id) > 0.0)

    if is_smelting and can_output and has_fuel:
        var progress = state.smelt_progress / SMELT_TIME
        var bar_width = progress_bar_bg.size.x * progress
        progress_bar_fill.size.x = bar_width

        var time_remaining = SMELT_TIME - state.smelt_progress
        progress_label.text = "%ds" % int(ceil(time_remaining))
        progress_bar_fill.visible = true
    else:
        progress_bar_fill.size.x = 0
        progress_bar_fill.visible = false
        if state.input_item == null:
            progress_label.text = "Add ore"
        elif not is_smelting:
            progress_label.text = "Wrong item"
        elif not can_output:
            progress_label.text = "Output full"
        elif not has_fuel:
            progress_label.text = "Add fuel"
        else:
            progress_label.text = ""


func _update_item_icons() -> void:
    if not world:
        return
    var state = world.get_furnace_state(current_furnace_pos)
    _update_ui(state)


func _input(event: InputEvent) -> void:
    if not is_open:
        return

    # Close on Escape or C
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_ESCAPE:
            close()
            get_viewport().set_input_as_handled()
            return
        elif event.keycode == KEY_C and not event.ctrl_pressed and not event.meta_pressed:
            close()
            get_viewport().set_input_as_handled()
            return
        elif event.keycode == KEY_W and event.meta_pressed:
            close()
            get_viewport().set_input_as_handled()
            return

    # Handle drag and drop
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                if not _is_point_in_panel(event.global_position) and not _is_point_in_hotbar(event.global_position):
                    close()
                    get_viewport().set_input_as_handled()
                    return
                _start_drag(event.global_position)
            else:
                _end_drag(event.global_position)
        elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            if not _is_point_in_panel(event.global_position) and not _is_point_in_hotbar(event.global_position):
                close()
                get_viewport().set_input_as_handled()

    if event is InputEventMouseMotion and dragging:
        _update_drag(event.global_position)


func _is_point_in_panel(global_pos: Vector2) -> bool:
    if panel:
        return panel.get_global_rect().has_point(global_pos)
    return false


func _is_point_in_hotbar(global_pos: Vector2) -> bool:
    return _get_hotbar_slot_at_position(global_pos) >= 0


func _start_drag(pos: Vector2) -> void:
    if not world:
        return

    var state = world.get_furnace_state(current_furnace_pos)

    # Check input slot
    if input_slot.get_global_rect().has_point(pos) and state.input_item != null:
        dragging = true
        drag_from_input = true
        drag_from_output = false
        drag_from_fuel = false
        drag_from_hotbar_slot = -1
        _create_drag_preview(state.input_item.texture, pos)
        input_icon.modulate.a = 0.3
        get_viewport().set_input_as_handled()
        return

    # Check output slot
    if output_slot.get_global_rect().has_point(pos) and state.output_item != null:
        dragging = true
        drag_from_input = false
        drag_from_output = true
        drag_from_fuel = false
        drag_from_hotbar_slot = -1
        _create_drag_preview(state.output_item.texture, pos)
        output_icon.modulate.a = 0.3
        get_viewport().set_input_as_handled()
        return

    # Check fuel slot
    var fuel_item = state.get("fuel_item")
    if fuel_slot.get_global_rect().has_point(pos) and fuel_item != null:
        dragging = true
        drag_from_input = false
        drag_from_output = false
        drag_from_fuel = true
        drag_from_hotbar_slot = -1
        _create_drag_preview(fuel_item.texture, pos)
        fuel_icon.modulate.a = 0.3
        get_viewport().set_input_as_handled()
        return

    # Check hotbar slots
    var hotbar_slot = _get_hotbar_slot_at_position(pos)
    if hotbar_slot >= 0 and hotbar.get_item(hotbar_slot) != null:
        dragging = true
        drag_from_input = false
        drag_from_output = false
        drag_from_fuel = false
        drag_from_hotbar_slot = hotbar_slot
        _create_drag_preview(hotbar.get_item(hotbar_slot).texture, pos)
        hotbar.item_icons[hotbar_slot].modulate.a = 0.3
        get_viewport().set_input_as_handled()


func _create_drag_preview(texture: Texture2D, pos: Vector2) -> void:
    drag_preview = TextureRect.new()
    drag_preview.texture = texture
    drag_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
    drag_preview.modulate.a = 0.7
    get_parent().add_child(drag_preview)
    drag_preview.position = pos - drag_preview.size / 2


func _update_drag(pos: Vector2) -> void:
    if drag_preview:
        drag_preview.position = pos - drag_preview.size / 2


func _end_drag(pos: Vector2) -> void:
    if not dragging or not world:
        return

    var state = world.get_furnace_state(current_furnace_pos)
    var target_hotbar_slot = _get_hotbar_slot_at_position(pos)
    var target_input = input_slot.get_global_rect().has_point(pos)
    var target_output = output_slot.get_global_rect().has_point(pos)
    var target_fuel = fuel_slot.get_global_rect().has_point(pos)

    if drag_from_hotbar_slot >= 0:
        # Dragging from hotbar
        var hotbar_item = hotbar.get_item(drag_from_hotbar_slot)
        if target_input and hotbar_item != null and _is_smeltable(hotbar_item.item_id):
            # Move to input slot
            if state.input_item == null:
                state.input_item = hotbar_item.duplicate()
                hotbar.set_item(drag_from_hotbar_slot, null)
            elif state.input_item.item_id == hotbar_item.item_id and state.input_item.quantity < 99:
                var can_add = 99 - state.input_item.quantity
                var to_add = mini(hotbar_item.quantity, can_add)
                state.input_item.quantity += to_add
                hotbar_item.quantity -= to_add
                if hotbar_item.quantity <= 0:
                    hotbar.set_item(drag_from_hotbar_slot, null)
            world.set_furnace_state(current_furnace_pos, state)
            hotbar._update_item_icons()
        elif target_fuel and hotbar_item != null and _is_fuel(hotbar_item.item_id):
            # Move to fuel slot
            var current_fuel = state.get("fuel_item")
            if current_fuel == null:
                state.fuel_item = hotbar_item.duplicate()
                hotbar.set_item(drag_from_hotbar_slot, null)
            elif current_fuel.item_id == hotbar_item.item_id and current_fuel.quantity < 99:
                var can_add = 99 - current_fuel.quantity
                var to_add = mini(hotbar_item.quantity, can_add)
                current_fuel.quantity += to_add
                hotbar_item.quantity -= to_add
                if hotbar_item.quantity <= 0:
                    hotbar.set_item(drag_from_hotbar_slot, null)
            world.set_furnace_state(current_furnace_pos, state)
            hotbar._update_item_icons()
        elif target_hotbar_slot >= 0 and target_hotbar_slot != drag_from_hotbar_slot:
            # Hotbar to hotbar transfer (reorganization)
            var source_item = hotbar.get_item(drag_from_hotbar_slot)
            var target_item = hotbar.get_item(target_hotbar_slot)
            if target_item != null and source_item != null and target_item.can_stack_with(source_item):
                var leftover = target_item.add_quantity(source_item.quantity)
                if leftover == 0:
                    hotbar.set_item(drag_from_hotbar_slot, null)
                else:
                    source_item.quantity = leftover
            else:
                hotbar.set_item(target_hotbar_slot, source_item)
                hotbar.set_item(drag_from_hotbar_slot, target_item)
            hotbar._update_item_icons()
        hotbar.item_icons[drag_from_hotbar_slot].modulate.a = 1.0

    elif drag_from_input:
        # Dragging from input
        if target_hotbar_slot >= 0:
            var hotbar_item = hotbar.get_item(target_hotbar_slot)
            if hotbar_item == null:
                hotbar.set_item(target_hotbar_slot, state.input_item)
                state.input_item = null
            elif state.input_item != null and hotbar_item.item_id == state.input_item.item_id and hotbar_item.quantity < 99:
                var can_add = 99 - hotbar_item.quantity
                var to_add = mini(state.input_item.quantity, can_add)
                hotbar_item.quantity += to_add
                state.input_item.quantity -= to_add
                if state.input_item.quantity <= 0:
                    state.input_item = null
            world.set_furnace_state(current_furnace_pos, state)
            hotbar._update_item_icons()
        input_icon.modulate.a = 1.0

    elif drag_from_output:
        # Dragging from output
        if target_hotbar_slot >= 0:
            var hotbar_item = hotbar.get_item(target_hotbar_slot)
            if hotbar_item == null:
                hotbar.set_item(target_hotbar_slot, state.output_item)
                state.output_item = null
            elif state.output_item != null and hotbar_item.item_id == state.output_item.item_id and hotbar_item.quantity < 99:
                var can_add = 99 - hotbar_item.quantity
                var to_add = mini(state.output_item.quantity, can_add)
                hotbar_item.quantity += to_add
                state.output_item.quantity -= to_add
                if state.output_item.quantity <= 0:
                    state.output_item = null
            world.set_furnace_state(current_furnace_pos, state)
            hotbar._update_item_icons()
        output_icon.modulate.a = 1.0

    elif drag_from_fuel:
        # Dragging from fuel
        if target_hotbar_slot >= 0:
            var fuel_item = state.get("fuel_item")
            var hotbar_item = hotbar.get_item(target_hotbar_slot)
            if hotbar_item == null:
                hotbar.set_item(target_hotbar_slot, fuel_item)
                state.fuel_item = null
            elif fuel_item != null and hotbar_item.item_id == fuel_item.item_id and hotbar_item.quantity < 99:
                var can_add = 99 - hotbar_item.quantity
                var to_add = mini(fuel_item.quantity, can_add)
                hotbar_item.quantity += to_add
                fuel_item.quantity -= to_add
                if fuel_item.quantity <= 0:
                    state.fuel_item = null
            world.set_furnace_state(current_furnace_pos, state)
            hotbar._update_item_icons()
        fuel_icon.modulate.a = 1.0

    _update_item_icons()

    # Clean up drag preview
    if drag_preview:
        drag_preview.queue_free()
        drag_preview = null

    dragging = false
    drag_from_input = false
    drag_from_output = false
    drag_from_fuel = false
    drag_from_hotbar_slot = -1


func _get_hotbar_slot_at_position(global_pos: Vector2) -> int:
    if not hotbar:
        return -1
    for i in range(hotbar.slots.size()):
        var slot = hotbar.slots[i]
        var rect = slot.get_global_rect()
        if rect.has_point(global_pos):
            return i
    return -1


func open_for_furnace(furnace_pos: Vector2i) -> void:
    if is_open:
        return
    current_furnace_pos = furnace_pos
    is_open = true
    visible = true
    _update_item_icons()


func close() -> void:
    if not is_open:
        return
    is_open = false
    visible = false

    # Clean up any ongoing drag
    if dragging:
        if drag_from_hotbar_slot >= 0:
            hotbar.item_icons[drag_from_hotbar_slot].modulate.a = 1.0
        elif drag_from_input:
            input_icon.modulate.a = 1.0
        elif drag_from_output:
            output_icon.modulate.a = 1.0
        elif drag_from_fuel:
            fuel_icon.modulate.a = 1.0
        if drag_preview:
            drag_preview.queue_free()
            drag_preview = null
        dragging = false
        drag_from_input = false
        drag_from_output = false
        drag_from_fuel = false
        drag_from_hotbar_slot = -1

    closed.emit()
