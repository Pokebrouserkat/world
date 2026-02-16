extends Sprite2D

var _grass_texture: Texture2D = preload("res://graphics/grass.png")
var _cave_texture: Texture2D = preload("res://graphics/cavefloor.png")

func _ready() -> void:
    centered = false

func _process(_delta: float) -> void:
    var canvas_xform = get_canvas_transform()
    var camera_pos = -canvas_xform.origin / canvas_xform.get_scale()
    var viewport_size = get_viewport_rect().size / canvas_xform.get_scale()

    # Size region to cover viewport plus buffer
    var region_size = viewport_size + Vector2(64, 64)
    region_rect = Rect2(0, 0, region_size.x, region_size.y)

    # Position at top-left of visible area, snapped to tile grid
    position = Vector2(
        snappedf(camera_pos.x - 32, 16),
        snappedf(camera_pos.y - 32, 16)
    )

    # Swap texture based on mine state
    var world = get_tree().get_first_node_in_group("world")
    if world and world.player_in_mine:
        if texture != _cave_texture:
            texture = _cave_texture
    else:
        if texture != _grass_texture:
            texture = _grass_texture
