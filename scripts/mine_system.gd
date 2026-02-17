class_name MineSystem
extends RefCounted

var _world: TileMapLayer

# Mine state
var known_mines: Dictionary = {}  # "x,y" -> {origin: Vector2i, exit_pos: Vector2i}
var player_in_mine: bool = false
var current_mine_entrance: Vector2i = Vector2i.ZERO
var mine_level: int = 0  # 0 = overworld, 1+ = mine depth
var mine_return_stack: Array = []  # Stack of return positions (Vector2)

# Mine lighting state
var lighting_active: bool = false
var _mine_modulate: CanvasModulate = null

# Torch lights
var torch_lights: Dictionary = {}  # Vector2i -> PointLight2D
var _torch_glow_texture: GradientTexture2D = null
var _torch_glow_material: ShaderMaterial = null
var _torch_light_texture: Texture2D = null


func init(world: TileMapLayer) -> void:
    _world = world


func get_torch_light_texture() -> Texture2D:
    if _torch_light_texture == null:
        _torch_light_texture = load("res://graphics/light_radial.png")
    return _torch_light_texture


func _get_torch_glow_texture() -> GradientTexture2D:
    if _torch_glow_texture == null:
        var gradient = Gradient.new()
        gradient.set_color(0, Color.WHITE)
        gradient.set_color(1, Color.TRANSPARENT)
        _torch_glow_texture = GradientTexture2D.new()
        _torch_glow_texture.gradient = gradient
        _torch_glow_texture.width = 256
        _torch_glow_texture.height = 256
        _torch_glow_texture.fill = GradientTexture2D.FILL_RADIAL
        _torch_glow_texture.fill_from = Vector2(0.5, 0.5)
        _torch_glow_texture.fill_to = Vector2(0.5, 0.0)
    return _torch_glow_texture


func _get_torch_glow_material() -> ShaderMaterial:
    if _torch_glow_material == null:
        var shader = Shader.new()
        shader.code = "shader_type canvas_item;\nrender_mode unshaded, blend_add;"
        _torch_glow_material = ShaderMaterial.new()
        _torch_glow_material.shader = shader
    return _torch_glow_material


func add_torch_light(tile_pos: Vector2i) -> void:
    if torch_lights.has(tile_pos):
        return
    var light = PointLight2D.new()
    light.texture = _get_torch_glow_texture()
    light.texture_scale = 0.8
    light.energy = 0.8
    light.color = Color(1.0, 0.8, 0.4)
    light.shadow_enabled = true
    light.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
    light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
    light.shadow_filter_smooth = 1.0
    light.position = _world.map_to_local(tile_pos)
    _world.add_child(light)

    # Unshaded additive glow sprite bypasses CanvasModulate and the
    # GL Compatibility per-canvas-item light limit (16), so every torch
    # is always visibly lit regardless of how many are on screen.
    var glow = Sprite2D.new()
    glow.texture = _get_torch_glow_texture()
    glow.material = _get_torch_glow_material()
    glow.scale = Vector2(0.6, 0.6)
    glow.modulate = Color(1.0, 0.7, 0.3, 0.3)
    light.add_child(glow)

    torch_lights[tile_pos] = light


func remove_torch_light(tile_pos: Vector2i) -> void:
    if torch_lights.has(tile_pos):
        var light = torch_lights[tile_pos]
        if is_instance_valid(light):
            light.queue_free()
        torch_lights.erase(tile_pos)


func clear_all_torch_lights() -> void:
    for tile_pos in torch_lights:
        var light = torch_lights[tile_pos]
        if is_instance_valid(light):
            light.queue_free()
    torch_lights.clear()


func apply_mine_lighting(enabled: bool, day_night: DayNightCycle) -> void:
    lighting_active = enabled
    _world.occlusion_enabled = enabled

    if enabled:
        if not _mine_modulate:
            _mine_modulate = CanvasModulate.new()
            _mine_modulate.name = "MineModulate"
            _mine_modulate.color = Color(0.05, 0.05, 0.08)
            _world.get_parent().add_child(_mine_modulate)
        _mine_modulate.visible = true
        day_night.set_visible(false)
    else:
        if _mine_modulate:
            _mine_modulate.visible = false
        day_night.set_visible(true)

    # Toggle player's mine light
    var player = _get_local_player()
    if player and player.has_method("set_mine_light"):
        player.set_mine_light(enabled)


func enter_mine(entrance_pos: Vector2i, tile_modifications: Dictionary, generated_tiles: Dictionary, damage: TileDamageSystem) -> void:
    # Block in multiplayer
    if NetworkManager.is_connected_to_game():
        return

    var new_level = mine_level + 1

    var key = "%d,%d" % [entrance_pos.x, entrance_pos.y]
    if not known_mines.has(key):
        # Generate the mine and write tiles into tile_modifications
        var result = MineGenerator.generate(entrance_pos, new_level)
        var mine_tiles: Dictionary = result["tiles"]
        for pos in mine_tiles:
            tile_modifications[pos] = mine_tiles[pos]
        known_mines[key] = {
            "origin": MineGenerator.get_mine_origin(entrance_pos, new_level),
            "exit_pos": result["exit_pos"]
        }

    # Save current position to return stack
    var player = _get_local_player()
    if not player:
        return
    mine_return_stack.push_back({"x": player.global_position.x, "y": player.global_position.y})

    # Set mine state
    mine_level = new_level
    player_in_mine = true
    current_mine_entrance = entrance_pos

    # Clear health bars and torch lights before tile reload
    damage.clear_all_health_bars()
    clear_all_torch_lights()

    # Force tile reload
    generated_tiles.clear()
    _world._last_rect = Rect2i()

    # Teleport player to mine exit (spawn point)
    var exit_pos: Vector2i = known_mines[key]["exit_pos"]
    player.global_position = _world.map_to_local(exit_pos) + Vector2(0, 16)

    # Snap camera to new position immediately (skip smoothing)
    var camera = player.get_node_or_null("Camera2D") as Camera2D
    if camera:
        camera.reset_smoothing()


func exit_mine(generated_tiles: Dictionary, damage: TileDamageSystem) -> void:
    # Pop return position from stack
    var return_pos = Vector2.ZERO
    if mine_return_stack.size() > 0:
        var pos_data = mine_return_stack.pop_back()
        return_pos = Vector2(pos_data["x"], pos_data["y"])

    mine_level = maxi(mine_level - 1, 0)
    player_in_mine = mine_level > 0

    # Clear health bars and torch lights before tile reload
    damage.clear_all_health_bars()
    clear_all_torch_lights()

    # Force tile reload
    generated_tiles.clear()
    _world._last_rect = Rect2i()

    # Teleport player back to previous position
    var player = _get_local_player()
    if player:
        player.global_position = return_pos

        # Snap camera to new position immediately (skip smoothing)
        var camera = player.get_node_or_null("Camera2D") as Camera2D
        if camera:
            camera.reset_smoothing()


func _get_local_player() -> CharacterBody2D:
    var players = _world.get_tree().get_nodes_in_group("player")
    for player in players:
        if player.is_local_player():
            return player
    return null
