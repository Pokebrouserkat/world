class_name HitEffects
extends RefCounted

var _world: TileMapLayer

# Hit effect textures (lazy-loaded)
var _flash_texture: ImageTexture = null
var _particle_texture: ImageTexture = null
var _flash_shader: Shader = null

const ROOF_HIT_COLORS = {
    0: Color(0.55, 0.35, 0.17),  # Wood roof - brown
    1: Color(0.55, 0.55, 0.55),  # Stone roof - gray
    2: Color(0.78, 0.78, 0.82),  # Iron roof - silver
    3: Color(0.85, 0.7, 0.2),    # Gold roof - golden
}


func init(world: TileMapLayer) -> void:
    _world = world


func show_tile_hit(tile_pos: Vector2i, source_id: int) -> void:
    var local_pos = _world.map_to_local(tile_pos)
    # Adjust position for tree's texture_origin offset (drawn 12px higher)
    if source_id == 2:
        local_pos.y -= 12
    _create_hit_particles(local_pos, source_id, _world)
    _create_hit_flash(local_pos, source_id, _world)


func show_roof_hit(tile_pos: Vector2i, roof_source_id: int, roof_layer: TileMapLayer) -> void:
    if not roof_layer:
        return
    var local_pos = roof_layer.map_to_local(tile_pos)

    # Particles
    var particles = CPUParticles2D.new()
    particles.position = local_pos
    particles.texture = _get_particle_texture()
    particles.emitting = true
    particles.one_shot = true
    particles.explosiveness = 1.0
    particles.amount = 6
    particles.lifetime = 0.3
    particles.direction = Vector2(0, -1)
    particles.spread = 180.0
    particles.initial_velocity_min = 15.0
    particles.initial_velocity_max = 40.0
    particles.gravity = Vector2(0, 80)
    particles.color = ROOF_HIT_COLORS.get(roof_source_id, Color(0.5, 0.5, 0.5))
    particles.z_index = 21  # Above roof layer (z=20)
    roof_layer.add_child(particles)
    _world.get_tree().create_timer(1.0).timeout.connect(particles.queue_free)

    # Flash
    var flash = Sprite2D.new()
    var atlas_source = roof_layer.tile_set.get_source(roof_source_id) as TileSetAtlasSource
    if atlas_source:
        flash.texture = atlas_source.texture
        var mat = ShaderMaterial.new()
        mat.shader = _get_flash_shader()
        flash.material = mat
    else:
        flash.texture = _get_flash_texture()
    flash.position = local_pos
    flash.modulate = Color(1, 1, 1, 0.5)
    flash.z_index = 21
    roof_layer.add_child(flash)
    var flash_tween = _world.create_tween()
    flash_tween.tween_property(flash, "modulate:a", 0.0, 0.1)
    flash_tween.tween_callback(flash.queue_free)


func _get_hit_color(source_id: int) -> Color:
    match source_id:
        1: return Color(0.6, 0.6, 0.6)    # Rock - gray
        2: return Color(0.35, 0.55, 0.2)   # Tree - green-brown
        4: return Color(0.6, 0.4, 0.2)     # Wood wall - light brown
        5: return Color(0.5, 0.5, 0.5)     # Stone wall - gray
        6: return Color(0.3, 0.3, 0.3)     # Furnace - dark gray
        7: return Color(0.7, 0.5, 0.3)     # Iron ore - brownish
        8: return Color(0.7, 0.7, 0.7)     # Iron wall - light gray
        9: return Color(0.55, 0.35, 0.17)  # Wood floor - brown
        10: return Color(0.55, 0.55, 0.55) # Stone floor - gray
        11: return Color(0.85, 0.7, 0.2)   # Gold wall - golden
        14: return Color(0.3, 0.28, 0.25)  # Cave wall - dark
        15: return Color(0.85, 0.7, 0.2)   # Gold ore - golden
        17: return Color(0.8, 0.5, 0.2)    # Torch - orange
        18: return Color(0.15, 0.15, 0.15) # Coal ore - dark
        19: return Color(0.8, 0.4, 0.1)    # Campfire - orange
        _: return Color(0.5, 0.5, 0.5)


func _get_particle_texture() -> ImageTexture:
    if _particle_texture == null:
        var img = Image.create(2, 2, false, Image.FORMAT_RGBA8)
        img.fill(Color.WHITE)
        _particle_texture = ImageTexture.create_from_image(img)
    return _particle_texture


func _get_flash_texture() -> ImageTexture:
    if _flash_texture == null:
        var ts = _world.tile_set.tile_size
        var img = Image.create(ts.x, ts.y, false, Image.FORMAT_RGBA8)
        img.fill(Color.WHITE)
        _flash_texture = ImageTexture.create_from_image(img)
    return _flash_texture


func _get_flash_shader() -> Shader:
    if _flash_shader == null:
        _flash_shader = Shader.new()
        _flash_shader.code = "shader_type canvas_item;\nvoid fragment() { COLOR = vec4(1.0, 1.0, 1.0, texture(TEXTURE, UV).a * COLOR.a); }"
    return _flash_shader


func _create_hit_particles(local_pos: Vector2, source_id: int, parent: Node) -> void:
    var particles = CPUParticles2D.new()
    particles.position = local_pos
    particles.texture = _get_particle_texture()
    particles.emitting = true
    particles.one_shot = true
    particles.explosiveness = 1.0
    particles.amount = 6
    particles.lifetime = 0.3
    particles.direction = Vector2(0, -1)
    particles.spread = 180.0
    particles.initial_velocity_min = 15.0
    particles.initial_velocity_max = 40.0
    particles.gravity = Vector2(0, 80)
    particles.color = _get_hit_color(source_id)
    # Floors render below player
    if source_id == 9 or source_id == 10:
        particles.z_index = -1
    else:
        particles.z_index = 10
    parent.add_child(particles)

    # Auto-cleanup after particles finish
    _world.get_tree().create_timer(1.0).timeout.connect(particles.queue_free)


func _create_hit_flash(local_pos: Vector2, source_id: int, parent: Node) -> void:
    var flash = Sprite2D.new()
    # Use the tile's own texture so the flash matches its shape
    var atlas_source = _world.tile_set.get_source(source_id) as TileSetAtlasSource
    if atlas_source:
        flash.texture = atlas_source.texture
        var mat = ShaderMaterial.new()
        mat.shader = _get_flash_shader()
        flash.material = mat
    else:
        flash.texture = _get_flash_texture()
    flash.position = local_pos
    flash.modulate = Color(1, 1, 1, 0.5)
    # Floors render below player
    if source_id == 9 or source_id == 10:
        flash.z_index = -1
    else:
        flash.z_index = 10
    parent.add_child(flash)

    var tween = _world.create_tween()
    tween.tween_property(flash, "modulate:a", 0.0, 0.1)
    tween.tween_callback(flash.queue_free)
