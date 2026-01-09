extends CharacterBody2D

@export var run_speed: float = 160.0
@export var walk_speed: float = 80.0
@export var peer_id: int = 1  # Network peer ID, set by PlayerSpawner

var hotbar: Node = null
var dropped_item_scene: PackedScene = preload("res://scenes/dropped_item.tscn")
var pickup_sound: AudioStream = preload("res://audio/pickup.wav")

var world: TileMapLayer = null

# Derived from sprite size
var sprite_size: float = 16.0
var pickup_range: float = 32.0

# Tool hit counts for different tiers
const PLASTIC_TOOL_HITS: int = 10
const WOOD_TOOL_HITS: int = 5
const STONE_TOOL_HITS: int = 3

var _pending_left_click: bool = false
var _pending_right_click: bool = false
var box_inventory: Node = null
var _last_pickup_sound_frame: int = -1


func is_local_player() -> bool:
    return peer_id == NetworkManager.get_local_peer_id()


func _ready() -> void:
    add_to_group("player")

    # Set multiplayer authority based on peer_id
    set_multiplayer_authority(peer_id)

    # Derive sizes from actual sprite dimensions
    var sprite = $Sprite2D
    if sprite and sprite.texture:
        sprite_size = sprite.texture.get_width()
        pickup_range = sprite_size * 2.0

    # Update collision shape to match sprite (slightly smaller for feel)
    var collision = $CollisionShape2D
    if collision and collision.shape is RectangleShape2D:
        collision.shape.size = Vector2(sprite_size * 0.875, sprite_size * 0.875)

    # Only enable camera for local player
    var camera = $Camera2D
    if camera:
        camera.enabled = is_local_player()

    # Find world tilemap for rock breaking (sibling node)
    world = get_parent().get_node_or_null("TileMapLayer") as TileMapLayer

    # Only local player sets up hotbar and UI connections
    if is_local_player():
        await get_tree().process_frame
        hotbar = get_tree().get_first_node_in_group("hotbar")
        if hotbar == null:
            hotbar = get_node_or_null("/root/Node2D/CanvasLayer/Hotbar")

        if hotbar:
            hotbar.item_dropped.connect(_on_item_dropped)
            # Give player starting tool (not stackable) - just an axe, pick must be crafted
            var axe = Item.create("Axe", TextureCache.get_texture("axe"))
            axe.stackable = false
            hotbar.set_item(0, axe)

        # Find box inventory
        box_inventory = get_tree().get_first_node_in_group("box_inventory")


func _physics_process(_delta: float) -> void:
    # Only process input for local player
    if not is_local_player():
        return

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
    # Only process input for local player
    if not is_local_player():
        return

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
    return item_name in ["Axe", "Wood Pick", "Wood Axe", "Stone Pick", "Stone Axe"]


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

    # Request tile hit through world (host-authoritative)
    if source_id > 0:  # Not grass
        world.request_hit_tile.rpc_id(1, tile_pos, tool_name, peer_id)


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

    # Request placement through world (host-authoritative)
    world.request_place_tile.rpc_id(1, tile_pos, tile_source_id, selected_item.name, peer_id)


func _try_pickup() -> void:
    if not is_local_player():
        return

    var dropped_items = get_tree().get_nodes_in_group("dropped_items")
    var picked_up_any := false

    for item_node in dropped_items:
        var dropped: DroppedItem = item_node as DroppedItem
        if dropped == null or not dropped.can_pickup or dropped.being_picked_up:
            continue

        var dist = global_position.distance_to(dropped.global_position)
        if dist < pickup_range and dropped.item and hotbar:
            # Request pickup through world (host-authoritative)
            if dropped.network_id >= 0:
                world.request_pickup_item.rpc_id(1, dropped.network_id, peer_id)
            else:
                # Fallback for items spawned before networking (single player mode)
                if hotbar.add_item(dropped.item):
                    dropped.start_pickup(self)
                    picked_up_any = true

    if picked_up_any:
        _play_pickup_sound()


func _play_pickup_sound() -> void:
    # Prevent multiple pickup sounds on the same frame
    var current_frame = Engine.get_process_frames()
    if current_frame == _last_pickup_sound_frame:
        return
    _last_pickup_sound_frame = current_frame

    var audio = AudioStreamPlayer.new()
    audio.stream = pickup_sound
    audio.bus = "Master"
    get_tree().root.add_child(audio)
    audio.play()
    audio.finished.connect(audio.queue_free)


func _on_item_dropped(item: Item, _slot_index: int) -> void:
    if item == null or not world:
        return

    # Request drop through world (host-authoritative)
    var drop_offset = Vector2(sprite_size, 0).rotated(randf() * TAU)
    var drop_pos = global_position + drop_offset
    world.request_drop_item.rpc_id(1, item.name, _get_texture_path(item.texture), item.quantity, item.stackable, drop_pos, peer_id)


func _get_texture_path(texture: Texture2D) -> String:
    return TextureCache.get_key(texture)


# Called by world.gd when placement is confirmed
func on_placement_confirmed(item_name: String) -> void:
    if not hotbar:
        return
    var selected_item = hotbar.get_selected_item()
    if selected_item and selected_item.name == item_name:
        selected_item.quantity -= 1
        if selected_item.quantity <= 0:
            hotbar.set_item(hotbar.selected_slot, null)
        hotbar._update_item_icons()


# Called by world.gd when pickup is confirmed
func on_pickup_confirmed(item: Item) -> void:
    if hotbar and hotbar.add_item(item):
        _play_pickup_sound()
