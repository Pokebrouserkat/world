extends TileMapLayer

# Tile type constants
enum TileType {
    GRASS = 0,
    ROCK = 1,
    TREE = 2,
    BOX = 3,
    WOOD_WALL = 4,
    STONE_WALL = 5
}

# Box inventory storage: Dictionary[Vector2i, Array[Item]]
var _box_contents: Dictionary = {}
const BOX_SLOT_COUNT: int = 9

# Atlas source ID for each tile type
const TILE_SOURCE = {
    TileType.GRASS: 0,
    TileType.ROCK: 1,
    TileType.TREE: 2,
    TileType.BOX: 3,
    TileType.WOOD_WALL: 4,
    TileType.STONE_WALL: 5
}

# Atlas coordinates for each tile type (within their source)
const TILE_COORDS = {
    TileType.GRASS: Vector2i(0, 0),
    TileType.ROCK: Vector2i(0, 0),
    TileType.TREE: Vector2i(0, 0),
    TileType.BOX: Vector2i(0, 0),
    TileType.WOOD_WALL: Vector2i(0, 0),
    TileType.STONE_WALL: Vector2i(0, 0)
}

# Chance for a rock to spawn (1 in N tiles)
const ROCK_SPAWN_CHANCE: int = 40

# Chance for a tree to spawn on grass (1 in N grass tiles)
const TREE_SPAWN_CHANCE: int = 40

# Seed for deterministic world generation
const WORLD_SEED: int = 12345


# Buffer of extra tiles to generate beyond the visible area
@export var tile_buffer: int = 2

# Track which tiles have been generated
var _generated_tiles: Dictionary = {}

# Cache last rect to avoid redundant work
var _last_rect: Rect2i

# === MULTIPLAYER STATE (Host-authoritative) ===

# Tile health tracking (moved from player.gd)
var _tile_health: Dictionary = {}  # Vector2i -> int

# Tile modifications for late-joiners (tiles changed from their procedural state)
var _tile_modifications: Dictionary = {}  # Vector2i -> source_id

# Dropped items tracking
var _dropped_items: Dictionary = {}  # network_id -> DroppedItem
var _next_item_id: int = 0

# Texture preloads for spawning items
var rock_item_texture: Texture2D = preload("res://graphics/rock_item.png")
var wood_texture: Texture2D = preload("res://graphics/wood.png")
var box_texture: Texture2D = preload("res://graphics/box.png")
var wood_wall_texture: Texture2D = preload("res://graphics/woodwall.png")
var stone_wall_texture: Texture2D = preload("res://graphics/stonewall.png")
var pick_texture: Texture2D = preload("res://graphics/plasticpick.png")
var axe_texture: Texture2D = preload("res://graphics/plasticax.png")
var wood_pick_texture: Texture2D = preload("res://graphics/woodpick.png")
var wood_axe_texture: Texture2D = preload("res://graphics/woodax.png")
var stone_pick_texture: Texture2D = preload("res://graphics/stonepick.png")
var stone_axe_texture: Texture2D = preload("res://graphics/stoneax.png")
var dropped_item_scene: PackedScene = preload("res://scenes/dropped_item.tscn")

# Tile durability constants
const BASE_TILE_DURABILITY: int = 10
const WOOD_WALL_DURABILITY: int = 20
const STONE_WALL_DURABILITY: int = 30
const PLASTIC_TOOL_HITS: int = 10
const WOOD_TOOL_HITS: int = 5
const STONE_TOOL_HITS: int = 3


func _ready() -> void:
    add_to_group("world")
    _setup_tile_physics()
    _update_tiles()

    # Connect to NetworkManager for late-joiner sync
    NetworkManager.player_connected.connect(_on_player_connected)


func _setup_tile_physics() -> void:
    # Update rock tile collision polygon to match tile size
    if tile_set:
        var tile_size = tile_set.tile_size
        var half_w = tile_size.x / 2.0
        var half_h = tile_size.y / 2.0

        # Get the rock atlas source (source ID 1)
        var rock_source = tile_set.get_source(TILE_SOURCE[TileType.ROCK]) as TileSetAtlasSource
        if rock_source:
            var tile_data = rock_source.get_tile_data(TILE_COORDS[TileType.ROCK], 0)
            if tile_data:
                # Set collision polygon to match tile size
                var polygon = PackedVector2Array([
                    Vector2(-half_w, -half_h),
                    Vector2(half_w, -half_h),
                    Vector2(half_w, half_h),
                    Vector2(-half_w, half_h)
                ])
                tile_data.set_collision_polygon_points(0, 0, polygon)


func _process(_delta: float) -> void:
    _update_tiles()


func _update_tiles() -> void:
    var rect = get_visible_tile_rect()
    if rect == _last_rect:
        return
    _last_rect = rect

    for x in range(rect.position.x, rect.end.x):
        for y in range(rect.position.y, rect.end.y):
            var tile_pos = Vector2i(x, y)
            if not _generated_tiles.has(tile_pos):
                # Check if this tile was modified by a player
                if _tile_modifications.has(tile_pos):
                    set_cell(tile_pos, _tile_modifications[tile_pos], Vector2i(0, 0))
                else:
                    var tile_type = get_tile_type(x, y)
                    set_cell(tile_pos, TILE_SOURCE[tile_type], TILE_COORDS[tile_type])
                _generated_tiles[tile_pos] = true


func get_visible_tile_rect() -> Rect2i:
    var viewport_rect = get_viewport_rect()
    var canvas_xform = get_canvas_transform()

    var top_left = -canvas_xform.origin / canvas_xform.get_scale()
    var size = viewport_rect.size / canvas_xform.get_scale()

    var tile_size = tile_set.tile_size
    return Rect2i(
        Vector2i(floori(top_left.x / tile_size.x) - tile_buffer,
                 floori(top_left.y / tile_size.y) - tile_buffer),
        Vector2i(ceili(size.x / tile_size.x) + tile_buffer * 2,
                 ceili(size.y / tile_size.y) + tile_buffer * 2)
    )


func get_tile_type(x: int, y: int) -> TileType:
    # Use position-based hash for deterministic generation
    var hash_value = _position_hash(x, y)
    if hash_value % ROCK_SPAWN_CHANCE == 0:
        return TileType.ROCK
    # Check for tree on grass tiles (use offset hash)
    var tree_hash = _position_hash(x + 1000, y + 1000)
    if tree_hash % TREE_SPAWN_CHANCE == 0:
        return TileType.TREE
    return TileType.GRASS


func _position_hash(x: int, y: int) -> int:
    # Use fmod-based noise for reliable pseudo-random distribution
    var n = sin(x * 12.9898 + y * 78.233 + WORLD_SEED) * 43758.5453
    return absi(int(n * 1000) % 10000)


# Box inventory functions
func get_box_contents(box_pos: Vector2i) -> Array:
    if not _box_contents.has(box_pos):
        # Initialize empty box with null slots
        var contents: Array = []
        for i in range(BOX_SLOT_COUNT):
            contents.append(null)
        _box_contents[box_pos] = contents
    return _box_contents[box_pos]


func set_box_slot(box_pos: Vector2i, slot: int, item) -> void:
    var contents = get_box_contents(box_pos)
    if slot >= 0 and slot < BOX_SLOT_COUNT:
        contents[slot] = item


func clear_box_contents(box_pos: Vector2i) -> Array:
    # Returns contents and removes from storage (for when box is broken)
    var contents: Array = []
    if _box_contents.has(box_pos):
        contents = _box_contents[box_pos]
        _box_contents.erase(box_pos)
    return contents


# === MULTIPLAYER RPC METHODS ===

func _on_player_connected(peer_id: int) -> void:
    # Send current world state to late-joiner (only host does this)
    if not multiplayer.is_server():
        return

    # Send tile modifications
    _rpc_sync_tile_modifications.rpc_id(peer_id, _tile_modifications)

    # Send all dropped items
    for item_id in _dropped_items:
        var dropped: DroppedItem = _dropped_items[item_id]
        if dropped and is_instance_valid(dropped) and dropped.item:
            _rpc_spawn_dropped_item.rpc_id(peer_id, item_id, dropped.item.name,
                _get_texture_key(dropped.item.texture), dropped.item.quantity,
                dropped.item.stackable, dropped.global_position, 0.0)

    # Send all box contents
    for box_pos in _box_contents:
        var contents = _box_contents[box_pos]
        for slot in range(contents.size()):
            var item = contents[slot]
            if item != null:
                _rpc_sync_box_slot.rpc_id(peer_id, box_pos, slot, item.name,
                    _get_texture_key(item.texture), item.quantity, item.stackable)


func _get_tile_durability(tile_type: String) -> int:
    match tile_type:
        "wood_wall":
            return WOOD_WALL_DURABILITY
        "stone_wall":
            return STONE_WALL_DURABILITY
        _:
            return BASE_TILE_DURABILITY


func _get_tool_hits(tool_name: String) -> int:
    if tool_name.begins_with("Stone"):
        return STONE_TOOL_HITS
    elif tool_name.begins_with("Wood"):
        return WOOD_TOOL_HITS
    else:
        return PLASTIC_TOOL_HITS


func _get_tile_type_string(source_id: int) -> String:
    match source_id:
        1: return "rock"
        2: return "tree"
        3: return "box"
        4: return "wood_wall"
        5: return "stone_wall"
        _: return "grass"


func _is_correct_tool(tool_name: String, source_id: int) -> bool:
    var is_pick = tool_name in ["Pick", "Wood Pick", "Stone Pick"]
    var is_axe = tool_name in ["Axe", "Wood Axe", "Stone Axe"]

    match source_id:
        1:  # Rock - requires pick
            return is_pick
        2:  # Tree - requires axe
            return is_axe
        3:  # Box - any tool works
            return true
        4, 5:  # Walls - any tool works
            return true
        _:
            return false


@rpc("any_peer", "call_local", "reliable")
func request_hit_tile(tile_pos: Vector2i, tool_name: String, requester_peer_id: int) -> void:
    # Host validates and processes tile hits
    if not multiplayer.is_server():
        return

    var source_id = get_cell_source_id(tile_pos)
    if source_id <= 0:  # Grass or invalid
        return

    # Check if correct tool is used
    if not _is_correct_tool(tool_name, source_id):
        return

    var tile_type = _get_tile_type_string(source_id)

    # Box is instant break
    if source_id == 3:
        _break_tile(tile_pos, tile_type)
        return

    # Initialize health if not tracked
    if not _tile_health.has(tile_pos):
        _tile_health[tile_pos] = _get_tile_durability(tile_type)

    # Calculate damage
    var tool_hits = _get_tool_hits(tool_name)
    var damage = ceili(float(BASE_TILE_DURABILITY) / tool_hits)

    _tile_health[tile_pos] -= damage

    if _tile_health[tile_pos] <= 0:
        _break_tile(tile_pos, tile_type)
        _tile_health.erase(tile_pos)


func _break_tile(tile_pos: Vector2i, tile_type: String) -> void:
    # Replace with grass and broadcast to all
    _rpc_sync_tile_change.rpc(tile_pos, 0)
    _tile_modifications[tile_pos] = 0
    _trigger_autosave()

    # Spawn appropriate items
    var tile_world_pos = map_to_local(tile_pos)

    if tile_type == "rock":
        var rock_count = randi_range(1, 4)
        for i in range(rock_count):
            var spread_offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
            _spawn_item_at("Rock", "rock_item", 1, true, tile_world_pos + spread_offset, 0.3)
    elif tile_type == "tree":
        # Spread out 10 wood drops
        for i in range(10):
            var spread_offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
            _spawn_item_at("Wood", "wood", 1, true, tile_world_pos + spread_offset, 0.3)
    elif tile_type == "box":
        # Drop box contents first - drop each item in stack individually
        var contents = clear_box_contents(tile_pos)
        for item in contents:
            if item != null:
                for i in range(item.quantity):
                    var spread_offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
                    _spawn_item_at(item.name, _get_texture_key(item.texture), 1,
                        item.stackable, tile_world_pos + spread_offset, 0.3)
        _spawn_item_at("Box", "box", 1, true, tile_world_pos, 0.0)
    elif tile_type == "wood_wall":
        _spawn_item_at("Wood Wall", "wood_wall", 1, true, tile_world_pos, 0.0)
    elif tile_type == "stone_wall":
        _spawn_item_at("Stone Wall", "stone_wall", 1, true, tile_world_pos, 0.0)


@rpc("any_peer", "call_local", "reliable")
func request_place_tile(tile_pos: Vector2i, tile_source_id: int, item_name: String, requester_peer_id: int) -> void:
    # Host validates and processes tile placement
    if not multiplayer.is_server():
        return

    var source_id = get_cell_source_id(tile_pos)

    # Can only place on grass
    if source_id != 0:
        return

    # Don't allow placing on player positions
    var players = get_tree().get_nodes_in_group("player")
    for player in players:
        var player_tile = local_to_map(to_local(player.global_position))
        if tile_pos == player_tile:
            return

    # Place the tile and broadcast
    _rpc_sync_tile_change.rpc(tile_pos, tile_source_id)
    _tile_modifications[tile_pos] = tile_source_id
    _trigger_autosave()

    # Tell the requester to consume their item
    if requester_peer_id == 1:
        # Host is placing - call directly since call_remote won't reach us
        _confirm_placement_local(item_name)
    else:
        _rpc_confirm_placement.rpc_id(requester_peer_id, item_name)


@rpc("any_peer", "call_local", "reliable")
func request_pickup_item(network_id: int, requester_peer_id: int) -> void:
    # Host validates and processes item pickup
    if not multiplayer.is_server():
        return

    if not _dropped_items.has(network_id):
        return

    var dropped: DroppedItem = _dropped_items[network_id]
    if dropped == null or not is_instance_valid(dropped) or not dropped.can_pickup or dropped.being_picked_up:
        return

    # Mark as being picked up to prevent double-pickup
    dropped.being_picked_up = true

    # Create item for the picker
    var item = Item.create(dropped.item.name, dropped.item.texture, dropped.item.quantity)
    item.stackable = dropped.item.stackable

    # Remove from tracking and broadcast removal
    _dropped_items.erase(network_id)
    _rpc_remove_dropped_item.rpc(network_id, requester_peer_id)

    # Tell the picker they got the item
    if requester_peer_id == 1:
        # Host is picking up - call directly since call_remote won't reach us
        _confirm_pickup_local(item)
    else:
        _rpc_confirm_pickup.rpc_id(requester_peer_id, item.name, _get_texture_key(item.texture),
            item.quantity, item.stackable)


@rpc("any_peer", "call_local", "reliable")
func request_drop_item(item_name: String, texture_key: String, quantity: int, stackable: bool, pos: Vector2, requester_peer_id: int) -> void:
    # Host spawns dropped item
    if not multiplayer.is_server():
        return

    _spawn_item_at(item_name, texture_key, quantity, stackable, pos, 1.0)


func _spawn_item_at(item_name: String, texture_key: String, quantity: int, stackable: bool, pos: Vector2, pickup_delay: float) -> void:
    var network_id = _next_item_id
    _next_item_id += 1

    # Spawn locally and on all clients
    _rpc_spawn_dropped_item.rpc(network_id, item_name, texture_key, quantity, stackable, pos, pickup_delay)


func _get_texture_from_key(key: String) -> Texture2D:
    match key:
        "rock_item": return rock_item_texture
        "wood": return wood_texture
        "box": return box_texture
        "wood_wall": return wood_wall_texture
        "stone_wall": return stone_wall_texture
        "pick": return pick_texture
        "axe": return axe_texture
        "wood_pick": return wood_pick_texture
        "wood_axe": return wood_axe_texture
        "stone_pick": return stone_pick_texture
        "stone_axe": return stone_axe_texture
        _: return rock_item_texture


func _get_texture_key(texture: Texture2D) -> String:
    if texture == rock_item_texture: return "rock_item"
    elif texture == wood_texture: return "wood"
    elif texture == box_texture: return "box"
    elif texture == wood_wall_texture: return "wood_wall"
    elif texture == stone_wall_texture: return "stone_wall"
    elif texture == pick_texture: return "pick"
    elif texture == axe_texture: return "axe"
    elif texture == wood_pick_texture: return "wood_pick"
    elif texture == wood_axe_texture: return "wood_axe"
    elif texture == stone_pick_texture: return "stone_pick"
    elif texture == stone_axe_texture: return "stone_axe"
    return "rock_item"


# === RPC BROADCAST METHODS ===

@rpc("authority", "call_local", "reliable")
func _rpc_sync_tile_change(tile_pos: Vector2i, source_id: int) -> void:
    set_cell(tile_pos, source_id, Vector2i(0, 0))
    if not multiplayer.is_server():
        _tile_modifications[tile_pos] = source_id


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_tile_modifications(modifications: Dictionary) -> void:
    _tile_modifications = modifications
    # Re-apply modifications to already generated tiles
    for pos in modifications:
        if _generated_tiles.has(pos):
            set_cell(pos, modifications[pos], Vector2i(0, 0))


@rpc("authority", "call_local", "reliable")
func _rpc_spawn_dropped_item(network_id: int, item_name: String, texture_key: String,
        quantity: int, stackable: bool, pos: Vector2, pickup_delay: float) -> void:
    var dropped = dropped_item_scene.instantiate() as DroppedItem
    var texture = _get_texture_from_key(texture_key)
    var item = Item.create(item_name, texture, quantity)
    item.stackable = stackable
    dropped.set_item(item)
    dropped.network_id = network_id
    dropped.add_to_group("dropped_items")
    dropped.global_position = pos
    get_parent().add_child(dropped)

    if pickup_delay > 0:
        dropped.enable_pickup_after_delay(pickup_delay)
    else:
        dropped.can_pickup = true

    # Track on host
    if multiplayer.is_server():
        _dropped_items[network_id] = dropped


@rpc("authority", "call_local", "reliable")
func _rpc_remove_dropped_item(network_id: int, picker_peer_id: int) -> void:
    # Find and remove the item
    var dropped_items = get_tree().get_nodes_in_group("dropped_items")
    for item_node in dropped_items:
        var dropped: DroppedItem = item_node as DroppedItem
        if dropped and dropped.network_id == network_id:
            # Find the picker player for animation
            var players = get_tree().get_nodes_in_group("player")
            for player in players:
                if player.peer_id == picker_peer_id:
                    dropped.start_pickup(player)
                    break
            break


@rpc("authority", "call_remote", "reliable")
func _rpc_confirm_placement(item_name: String) -> void:
    _confirm_placement_local(item_name)


func _confirm_placement_local(item_name: String) -> void:
    # Local player consumes item from inventory
    var players = get_tree().get_nodes_in_group("player")
    for player in players:
        if player.is_local_player():
            player.on_placement_confirmed(item_name)
            break


@rpc("authority", "call_remote", "reliable")
func _rpc_confirm_pickup(item_name: String, texture_key: String, quantity: int, stackable: bool) -> void:
    # Local player receives item
    var texture = _get_texture_from_key(texture_key)
    var item = Item.create(item_name, texture, quantity)
    item.stackable = stackable
    _confirm_pickup_local(item)


func _confirm_pickup_local(item: Item) -> void:
    var players = get_tree().get_nodes_in_group("player")
    for player in players:
        if player.is_local_player():
            player.on_pickup_confirmed(item)
            break


# === BOX INVENTORY SYNC ===

@rpc("any_peer", "call_local", "reliable")
func request_set_box_slot(box_pos: Vector2i, slot: int, item_name: String, texture_key: String, quantity: int, stackable: bool) -> void:
    # Host validates and processes box slot changes
    if not multiplayer.is_server():
        return

    var item: Item = null
    if item_name != "":
        var texture = _get_texture_from_key(texture_key)
        item = Item.create(item_name, texture, quantity)
        item.stackable = stackable

    # Update local storage
    var contents = get_box_contents(box_pos)
    if slot >= 0 and slot < BOX_SLOT_COUNT:
        contents[slot] = item

    # Broadcast to all clients
    _rpc_sync_box_slot.rpc(box_pos, slot, item_name, texture_key, quantity, stackable)


@rpc("authority", "call_local", "reliable")
func _rpc_sync_box_slot(box_pos: Vector2i, slot: int, item_name: String, texture_key: String, quantity: int, stackable: bool) -> void:
    # Skip on server - already updated
    if multiplayer.is_server():
        return

    var item: Item = null
    if item_name != "":
        var texture = _get_texture_from_key(texture_key)
        item = Item.create(item_name, texture, quantity)
        item.stackable = stackable

    var contents = get_box_contents(box_pos)
    if slot >= 0 and slot < BOX_SLOT_COUNT:
        contents[slot] = item

    # Update UI if box inventory is open
    var box_inventory = get_tree().get_first_node_in_group("box_inventory")
    if box_inventory and box_inventory.is_open and box_inventory.current_box_pos == box_pos:
        box_inventory._update_item_icons()


# === AUTOSAVE ===

var _autosave_pending: bool = false

func _trigger_autosave() -> void:
    # Only autosave in single player mode (host)
    if not multiplayer.is_server():
        return
    if NetworkManager.is_connected_to_game() and not NetworkManager.is_host():
        return

    # Debounce autosave to avoid saving on every action
    if _autosave_pending:
        return
    _autosave_pending = true
    _do_autosave.call_deferred()


func _do_autosave() -> void:
    _autosave_pending = false
    SaveManager.save_game()
