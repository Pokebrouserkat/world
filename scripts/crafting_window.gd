extends Control

signal closed

var hotbar: Node = null
var player: Node = null
var is_open: bool = false
var dropped_item_scene: PackedScene = preload("res://scenes/dropped_item.tscn")

# Recipe structure: {"output_name": {"ingredients": {"item_name": quantity}, "output_quantity": int, "texture": Texture2D}}
var recipes: Dictionary = {}

# UI elements
var panel: NinePatchRect = null
var recipe_container: VBoxContainer = null
var recipe_buttons: Array[TextureButton] = []

# Textures
var box_texture: Texture2D = preload("res://graphics/box.png")
var wood_texture: Texture2D = preload("res://graphics/wood.png")
var rock_texture: Texture2D = preload("res://graphics/rock_item.png")
var window_bg: Texture2D = preload("res://graphics/windowtileset.png")
var slot_texture: Texture2D = preload("res://graphics/itemslot.png")
var wood_pick_texture: Texture2D = preload("res://graphics/woodpick.png")
var wood_axe_texture: Texture2D = preload("res://graphics/woodax.png")
var stone_pick_texture: Texture2D = preload("res://graphics/stonepick.png")
var stone_axe_texture: Texture2D = preload("res://graphics/stoneax.png")
var wood_wall_texture: Texture2D = preload("res://graphics/woodwall.png")
var stone_wall_texture: Texture2D = preload("res://graphics/stonewall.png")
var iron_texture: Texture2D = preload("res://graphics/iron.png")
var iron_pick_texture: Texture2D = preload("res://graphics/ironpick.png")
var iron_axe_texture: Texture2D = preload("res://graphics/ironax.png")
var furnace_texture: Texture2D = preload("res://graphics/furnace.png")

# Ingredient textures lookup
var ingredient_textures: Dictionary = {}


func _ready() -> void:
	add_to_group("crafting_window")
	visible = false

	_setup_recipes()
	_create_ui()

	# Find hotbar and player
	await get_tree().process_frame
	hotbar = get_tree().get_first_node_in_group("hotbar")
	player = get_tree().get_first_node_in_group("player")


func _setup_recipes() -> void:
	# Set up ingredient texture lookup
	ingredient_textures["Wood"] = wood_texture
	ingredient_textures["Rock"] = rock_texture
	ingredient_textures["Iron"] = iron_texture

	recipes["Box"] = {
		"ingredients": {"Wood": 5},
		"output_quantity": 1,
		"texture": box_texture
	}

	# Wood tools - 5 wood each
	recipes["Wood Pick"] = {
		"ingredients": {"Wood": 5},
		"output_quantity": 1,
		"texture": wood_pick_texture,
		"stackable": false
	}

	recipes["Wood Axe"] = {
		"ingredients": {"Wood": 5},
		"output_quantity": 1,
		"texture": wood_axe_texture,
		"stackable": false
	}

	# Stone tools - 2 wood + 3 stone each
	recipes["Stone Pick"] = {
		"ingredients": {"Wood": 2, "Rock": 3},
		"output_quantity": 1,
		"texture": stone_pick_texture,
		"stackable": false
	}

	recipes["Stone Axe"] = {
		"ingredients": {"Wood": 2, "Rock": 3},
		"output_quantity": 1,
		"texture": stone_axe_texture,
		"stackable": false
	}

	# Walls - 20 of respective material
	recipes["Wood Wall"] = {
		"ingredients": {"Wood": 20},
		"output_quantity": 1,
		"texture": wood_wall_texture
	}

	recipes["Stone Wall"] = {
		"ingredients": {"Rock": 20},
		"output_quantity": 1,
		"texture": stone_wall_texture
	}

	# Furnace - 10 rock
	recipes["Furnace"] = {
		"ingredients": {"Rock": 10},
		"output_quantity": 1,
		"texture": furnace_texture
	}

	# Iron tools - 2 wood + 3 iron each
	recipes["Iron Pick"] = {
		"ingredients": {"Wood": 2, "Iron": 3},
		"output_quantity": 1,
		"texture": iron_pick_texture,
		"stackable": false
	}

	recipes["Iron Axe"] = {
		"ingredients": {"Wood": 2, "Iron": 3},
		"output_quantity": 1,
		"texture": iron_axe_texture,
		"stackable": false
	}


func _create_ui() -> void:
	# Calculate required height based on recipe count
	var row_height = 16  # Icon height
	var row_spacing = 4
	var header_height = 22  # Title area
	var padding = 16  # Border padding
	var recipe_count = recipes.size()
	var recipes_height = recipe_count * row_height + (recipe_count - 1) * row_spacing
	var content_height = header_height + recipes_height + padding

	# Check if we need scrolling (80% of 360 viewport height = 288)
	var max_height = 288
	var needs_scroll = content_height > max_height
	var panel_height = min(content_height, max_height)
	var panel_width = 140

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
	title.text = "Crafting"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 6)
	title.size = Vector2(panel_width, 14)
	panel.add_child(title)

	# Recipe container (with optional scroll)
	var container_height = panel_height - header_height - padding

	if needs_scroll:
		var scroll = ScrollContainer.new()
		scroll.position = Vector2(8, header_height)
		scroll.size = Vector2(panel_width - 16, container_height)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		panel.add_child(scroll)

		recipe_container = VBoxContainer.new()
		recipe_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		recipe_container.add_theme_constant_override("separation", row_spacing)
		scroll.add_child(recipe_container)
	else:
		recipe_container = VBoxContainer.new()
		recipe_container.position = Vector2(8, header_height)
		recipe_container.size = Vector2(panel_width - 16, container_height)
		recipe_container.add_theme_constant_override("separation", row_spacing)
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
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	# Clickable output icon
	var output_btn = TextureButton.new()
	output_btn.texture_normal = recipe.texture
	output_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	output_btn.stretch_mode = TextureButton.STRETCH_KEEP
	output_btn.pressed.connect(_on_craft_pressed.bind(recipe_name))
	row.add_child(output_btn)
	recipe_buttons.append(output_btn)

	# Equals sign
	var equals = Label.new()
	equals.text = "="
	equals.add_theme_font_size_override("font_size", 10)
	row.add_child(equals)

	# Ingredients
	var first_ing = true
	for ing_name in recipe.ingredients:
		if not first_ing:
			var plus = Label.new()
			plus.text = "+"
			plus.add_theme_font_size_override("font_size", 10)
			row.add_child(plus)
		first_ing = false

		# Ingredient icon (smaller to show it's not clickable)
		var ing_icon = TextureRect.new()
		if ingredient_textures.has(ing_name):
			ing_icon.texture = ingredient_textures[ing_name]
		ing_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ing_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ing_icon.custom_minimum_size = Vector2(12, 12)
		ing_icon.size = Vector2(12, 12)
		row.add_child(ing_icon)

		# Quantity label
		var qty = Label.new()
		qty.text = str(recipe.ingredients[ing_name])
		qty.add_theme_font_size_override("font_size", 10)
		qty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(qty)

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
	if recipe.has("stackable") and recipe.stackable == false:
		output.stackable = false

	# Try to add to inventory, drop if full
	if not hotbar.add_item(output):
		_drop_item(output)

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


func _drop_item(item: Item) -> void:
	if not player:
		return

	var dropped = dropped_item_scene.instantiate()
	dropped.set_item(item)
	dropped.add_to_group("dropped_items")

	# Drop near player with random offset
	var drop_offset = Vector2(16, 0).rotated(randf() * TAU)
	dropped.global_position = player.global_position + drop_offset

	player.get_parent().add_child(dropped)
	dropped.enable_pickup_after_delay(0.5)


func _update_craft_buttons() -> void:
	var idx = 0
	for recipe_name in recipes:
		if idx < recipe_buttons.size():
			var can_craft = _can_craft(recipes[recipe_name])
			# Dim the button if can't craft
			recipe_buttons[idx].modulate.a = 1.0 if can_craft else 0.4
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
		# Close on Escape or CMD+W when open
		elif is_open:
			if event.keycode == KEY_ESCAPE:
				close()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_W and event.meta_pressed:
				close()
				get_viewport().set_input_as_handled()

	# Click outside to close
	if is_open and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			if panel and not panel.get_global_rect().has_point(event.global_position):
				close()
				get_viewport().set_input_as_handled()
