extends CharacterBody2D

@export var run_speed: float = 160.0
@export var walk_speed: float = 80.0

var hotbar: Node = null
var dropped_item_scene: PackedScene = preload("res://scenes/dropped_item.tscn")
var axe_texture: Texture2D = preload("res://sprites/plasticax.png")
var pick_texture: Texture2D = preload("res://sprites/plasticpick.png")
var rock_item_texture: Texture2D = preload("res://sprites/rock_item.png")

var world: TileMapLayer = null

# Derived from sprite size
var sprite_size: float = 16.0
var pickup_range: float = 32.0


func _ready() -> void:
	# Derive sizes from actual sprite dimensions
	var sprite = $Sprite2D
	if sprite and sprite.texture:
		sprite_size = sprite.texture.get_width()
		pickup_range = sprite_size * 2.0

	# Update collision shape to match sprite (slightly smaller for feel)
	var collision = $CollisionShape2D
	if collision and collision.shape is RectangleShape2D:
		collision.shape.size = Vector2(sprite_size * 0.875, sprite_size * 0.875)

	# Find world tilemap for rock breaking (sibling node)
	world = get_parent().get_node("TileMapLayer") as TileMapLayer

	# Find hotbar and connect signals
	await get_tree().process_frame
	hotbar = get_tree().get_first_node_in_group("hotbar")
	if hotbar == null:
		hotbar = get_node_or_null("/root/Node2D/CanvasLayer/Hotbar")

	if hotbar:
		hotbar.item_dropped.connect(_on_item_dropped)
		# Give player starting tools (not stackable)
		var pick = Item.create("Pick", pick_texture)
		pick.stackable = false
		var axe = Item.create("Axe", axe_texture)
		axe.stackable = false
		hotbar.set_item(0, pick)
		hotbar.set_item(1, axe)


func _physics_process(_delta: float) -> void:
	var input_dir = Vector2.ZERO

	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		input_dir.y += 1

	var current_speed = walk_speed if Input.is_key_pressed(KEY_SHIFT) else run_speed
	velocity = input_dir.normalized() * current_speed
	move_and_slide()

	_try_pickup()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_try_use_tool()


func _try_use_tool() -> void:
	if not hotbar or not world:
		return

	var selected_item = hotbar.get_selected_item()
	if selected_item == null or selected_item.name != "Pick":
		return

	# Get mouse position in world coordinates
	var mouse_pos = get_global_mouse_position()

	# Check if within range (2 tiles)
	var use_range = sprite_size * 2.0
	if global_position.distance_to(mouse_pos) > use_range:
		return

	# Convert to tile coordinates
	var tile_pos = world.local_to_map(mouse_pos)

	# Check if it's a rock tile
	var source_id = world.get_cell_source_id(tile_pos)
	if source_id == 1:  # Rock source ID
		_break_rock(tile_pos)


func _break_rock(tile_pos: Vector2i) -> void:
	# Replace rock with grass
	world.set_cell(tile_pos, 0, Vector2i(0, 0))  # Grass source ID 0

	# Spawn rock item at tile center
	var tile_world_pos = world.map_to_local(tile_pos)

	var dropped = dropped_item_scene.instantiate() as DroppedItem
	var rock_item = Item.create("Rock", rock_item_texture)
	dropped.set_item(rock_item)
	dropped.add_to_group("dropped_items")
	dropped.global_position = tile_world_pos

	get_parent().add_child(dropped)
	dropped.enable_pickup_after_delay(0.3)


func _try_pickup() -> void:
	var dropped_items = get_tree().get_nodes_in_group("dropped_items")

	for item_node in dropped_items:
		var dropped: DroppedItem = item_node as DroppedItem
		if dropped == null or not dropped.can_pickup:
			continue

		var dist = global_position.distance_to(dropped.global_position)
		if dist < pickup_range and dropped.item and hotbar:
			if hotbar.add_item(dropped.item):
				dropped.queue_free()


func _on_item_dropped(item: Item, _slot_index: int) -> void:
	if item == null:
		return

	# Spawn dropped item in world near player
	var dropped = dropped_item_scene.instantiate() as DroppedItem
	dropped.set_item(item)
	dropped.add_to_group("dropped_items")

	# Drop slightly in front of player (1x sprite size away)
	var drop_offset = Vector2(sprite_size, 0).rotated(randf() * TAU)
	dropped.global_position = global_position + drop_offset

	get_parent().add_child(dropped)
	dropped.enable_pickup_after_delay(1.0)
