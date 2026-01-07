extends HBoxContainer

signal slot_selected(index: int)
signal item_dropped(item: Item, slot_index: int)

@export var slot_count: int = 9

var selected_slot: int = 0
var slots: Array[TextureButton] = []
var items: Array[Item] = []
var item_icons: Array[TextureRect] = []
var stack_labels: Array[Label] = []

# Textures for slot states
var left_off: Texture2D
var left_on: Texture2D
var mid_off: Texture2D
var mid_on: Texture2D
var right_off: Texture2D
var right_on: Texture2D

# Drag state
var dragging: bool = false
var drag_from_slot: int = -1
var drag_preview: TextureRect = null


func _ready() -> void:
	add_to_group("hotbar")
	left_off = preload("res://sprites/leftbox.png")
	left_on = preload("res://sprites/leftboxon.png")
	mid_off = preload("res://sprites/midbox.png")
	mid_on = preload("res://sprites/midboxon.png")
	right_off = preload("res://sprites/rightbox.png")
	right_on = preload("res://sprites/rightboxon.png")

	# Initialize items array
	for i in range(slot_count):
		items.append(null)

	_create_slots()
	_update_slot_visuals()
	_update_layout_from_textures()


func _update_layout_from_textures() -> void:
	# Derive hotbar size from slot textures
	if mid_off:
		var slot_width = mid_off.get_width()
		var slot_height = mid_off.get_height()
		var total_width = slot_width * slot_count
		var half_width = total_width / 2.0

		# Update container offsets to center the hotbar
		offset_left = -half_width
		offset_right = half_width
		offset_top = -(slot_height + 8)
		offset_bottom = -8


func _create_slots() -> void:
	for i in range(slot_count):
		var slot = TextureButton.new()
		slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot.stretch_mode = TextureButton.STRETCH_KEEP
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(slot)
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


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var key = event.keycode
		if key >= KEY_1 and key <= KEY_9:
			var index = key - KEY_1
			if index < slot_count:
				select_slot(index)
		elif key == KEY_MINUS or key == KEY_UNDERSCORE:
			select_slot((selected_slot - 1 + slot_count) % slot_count)
		elif key == KEY_EQUAL or key == KEY_PLUS:
			select_slot((selected_slot + 1) % slot_count)
		elif key == KEY_Q:
			_drop_selected_item()

	# Handle drag and drop
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag(event.global_position)
			else:
				_end_drag(event.global_position)

	if event is InputEventMouseMotion and dragging:
		_update_drag(event.global_position)


func _start_drag(pos: Vector2) -> void:
	var slot_index = _get_slot_at_position(pos)
	if slot_index >= 0 and items[slot_index] != null:
		dragging = true
		drag_from_slot = slot_index
		select_slot(slot_index)

		# Create drag preview in same CanvasLayer
		drag_preview = TextureRect.new()
		drag_preview.texture = items[slot_index].texture
		drag_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drag_preview.modulate.a = 0.7
		get_parent().add_child(drag_preview)
		drag_preview.position = pos - drag_preview.size / 2

		# Hide original icon
		item_icons[slot_index].modulate.a = 0.3


func _update_drag(pos: Vector2) -> void:
	if drag_preview:
		drag_preview.position = pos - drag_preview.size / 2


func _end_drag(pos: Vector2) -> void:
	if not dragging:
		return

	var target_slot = _get_slot_at_position(pos)

	if target_slot >= 0 and target_slot != drag_from_slot:
		# Swap items between slots
		var temp = items[target_slot]
		items[target_slot] = items[drag_from_slot]
		items[drag_from_slot] = temp
		_update_item_icons()
	elif target_slot < 0:
		# Dropped outside hotbar - drop the item
		var dropped_item = items[drag_from_slot]
		items[drag_from_slot] = null
		_update_item_icons()
		item_dropped.emit(dropped_item, drag_from_slot)

	# Restore original icon opacity
	item_icons[drag_from_slot].modulate.a = 1.0

	# Clean up drag preview
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null

	dragging = false
	drag_from_slot = -1


func _get_slot_at_position(global_pos: Vector2) -> int:
	for i in range(slots.size()):
		var slot = slots[i]
		var rect = slot.get_global_rect()
		if rect.has_point(global_pos):
			return i
	return -1


func _drop_selected_item() -> void:
	if items[selected_slot] != null:
		var stack = items[selected_slot]
		if stack.quantity > 1:
			# Drop one from the stack
			stack.quantity -= 1
			var dropped_item = Item.create(stack.name, stack.texture, 1)
			dropped_item.stackable = stack.stackable
			_update_item_icons()
			item_dropped.emit(dropped_item, selected_slot)
		else:
			# Drop the whole item
			items[selected_slot] = null
			_update_item_icons()
			item_dropped.emit(stack, selected_slot)


func select_slot(index: int) -> void:
	if index >= 0 and index < slot_count:
		selected_slot = index
		_update_slot_visuals()
		slot_selected.emit(index)


func _update_slot_visuals() -> void:
	for i in range(slots.size()):
		var slot = slots[i]
		var is_selected = (i == selected_slot)

		if i == 0:
			slot.texture_normal = left_on if is_selected else left_off
		elif i == slot_count - 1:
			slot.texture_normal = right_on if is_selected else right_off
		else:
			slot.texture_normal = mid_on if is_selected else mid_off


func _update_item_icons() -> void:
	for i in range(slot_count):
		if items[i] != null:
			item_icons[i].texture = items[i].texture
			# Show stack count if more than 1
			if items[i].quantity > 1:
				stack_labels[i].text = str(items[i].quantity)
			else:
				stack_labels[i].text = ""
		else:
			item_icons[i].texture = null
			stack_labels[i].text = ""


func set_item(slot_index: int, item: Item) -> void:
	if slot_index >= 0 and slot_index < slot_count:
		items[slot_index] = item
		_update_item_icons()


func get_item(slot_index: int) -> Item:
	if slot_index >= 0 and slot_index < slot_count:
		return items[slot_index]
	return null


func get_selected_item() -> Item:
	return get_item(selected_slot)


func add_item(item: Item) -> bool:
	# First try to stack with existing items
	if item.stackable:
		for i in range(slot_count):
			if items[i] != null and items[i].can_stack_with(item):
				var leftover = items[i].add_quantity(item.quantity)
				if leftover == 0:
					_update_item_icons()
					return true
				item.quantity = leftover

	# Find first empty slot for remaining quantity
	for i in range(slot_count):
		if items[i] == null:
			items[i] = item
			_update_item_icons()
			return true
	return false
