class_name TileDamageSystem
extends RefCounted

var _world: TileMapLayer

# === TILE HEALTH BAR ===
class TileHealthBar extends Node2D:
    var ratio: float = 1.0
    var bar_width: float = 12.0
    var bar_height: float = 2.0

    func _draw() -> void:
        var bg_rect = Rect2(-bar_width / 2.0, 0, bar_width, bar_height)
        draw_rect(bg_rect, Color(0.15, 0.15, 0.15, 0.8))
        var fill_width = bar_width * ratio
        if fill_width > 0:
            var fill_rect = Rect2(-bar_width / 2.0, 0, fill_width, bar_height)
            var color: Color
            if ratio > 0.5:
                color = Color(0.2, 0.8, 0.2)
            elif ratio > 0.25:
                color = Color(0.9, 0.8, 0.1)
            else:
                color = Color(0.9, 0.2, 0.1)
            draw_rect(fill_rect, color)

    func set_ratio(new_ratio: float) -> void:
        ratio = clampf(new_ratio, 0.0, 1.0)
        queue_redraw()

# Tile health tracking
var tile_health: Dictionary = {}  # Vector2i -> int
var roof_health: Dictionary = {}  # Vector2i -> int

# Health bar tracking
var _tile_health_bars: Dictionary = {}  # Vector2i -> TileHealthBar
var _roof_health_bars: Dictionary = {}  # Vector2i -> TileHealthBar

# Tile durability constants
const BASE_TILE_DURABILITY: int = 10
const WOOD_WALL_DURABILITY: int = 20
const STONE_WALL_DURABILITY: int = 30
const IRON_WALL_DURABILITY: int = 60
const GOLD_WALL_DURABILITY: int = 120
const IRON_ORE_DURABILITY: int = 20
const CAVE_WALL_DURABILITY: int = 10
const GOLD_ORE_DURABILITY: int = 20
const COAL_ORE_DURABILITY: int = 15

# Tool strength constants
const PLASTIC_TOOL_STRENGTH: int = 10
const WOOD_TOOL_STRENGTH: int = 5
const STONE_TOOL_STRENGTH: int = 3
const IRON_TOOL_STRENGTH: int = 1
const GOLD_TOOL_STRENGTH: int = 1

# Health regeneration
const TILE_REGEN_AMOUNT: int = 1



func init(world: TileMapLayer) -> void:
    _world = world


func get_tile_durability(tile_type: String) -> int:
    match tile_type:
        "wood_wall":
            return WOOD_WALL_DURABILITY
        "stone_wall":
            return STONE_WALL_DURABILITY
        "iron_wall":
            return IRON_WALL_DURABILITY
        "gold_wall":
            return GOLD_WALL_DURABILITY
        "iron_ore":
            return IRON_ORE_DURABILITY
        "cave_wall":
            return CAVE_WALL_DURABILITY
        "gold_ore":
            return GOLD_ORE_DURABILITY
        "coal_ore":
            return COAL_ORE_DURABILITY
        _:
            return BASE_TILE_DURABILITY


func get_tool_strength(tool_id: String) -> int:
    if tool_id.begins_with("gold_"):
        return GOLD_TOOL_STRENGTH
    elif tool_id.begins_with("iron_"):
        return IRON_TOOL_STRENGTH
    elif tool_id.begins_with("stone_"):
        return STONE_TOOL_STRENGTH
    elif tool_id.begins_with("wood_"):
        return WOOD_TOOL_STRENGTH
    else:
        return PLASTIC_TOOL_STRENGTH


func get_tile_type_string(source_id: int) -> String:
    match source_id:
        1: return "rock"
        2: return "tree"
        3: return "box"
        4: return "wood_wall"
        5: return "stone_wall"
        6: return "furnace"
        7: return "iron_ore"
        8: return "iron_wall"
        9: return "wood_floor"
        10: return "stone_floor"
        11: return "gold_wall"
        12: return "mine_entrance"
        13: return "mine_exit"
        14: return "cave_wall"
        15: return "gold_ore"
        16: return "cave_floor"
        17: return "torch"
        18: return "coal_ore"
        19: return "campfire"
        20: return "sapling"
        _: return "grass"


func is_correct_tool(tool_id: String, source_id: int) -> bool:
    var is_pick = tool_id in ["wood_pick", "stone_pick", "iron_pick", "gold_pick"]
    var is_axe = tool_id in ["axe", "wood_axe", "stone_axe", "iron_axe", "gold_axe"]

    match source_id:
        1:  # Rock - requires pick
            return is_pick
        2, 20:  # Tree/Sapling - requires axe
            return is_axe
        3:  # Box - any tool works
            return true
        4, 5, 8, 11:  # Walls - any tool works
            return true
        6:  # Furnace - requires any pick
            return is_pick
        7:  # Iron ore - requires pick
            return is_pick
        9, 10:  # Floors - any tool works
            return true
        12:  # Mine entrance - breakable in sandbox with any tool
            return GameMode.is_sandbox()
        13, 14, 16:  # Mine exit/cave wall/cave floor - unbreakable
            return false
        15:  # Gold ore - requires pick
            return is_pick
        17:  # Torch - any tool works
            return true
        18:  # Coal ore - requires pick
            return is_pick
        19:  # Campfire - any tool works
            return true
        _:
            return false


func calculate_damage(tool_id: String) -> int:
    var tool_strength = get_tool_strength(tool_id)
    return ceili(float(BASE_TILE_DURABILITY) / tool_strength)


func apply_tile_damage(tile_pos: Vector2i, tile_type: String, damage: int) -> int:
    ## Apply damage to a tile. Returns remaining health (0 = broken).
    if not tile_health.has(tile_pos):
        tile_health[tile_pos] = get_tile_durability(tile_type)
    tile_health[tile_pos] -= damage
    if tile_health[tile_pos] <= 0:
        tile_health.erase(tile_pos)
        return 0
    return tile_health[tile_pos]


func get_tile_health_ratio(tile_pos: Vector2i, tile_type: String) -> float:
    if not tile_health.has(tile_pos):
        return 1.0
    var max_hp = get_tile_durability(tile_type)
    return float(tile_health[tile_pos]) / float(max_hp)


func apply_roof_damage(tile_pos: Vector2i, roof_item_id: String, damage: int) -> int:
    ## Apply damage to a roof. Returns remaining health (0 = broken).
    if not roof_health.has(tile_pos):
        roof_health[tile_pos] = Constants.ROOF_DURABILITY[roof_item_id]
    roof_health[tile_pos] -= damage
    if roof_health[tile_pos] <= 0:
        roof_health.erase(tile_pos)
        return 0
    return roof_health[tile_pos]


func get_roof_health_ratio(tile_pos: Vector2i, roof_item_id: String) -> float:
    if not roof_health.has(tile_pos):
        return 1.0
    var max_hp = Constants.ROOF_DURABILITY[roof_item_id]
    return float(roof_health[tile_pos]) / float(max_hp)


# === HEALTH BARS ===

func show_health_bar(tile_pos: Vector2i, ratio: float, is_roof: bool, roof_layer: TileMapLayer = null) -> void:
    var bars = _roof_health_bars if is_roof else _tile_health_bars
    if ratio >= 1.0 or ratio <= 0.0:
        remove_health_bar(tile_pos, is_roof)
        return

    if bars.has(tile_pos):
        var bar: TileHealthBar = bars[tile_pos]
        if is_instance_valid(bar):
            bar.set_ratio(ratio)
            return

    var bar = TileHealthBar.new()
    bar.set_ratio(ratio)
    if is_roof:
        if roof_layer:
            bar.position = roof_layer.map_to_local(tile_pos) + Vector2(0, 10)
            bar.z_index = 21
            roof_layer.add_child(bar)
        else:
            return
    else:
        bar.position = _world.map_to_local(tile_pos) + Vector2(0, 10)
        bar.z_index = 10
        _world.add_child(bar)
    bars[tile_pos] = bar


func remove_health_bar(tile_pos: Vector2i, is_roof: bool) -> void:
    var bars = _roof_health_bars if is_roof else _tile_health_bars
    if bars.has(tile_pos):
        var bar = bars[tile_pos]
        if is_instance_valid(bar):
            bar.queue_free()
        bars.erase(tile_pos)


func clear_all_health_bars() -> void:
    for tile_pos in _tile_health_bars:
        var bar = _tile_health_bars[tile_pos]
        if is_instance_valid(bar):
            bar.queue_free()
    _tile_health_bars.clear()
    for tile_pos in _roof_health_bars:
        var bar = _roof_health_bars[tile_pos]
        if is_instance_valid(bar):
            bar.queue_free()
    _roof_health_bars.clear()


