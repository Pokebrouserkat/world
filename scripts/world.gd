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


func _ready() -> void:
    add_to_group("world")
    _setup_tile_physics()
    _update_tiles()


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
