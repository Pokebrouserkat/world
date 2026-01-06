extends TileMapLayer

# Tile type constants
enum TileType {
    GRASS = 0
}

# Atlas coordinates for each tile type
const TILE_COORDS = {
    TileType.GRASS: Vector2i(0, 0)
}

# Buffer of extra tiles to generate beyond the visible area
@export var tile_buffer: int = 2

# Track which tiles have been generated
var _generated_tiles: Dictionary = {}

# Cache last rect to avoid redundant work
var _last_rect: Rect2i


func _ready() -> void:
    _update_tiles()


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
                set_cell(tile_pos, 0, TILE_COORDS[tile_type])
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
    # TODO: Implement seeded RNG and biome generation
    # For now, always return grass
    return TileType.GRASS
