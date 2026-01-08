extends Control

signal closed

var hotbar: Node = null
var world: Node = null
var is_open: bool = false
var current_box_pos: Vector2i = Vector2i.ZERO

# UI elements
var panel: NinePatchRect = null
var slot_container: GridContainer = null
var slots: Array[TextureButton] = []
var item_icons: Array[TextureRect] = []
var stack_labels: Array[Label] = []

const SLOT_COUNT: int = 9
const GRID_COLS: int = 3

# Textures
var slot_texture: Texture2D = preload("res://graphics/itemslot.png")
var window_bg: Texture2D = preload("res://graphics/windowtileset.png")

# Drag state
var dragging: bool = false
var drag_from_slot: int = -1
var drag_from_hotbar: bool = false
var drag_preview: TextureRect = null


func _ready() -> void:
	add_to_group("box_inventory")
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	_create_ui()

	# Find hotbar and world
	await get_tree().process_frame
	hotbar = get_tree().get_first_node_in_group("hotbar")
	world = get_tree().get_first_node_in_group("world")


func _create_ui() -> void:
	# Calculate sizes
	var slot_size = slot_texture.get_width()
	var slot_spacing = 2
	var grid_size = GRID_COLS * slot_size + (GRID_COLS - 1) * slot_spacing
	var padding = 16
	var header_height = 20
	var panel_width = grid_size + padding * 2
	var panel_height = grid_size + header_height + padding * 2

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
	title.text = "Box"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 6)
	title.size = Vector2(panel_width, 14)
	panel.add_child(title)

	# Slot grid container
	slot_container = GridContainer.new()
	slot_container.columns = GRID_COLS
	slot_container.add_theme_constant_override("h_separation", slot_spacing)
	slot_container.add_theme_constant_override("v_separation", slot_spacing)
	slot_container.position = Vector2(padding, header_height + padding)
	panel.add_child(slot_container)

	# Create slots
	for i in range(SLOT_COUNT):
		var slot = TextureButton.new()
		slot.texture_normal = slot_texture
		slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot.stretch_mode = TextureButton.STRETCH_KEEP
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot_container.add_child(slot)
		slots.append(slot)

		# Add item icon as child of slot
		var icon = TextureRect.new()
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot.add_child(icon)
		item_icons.append(icon)

		# Add stack count label
		var label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.add_theme_font_size_override("font_size", 8)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(label)
		stack_labels.append(label)


func _update_item_icons() -> void:
	if not world:
		return

	var contents = world.get_box_contents(current_box_pos)

	for i in range(SLOT_COUNT):
		var item = contents[i] if i < contents.size() else null
		if item != null:
			item_icons[i].texture = item.texture
			if item.quantity > 1:
				stack_labels[i].text = str(item.quantity)
			else:
				stack_labels[i].text = ""
		else:
			item_icons[i].texture = null
			stack_labels[i].text = ""


func _input(event: InputEvent) -> void:
	if not is_open:
		return

	# Close on Escape, C, or CMD+W
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
				# Check if click is outside panel to close
				if not _is_point_in_panel(event.global_position) and not _is_point_in_hotbar(event.global_position):
					close()
					get_viewport().set_input_as_handled()
					return
				_start_drag(event.global_position)
			else:
				_end_drag(event.global_position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Right-click outside to close
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
	# Check box inventory slots first
	var slot_index = _get_slot_at_position(pos)
	if slot_index >= 0:
		var contents = world.get_box_contents(current_box_pos)
		if slot_index < contents.size() and contents[slot_index] != null:
			dragging = true
			drag_from_slot = slot_index
			drag_from_hotbar = false
			_create_drag_preview(contents[slot_index].texture, pos)
			item_icons[slot_index].modulate.a = 0.3
			get_viewport().set_input_as_handled()
			return

	# Check hotbar slots
	var hotbar_slot = _get_hotbar_slot_at_position(pos)
	if hotbar_slot >= 0 and hotbar.get_item(hotbar_slot) != null:
		dragging = true
		drag_from_slot = hotbar_slot
		drag_from_hotbar = true
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
	if not dragging:
		return

	var target_box_slot = _get_slot_at_position(pos)
	var target_hotbar_slot = _get_hotbar_slot_at_position(pos)

	if drag_from_hotbar:
		# Dragging from hotbar
		if target_box_slot >= 0:
			# Move to box
			_transfer_hotbar_to_box(drag_from_slot, target_box_slot)
		elif target_hotbar_slot >= 0 and target_hotbar_slot != drag_from_slot:
			# Swap within hotbar
			var temp = hotbar.items[target_hotbar_slot]
			hotbar.items[target_hotbar_slot] = hotbar.items[drag_from_slot]
			hotbar.items[drag_from_slot] = temp
			hotbar._update_item_icons()
		hotbar.item_icons[drag_from_slot].modulate.a = 1.0
	else:
		# Dragging from box
		if target_hotbar_slot >= 0:
			# Move to hotbar
			_transfer_box_to_hotbar(drag_from_slot, target_hotbar_slot)
		elif target_box_slot >= 0 and target_box_slot != drag_from_slot:
			# Swap within box
			var contents = world.get_box_contents(current_box_pos)
			var temp = contents[target_box_slot] if target_box_slot < contents.size() else null
			world.set_box_slot(current_box_pos, target_box_slot, contents[drag_from_slot] if drag_from_slot < contents.size() else null)
			world.set_box_slot(current_box_pos, drag_from_slot, temp)
		item_icons[drag_from_slot].modulate.a = 1.0

	_update_item_icons()

	# Clean up drag preview
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null

	dragging = false
	drag_from_slot = -1
	drag_from_hotbar = false


func _transfer_hotbar_to_box(hotbar_slot: int, box_slot: int) -> void:
	var hotbar_item = hotbar.get_item(hotbar_slot)
	var contents = world.get_box_contents(current_box_pos)
	var box_item = contents[box_slot] if box_slot < contents.size() else null

	# Swap items
	world.set_box_slot(current_box_pos, box_slot, hotbar_item)
	hotbar.set_item(hotbar_slot, box_item)


func _transfer_box_to_hotbar(box_slot: int, hotbar_slot: int) -> void:
	var contents = world.get_box_contents(current_box_pos)
	var box_item = contents[box_slot] if box_slot < contents.size() else null
	var hotbar_item = hotbar.get_item(hotbar_slot)

	# Swap items
	hotbar.set_item(hotbar_slot, box_item)
	world.set_box_slot(current_box_pos, box_slot, hotbar_item)


func _get_slot_at_position(global_pos: Vector2) -> int:
	for i in range(slots.size()):
		var slot = slots[i]
		var rect = slot.get_global_rect()
		if rect.has_point(global_pos):
			return i
	return -1


func _get_hotbar_slot_at_position(global_pos: Vector2) -> int:
	if not hotbar:
		return -1
	for i in range(hotbar.slots.size()):
		var slot = hotbar.slots[i]
		var rect = slot.get_global_rect()
		if rect.has_point(global_pos):
			return i
	return -1


func open_for_box(box_pos: Vector2i) -> void:
	if is_open:
		return
	current_box_pos = box_pos
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
		if drag_from_hotbar:
			hotbar.item_icons[drag_from_slot].modulate.a = 1.0
		else:
			item_icons[drag_from_slot].modulate.a = 1.0
		if drag_preview:
			drag_preview.queue_free()
			drag_preview = null
		dragging = false
		drag_from_slot = -1

	closed.emit()
