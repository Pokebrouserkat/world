extends Control

signal closed

var hotbar: Node = null
var is_open: bool = false

# Recipe structure: {"output_name": {"ingredients": {"item_name": quantity}, "output_quantity": int, "texture": Texture2D}}
var recipes: Dictionary = {}

# UI elements
var recipe_container: VBoxContainer = null
var recipe_buttons: Array[Button] = []

# Textures
var box_texture: Texture2D = preload("res://graphics/box.png")
var wood_texture: Texture2D = preload("res://graphics/wood.png")
var window_bg: Texture2D = preload("res://graphics/windowtileset.png")
var slot_texture: Texture2D = preload("res://graphics/itemslot.png")


func _ready() -> void:
	add_to_group("crafting_window")
	visible = false

	_setup_recipes()
	_create_ui()

	# Find hotbar
	await get_tree().process_frame
	hotbar = get_tree().get_first_node_in_group("hotbar")


func _setup_recipes() -> void:
	recipes["Box"] = {
		"ingredients": {"Wood": 5},
		"output_quantity": 1,
		"texture": box_texture
	}


func _create_ui() -> void:
	# Main panel
	var panel = NinePatchRect.new()
	panel.texture = window_bg
	panel.patch_margin_left = 4
	panel.patch_margin_right = 4
	panel.patch_margin_top = 4
	panel.patch_margin_bottom = 4
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(160, 120)
	panel.size = Vector2(160, 120)
	panel.position = -panel.size / 2
	add_child(panel)

	# Title label
	var title = Label.new()
	title.text = "Crafting"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 8)
	title.size = Vector2(160, 16)
	panel.add_child(title)

	# Recipe container
	recipe_container = VBoxContainer.new()
	recipe_container.position = Vector2(8, 28)
	recipe_container.size = Vector2(144, 84)
	panel.add_child(recipe_container)

	_populate_recipes()


func _populate_recipes() -> void:
	# Clear existing
	for child in recipe_container.get_children():
		child.queue_free()
	recipe_buttons.clear()

	for recipe_name in recipes:
		var recipe = recipes[recipe_name]
		var row = _create_recipe_row(recipe_name, recipe)
		recipe_container.add_child(row)


func _create_recipe_row(recipe_name: String, recipe: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	# Output icon
	var output_icon = TextureRect.new()
	output_icon.texture = recipe.texture
	output_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	output_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	output_icon.custom_minimum_size = Vector2(16, 16)
	row.add_child(output_icon)

	# Recipe info label
	var info = Label.new()
	var ingredients_text = ""
	for ing_name in recipe.ingredients:
		if ingredients_text != "":
			ingredients_text += ", "
		ingredients_text += str(recipe.ingredients[ing_name]) + " " + ing_name
	info.text = recipe_name + " (" + ingredients_text + ")"
	info.add_theme_font_size_override("font_size", 8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	# Craft button
	var craft_btn = Button.new()
	craft_btn.text = "Craft"
	craft_btn.add_theme_font_size_override("font_size", 8)
	craft_btn.pressed.connect(_on_craft_pressed.bind(recipe_name))
	row.add_child(craft_btn)
	recipe_buttons.append(craft_btn)

	return row


func _on_craft_pressed(recipe_name: String) -> void:
	if not hotbar:
		return

	var recipe = recipes[recipe_name]
	if not _can_craft(recipe):
		return

	# Consume ingredients
	for ing_name in recipe.ingredients:
		var needed = recipe.ingredients[ing_name]
		_consume_item(ing_name, needed)

	# Create output item
	var output = Item.create(recipe_name, recipe.texture, recipe.output_quantity)
	hotbar.add_item(output)

	_update_craft_buttons()


func _can_craft(recipe: Dictionary) -> bool:
	if not hotbar:
		return false

	for ing_name in recipe.ingredients:
		var needed = recipe.ingredients[ing_name]
		var have = _count_item(ing_name)
		if have < needed:
			return false
	return true


func _count_item(item_name: String) -> int:
	var total = 0
	for i in range(hotbar.slot_count):
		var item = hotbar.get_item(i)
		if item and item.name == item_name:
			total += item.quantity
	return total


func _consume_item(item_name: String, amount: int) -> void:
	var remaining = amount
	for i in range(hotbar.slot_count):
		if remaining <= 0:
			break
		var item = hotbar.get_item(i)
		if item and item.name == item_name:
			var to_take = mini(item.quantity, remaining)
			item.quantity -= to_take
			remaining -= to_take
			if item.quantity <= 0:
				hotbar.set_item(i, null)
	hotbar._update_item_icons()


func _update_craft_buttons() -> void:
	var idx = 0
	for recipe_name in recipes:
		if idx < recipe_buttons.size():
			recipe_buttons[idx].disabled = not _can_craft(recipes[recipe_name])
		idx += 1


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	_update_craft_buttons()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	closed.emit()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# C key to toggle crafting window
		if event.keycode == KEY_C and not event.ctrl_pressed and not event.meta_pressed:
			toggle()
			get_viewport().set_input_as_handled()
