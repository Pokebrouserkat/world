extends Control

signal closed

var hotbar: Node = null
var world: Node = null
var is_open: bool = false
var current_furnace_pos: Vector2i = Vector2i.ZERO

# UI elements
var panel: NinePatchRect = null
var input_slot: TextureButton = null
var output_slot: TextureButton = null
var input_icon: TextureRect = null
var output_icon: TextureRect = null
var input_stack_label: Label = null
var output_stack_label: Label = null
var progress_container: Control = null
var ore_sprite: TextureRect = null
var iron_sprite: TextureRect = null
var progress_mask: Control = null

# Textures
var slot_texture: Texture2D = preload("res://graphics/itemslot.png")
var window_bg: Texture2D = preload("res://graphics/windowtileset.png")
var iron_ore_texture: Texture2D = preload("res://graphics/ironore.png")
var iron_texture: Texture2D = preload("res://graphics/iron.png")

# Smelting state - stored per furnace in world.gd
const SMELT_TIME: float = 30.0

# Drag state
var dragging: bool = false
var drag_from_input: bool = false
var drag_from_output: bool = false
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
	var slot_size = slot_texture.get_width()
	var padding = 16
	var header_height = 20
	var panel_width = slot_size * 3 + padding * 2 + 8
	var panel_height = slot_size + header_height + padding * 2 + 8

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

	# Title label
	var title = Label.new()
	title.text = "Furnace"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 6)
	title.size = Vector2(panel_width, 14)
	panel.add_child(title)

	var content_y = header_height + padding

	# Input slot (left)
	input_slot = TextureButton.new()
	input_slot.texture_normal = slot_texture
	input_slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	input_slot.stretch_mode = TextureButton.STRETCH_KEEP
	input_slot.position = Vector2(padding, content_y)
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
	input_stack_label.add_theme_font_size_override("font_size", 8)
	input_stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	input_slot.add_child(input_stack_label)

	# Progress container (center) - shows ore transforming to iron
	progress_container = Control.new()
	progress_container.position = Vector2(padding + slot_size + 4, content_y)
	progress_container.size = Vector2(slot_size, slot_size)
	panel.add_child(progress_container)

	# Iron sprite (bottom layer - revealed as progress increases)
	iron_sprite = TextureRect.new()
	iron_sprite.texture = iron_texture
	iron_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	iron_sprite.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	iron_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	iron_sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
	progress_container.add_child(iron_sprite)

	# Ore sprite with clip (top layer - shrinks from bottom as progress increases)
	ore_sprite = TextureRect.new()
	ore_sprite.texture = iron_ore_texture
	ore_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ore_sprite.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	ore_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ore_sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
	ore_sprite.clip_contents = true
	progress_container.add_child(ore_sprite)

	# Output slot (right)
	output_slot = TextureButton.new()
	output_slot.texture_normal = slot_texture
	output_slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	output_slot.stretch_mode = TextureButton.STRETCH_KEEP
	output_slot.position = Vector2(padding + slot_size * 2 + 8, content_y)
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
	output_stack_label.add_theme_font_size_override("font_size", 8)
	output_stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	output_slot.add_child(output_stack_label)


func _process(delta: float) -> void:
	if not is_open or not world:
		return

	var state = world.get_furnace_state(current_furnace_pos)

	# Update smelting progress if there's input and room for output
	if state.input_item != null and state.input_item.name == "Iron Ore":
		var can_output = state.output_item == null or (state.output_item.name == "Iron" and state.output_item.quantity < 99)
		if can_output:
			state.smelt_progress += delta
			if state.smelt_progress >= SMELT_TIME:
				# Smelting complete
				state.smelt_progress = 0.0
				state.input_item.quantity -= 1
				if state.input_item.quantity <= 0:
					state.input_item = null

				if state.output_item == null:
					state.output_item = Item.create("Iron", iron_texture, 1)
				else:
					state.output_item.quantity += 1

				world.set_furnace_state(current_furnace_pos, state)
	else:
		state.smelt_progress = 0.0

	_update_ui(state)


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

	# Update progress visual - ore shrinks from bottom, iron shows underneath
	var progress = state.smelt_progress / SMELT_TIME
	var slot_size = slot_texture.get_width()

	# Show progress display only when actively smelting
	var is_smelting = state.input_item != null and state.input_item.name == "Iron Ore"
	progress_container.visible = is_smelting

	if is_smelting:
		# Ore sprite clips from bottom - position it up as progress increases
		var clip_height = slot_size * (1.0 - progress)
		ore_sprite.position.y = 0
		ore_sprite.size.y = clip_height


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
		drag_from_hotbar_slot = -1
		_create_drag_preview(state.output_item.texture, pos)
		output_icon.modulate.a = 0.3
		get_viewport().set_input_as_handled()
		return

	# Check hotbar slots
	var hotbar_slot = _get_hotbar_slot_at_position(pos)
	if hotbar_slot >= 0 and hotbar.get_item(hotbar_slot) != null:
		dragging = true
		drag_from_input = false
		drag_from_output = false
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

	if drag_from_hotbar_slot >= 0:
		# Dragging from hotbar
		var hotbar_item = hotbar.get_item(drag_from_hotbar_slot)
		if target_input and hotbar_item != null and hotbar_item.name == "Iron Ore":
			# Move to input slot
			if state.input_item == null:
				state.input_item = hotbar_item.duplicate()
				hotbar.set_item(drag_from_hotbar_slot, null)
			elif state.input_item.name == "Iron Ore" and state.input_item.quantity < 99:
				var can_add = 99 - state.input_item.quantity
				var to_add = mini(hotbar_item.quantity, can_add)
				state.input_item.quantity += to_add
				hotbar_item.quantity -= to_add
				if hotbar_item.quantity <= 0:
					hotbar.set_item(drag_from_hotbar_slot, null)
			world.set_furnace_state(current_furnace_pos, state)
			hotbar._update_item_icons()
		hotbar.item_icons[drag_from_hotbar_slot].modulate.a = 1.0

	elif drag_from_input:
		# Dragging from input
		if target_hotbar_slot >= 0:
			var hotbar_item = hotbar.get_item(target_hotbar_slot)
			if hotbar_item == null:
				hotbar.set_item(target_hotbar_slot, state.input_item)
				state.input_item = null
			elif hotbar_item.name == "Iron Ore" and hotbar_item.quantity < 99:
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
			elif hotbar_item.name == "Iron" and hotbar_item.quantity < 99:
				var can_add = 99 - hotbar_item.quantity
				var to_add = mini(state.output_item.quantity, can_add)
				hotbar_item.quantity += to_add
				state.output_item.quantity -= to_add
				if state.output_item.quantity <= 0:
					state.output_item = null
			world.set_furnace_state(current_furnace_pos, state)
			hotbar._update_item_icons()
		output_icon.modulate.a = 1.0

	_update_item_icons()

	# Clean up drag preview
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null

	dragging = false
	drag_from_input = false
	drag_from_output = false
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
		if drag_preview:
			drag_preview.queue_free()
			drag_preview = null
		dragging = false
		drag_from_input = false
		drag_from_output = false
		drag_from_hotbar_slot = -1

	closed.emit()
