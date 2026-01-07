extends HBoxContainer

signal slot_selected(index: int)

@export var slot_count: int = 9

var selected_slot: int = 0
var slots: Array[TextureButton] = []

# Textures for slot states
var left_off: Texture2D
var left_on: Texture2D
var mid_off: Texture2D
var mid_on: Texture2D
var right_off: Texture2D
var right_on: Texture2D


func _ready() -> void:
	left_off = preload("res://leftbox.png")
	left_on = preload("res://leftboxon.png")
	mid_off = preload("res://midbox.png")
	mid_on = preload("res://midboxon.png")
	right_off = preload("res://rightbox.png")
	right_on = preload("res://rightboxon.png")

	_create_slots()
	_update_slot_visuals()


func _create_slots() -> void:
	for i in range(slot_count):
		var slot = TextureButton.new()
		slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot.stretch_mode = TextureButton.STRETCH_KEEP
		slot.pressed.connect(_on_slot_pressed.bind(i))
		add_child(slot)
		slots.append(slot)


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


func select_slot(index: int) -> void:
	if index >= 0 and index < slot_count:
		selected_slot = index
		_update_slot_visuals()
		slot_selected.emit(index)


func _on_slot_pressed(index: int) -> void:
	select_slot(index)


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
