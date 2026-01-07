extends CharacterBody2D

@export var run_speed: float = 160.0
@export var walk_speed: float = 80.0

var hotbar: Node = null
var dropped_item_scene: PackedScene = preload("res://scenes/dropped_item.tscn")
var axe_texture: Texture2D = preload("res://sprites/plasticax.png")

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

	# Find hotbar and connect signals
	await get_tree().process_frame
	hotbar = get_tree().get_first_node_in_group("hotbar")
	if hotbar == null:
		hotbar = get_node_or_null("/root/Node2D/CanvasLayer/Hotbar")

	if hotbar:
		hotbar.item_dropped.connect(_on_item_dropped)
		# Give player an axe at start
		var axe = Item.create("Axe", axe_texture)
		hotbar.set_item(0, axe)


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
