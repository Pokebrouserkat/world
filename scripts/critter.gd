extends Node2D

# Deterministic ambient critter with Lissajous movement.
# Position is computed from spawn_pos + sine waves, so all clients
# get identical results with zero network traffic.

var spawn_pos: Vector2
var freq_x: float
var freq_y: float
var phase_x: float
var phase_y: float
var radius_x: float
var radius_y: float
var sprite: Sprite2D


func setup(pos: Vector2, texture: Texture2D, hash_val: int, config: Dictionary) -> void:
    spawn_pos = pos
    position = pos

    # Derive deterministic movement parameters from hash
    var h1 = (hash_val * 7 + 13) % 10000
    var h2 = (hash_val * 11 + 37) % 10000
    var h3 = (hash_val * 17 + 53) % 10000
    var h4 = (hash_val * 23 + 71) % 10000

    var speed_mult: float = config.get("speed", 1.0)
    var min_radius: float = config.get("min_radius", 16.0)
    var max_radius: float = config.get("max_radius", 40.0)

    freq_x = (0.3 + (h1 % 100) / 100.0 * 0.6) * speed_mult
    freq_y = (0.2 + (h2 % 100) / 100.0 * 0.5) * speed_mult
    phase_x = (h3 % 1000) / 1000.0 * TAU
    phase_y = (h4 % 1000) / 1000.0 * TAU
    radius_x = min_radius + (h1 % 50) / 50.0 * (max_radius - min_radius)
    radius_y = min_radius + (h2 % 50) / 50.0 * (max_radius - min_radius)

    sprite = Sprite2D.new()
    sprite.texture = texture
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    # Offset sprite up so the node's position (used for y-sort) is at the critter's feet
    sprite.position.y = -texture.get_height() * 0.5
    add_child(sprite)

    z_index = config.get("z_index", 0)


func update_position(time: float) -> void:
    var old_x = position.x
    position = spawn_pos + Vector2(
        sin(time * freq_x + phase_x) * radius_x,
        sin(time * freq_y + phase_y) * radius_y
    )
    # Flip sprite based on movement direction
    if sprite:
        if position.x < old_x:
            sprite.flip_h = true
        elif position.x > old_x:
            sprite.flip_h = false
