extends TileMapLayer

# Tile type constants
enum TileType {
	GRASS = 0,
	ROCK = 1,
	TREE = 2,
	BOX = 3,
	WOOD_WALL = 4,
	STONE_WALL = 5,
	FURNACE = 6,
	IRON_ORE = 7,
	IRON_WALL = 8,
	WOOD_FLOOR = 9,
	STONE_FLOOR = 10,
	GOLD_WALL = 11,
	MINE_ENTRANCE = 12,
	MINE_EXIT = 13,
	CAVE_WALL = 14,
	GOLD_ORE = 15,
	CAVE_FLOOR = 16,
	TORCH = 17,
	COAL_ORE = 18,
	CAMPFIRE = 19
}

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

# Box inventory storage: Dictionary[Vector2i, Array[Item]]
var _box_contents: Dictionary = {}
const BOX_SLOT_COUNT: int = 9

# Furnace state storage: Dictionary[Vector2i, {input_item, output_item, smelt_progress}]
var _furnace_states: Dictionary = {}

# === ROOF LAYER ===
var roof_layer: TileMapLayer = null
var _roof_modifications: Dictionary = {}  # Vector2i -> source_id (0=wood,1=stone,2=iron,3=gold)
var _roof_health: Dictionary = {}  # Vector2i -> int

const ROOF_ITEMS: Array[String] = ["wood_roof", "stone_roof", "iron_roof", "gold_roof"]

const ROOF_DURABILITY = {
	"wood_roof": 20,
	"stone_roof": 30,
	"iron_roof": 60,
	"gold_roof": 120,
}

const ROOF_HIT_COLORS = {
	0: Color(0.55, 0.35, 0.17),  # Wood roof - brown
	1: Color(0.55, 0.55, 0.55),  # Stone roof - gray
	2: Color(0.78, 0.78, 0.82),  # Iron roof - silver
	3: Color(0.85, 0.7, 0.2),    # Gold roof - golden
}

const MINE_DARKNESS_SOURCE: int = 4  # Roof layer source ID for mine darkness overlay
const ROOF_REVEAL_RADIUS = {
	0: 20.0,   # Wood roof
	1: 28.0,   # Stone roof
	2: 40.0,   # Iron roof
	3: 10.0,   # Gold roof
	4: 1.0,    # Mine darkness
}
const ROOF_REVEAL_EDGE_BLUR = {
	0: 0.0,    # Wood roof - sharp
	1: 0.0,    # Stone roof - sharp
	2: 0.0,    # Iron roof - sharp
	3: 160.0,  # Gold roof - blurry
	4: 160.0,  # Mine darkness - blurry
}
const ROOF_REVEAL_DURATION: float = 0.25  # seconds per transition
var _roof_reveal_radius: float = 0.0
var _roof_fade_width: float = 0.0
var _roof_reveal_speed: float = 0.0
var _roof_blur_speed: float = 0.0
var _roof_reveal_target: float = 0.0
var _roof_blur_target: float = 0.0

# Atlas source ID for each tile type
const TILE_SOURCE = {
	TileType.GRASS: 0,
	TileType.ROCK: 1,
	TileType.TREE: 2,
	TileType.BOX: 3,
	TileType.WOOD_WALL: 4,
	TileType.STONE_WALL: 5,
	TileType.FURNACE: 6,
	TileType.IRON_ORE: 7,
	TileType.IRON_WALL: 8,
	TileType.WOOD_FLOOR: 9,
	TileType.STONE_FLOOR: 10,
	TileType.GOLD_WALL: 11,
	TileType.MINE_ENTRANCE: 12,
	TileType.MINE_EXIT: 13,
	TileType.CAVE_WALL: 14,
	TileType.GOLD_ORE: 15,
	TileType.CAVE_FLOOR: 16,
	TileType.TORCH: 17,
	TileType.COAL_ORE: 18,
	TileType.CAMPFIRE: 19
}

# Atlas coordinates for each tile type (within their source)
const TILE_COORDS = {
	TileType.GRASS: Vector2i(0, 0),
	TileType.ROCK: Vector2i(0, 0),
	TileType.TREE: Vector2i(0, 0),
	TileType.BOX: Vector2i(0, 0),
	TileType.WOOD_WALL: Vector2i(0, 0),
	TileType.STONE_WALL: Vector2i(0, 0),
	TileType.FURNACE: Vector2i(0, 0),
	TileType.IRON_ORE: Vector2i(0, 0),
	TileType.IRON_WALL: Vector2i(0, 0),
	TileType.WOOD_FLOOR: Vector2i(0, 0),
	TileType.STONE_FLOOR: Vector2i(0, 0),
	TileType.GOLD_WALL: Vector2i(0, 0),
	TileType.MINE_ENTRANCE: Vector2i(0, 0),
	TileType.MINE_EXIT: Vector2i(0, 0),
	TileType.CAVE_WALL: Vector2i(0, 0),
	TileType.GOLD_ORE: Vector2i(0, 0),
	TileType.CAVE_FLOOR: Vector2i(0, 0),
	TileType.TORCH: Vector2i(0, 0),
	TileType.COAL_ORE: Vector2i(0, 0),
	TileType.CAMPFIRE: Vector2i(0, 0)
}

# Chance for a rock to spawn (1 in N tiles)
const ROCK_SPAWN_CHANCE: int = 40

# Chance for a tree to spawn on grass (1 in N grass tiles)
const TREE_SPAWN_CHANCE: int = 40

# Chance for iron ore to spawn (1 in N tiles) - very rare
const IRON_ORE_SPAWN_CHANCE: int = 2000

# Chance for mine entrance to spawn (1 in N tiles)
const MINE_ENTRANCE_SPAWN_CHANCE: int = 5000

# Cave tile durabilities
const CAVE_WALL_DURABILITY: int = 10
const GOLD_ORE_DURABILITY: int = 20
const COAL_ORE_DURABILITY: int = 15

# Seed for deterministic world generation
const WORLD_SEED: int = 12345


# Buffer of extra tiles to generate beyond the visible area
@export var tile_buffer: int = 2

# Track which tiles have been generated
var _generated_tiles: Dictionary = {}

# Cache last rect to avoid redundant work
var _last_rect: Rect2i

# === MULTIPLAYER STATE (Host-authoritative) ===

# Tile health tracking (moved from player.gd)
var _tile_health: Dictionary = {}  # Vector2i -> int

# Health bar tracking
var _tile_health_bars: Dictionary = {}  # Vector2i -> TileHealthBar
var _roof_health_bars: Dictionary = {}  # Vector2i -> TileHealthBar

# Tile modifications for late-joiners (tiles changed from their procedural state)
var _tile_modifications: Dictionary = {}  # Vector2i -> source_id

# Dropped items tracking
var _dropped_items: Dictionary = {}  # network_id -> DroppedItem
var _next_item_id: int = 0

var dropped_item_scene: PackedScene = preload("res://scenes/dropped_item.tscn")

# === MINE STATE ===
var _known_mines: Dictionary = {}  # "x,y" -> {origin: Vector2i, exit_pos: Vector2i}
var player_in_mine: bool = false
var _current_mine_entrance: Vector2i = Vector2i.ZERO
var _mine_level: int = 0  # 0 = overworld, 1+ = mine depth
var _mine_return_stack: Array = []  # Stack of return positions (Vector2)

# Mine lighting state
var _mine_lighting_active: bool = false
var _mine_modulate: CanvasModulate = null
var _torch_lights: Dictionary = {}  # Vector2i -> PointLight2D
var _torch_glow_texture: GradientTexture2D = null
var _torch_glow_material: ShaderMaterial = null
var _campfire = CampfireManager.new()
var _torch_light_texture: Texture2D = null
var _flicker_time: float = 0.0

# Day/night cycle
var game_time: float = 0.0
const DAY_LENGTH: float = 300.0
var _day_night_modulate: CanvasModulate = null

# Hit effect textures (lazy-loaded)
var _flash_texture: ImageTexture = null
var _particle_texture: ImageTexture = null
var _flash_shader: Shader = null

# Tile durability constants
const BASE_TILE_DURABILITY: int = 10
const WOOD_WALL_DURABILITY: int = 20
const STONE_WALL_DURABILITY: int = 30
const IRON_WALL_DURABILITY: int = 60
const GOLD_WALL_DURABILITY: int = 120
const IRON_ORE_DURABILITY: int = 20
const PLASTIC_TOOL_STRENGTH: int = 10
const WOOD_TOOL_STRENGTH: int = 5
const STONE_TOOL_STRENGTH: int = 3
const IRON_TOOL_STRENGTH: int = 1
const GOLD_TOOL_STRENGTH: int = 1

# Health regeneration
const TILE_REGEN_INTERVAL: float = 2.0
const TILE_REGEN_AMOUNT: int = 1


func _ready() -> void:
	add_to_group("world")
	_campfire.init(self)
	_setup_tile_physics()
	_setup_tile_occlusion()
	_update_tiles()

	# Find the roof layer sibling
	roof_layer = get_parent().get_node_or_null("RoofLayer") as TileMapLayer

	# Connect to NetworkManager for late-joiner sync
	NetworkManager.player_connected.connect(_on_player_connected)

	# Health regeneration timer (host-only logic in callback)
	var regen_timer = Timer.new()
	regen_timer.wait_time = TILE_REGEN_INTERVAL
	regen_timer.autostart = true
	regen_timer.timeout.connect(_on_regen_tick)
	add_child(regen_timer)

	# Day/night cycle CanvasModulate
	_day_night_modulate = CanvasModulate.new()
	_day_night_modulate.name = "DayNightModulate"
	_day_night_modulate.color = Color(1.0, 1.0, 1.0)
	get_parent().add_child.call_deferred(_day_night_modulate)


func _setup_tile_physics() -> void:
	# Update rock tile collision polygon to match tile size
	if tile_set:
		var tile_size = tile_set.tile_size
		var half_w = tile_size.x / 2.0
		var half_h = tile_size.y / 2.0

		# Get the rock atlas source (source ID 1)
		var rock_source = tile_set.get_source(TILE_SOURCE[TileType.ROCK]) as TileSetAtlasSource
		if rock_source:
			var tile_data = rock_source.get_tile_data(TILE_COORDS[TileType.ROCK], 0)
			if tile_data:
				# Set collision polygon to match tile size
				var polygon = PackedVector2Array([
					Vector2(-half_w, -half_h),
					Vector2(half_w, -half_h),
					Vector2(half_w, half_h),
					Vector2(-half_w, half_h)
				])
				tile_data.set_collision_polygon_points(0, 0, polygon)


func _setup_tile_occlusion() -> void:
	if not tile_set:
		return
	# Add occlusion layer to tileset for Light2D shadow casting
	if tile_set.get_occlusion_layers_count() == 0:
		tile_set.add_occlusion_layer()

	var tile_size = tile_set.tile_size
	var half_w = tile_size.x / 2.0
	var half_h = tile_size.y / 2.0
	var polygon = PackedVector2Array([
		Vector2(-half_w, -half_h),
		Vector2(half_w, -half_h),
		Vector2(half_w, half_h),
		Vector2(-half_w, half_h)
	])

	# Add occlusion polygons to all solid tiles that should block light
	var solid_tiles = [
		TileType.ROCK, TileType.CAVE_WALL, TileType.GOLD_ORE, TileType.IRON_ORE,
		TileType.BOX, TileType.WOOD_WALL, TileType.STONE_WALL, TileType.FURNACE,
		TileType.IRON_WALL, TileType.GOLD_WALL, TileType.TREE, TileType.COAL_ORE
	]
	for tile_type in solid_tiles:
		var source = tile_set.get_source(TILE_SOURCE[tile_type]) as TileSetAtlasSource
		if source:
			var tile_data = source.get_tile_data(TILE_COORDS[tile_type], 0)
			if tile_data:
				var occluder = OccluderPolygon2D.new()
				occluder.polygon = polygon
				tile_data.set_occluder(0, occluder)


func _process(delta: float) -> void:
	_update_tiles()
	_update_roof_shader(delta)
	# Toggle mine lighting when player_in_mine state changes (handles enter/exit and save load)
	if player_in_mine != _mine_lighting_active:
		_apply_mine_lighting(player_in_mine)
	# Advance day/night cycle
	game_time += delta
	if game_time >= DAY_LENGTH:
		game_time -= DAY_LENGTH
	_flicker_time += delta
	_update_day_night_modulate()
	_update_fire_flicker()


func _update_tiles() -> void:
	var rect = get_visible_tile_rect()
	if rect == _last_rect:
		return
	_last_rect = rect

	# Generate new tiles in visible area
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var tile_pos = Vector2i(x, y)
			if not _generated_tiles.has(tile_pos):
				# Check if this tile was modified by a player
				if _tile_modifications.has(tile_pos):
					set_cell(tile_pos, _tile_modifications[tile_pos], Vector2i(0, 0))
				else:
					var tile_type = get_tile_type(x, y)
					set_cell(tile_pos, TILE_SOURCE[tile_type], TILE_COORDS[tile_type])
				# Load roof tiles for this position
				if roof_layer:
					if _roof_modifications.has(tile_pos):
						roof_layer.set_cell(tile_pos, _roof_modifications[tile_pos], Vector2i(0, 0))
				# Create light for torch and campfire tiles
				var loaded_source = get_cell_source_id(tile_pos)
				if loaded_source == TILE_SOURCE[TileType.TORCH]:
					_add_torch_light(tile_pos)
				elif loaded_source == TILE_SOURCE[TileType.CAMPFIRE]:
					_campfire.add_light(tile_pos, _get_torch_light_texture())
				_generated_tiles[tile_pos] = true

	# Unload tiles outside visible area
	var tiles_to_remove: Array[Vector2i] = []
	for tile_pos in _generated_tiles:
		if not rect.has_point(tile_pos):
			tiles_to_remove.append(tile_pos)

	for tile_pos in tiles_to_remove:
		erase_cell(tile_pos)
		if roof_layer:
			roof_layer.erase_cell(tile_pos)
		_remove_health_bar(tile_pos, false)
		_remove_health_bar(tile_pos, true)
		_remove_torch_light(tile_pos)
		_campfire.remove_light(tile_pos)
		_generated_tiles.erase(tile_pos)


func _update_roof_shader(delta: float) -> void:
	if not roof_layer:
		return
	var mat = roof_layer.material as ShaderMaterial
	if not mat:
		return

	# Find local player
	var players = get_tree().get_nodes_in_group("player")
	var local_player: Node = null
	for player in players:
		if player.is_local_player():
			local_player = player
			break
	if not local_player:
		return

	# Use visual center (sprite is drawn 16px above global_position)
	var visual_center = local_player.global_position + Vector2(0, -16)
	mat.set_shader_parameter("player_pos", visual_center)

	# Check if player is under roof - require current tile + at least 3 of 4 cardinal neighbors
	var player_local = roof_layer.to_local(visual_center)
	var player_tile = roof_layer.local_to_map(player_local)
	var roof_source = roof_layer.get_cell_source_id(player_tile)
	var under_roof = roof_source >= 0
	if under_roof:
		var neighbor_count: int = 0
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if roof_layer.get_cell_source_id(player_tile + offset) >= 0:
				neighbor_count += 1
		under_roof = neighbor_count >= 3

	# Animate reveal radius and blur - targets depend on roof material
	var reveal_target = ROOF_REVEAL_RADIUS.get(roof_source, 20.0) if under_roof else 0.0
	var blur_target = ROOF_REVEAL_EDGE_BLUR.get(roof_source, 0.0) if under_roof else 0.0
	# Recompute speeds only when targets change
	if reveal_target != _roof_reveal_target:
		_roof_reveal_target = reveal_target
		_roof_reveal_speed = absf(reveal_target - _roof_reveal_radius) / ROOF_REVEAL_DURATION
	if blur_target != _roof_blur_target:
		_roof_blur_target = blur_target
		_roof_blur_speed = absf(blur_target - _roof_fade_width) / ROOF_REVEAL_DURATION
	_roof_reveal_radius = move_toward(_roof_reveal_radius, reveal_target, _roof_reveal_speed * delta)
	_roof_fade_width = move_toward(_roof_fade_width, blur_target, _roof_blur_speed * delta)

	mat.set_shader_parameter("enabled", _roof_reveal_radius > 0.0 or _roof_fade_width > 0.0)
	mat.set_shader_parameter("reveal_radius", _roof_reveal_radius)
	mat.set_shader_parameter("fade_width", _roof_fade_width)


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
	# Mine region fallback - ungenerated mine area tiles are cave wall
	if y < -50_000:
		return TileType.CAVE_WALL

	# Use position-based hash for deterministic generation
	var hash_value = _position_hash(x, y)
	if hash_value % ROCK_SPAWN_CHANCE == 0:
		return TileType.ROCK
	# Check for iron ore (rare, use offset hash)
	var iron_hash = _position_hash(x + 2000, y + 2000)
	if iron_hash % IRON_ORE_SPAWN_CHANCE == 0:
		return TileType.IRON_ORE
	# Check for tree on grass tiles (use offset hash)
	var tree_hash = _position_hash(x + 1000, y + 1000)
	if tree_hash % TREE_SPAWN_CHANCE == 0:
		return TileType.TREE
	return TileType.GRASS


func _position_hash(x: int, y: int) -> int:
	# Use fmod-based noise for reliable pseudo-random distribution
	var n = sin(x * 12.9898 + y * 78.233 + WORLD_SEED) * 43758.5453
	return absi(int(n * 1000) % 10000)


# Box inventory functions
func get_box_contents(box_pos: Vector2i) -> Array:
	if not _box_contents.has(box_pos):
		# Initialize empty box with null slots
		var contents: Array = []
		for i in range(BOX_SLOT_COUNT):
			contents.append(null)
		_box_contents[box_pos] = contents
	return _box_contents[box_pos]


func set_box_slot(box_pos: Vector2i, slot: int, item) -> void:
	var contents = get_box_contents(box_pos)
	if slot >= 0 and slot < BOX_SLOT_COUNT:
		contents[slot] = item


func clear_box_contents(box_pos: Vector2i) -> Array:
	# Returns contents and removes from storage (for when box is broken)
	var contents: Array = []
	if _box_contents.has(box_pos):
		contents = _box_contents[box_pos]
		_box_contents.erase(box_pos)
	return contents


# Furnace state functions
func get_furnace_state(furnace_pos: Vector2i) -> Dictionary:
	if not _furnace_states.has(furnace_pos):
		_furnace_states[furnace_pos] = {
			"input_item": null,
			"output_item": null,
			"smelt_progress": 0.0,
			"fuel_item": null,
			"fuel_level": 0.0
		}
	return _furnace_states[furnace_pos]


func set_furnace_state(furnace_pos: Vector2i, state: Dictionary) -> void:
	_furnace_states[furnace_pos] = state


func clear_furnace_state(furnace_pos: Vector2i) -> Dictionary:
	# Returns state and removes from storage (for when furnace is broken)
	var state: Dictionary = {"input_item": null, "output_item": null, "smelt_progress": 0.0, "fuel_item": null, "fuel_level": 0.0}
	if _furnace_states.has(furnace_pos):
		state = _furnace_states[furnace_pos]
		_furnace_states.erase(furnace_pos)
	return state


# === MINE ENTER/EXIT ===

func enter_mine(entrance_pos: Vector2i) -> void:
	# Block in multiplayer
	if NetworkManager.is_connected_to_game():
		return

	var new_level = _mine_level + 1

	var key = "%d,%d" % [entrance_pos.x, entrance_pos.y]
	if not _known_mines.has(key):
		# Generate the mine and write tiles into _tile_modifications
		var result = MineGenerator.generate(entrance_pos, new_level)
		var mine_tiles: Dictionary = result["tiles"]
		for pos in mine_tiles:
			_tile_modifications[pos] = mine_tiles[pos]
		_known_mines[key] = {
			"origin": MineGenerator.get_mine_origin(entrance_pos, new_level),
			"exit_pos": result["exit_pos"]
		}

	# Save current position to return stack
	var player = _get_local_player()
	if not player:
		return
	_mine_return_stack.push_back({"x": player.global_position.x, "y": player.global_position.y})

	# Set mine state
	_mine_level = new_level
	player_in_mine = true
	_current_mine_entrance = entrance_pos

	# Clear health bars and torch lights before tile reload
	_clear_all_health_bars()
	_clear_all_torch_lights()

	# Force tile reload
	_generated_tiles.clear()
	_last_rect = Rect2i()

	# Teleport player to mine exit (spawn point)
	var exit_pos: Vector2i = _known_mines[key]["exit_pos"]
	player.global_position = map_to_local(exit_pos) + Vector2(0, 16)

	# Snap camera to new position immediately (skip smoothing)
	var camera = player.get_node_or_null("Camera2D") as Camera2D
	if camera:
		camera.reset_smoothing()

	_trigger_autosave()


func exit_mine() -> void:
	# Pop return position from stack
	var return_pos = Vector2.ZERO
	if _mine_return_stack.size() > 0:
		var pos_data = _mine_return_stack.pop_back()
		return_pos = Vector2(pos_data["x"], pos_data["y"])

	_mine_level = maxi(_mine_level - 1, 0)
	player_in_mine = _mine_level > 0

	# Clear health bars and torch lights before tile reload
	_clear_all_health_bars()
	_clear_all_torch_lights()

	# Force tile reload
	_generated_tiles.clear()
	_last_rect = Rect2i()

	# Teleport player back to previous position
	var player = _get_local_player()
	if player:
		player.global_position = return_pos

		# Snap camera to new position immediately (skip smoothing)
		var camera = player.get_node_or_null("Camera2D") as Camera2D
		if camera:
			camera.reset_smoothing()

	_trigger_autosave()


func _get_torch_light_texture() -> Texture2D:
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


func _add_torch_light(tile_pos: Vector2i) -> void:
	if _torch_lights.has(tile_pos):
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
	light.position = map_to_local(tile_pos)
	add_child(light)

	# Unshaded additive glow sprite bypasses CanvasModulate and the
	# GL Compatibility per-canvas-item light limit (16), so every torch
	# is always visibly lit regardless of how many are on screen.
	var glow = Sprite2D.new()
	glow.texture = _get_torch_glow_texture()
	glow.material = _get_torch_glow_material()
	glow.scale = Vector2(0.6, 0.6)
	glow.modulate = Color(1.0, 0.7, 0.3, 0.3)
	light.add_child(glow)

	_torch_lights[tile_pos] = light


func _remove_torch_light(tile_pos: Vector2i) -> void:
	if _torch_lights.has(tile_pos):
		var light = _torch_lights[tile_pos]
		if is_instance_valid(light):
			light.queue_free()
		_torch_lights.erase(tile_pos)


func _update_day_night_modulate() -> void:
	if not _day_night_modulate or not _day_night_modulate.visible:
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
	_day_night_modulate.color = color
	# Scale light energy so they don't blow out during daytime
	# Flicker intensity scales with darkness so it's most visible at night
	var ft = _flicker_time
	var torch_flicker = (
		sin(ft * 9.5 + 2.0) * 0.12 +
		sin(ft * 15.3 + 1.0) * 0.08 +
		sin(ft * 21.0 + 3.0) * 0.06
	)
	var torch_base = lerpf(0.1, 0.8, darkness)
	var energy_flicker_strength = darkness * 0.25
	for light in _torch_lights.values():
		if is_instance_valid(light):
			light.energy = torch_base + torch_flicker * energy_flicker_strength
	_campfire.update_energy(darkness, ft)


func _update_fire_flicker() -> void:
	var t = _flicker_time
	_campfire.update_flicker(t)
	# Torches: subtler flicker, offset phase so they don't sync with campfires
	var torch_flicker = (
		sin(t * 9.5 + 2.0) * 0.12 +
		sin(t * 15.3 + 1.0) * 0.08 +
		sin(t * 21.0 + 3.0) * 0.06
	)
	for light in _torch_lights.values():
		if is_instance_valid(light):
			var base_scale = 0.8
			light.texture_scale = base_scale + torch_flicker * 0.04
			light.color = Color(1.0, 0.8 + torch_flicker * 0.06, 0.4 + torch_flicker * 0.04)


func _clear_all_torch_lights() -> void:
	for tile_pos in _torch_lights:
		var light = _torch_lights[tile_pos]
		if is_instance_valid(light):
			light.queue_free()
	_torch_lights.clear()


func _apply_mine_lighting(enabled: bool) -> void:
	_mine_lighting_active = enabled
	occlusion_enabled = enabled

	if enabled:
		if not _mine_modulate:
			_mine_modulate = CanvasModulate.new()
			_mine_modulate.name = "MineModulate"
			_mine_modulate.color = Color(0.05, 0.05, 0.08)
			get_parent().add_child(_mine_modulate)
		_mine_modulate.visible = true
		if _day_night_modulate:
			_day_night_modulate.visible = false
	else:
		if _mine_modulate:
			_mine_modulate.visible = false
		if _day_night_modulate:
			_day_night_modulate.visible = true

	# Toggle player's mine light
	var player = _get_local_player()
	if player and player.has_method("set_mine_light"):
		player.set_mine_light(enabled)


func _get_local_player() -> CharacterBody2D:
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if player.is_local_player():
			return player
	return null


# === MULTIPLAYER RPC METHODS ===

func _on_player_connected(peer_id: int) -> void:
	# Send current world state to late-joiner (only host does this)
	if not multiplayer.is_server():
		return

	# Send tile modifications
	_rpc_sync_tile_modifications.rpc_id(peer_id, _tile_modifications)

	# Send all dropped items
	for network_id in _dropped_items:
		var dropped: DroppedItem = _dropped_items[network_id]
		if dropped and is_instance_valid(dropped) and dropped.item:
			_rpc_spawn_dropped_item.rpc_id(peer_id, network_id, dropped.item.item_id,
				dropped.item.quantity, dropped.global_position, 0.0)

	# Send roof modifications
	_rpc_sync_roof_modifications.rpc_id(peer_id, _roof_modifications)

	# Send all box contents
	for box_pos in _box_contents:
		var contents = _box_contents[box_pos]
		for slot in range(contents.size()):
			var item = contents[slot]
			if item != null:
				_rpc_sync_box_slot.rpc_id(peer_id, box_pos, slot, item.item_id, item.quantity)


func _get_tile_durability(tile_type: String) -> int:
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


func _get_tool_strength(tool_id: String) -> int:
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


func _get_tile_type_string(source_id: int) -> String:
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
		_: return "grass"


func _is_correct_tool(tool_id: String, source_id: int) -> bool:
	var is_pick = tool_id in ["wood_pick", "stone_pick", "iron_pick", "gold_pick"]
	var is_axe = tool_id in ["axe", "wood_axe", "stone_axe", "iron_axe", "gold_axe"]

	match source_id:
		1:  # Rock - requires pick
			return is_pick
		2:  # Tree - requires axe
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


@rpc("any_peer", "call_local", "reliable")
func request_hit_tile(tile_pos: Vector2i, tool_id: String, requester_peer_id: int) -> void:
	# Host validates and processes tile hits
	if not multiplayer.is_server():
		return

	var source_id = get_cell_source_id(tile_pos)
	if source_id <= 0:  # Grass or invalid
		return

	# Mine entrance, exit, cave wall, and cave floor are unbreakable (except mine entrance in sandbox)
	if source_id in [13, 14, 16]:
		return
	if source_id == 12 and not GameMode.is_sandbox():
		return

	# Check if correct tool is used
	if not _is_correct_tool(tool_id, source_id):
		return

	var tile_type = _get_tile_type_string(source_id)

	# Box, furnace, torch, campfire, and mine entrance are instant break
	if source_id in [3, 6, 12, 17, 19]:
		_rpc_show_hit_effect.rpc(tile_pos, source_id)
		_break_tile(tile_pos, tile_type)
		return

	# Initialize health if not tracked
	if not _tile_health.has(tile_pos):
		_tile_health[tile_pos] = _get_tile_durability(tile_type)

	# Calculate damage
	var tool_strength = _get_tool_strength(tool_id)
	var damage = ceili(float(BASE_TILE_DURABILITY) / tool_strength)

	_tile_health[tile_pos] -= damage

	# Show hit effect to all players
	_rpc_show_hit_effect.rpc(tile_pos, source_id)

	if _tile_health[tile_pos] <= 0:
		_rpc_update_tile_health_bar.rpc(tile_pos, 0.0, false)
		_break_tile(tile_pos, tile_type)
		_tile_health.erase(tile_pos)
	else:
		var max_hp = _get_tile_durability(tile_type)
		var ratio = float(_tile_health[tile_pos]) / float(max_hp)
		_rpc_update_tile_health_bar.rpc(tile_pos, ratio, false)


func _break_tile(tile_pos: Vector2i, tile_type: String) -> void:
	# Replace with appropriate base tile: cave floor in mines, grass in overworld
	var replace_source: int = 0
	if tile_type in ["cave_wall", "gold_ore", "coal_ore", "cave_floor"]:
		replace_source = TILE_SOURCE[TileType.CAVE_FLOOR]
	elif tile_pos.y < -50_000:
		# Any tile broken in mine area reveals cave floor
		replace_source = TILE_SOURCE[TileType.CAVE_FLOOR]
	_rpc_sync_tile_change.rpc(tile_pos, replace_source)
	_tile_modifications[tile_pos] = replace_source
	_trigger_autosave()

	# Spawn appropriate items (add 16 to Y to compensate for sprite's -16 Y offset)
	var tile_world_pos = map_to_local(tile_pos) + Vector2(0, 16)

	if tile_type == "rock":
		# Check if breaking this rock reveals a cave entrance (deterministic by position)
		var cave_hash = _position_hash(tile_pos.x + 5000, tile_pos.y + 5000)
		if cave_hash % MINE_ENTRANCE_SPAWN_CHANCE == 0:
			# Reveal cave entrance instead of grass
			replace_source = TILE_SOURCE[TileType.MINE_ENTRANCE]
			_rpc_sync_tile_change.rpc(tile_pos, replace_source)
			_tile_modifications[tile_pos] = replace_source
			_trigger_autosave()
		var rock_count = randi_range(1, 4)
		for i in range(rock_count):
			var spread_offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
			_spawn_item_by_id("rock", 1, tile_world_pos + spread_offset, 0.3)
		# 20% chance to drop iron ore, with 25% chance for 2 instead of 1
		if randi() % 5 == 0:
			var iron_count = 1
			if randi() % 4 == 0:
				iron_count = 2
			for i in range(iron_count):
				var spread_offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
				_spawn_item_by_id("iron_ore", 1, tile_world_pos + spread_offset, 0.3)
	elif tile_type == "iron_ore":
		# Iron ore tiles drop 3-6 iron ore
		var iron_count = randi_range(3, 6)
		for i in range(iron_count):
			var spread_offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
			_spawn_item_by_id("iron_ore", 1, tile_world_pos + spread_offset, 0.3)
	elif tile_type == "tree":
		# Spread out 10 wood drops
		for i in range(10):
			var spread_offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
			_spawn_item_by_id("wood", 1, tile_world_pos + spread_offset, 0.3)
	elif tile_type == "box":
		# Drop box contents first - drop each item in stack individually
		var contents = clear_box_contents(tile_pos)
		for item in contents:
			if item != null:
				for i in range(item.quantity):
					var spread_offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
					_spawn_item_by_id(item.item_id, 1, tile_world_pos + spread_offset, 0.3)
		_spawn_item_by_id("box", 1, tile_world_pos, 0.0)
	elif tile_type == "wood_wall":
		_spawn_item_by_id("wood_wall", 1, tile_world_pos, 0.0)
	elif tile_type == "stone_wall":
		_spawn_item_by_id("stone_wall", 1, tile_world_pos, 0.0)
	elif tile_type == "furnace":
		# Drop furnace contents first
		var state = clear_furnace_state(tile_pos)
		if state.input_item != null:
			for i in range(state.input_item.quantity):
				var spread_offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
				_spawn_item_by_id(state.input_item.item_id, 1, tile_world_pos + spread_offset, 0.3)
		if state.output_item != null:
			for i in range(state.output_item.quantity):
				var spread_offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
				_spawn_item_by_id(state.output_item.item_id, 1, tile_world_pos + spread_offset, 0.3)
		if state.get("fuel_item") != null:
			for i in range(state.fuel_item.quantity):
				var spread_offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
				_spawn_item_by_id(state.fuel_item.item_id, 1, tile_world_pos + spread_offset, 0.3)
		_spawn_item_by_id("furnace", 1, tile_world_pos, 0.0)
	elif tile_type == "iron_wall":
		_spawn_item_by_id("iron_wall", 1, tile_world_pos, 0.0)
	elif tile_type == "wood_floor":
		_spawn_item_by_id("wood_floor", 1, tile_world_pos, 0.0)
	elif tile_type == "stone_floor":
		_spawn_item_by_id("stone_floor", 1, tile_world_pos, 0.0)
	elif tile_type == "gold_wall":
		_spawn_item_by_id("gold_wall", 1, tile_world_pos, 0.0)
	elif tile_type == "cave_wall":
		var rock_count = randi_range(1, 3)
		for i in range(rock_count):
			var spread_offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
			_spawn_item_by_id("rock", 1, tile_world_pos + spread_offset, 0.3)
	elif tile_type == "gold_ore":
		var gold_count = randi_range(3, 6)
		for i in range(gold_count):
			var spread_offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
			_spawn_item_by_id("gold_ore", 1, tile_world_pos + spread_offset, 0.3)
	elif tile_type == "coal_ore":
		var coal_count = randi_range(2, 5)
		for i in range(coal_count):
			var spread_offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
			_spawn_item_by_id("coal", 1, tile_world_pos + spread_offset, 0.3)
	elif tile_type == "mine_entrance":
		_spawn_item_by_id("mine_spawner", 1, tile_world_pos, 0.0)
	elif tile_type == "torch":
		_remove_torch_light(tile_pos)
		_spawn_item_by_id("torch", 1, tile_world_pos, 0.0)
	elif tile_type == "campfire":
		_campfire.remove_light(tile_pos)
		_spawn_item_by_id("campfire", 1, tile_world_pos, 0.0)


@rpc("any_peer", "call_local", "reliable")
func request_place_tile(tile_pos: Vector2i, tile_source_id: int, item_id: String, requester_peer_id: int) -> void:
	# Host validates and processes tile placement
	if not multiplayer.is_server():
		return

	var source_id = get_cell_source_id(tile_pos)

	# Can place on grass, or torches/campfires/mine_spawner can also go on cave floor
	var can_place_on_cave_floor = item_id in ["torch", "campfire", "mine_spawner"]
	if source_id != 0 and not (can_place_on_cave_floor and source_id == TILE_SOURCE[TileType.CAVE_FLOOR]):
		return

	# Don't allow placing on player positions - use world coordinates for robustness
	var tile_world_pos = to_global(map_to_local(tile_pos))
	var tile_half_size = Vector2(tile_set.tile_size) / 2.0
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		var player_pos = player.global_position
		if abs(player_pos.x - tile_world_pos.x) < tile_half_size.x and abs(player_pos.y - tile_world_pos.y) < tile_half_size.y:
			return

	# Place the tile and broadcast
	_rpc_sync_tile_change.rpc(tile_pos, tile_source_id)
	_tile_modifications[tile_pos] = tile_source_id
	_trigger_autosave()

	# Tell the requester to consume their item
	if requester_peer_id == 1:
		# Host is placing - call directly since call_remote won't reach us
		_confirm_placement_local(item_id)
	else:
		_rpc_confirm_placement.rpc_id(requester_peer_id, item_id)


@rpc("any_peer", "call_local", "reliable")
func request_place_roof(tile_pos: Vector2i, roof_source_id: int, item_id: String, requester_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not roof_layer:
		return

	# Can only place if no roof already there
	if roof_layer.get_cell_source_id(tile_pos) >= 0:
		return

	# Place the roof and broadcast
	_rpc_sync_roof_change.rpc(tile_pos, roof_source_id)
	_roof_modifications[tile_pos] = roof_source_id
	_trigger_autosave()

	# Tell the requester to consume their item
	if requester_peer_id == 1:
		_confirm_placement_local(item_id)
	else:
		_rpc_confirm_placement.rpc_id(requester_peer_id, item_id)


@rpc("any_peer", "call_local", "reliable")
func request_hit_roof(tile_pos: Vector2i, tool_id: String, requester_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not roof_layer:
		return

	var source_id = roof_layer.get_cell_source_id(tile_pos)
	if source_id < 0 or source_id >= ROOF_ITEMS.size():
		return

	var roof_item_id = ROOF_ITEMS[source_id]

	# Initialize health if not tracked
	if not _roof_health.has(tile_pos):
		_roof_health[tile_pos] = ROOF_DURABILITY[roof_item_id]

	# Calculate damage
	var tool_strength = _get_tool_strength(tool_id)
	var damage = ceili(float(BASE_TILE_DURABILITY) / tool_strength)

	_roof_health[tile_pos] -= damage

	# Show hit effect on roof layer
	_rpc_show_roof_hit_effect.rpc(tile_pos, source_id)

	if _roof_health[tile_pos] <= 0:
		_rpc_update_tile_health_bar.rpc(tile_pos, 0.0, true)
		_break_roof(tile_pos, roof_item_id)
		_roof_health.erase(tile_pos)
	else:
		var max_hp = ROOF_DURABILITY[roof_item_id]
		var ratio = float(_roof_health[tile_pos]) / float(max_hp)
		_rpc_update_tile_health_bar.rpc(tile_pos, ratio, true)


func _break_roof(tile_pos: Vector2i, roof_item_id: String) -> void:
	_rpc_sync_roof_change.rpc(tile_pos, -1)
	_roof_modifications.erase(tile_pos)
	_trigger_autosave()

	var tile_world_pos = roof_layer.map_to_local(tile_pos) + Vector2(0, 16)
	_spawn_item_by_id(roof_item_id, 1, tile_world_pos, 0.0)


@rpc("any_peer", "call_local", "reliable")
func request_pickup_item(network_id: int, requester_peer_id: int) -> void:
	# Host validates and processes item pickup
	if not multiplayer.is_server():
		return

	if not _dropped_items.has(network_id):
		return

	var dropped: DroppedItem = _dropped_items[network_id]
	if dropped == null or not is_instance_valid(dropped) or not dropped.can_pickup or dropped.being_picked_up:
		return

	# Mark as being picked up to prevent double-pickup
	dropped.being_picked_up = true

	# Create item for the picker
	var item = Item.create(dropped.item.item_id, dropped.item.quantity)

	# Remove from tracking and broadcast removal
	_dropped_items.erase(network_id)
	_rpc_remove_dropped_item.rpc(network_id, requester_peer_id)

	# Tell the picker they got the item
	if requester_peer_id == 1:
		# Host is picking up - call directly since call_remote won't reach us
		_confirm_pickup_local(item)
	else:
		_rpc_confirm_pickup.rpc_id(requester_peer_id, item.item_id, item.quantity)


@rpc("any_peer", "call_local", "reliable")
func request_drop_item(item_id: String, quantity: int, pos: Vector2, requester_peer_id: int) -> void:
	# Host spawns dropped item
	if not multiplayer.is_server():
		return

	_spawn_item_by_id(item_id, quantity, pos, 1.0)


func _spawn_item_by_id(item_id: String, quantity: int, pos: Vector2, pickup_delay: float) -> void:
	var network_id = _next_item_id
	_next_item_id += 1

	# Spawn locally and on all clients
	_rpc_spawn_dropped_item.rpc(network_id, item_id, quantity, pos, pickup_delay)


# === RPC BROADCAST METHODS ===

@rpc("authority", "call_local", "reliable")
func _rpc_sync_tile_change(tile_pos: Vector2i, source_id: int) -> void:
	set_cell(tile_pos, source_id, Vector2i(0, 0))
	# Manage torch lights on tile changes
	if source_id == TILE_SOURCE[TileType.TORCH]:
		_add_torch_light(tile_pos)
	else:
		_remove_torch_light(tile_pos)
	# Manage campfire lights on tile changes
	if source_id == TILE_SOURCE[TileType.CAMPFIRE]:
		_campfire.add_light(tile_pos, _get_torch_light_texture())
	else:
		_campfire.remove_light(tile_pos)
	if not multiplayer.is_server():
		_tile_modifications[tile_pos] = source_id


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_tile_modifications(modifications: Dictionary) -> void:
	_tile_modifications = modifications
	# Re-apply modifications to already generated tiles
	for pos in modifications:
		if _generated_tiles.has(pos):
			set_cell(pos, modifications[pos], Vector2i(0, 0))


@rpc("authority", "call_local", "reliable")
func _rpc_sync_roof_change(tile_pos: Vector2i, source_id: int) -> void:
	if not roof_layer:
		return
	if source_id < 0:
		roof_layer.erase_cell(tile_pos)
	else:
		roof_layer.set_cell(tile_pos, source_id, Vector2i(0, 0))
	if not multiplayer.is_server():
		if source_id < 0:
			_roof_modifications.erase(tile_pos)
		else:
			_roof_modifications[tile_pos] = source_id


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_roof_modifications(modifications: Dictionary) -> void:
	_roof_modifications = modifications
	if roof_layer:
		for pos in modifications:
			if _generated_tiles.has(pos):
				roof_layer.set_cell(pos, modifications[pos], Vector2i(0, 0))


@rpc("authority", "call_local", "reliable")
func _rpc_spawn_dropped_item(network_id: int, item_id: String, quantity: int, pos: Vector2, pickup_delay: float) -> void:
	var dropped = dropped_item_scene.instantiate() as DroppedItem
	var item = Item.create(item_id, quantity)
	dropped.set_item(item)
	dropped.network_id = network_id
	dropped.add_to_group("dropped_items")
	dropped.global_position = pos
	get_parent().add_child(dropped)

	if pickup_delay > 0:
		dropped.enable_pickup_after_delay(pickup_delay)
	else:
		dropped.can_pickup = true

	# Track on host
	if multiplayer.is_server():
		_dropped_items[network_id] = dropped


@rpc("authority", "call_local", "reliable")
func _rpc_remove_dropped_item(network_id: int, picker_peer_id: int) -> void:
	# Find and remove the item
	var dropped_items = get_tree().get_nodes_in_group("dropped_items")
	for item_node in dropped_items:
		var dropped: DroppedItem = item_node as DroppedItem
		if dropped and dropped.network_id == network_id:
			# Find the picker player for animation
			var players = get_tree().get_nodes_in_group("player")
			for player in players:
				if player.peer_id == picker_peer_id:
					dropped.start_pickup(player)
					break
			break


@rpc("authority", "call_remote", "reliable")
func _rpc_confirm_placement(item_id: String) -> void:
	_confirm_placement_local(item_id)


func _confirm_placement_local(item_id: String) -> void:
	# Local player consumes item from inventory
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if player.is_local_player():
			player.on_placement_confirmed(item_id)
			break


@rpc("authority", "call_remote", "reliable")
func _rpc_confirm_pickup(item_id: String, quantity: int) -> void:
	# Local player receives item
	var item = Item.create(item_id, quantity)
	_confirm_pickup_local(item)


func _confirm_pickup_local(item: Item) -> void:
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if player.is_local_player():
			player.on_pickup_confirmed(item)
			break


# === HIT VISUAL EFFECTS ===

@rpc("authority", "call_local", "reliable")
func _rpc_show_hit_effect(tile_pos: Vector2i, source_id: int) -> void:
	var local_pos = map_to_local(tile_pos)
	# Adjust position for tree's texture_origin offset (drawn 12px higher)
	if source_id == 2:
		local_pos.y -= 12
	_create_hit_particles(local_pos, source_id)
	_create_hit_flash(local_pos, source_id)


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
		var ts = tile_set.tile_size
		var img = Image.create(ts.x, ts.y, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_flash_texture = ImageTexture.create_from_image(img)
	return _flash_texture


func _create_hit_particles(local_pos: Vector2, source_id: int) -> void:
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
	add_child(particles)

	# Auto-cleanup after particles finish
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)


func _get_flash_shader() -> Shader:
	if _flash_shader == null:
		_flash_shader = Shader.new()
		_flash_shader.code = "shader_type canvas_item;\nvoid fragment() { COLOR = vec4(1.0, 1.0, 1.0, texture(TEXTURE, UV).a * COLOR.a); }"
	return _flash_shader


func _create_hit_flash(local_pos: Vector2, source_id: int) -> void:
	var flash = Sprite2D.new()
	# Use the tile's own texture so the flash matches its shape
	var atlas_source = tile_set.get_source(source_id) as TileSetAtlasSource
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
	add_child(flash)

	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.1)
	tween.tween_callback(flash.queue_free)


# === ROOF HIT EFFECTS ===

@rpc("authority", "call_local", "reliable")
func _rpc_show_roof_hit_effect(tile_pos: Vector2i, roof_source_id: int) -> void:
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
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)

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
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.1)
	flash_tween.tween_callback(flash.queue_free)


# === BOX INVENTORY SYNC ===

@rpc("any_peer", "call_local", "reliable")
func request_set_box_slot(box_pos: Vector2i, slot: int, item_id: String, quantity: int) -> void:
	# Host validates and processes box slot changes
	if not multiplayer.is_server():
		return

	var item: Item = null
	if item_id != "":
		item = Item.create(item_id, quantity)

	# Update local storage
	var contents = get_box_contents(box_pos)
	if slot >= 0 and slot < BOX_SLOT_COUNT:
		contents[slot] = item

	# Broadcast to all clients
	_rpc_sync_box_slot.rpc(box_pos, slot, item_id, quantity)


@rpc("authority", "call_local", "reliable")
func _rpc_sync_box_slot(box_pos: Vector2i, slot: int, item_id: String, quantity: int) -> void:
	# Skip on server - already updated
	if multiplayer.is_server():
		return

	var item: Item = null
	if item_id != "":
		item = Item.create(item_id, quantity)

	var contents = get_box_contents(box_pos)
	if slot >= 0 and slot < BOX_SLOT_COUNT:
		contents[slot] = item

	# Update UI if box inventory is open
	var box_inventory = get_tree().get_first_node_in_group("box_inventory")
	if box_inventory and box_inventory.is_open and box_inventory.current_box_pos == box_pos:
		box_inventory._update_item_icons()


# === TILE HEALTH BARS ===

func _show_health_bar(tile_pos: Vector2i, ratio: float, is_roof: bool) -> void:
	var bars = _roof_health_bars if is_roof else _tile_health_bars
	if ratio >= 1.0 or ratio <= 0.0:
		_remove_health_bar(tile_pos, is_roof)
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
		bar.position = map_to_local(tile_pos) + Vector2(0, 10)
		bar.z_index = 10
		add_child(bar)
	bars[tile_pos] = bar


func _remove_health_bar(tile_pos: Vector2i, is_roof: bool) -> void:
	var bars = _roof_health_bars if is_roof else _tile_health_bars
	if bars.has(tile_pos):
		var bar = bars[tile_pos]
		if is_instance_valid(bar):
			bar.queue_free()
		bars.erase(tile_pos)


func _clear_all_health_bars() -> void:
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


@rpc("authority", "call_local", "reliable")
func _rpc_update_tile_health_bar(tile_pos: Vector2i, health_ratio: float, is_roof: bool) -> void:
	if health_ratio >= 1.0 or health_ratio <= 0.0:
		_remove_health_bar(tile_pos, is_roof)
	else:
		_show_health_bar(tile_pos, health_ratio, is_roof)


func _on_regen_tick() -> void:
	if not multiplayer.is_server():
		return

	# Regenerate ground tile health
	var tiles_to_remove: Array[Vector2i] = []
	for tile_pos in _tile_health:
		var source_id = get_cell_source_id(tile_pos)
		if source_id <= 0:
			tiles_to_remove.append(tile_pos)
			continue
		var tile_type = _get_tile_type_string(source_id)
		var max_hp = _get_tile_durability(tile_type)
		_tile_health[tile_pos] = mini(_tile_health[tile_pos] + TILE_REGEN_AMOUNT, max_hp)
		if _tile_health[tile_pos] >= max_hp:
			tiles_to_remove.append(tile_pos)
			_rpc_update_tile_health_bar.rpc(tile_pos, 1.0, false)
		else:
			var ratio = float(_tile_health[tile_pos]) / float(max_hp)
			_rpc_update_tile_health_bar.rpc(tile_pos, ratio, false)
	for tile_pos in tiles_to_remove:
		_tile_health.erase(tile_pos)

	# Regenerate roof health
	var roofs_to_remove: Array[Vector2i] = []
	for tile_pos in _roof_health:
		if not roof_layer:
			break
		var source_id = roof_layer.get_cell_source_id(tile_pos)
		if source_id < 0:
			roofs_to_remove.append(tile_pos)
			continue
		var roof_item_id = ROOF_ITEMS[source_id]
		var max_hp = ROOF_DURABILITY[roof_item_id]
		_roof_health[tile_pos] = mini(_roof_health[tile_pos] + TILE_REGEN_AMOUNT, max_hp)
		if _roof_health[tile_pos] >= max_hp:
			roofs_to_remove.append(tile_pos)
			_rpc_update_tile_health_bar.rpc(tile_pos, 1.0, true)
		else:
			var ratio = float(_roof_health[tile_pos]) / float(max_hp)
			_rpc_update_tile_health_bar.rpc(tile_pos, ratio, true)
	for tile_pos in roofs_to_remove:
		_roof_health.erase(tile_pos)


# === AUTOSAVE ===

var _autosave_pending: bool = false

func _trigger_autosave() -> void:
	# Only autosave in single player mode (host)
	if not multiplayer.is_server():
		return
	if NetworkManager.is_connected_to_game() and not NetworkManager.is_host():
		return

	# Debounce autosave to avoid saving on every action
	if _autosave_pending:
		return
	_autosave_pending = true
	_do_autosave.call_deferred()


func _do_autosave() -> void:
	_autosave_pending = false
	SaveManager.save_game()
