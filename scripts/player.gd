extends CharacterBody2D

@export var run_speed: float = 160.0
@export var walk_speed: float = 80.0

var hotbar: Node = null
var dropped_item_scene: PackedScene = preload("res://scenes/dropped_item.tscn")
var axe_texture: Texture2D = preload("res://graphics/plasticax.png")
var pick_texture: Texture2D = preload("res://graphics/plasticpick.png")
var wood_axe_texture: Texture2D = preload("res://graphics/woodax.png")
var wood_pick_texture: Texture2D = preload("res://graphics/woodpick.png")
var stone_axe_texture: Texture2D = preload("res://graphics/stoneax.png")
var stone_pick_texture: Texture2D = preload("res://graphics/stonepick.png")
var rock_item_texture: Texture2D = preload("res://graphics/rock_item.png")
var wood_texture: Texture2D = preload("res://graphics/wood.png")
var box_texture: Texture2D = preload("res://graphics/box.png")
var wood_wall_texture: Texture2D = preload("res://graphics/woodwall.png")
var stone_wall_texture: Texture2D = preload("res://graphics/stonewall.png")
var pickup_sound: AudioStream = preload("res://audio/pickup.wav")

var world: TileMapLayer = null

# Derived from sprite size
var sprite_size: float = 16.0
var pickup_range: float = 32.0

# Track tile health (rocks, trees, etc.)
var _tile_health: Dictionary = {}
const PLASTIC_TOOL_HITS: int = 10
const WOOD_TOOL_HITS: int = 5
const STONE_TOOL_HITS: int = 3

# Base tile durability (how many hits with a 1-hit tool)
const BASE_TILE_DURABILITY: int = 10
const WOOD_WALL_DURABILITY: int = 20  # 2x base
const STONE_WALL_DURABILITY: int = 30  # 3x base

var _pending_left_click: bool = false
var _pending_right_click: bool = false
var box_inventory: Node = null


func _ready() -> void:
    add_to_group("player")

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

    # Find box inventory
    box_inventory = get_tree().get_first_node_in_group("box_inventory")


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

    if _pending_left_click:
        _pending_left_click = false
        _handle_left_click()

    if _pending_right_click:
        _pending_right_click = false
        _handle_right_click()

    _try_pickup()


func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            _pending_left_click = true
        elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            _pending_right_click = true


func _handle_left_click() -> void:
    if not hotbar or not world:
        return

    var selected_item = hotbar.get_selected_item()
    if selected_item == null:
        return

    # Check what item is selected and perform appropriate action
    if selected_item.name == "Box" or selected_item.name == "Wood Wall" or selected_item.name == "Stone Wall":
        _try_place_item()
    elif _is_tool(selected_item.name):
        _try_use_tool()


func _handle_right_click() -> void:
    if not world or not box_inventory:
        return

    # Don't open if box inventory is already open
    if box_inventory.is_open:
        return

    # Get mouse position in world coordinates
    var mouse_pos = get_global_mouse_position()

    # Check if within interaction range (2 tiles)
    var use_range = sprite_size * 2.0
    if global_position.distance_to(mouse_pos) > use_range:
        return

    # Convert to tile coordinates
    var tile_pos = world.local_to_map(world.to_local(mouse_pos))
    var source_id = world.get_cell_source_id(tile_pos)

    # Check if it's a box tile (source_id 3)
    if source_id == 3:
        box_inventory.open_for_box(tile_pos)


func _is_tool(item_name: String) -> bool:
    return item_name in ["Pick", "Axe", "Wood Pick", "Wood Axe", "Stone Pick", "Stone Axe"]


func _get_tool_hits(item_name: String) -> int:
    if item_name.begins_with("Stone"):
        return STONE_TOOL_HITS
    elif item_name.begins_with("Wood"):
        return WOOD_TOOL_HITS
    else:
        return PLASTIC_TOOL_HITS


func _try_use_tool() -> void:
    if not hotbar or not world:
        return

    var selected_item = hotbar.get_selected_item()
    if selected_item == null:
        return

    var tool_name = selected_item.name
    if not _is_tool(tool_name):
        return

    # Get mouse position in world coordinates
    var mouse_pos = get_global_mouse_position()

    # Check if within range (2 tiles)
    var use_range = sprite_size * 2.0
    if global_position.distance_to(mouse_pos) > use_range:
        return

    # Convert to tile coordinates (global to local first)
    var tile_pos = world.local_to_map(world.to_local(mouse_pos))
    var source_id = world.get_cell_source_id(tile_pos)

    # Check what tile we're hitting
    if source_id == 1:  # Rock
        _hit_tile(tile_pos, "rock", tool_name)
    elif source_id == 2:  # Tree
        _hit_tile(tile_pos, "tree", tool_name)
    elif source_id == 3:  # Box - instant pickup, no delay
        _break_tile(tile_pos, "box")
    elif source_id == 4:  # Wood Wall
        _hit_tile(tile_pos, "wood_wall", tool_name)
    elif source_id == 5:  # Stone Wall
        _hit_tile(tile_pos, "stone_wall", tool_name)


func _get_tile_durability(tile_type: String) -> int:
    match tile_type:
        "wood_wall":
            return WOOD_WALL_DURABILITY
        "stone_wall":
            return STONE_WALL_DURABILITY
        _:
            return BASE_TILE_DURABILITY


func _hit_tile(tile_pos: Vector2i, tile_type: String, tool_name: String) -> void:
    # Initialize health if not tracked (based on tile type durability)
    if not _tile_health.has(tile_pos):
        _tile_health[tile_pos] = _get_tile_durability(tile_type)

    # Calculate damage based on tool type
    var tool_hits = _get_tool_hits(tool_name)
    var damage = BASE_TILE_DURABILITY / tool_hits

    _tile_health[tile_pos] -= damage

    if _tile_health[tile_pos] <= 0:
        _break_tile(tile_pos, tile_type)
        _tile_health.erase(tile_pos)


func _break_tile(tile_pos: Vector2i, tile_type: String) -> void:
    # Replace with grass
    world.set_cell(tile_pos, 0, Vector2i(0, 0))

    # Spawn appropriate item(s) at tile center
    var tile_world_pos = world.map_to_local(tile_pos)

    if tile_type == "rock":
        _spawn_dropped_item("Rock", rock_item_texture, 1, tile_world_pos, 0.3)
    elif tile_type == "tree":
        # Spread out 10 wood drops
        for i in range(10):
            var spread_offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
            _spawn_dropped_item("Wood", wood_texture, 1, tile_world_pos + spread_offset, 0.3)
    elif tile_type == "box":
        # Box: no pickup delay, drop contents first
        var contents = world.clear_box_contents(tile_pos)
        for item in contents:
            if item != null:
                var spread_offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
                _spawn_dropped_item(item.name, item.texture, item.quantity, tile_world_pos + spread_offset, 0.3)
        _spawn_dropped_item("Box", box_texture, 1, tile_world_pos, 0.0)
    elif tile_type == "wood_wall":
        _spawn_dropped_item("Wood Wall", wood_wall_texture, 1, tile_world_pos, 0.0)
    elif tile_type == "stone_wall":
        _spawn_dropped_item("Stone Wall", stone_wall_texture, 1, tile_world_pos, 0.0)


func _spawn_dropped_item(item_name: String, texture: Texture2D, quantity: int, pos: Vector2, pickup_delay: float = 0.3) -> void:
    var dropped = dropped_item_scene.instantiate() as DroppedItem
    var item = Item.create(item_name, texture, quantity)
    dropped.set_item(item)
    dropped.add_to_group("dropped_items")
    dropped.global_position = pos
    get_parent().add_child(dropped)
    if pickup_delay > 0:
        dropped.enable_pickup_after_delay(pickup_delay)
    else:
        dropped.can_pickup = true


func _try_place_item() -> void:
    if not hotbar or not world:
        return

    var selected_item = hotbar.get_selected_item()
    if selected_item == null:
        return

    # Determine which tile to place based on item
    var tile_source_id: int = -1
    match selected_item.name:
        "Box":
            tile_source_id = 3
        "Wood Wall":
            tile_source_id = 4
        "Stone Wall":
            tile_source_id = 5
        _:
            return

    # Get mouse position in world coordinates
    var mouse_pos = get_global_mouse_position()

    # Check if within range (2 tiles)
    var use_range = sprite_size * 2.0
    if global_position.distance_to(mouse_pos) > use_range:
        return

    # Convert to tile coordinates
    var tile_pos = world.local_to_map(world.to_local(mouse_pos))
    var source_id = world.get_cell_source_id(tile_pos)

    # Can only place on grass (source_id 0)
    if source_id != 0:
        return

    # Don't allow placing on the tile the player is standing on
    var player_tile = world.local_to_map(world.to_local(global_position))
    if tile_pos == player_tile:
        return

    # Place the tile
    world.set_cell(tile_pos, tile_source_id, Vector2i(0, 0))

    # Consume one item from inventory
    selected_item.quantity -= 1
    if selected_item.quantity <= 0:
        hotbar.set_item(hotbar.selected_slot, null)
    hotbar._update_item_icons()


func _try_pickup() -> void:
    var dropped_items = get_tree().get_nodes_in_group("dropped_items")
    var picked_up_any := false

    for item_node in dropped_items:
        var dropped: DroppedItem = item_node as DroppedItem
        if dropped == null or not dropped.can_pickup:
            continue

        var dist = global_position.distance_to(dropped.global_position)
        if dist < pickup_range and dropped.item and hotbar:
            if hotbar.add_item(dropped.item):
                dropped.start_pickup(self)
                picked_up_any = true

    if picked_up_any:
        _play_pickup_sound()


func _play_pickup_sound() -> void:
    var audio = AudioStreamPlayer.new()
    audio.stream = pickup_sound
    audio.bus = "Master"
    get_tree().root.add_child(audio)
    audio.play()
    audio.finished.connect(audio.queue_free)


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
