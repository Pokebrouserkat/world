extends Node2D

# Spawns and despawns deterministic ambient critters in the visible area.
# Uses the world's _position_hash() and WORLD_SEED for deterministic placement.
# No network traffic - all clients compute identical results.

const CritterScene = preload("res://scripts/critter.gd")

const MAX_CRITTERS: int = 40

# Critter type configurations
const CRITTER_TYPES = {
    "rabbit": {
        "grid": 8,
        "spawn_chance": 12,
        "min_radius": 16.0,
        "max_radius": 40.0,
        "speed": 1.0,
        "z_index": 1,
        "environment": "overworld",
        "hash_offset": 5000,
    },
    "butterfly": {
        "grid": 10,
        "spawn_chance": 18,
        "min_radius": 12.0,
        "max_radius": 24.0,
        "speed": 0.7,
        "z_index": 1,
        "environment": "overworld",
        "hash_offset": 6000,
    },
    "bat": {
        "grid": 6,
        "spawn_chance": 8,
        "min_radius": 20.0,
        "max_radius": 48.0,
        "speed": 1.3,
        "z_index": 1,
        "environment": "mine",
        "hash_offset": 7000,
    },
}

var _active_critters: Dictionary = {}  # "gx,gy,type" -> Critter node
var _textures: Dictionary = {}  # type_name -> Texture2D
var _last_in_mine: bool = false
var _last_rect: Rect2i


func _ready() -> void:
    y_sort_enabled = true
    _textures["rabbit"] = load("res://graphics/rabbit.png")
    _textures["butterfly"] = load("res://graphics/butterfly.png")
    _textures["bat"] = load("res://graphics/bat.png")


func _process(_delta: float) -> void:
    var world = _get_world()
    if not world:
        return

    # Check for environment change (mine enter/exit)
    if world.player_in_mine != _last_in_mine:
        _last_in_mine = world.player_in_mine
        _clear_all_critters()
        _last_rect = Rect2i()

    var rect = world.get_visible_tile_rect()
    # Expand rect by buffer for smoother spawn/despawn at edges
    var buffer = 4
    var expanded = Rect2i(
        rect.position - Vector2i(buffer, buffer),
        rect.size + Vector2i(buffer * 2, buffer * 2)
    )

    if expanded == _last_rect:
        _update_critter_positions(world)
        return
    _last_rect = expanded

    var tile_size = world.tile_set.tile_size
    var in_mine = world.player_in_mine

    # Determine which critter keys should exist
    var desired_keys: Dictionary = {}

    for type_name in CRITTER_TYPES:
        var config = CRITTER_TYPES[type_name]
        var env = config["environment"]

        # Skip critters not for current environment
        if env == "overworld" and in_mine:
            continue
        if env == "mine" and not in_mine:
            continue

        var grid: int = config["grid"]
        var chance: int = config["spawn_chance"]
        var hash_offset: int = config["hash_offset"]

        # Iterate coarse grid within expanded rect
        var gx_start = int(floorf(float(expanded.position.x) / grid))
        var gx_end = int(ceilf(float(expanded.end.x) / grid))
        var gy_start = int(floorf(float(expanded.position.y) / grid))
        var gy_end = int(ceilf(float(expanded.end.y) / grid))

        for gx in range(gx_start, gx_end + 1):
            for gy in range(gy_start, gy_end + 1):
                var hash_val = world._position_hash(
                    gx * grid + hash_offset,
                    gy * grid + hash_offset
                )
                if hash_val % chance != 0:
                    continue

                var key = "%d,%d,%s" % [gx, gy, type_name]
                desired_keys[key] = true

                if _active_critters.has(key):
                    continue
                if _active_critters.size() >= MAX_CRITTERS:
                    continue

                # Spawn critter at grid cell center in world coords
                var tile_x = gx * grid
                var tile_y = gy * grid
                var spawn_pos = Vector2(
                    tile_x * tile_size.x + tile_size.x * 0.5,
                    tile_y * tile_size.y + tile_size.y * 0.5
                )

                var critter = Node2D.new()
                critter.set_script(CritterScene)
                critter.setup(spawn_pos, _textures[type_name], hash_val, config)
                add_child(critter)
                _active_critters[key] = critter

    # Despawn critters no longer in range
    var keys_to_remove: Array = []
    for key in _active_critters:
        if not desired_keys.has(key):
            keys_to_remove.append(key)

    for key in keys_to_remove:
        var critter = _active_critters[key]
        if is_instance_valid(critter):
            critter.queue_free()
        _active_critters.erase(key)

    _update_critter_positions(world)


func _update_critter_positions(_world: TileMapLayer) -> void:
    # Use physics frames for deterministic time across clients
    var time = float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)
    for key in _active_critters:
        var critter = _active_critters[key]
        if is_instance_valid(critter):
            critter.update_position(time)


func _clear_all_critters() -> void:
    for key in _active_critters:
        var critter = _active_critters[key]
        if is_instance_valid(critter):
            critter.queue_free()
    _active_critters.clear()


func _get_world() -> TileMapLayer:
    var worlds = get_tree().get_nodes_in_group("world")
    if worlds.size() > 0:
        return worlds[0]
    return null
