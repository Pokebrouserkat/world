class_name DayNightCycle
extends RefCounted

var _world: TileMapLayer

var game_time: float = 0.0
const DAY_LENGTH: float = 600.0

var _modulate: CanvasModulate = null
var _flicker_time: float = 0.0


func init(world: TileMapLayer) -> void:
    _world = world
    _modulate = CanvasModulate.new()
    _modulate.name = "DayNightModulate"
    _modulate.color = Color(1.0, 1.0, 1.0)
    world.get_parent().add_child.call_deferred(_modulate)


func update(delta: float, torch_lights: Dictionary, campfire: CampfireManager, player_in_mine: bool) -> void:
    # Advance time
    game_time += delta
    if game_time >= DAY_LENGTH:
        game_time -= DAY_LENGTH
    _flicker_time += delta

    # Update modulate color
    _update_modulate(torch_lights, campfire, player_in_mine)

    # Update fire flicker visuals
    _update_fire_flicker(torch_lights, campfire)


func _update_modulate(torch_lights: Dictionary, campfire: CampfireManager, player_in_mine: bool) -> void:
    if not _modulate or not _modulate.visible:
        return
    var time_ratio = game_time / DAY_LENGTH
    var day_color = Color(1.0, 1.0, 1.0)
    var night_color = Color(0.15, 0.15, 0.35)
    var color: Color
    var darkness: float  # 0.0 = full day, 1.0 = full night
    if time_ratio < 0.15:
        # Dawn: dark blue -> white
        var t = time_ratio / 0.15
        color = night_color.lerp(day_color, t)
        darkness = 1.0 - t
    elif time_ratio < 0.55:
        # Day: white
        color = day_color
        darkness = 0.0
    elif time_ratio < 0.70:
        # Dusk: white -> dark blue
        var t = (time_ratio - 0.55) / 0.15
        color = day_color.lerp(night_color, t)
        darkness = t
    else:
        # Night: dark blue
        color = night_color
        darkness = 1.0
    _modulate.color = color
    # In mines, lights should always be at full brightness regardless of surface time
    if player_in_mine:
        darkness = 1.0
    # Scale light energy so they don't blow out during daytime
    # Flicker intensity scales with darkness so it's most visible at night
    var ft = _flicker_time
    var torch_flicker = (
        sin(ft * 9.5 + 2.0) * 0.12 +
        sin(ft * 15.3 + 1.0) * 0.08 +
        sin(ft * 21.0 + 3.0) * 0.06
    )
    var torch_base = lerpf(0.3, 0.8, darkness)
    var energy_flicker_strength = 0.1 + darkness * 0.15
    for light in torch_lights.values():
        if is_instance_valid(light):
            light.energy = torch_base + torch_flicker * energy_flicker_strength
    campfire.update_energy(darkness, ft)
    # Update player night light
    _update_player_night_light(darkness, player_in_mine)


func _update_fire_flicker(torch_lights: Dictionary, campfire: CampfireManager) -> void:
    var t = _flicker_time
    campfire.update_flicker(t)
    # Torches: subtler flicker, offset phase so they don't sync with campfires
    var torch_flicker = (
        sin(t * 9.5 + 2.0) * 0.12 +
        sin(t * 15.3 + 1.0) * 0.08 +
        sin(t * 21.0 + 3.0) * 0.06
    )
    for light in torch_lights.values():
        if is_instance_valid(light):
            var base_scale = 0.8
            light.texture_scale = base_scale + torch_flicker * 0.04
            light.color = Color(1.0, 0.8 + torch_flicker * 0.06, 0.4 + torch_flicker * 0.04)


func _update_player_night_light(darkness: float, player_in_mine: bool) -> void:
    if player_in_mine:
        return  # Mine light handles cave illumination
    var player = _get_local_player()
    if player and player.has_method("set_night_light_energy"):
        player.set_night_light_energy(darkness)


func _get_local_player() -> CharacterBody2D:
    var players = _world.get_tree().get_nodes_in_group("player")
    for player in players:
        if player.is_local_player():
            return player
    return null


## Set visibility of the day/night modulate (hidden when in mine)
func set_visible(visible: bool) -> void:
    if _modulate:
        _modulate.visible = visible
