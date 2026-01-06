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


func _process(_delta: float) -> void:
    update_visible_tiles()


func update_visible_tiles() -> void:
    var visible_rect = get_visible_tile_rect()

    for x in range(visible_rect.position.x, visible_rect.end.x):
        for y in range(visible_rect.position.y, visible_rect.end.y):
            var tile_pos = Vector2i(x, y)
            if not _generated_tiles.has(tile_pos):
                generate_tile(tile_pos)


func generate_tile(tile_pos: Vector2i) -> void:
    var tile_type = get_tile_type(tile_pos.x, tile_pos.y)
    var atlas_coords = TILE_COORDS[tile_type]
    set_cell(tile_pos, 0, atlas_coords)
    _generated_tiles[tile_pos] = true


func get_visible_tile_rect() -> Rect2i:
    var canvas_transform = get_canvas_transform()
    var viewport_size = get_viewport_rect().size

    # Get the visible area in world coordinates
    var top_left = -canvas_transform.origin / canvas_transform.get_scale()
    var bottom_right = top_left + viewport_size / canvas_transform.get_scale()

    # Convert to tile coordinates with buffer
    var tile_size = tile_set.tile_size
    var start = Vector2i(
        floori(top_left.x / tile_size.x) - tile_buffer,
        floori(top_left.y / tile_size.y) - tile_buffer
    )
    var end = Vector2i(
        ceili(bottom_right.x / tile_size.x) + tile_buffer,
        ceili(bottom_right.y / tile_size.y) + tile_buffer
    )

    return Rect2i(start, end - start)


func get_tile_type(x: int, y: int) -> TileType:
    # TODO: Implement seeded RNG and biome generation
    # For now, always return grass
    return TileType.GRASS
