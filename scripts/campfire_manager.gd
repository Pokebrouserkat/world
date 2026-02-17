class_name CampfireManager
extends RefCounted

var _lights: Dictionary = {}  # Vector2i -> PointLight2D
var _offsets: Dictionary = {}  # Vector2i -> float (random time offset per campfire)
var _world: TileMapLayer


func init(world: TileMapLayer) -> void:
    _world = world


func add_light(tile_pos: Vector2i, light_texture: Texture2D) -> void:
    if _lights.has(tile_pos):
        return
    var light = PointLight2D.new()
    light.texture = light_texture
    light.texture_scale = 0.35
    light.energy = 1.0
    light.color = Color(1.0, 0.7, 0.3)
    light.shadow_enabled = true
    light.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
    light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
    light.shadow_filter_smooth = 1.0
    light.position = _world.map_to_local(tile_pos)
    _world.add_child(light)
    _lights[tile_pos] = light
    # Deterministic offset from tile position so it's stable across loads
    _offsets[tile_pos] = fmod(abs(sin(tile_pos.x * 12.9898 + tile_pos.y * 78.233) * 43758.5453), 100.0)


func remove_light(tile_pos: Vector2i) -> void:
    if _lights.has(tile_pos):
        var light = _lights[tile_pos]
        if is_instance_valid(light):
            light.queue_free()
        _lights.erase(tile_pos)
        _offsets.erase(tile_pos)


func _flicker(t: float) -> float:
    return (
        sin(t * 8.0) * 0.15 +
        sin(t * 13.7) * 0.10 +
        sin(t * 23.1) * 0.08 +
        sin(t * 3.3) * 0.05
    )


func update_flicker(flicker_time: float) -> void:
    for tile_pos in _lights:
        var light = _lights[tile_pos]
        if is_instance_valid(light):
            var t = flicker_time + _offsets.get(tile_pos, 0.0)
            var flicker = _flicker(t)
            light.texture_scale = 0.35 + flicker * 0.02
            light.color = Color(1.0, 0.7 + flicker * 0.08, 0.3 + flicker * 0.05)


func update_energy(darkness: float, flicker_time: float) -> void:
    var base = lerpf(0.15, 1.0, darkness)
    var energy_flicker_strength = darkness * 0.25
    for tile_pos in _lights:
        var light = _lights[tile_pos]
        if is_instance_valid(light):
            var t = flicker_time + _offsets.get(tile_pos, 0.0)
            var flicker = _flicker(t)
            light.energy = base + flicker * energy_flicker_strength
