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
	CAMPFIRE = 19,
	SAPLING = 20
}

# Tile damage system
var _damage = TileDamageSystem.new()

# Box inventory storage: Dictionary[Vector2i, Array[Item]]
var _box_contents: Dictionary = {}
const BOX_SLOT_COUNT: int = 9

# Furnace system
var _furnace = FurnaceSystem.new()

# === ROOF LAYER ===
var roof_layer: TileMapLayer = null
var _roof_modifications: Dictionary = {}  # Vector2i -> source_id (0=wood,1=stone,2=iron,3=gold)
const ROOF_ITEMS: Array[String] = ["wood_roof", "stone_roof", "iron_roof", "gold_roof"]

const ROOF_DURABILITY = {
	"wood_roof": 20,
	"stone_roof": 30,
	"iron_roof": 60,
	"gold_roof": 120,
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
	TileType.CAMPFIRE: 19,
	TileType.SAPLING: 20
}

# All tile atlas sources use coordinate (0, 0)
const TILE_ATLAS_COORD = Vector2i(0, 0)

# Chance for a rock to spawn (1 in N tiles)
const ROCK_SPAWN_CHANCE: int = 40

# Chance for a tree to spawn on grass (1 in N grass tiles)
const TREE_SPAWN_CHANCE: int = 40

# Chance for iron ore to spawn (1 in N tiles) - very rare
const IRON_ORE_SPAWN_CHANCE: int = 2000

# Chance for mine entrance to spawn (1 in N tiles)
const MINE_ENTRANCE_SPAWN_CHANCE: int = 5000


# Seed for deterministic world generation
const WORLD_SEED: int = 12345


# Buffer of extra tiles to generate beyond the visible area
@export var tile_buffer: int = 2

# Extra tiles beyond tile_buffer before torch/campfire lights are removed.
# Torch glow radius is ~6 tiles; this keeps lights alive until invisible.
const LIGHT_UNLOAD_EXTRA: int = 6

# Track which tiles have been generated
var _generated_tiles: Dictionary = {}

# Cache last rect to avoid redundant work
var _last_rect: Rect2i

# === MULTIPLAYER STATE (Host-authoritative) ===

# Tile modifications for late-joiners (tiles changed from their procedural state)
var _tile_modifications: Dictionary = {}  # Vector2i -> source_id

# Dropped items tracking
var _dropped_items: Dictionary = {}  # network_id -> DroppedItem
var _next_item_id: int = 0

var dropped_item_scene: PackedScene = preload("res://scenes/dropped_item.tscn")

# Mine system
var _mine = MineSystem.new()
var _campfire = CampfireManager.new()

# Proxy properties for mine state (used by SaveManager, coordinate_display, etc.)
var player_in_mine: bool:
	get: return _mine.player_in_mine
	set(v): _mine.player_in_mine = v

var known_mines: Dictionary:
	get: return _mine.known_mines
	set(v): _mine.known_mines = v

var current_mine_entrance: Vector2i:
	get: return _mine.current_mine_entrance
	set(v): _mine.current_mine_entrance = v

var mine_level: int:
	get: return _mine.mine_level
	set(v): _mine.mine_level = v

var mine_return_stack: Array:
	get: return _mine.mine_return_stack
	set(v): _mine.mine_return_stack = v

# Day/night cycle
var _day_night = DayNightCycle.new()
const DAY_LENGTH: float = 300.0

var game_time: float:
	get: return _day_night.game_time
	set(v): _day_night.game_time = v

# Hit effects system
var _hit_effects = HitEffects.new()

# Monotonic play time (never wraps, used for regrowth timers)
var _play_time: float = 0.0

var play_time: float:
	get: return _play_time
	set(v): _play_time = v

# Tree regrowth system
const TREE_REGROW_PHASE_TIME: float = 120.0  # 2 minutes per phase
const TREE_REGROW_PHASES: int = 2

var _tree_regrowth: Dictionary = {}  # Vector2i -> float (play_time of last phase start)
var _tree_regrowth_timers: Dictionary = {}  # Vector2i -> Timer (active on-screen timers)

# Health regeneration interval (timer period)
const TILE_REGEN_INTERVAL: float = 2.0


func _ready() -> void:
	add_to_group("world")
	_mine.init(self)
	_campfire.init(self)
	_hit_effects.init(self)
	_furnace.init(self)
	_damage.init(self)
	_day_night.init(self)
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


func _setup_tile_physics() -> void:
	# Update rock tile collision polygon to match tile size
	if tile_set:
		var tile_size = tile_set.tile_size
		var half_w = tile_size.x / 2.0
		var half_h = tile_size.y / 2.0

		# Get the rock atlas source (source ID 1)
		var rock_source = tile_set.get_source(TILE_SOURCE[TileType.ROCK]) as TileSetAtlasSource
		if rock_source:
			var tile_data = rock_source.get_tile_data(TILE_ATLAS_COORD, 0)
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
			var tile_data = source.get_tile_data(TILE_ATLAS_COORD, 0)
			if tile_data:
				var occluder = OccluderPolygon2D.new()
				occluder.polygon = polygon
				tile_data.set_occluder(0, occluder)


func _process(delta: float) -> void:
	_play_time += delta
	_update_tiles()
	_update_roof_shader(delta)
	# Toggle mine lighting when player_in_mine state changes (handles enter/exit and save load)
	if _mine.player_in_mine != _mine.lighting_active:
		_mine.apply_mine_lighting(_mine.player_in_mine, _day_night)
	# Day/night cycle + fire flicker
	_day_night.update(delta, _mine.torch_lights, _campfire, _mine.player_in_mine)
	# Tick all furnaces (background smelting regardless of UI state)
	if multiplayer.is_server():
		if _furnace.tick(delta):
			_trigger_autosave()


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
					set_cell(tile_pos, TILE_SOURCE[tile_type], TILE_ATLAS_COORD)
				# Load roof tiles for this position
				if roof_layer:
					if _roof_modifications.has(tile_pos):
						roof_layer.set_cell(tile_pos, _roof_modifications[tile_pos], Vector2i(0, 0))
				# Tree regrowth catch-up when tile comes on screen
				if _tree_regrowth.has(tile_pos):
					_process_regrowth_on_load(tile_pos)
				# Create light for torch and campfire tiles
				var loaded_source = get_cell_source_id(tile_pos)
				if loaded_source == TILE_SOURCE[TileType.TORCH]:
					_mine.add_torch_light(tile_pos)
				elif loaded_source == TILE_SOURCE[TileType.CAMPFIRE]:
					_campfire.add_light(tile_pos, _mine.get_torch_light_texture())
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
		_damage.remove_health_bar(tile_pos, false)
		_damage.remove_health_bar(tile_pos, true)
		# Clean up regrowth timer (data persists for off-screen catch-up)
		if _tree_regrowth_timers.has(tile_pos):
			_tree_regrowth_timers[tile_pos].queue_free()
			_tree_regrowth_timers.erase(tile_pos)
		_generated_tiles.erase(tile_pos)

	# Remove lights with a larger buffer so glow fades before unload
	var light_rect = rect.grow(LIGHT_UNLOAD_EXTRA)
	for tile_pos in _mine.torch_lights.keys():
		if not light_rect.has_point(tile_pos):
			_mine.remove_torch_light(tile_pos)
	for tile_pos in _campfire._lights.keys():
		if not light_rect.has_point(tile_pos):
			_campfire.remove_light(tile_pos)


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


# Furnace state proxy methods (used by furnace_inventory.gd, _break_tile, etc.)
var furnace_states: Dictionary:
	get: return _furnace.states
	set(v): _furnace.states = v

func get_furnace_state(furnace_pos: Vector2i) -> Dictionary:
	return _furnace.get_state(furnace_pos)

func set_furnace_state(furnace_pos: Vector2i, state: Dictionary) -> void:
	_furnace.set_state(furnace_pos, state)

func clear_furnace_state(furnace_pos: Vector2i) -> Dictionary:
	return _furnace.clear_state(furnace_pos)


# === MINE ENTER/EXIT ===

func enter_mine(entrance_pos: Vector2i) -> void:
	_mine.enter_mine(entrance_pos, _tile_modifications, _generated_tiles, _damage)
	_trigger_autosave()


func exit_mine() -> void:
	_mine.exit_mine(_generated_tiles, _damage)
	_trigger_autosave()









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
	if not _damage.is_correct_tool(tool_id, source_id):
		return

	var tile_type = _damage.get_tile_type_string(source_id)

	# Box, furnace, torch, campfire, mine entrance, and sapling are instant break
	if source_id in [3, 6, 12, 17, 19, 20]:
		_rpc_show_hit_effect.rpc(tile_pos, source_id)
		_break_tile(tile_pos, tile_type)
		return

	# Calculate and apply damage
	var damage = _damage.calculate_damage(tool_id)
	var remaining = _damage.apply_tile_damage(tile_pos, tile_type, damage)

	# Show hit effect to all players
	_rpc_show_hit_effect.rpc(tile_pos, source_id)

	if remaining <= 0:
		_rpc_update_tile_health_bar.rpc(tile_pos, 0.0, false)
		_break_tile(tile_pos, tile_type)
	else:
		var ratio = _damage.get_tile_health_ratio(tile_pos, tile_type)
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
		# Start regrowth if overworld and natural tree position
		_start_tree_regrowth(tile_pos)
		# Spread out 10 wood drops
		for i in range(10):
			var spread_offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
			_spawn_item_by_id("wood", 1, tile_world_pos + spread_offset, 0.3)
	elif tile_type == "sapling":
		# Start regrowth (restarts from grass phase)
		_start_tree_regrowth(tile_pos)
		# Drop 1-3 wood
		var sapling_wood_count = randi_range(1, 3)
		for i in range(sapling_wood_count):
			var spread_offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
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
		_mine.remove_torch_light(tile_pos)
		_spawn_item_by_id("torch", 1, tile_world_pos, 0.0)
	elif tile_type == "campfire":
		_campfire.remove_light(tile_pos)
		_spawn_item_by_id("campfire", 1, tile_world_pos, 0.0)


# Server-side mapping from item_id to tile source_id (single source of truth for placement)
const ITEM_TO_TILE_SOURCE: Dictionary = {
	"box": 3,
	"wood_wall": 4,
	"stone_wall": 5,
	"furnace": 6,
	"iron_wall": 8,
	"wood_floor": 9,
	"stone_floor": 10,
	"gold_wall": 11,
	"mine_spawner": 12,
	"torch": 17,
	"campfire": 19,
	"seed": 20,
}


@rpc("any_peer", "call_local", "reliable")
func request_place_tile(tile_pos: Vector2i, _tile_source_id: int, item_id: String, requester_peer_id: int) -> void:
	# Host validates and processes tile placement
	if not multiplayer.is_server():
		return

	# Derive tile source from item_id server-side (ignore client-provided source_id)
	var validated_source_id: int = ITEM_TO_TILE_SOURCE.get(item_id, -1)
	if validated_source_id < 0:
		return

	# Seeds are sandbox-exclusive
	if item_id == "seed" and not GameMode.is_sandbox():
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

	# Cancel tree regrowth if placing on a regrowing tile
	_cancel_tree_regrowth(tile_pos)

	# Place the tile and broadcast
	_rpc_sync_tile_change.rpc(tile_pos, validated_source_id)
	_tile_modifications[tile_pos] = validated_source_id
	_trigger_autosave()

	# Start regrowth for planted seeds (sapling → tree)
	# Offset by one phase so off-screen catch-up knows grass→sapling already happened
	if item_id == "seed":
		_tree_regrowth[tile_pos] = _play_time - TREE_REGROW_PHASE_TIME
		_start_regrowth_timer(tile_pos, TREE_REGROW_PHASE_TIME)

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

	# Cancel tree regrowth if placing roof over a regrowing tile
	_cancel_tree_regrowth(tile_pos)

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

	# Calculate and apply damage
	var damage = _damage.calculate_damage(tool_id)
	var remaining = _damage.apply_roof_damage(tile_pos, roof_item_id, damage)

	# Show hit effect on roof layer
	_rpc_show_roof_hit_effect.rpc(tile_pos, source_id)

	if remaining <= 0:
		_rpc_update_tile_health_bar.rpc(tile_pos, 0.0, true)
		_break_roof(tile_pos, roof_item_id)
	else:
		var ratio = _damage.get_roof_health_ratio(tile_pos, roof_item_id)
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
		_mine.add_torch_light(tile_pos)
	else:
		_mine.remove_torch_light(tile_pos)
	# Manage campfire lights on tile changes
	if source_id == TILE_SOURCE[TileType.CAMPFIRE]:
		_campfire.add_light(tile_pos, _mine.get_torch_light_texture())
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
	_hit_effects.show_tile_hit(tile_pos, source_id)


@rpc("authority", "call_local", "reliable")
func _rpc_show_roof_hit_effect(tile_pos: Vector2i, roof_source_id: int) -> void:
	_hit_effects.show_roof_hit(tile_pos, roof_source_id, roof_layer)


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


@rpc("any_peer", "call_local", "reliable")
func request_swap_box_slots(box_pos: Vector2i, slot_a: int, slot_b: int) -> void:
	if not multiplayer.is_server():
		return
	var contents = get_box_contents(box_pos)
	if slot_a < 0 or slot_a >= BOX_SLOT_COUNT or slot_b < 0 or slot_b >= BOX_SLOT_COUNT:
		return
	var item_a = contents[slot_a]
	var item_b = contents[slot_b]
	contents[slot_a] = item_b
	contents[slot_b] = item_a
	# Broadcast both changes
	var a_id := ""
	var a_qty := 0
	if item_b != null:
		a_id = item_b.item_id
		a_qty = item_b.quantity
	var b_id := ""
	var b_qty := 0
	if item_a != null:
		b_id = item_a.item_id
		b_qty = item_a.quantity
	_rpc_sync_box_slot.rpc(box_pos, slot_a, a_id, a_qty)
	_rpc_sync_box_slot.rpc(box_pos, slot_b, b_id, b_qty)


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


@rpc("authority", "call_local", "reliable")
func _rpc_update_tile_health_bar(tile_pos: Vector2i, health_ratio: float, is_roof: bool) -> void:
	if health_ratio >= 1.0 or health_ratio <= 0.0:
		_damage.remove_health_bar(tile_pos, is_roof)
	else:
		_damage.show_health_bar(tile_pos, health_ratio, is_roof, roof_layer)


func _on_regen_tick() -> void:
	if not multiplayer.is_server():
		return

	# Regenerate ground tile health
	var tiles_to_remove: Array[Vector2i] = []
	for tile_pos in _damage.tile_health:
		var source_id = get_cell_source_id(tile_pos)
		if source_id <= 0:
			tiles_to_remove.append(tile_pos)
			continue
		var tile_type = _damage.get_tile_type_string(source_id)
		var max_hp = _damage.get_tile_durability(tile_type)
		_damage.tile_health[tile_pos] = mini(_damage.tile_health[tile_pos] + _damage.TILE_REGEN_AMOUNT, max_hp)
		if _damage.tile_health[tile_pos] >= max_hp:
			tiles_to_remove.append(tile_pos)
			_rpc_update_tile_health_bar.rpc(tile_pos, 1.0, false)
		else:
			var ratio = float(_damage.tile_health[tile_pos]) / float(max_hp)
			_rpc_update_tile_health_bar.rpc(tile_pos, ratio, false)
	for tile_pos in tiles_to_remove:
		_damage.tile_health.erase(tile_pos)

	# Regenerate roof health
	var roofs_to_remove: Array[Vector2i] = []
	for tile_pos in _damage.roof_health:
		if not roof_layer:
			break
		var source_id = roof_layer.get_cell_source_id(tile_pos)
		if source_id < 0:
			roofs_to_remove.append(tile_pos)
			continue
		var roof_item_id = ROOF_ITEMS[source_id]
		var max_hp = ROOF_DURABILITY[roof_item_id]
		_damage.roof_health[tile_pos] = mini(_damage.roof_health[tile_pos] + _damage.TILE_REGEN_AMOUNT, max_hp)
		if _damage.roof_health[tile_pos] >= max_hp:
			roofs_to_remove.append(tile_pos)
			_rpc_update_tile_health_bar.rpc(tile_pos, 1.0, true)
		else:
			var ratio = float(_damage.roof_health[tile_pos]) / float(max_hp)
			_rpc_update_tile_health_bar.rpc(tile_pos, ratio, true)
	for tile_pos in roofs_to_remove:
		_damage.roof_health.erase(tile_pos)


# === TREE REGROWTH ===

func _start_tree_regrowth(tile_pos: Vector2i) -> void:
	# Only in overworld, only for natural tree positions
	if tile_pos.y < -50_000:
		return
	if get_tile_type(tile_pos.x, tile_pos.y) != TileType.TREE:
		return
	_tree_regrowth[tile_pos] = _play_time
	_start_regrowth_timer(tile_pos, TREE_REGROW_PHASE_TIME)


func _process_regrowth_on_load(tile_pos: Vector2i) -> void:
	# Check blocking: tile must be grass or sapling, no roof
	if _tile_modifications.has(tile_pos):
		var mod = _tile_modifications[tile_pos]
		if mod != TILE_SOURCE[TileType.GRASS] and mod != TILE_SOURCE[TileType.SAPLING]:
			_tree_regrowth.erase(tile_pos)
			return
	if _roof_modifications.has(tile_pos):
		_tree_regrowth.erase(tile_pos)
		return

	var elapsed = _play_time - _tree_regrowth[tile_pos]
	var completed_phases = int(elapsed / TREE_REGROW_PHASE_TIME)

	if completed_phases >= TREE_REGROW_PHASES:
		# Full tree restored
		_finish_tree_regrowth(tile_pos)
		set_cell(tile_pos, TILE_SOURCE[TileType.TREE], TILE_ATLAS_COORD)
		return

	if completed_phases == 1:
		# Advance to sapling if currently grass
		var current_mod = _tile_modifications.get(tile_pos, TILE_SOURCE[TileType.GRASS])
		if current_mod == TILE_SOURCE[TileType.GRASS]:
			_tile_modifications[tile_pos] = TILE_SOURCE[TileType.SAPLING]
			set_cell(tile_pos, TILE_SOURCE[TileType.SAPLING], TILE_ATLAS_COORD)
			_tree_regrowth[tile_pos] += TREE_REGROW_PHASE_TIME

	# Start timer for remaining time to next phase
	var remaining = TREE_REGROW_PHASE_TIME - fmod(elapsed, TREE_REGROW_PHASE_TIME)
	_start_regrowth_timer(tile_pos, remaining)


func _start_regrowth_timer(tile_pos: Vector2i, wait_time: float) -> void:
	# Clean up existing timer if any
	if _tree_regrowth_timers.has(tile_pos):
		_tree_regrowth_timers[tile_pos].queue_free()
		_tree_regrowth_timers.erase(tile_pos)

	var timer = Timer.new()
	timer.wait_time = wait_time
	timer.one_shot = true
	timer.timeout.connect(_on_tree_regrowth_timeout.bind(tile_pos))
	add_child(timer)
	timer.start()
	_tree_regrowth_timers[tile_pos] = timer


func _on_tree_regrowth_timeout(tile_pos: Vector2i) -> void:
	# Clean up timer
	if _tree_regrowth_timers.has(tile_pos):
		_tree_regrowth_timers[tile_pos].queue_free()
		_tree_regrowth_timers.erase(tile_pos)

	if not _tree_regrowth.has(tile_pos):
		return

	# Re-check blocking conditions
	if _roof_modifications.has(tile_pos):
		_tree_regrowth.erase(tile_pos)
		return

	var current_source = get_cell_source_id(tile_pos)

	if current_source == TILE_SOURCE[TileType.GRASS]:
		# Advance grass → sapling
		_tree_regrowth[tile_pos] += TREE_REGROW_PHASE_TIME
		_tile_modifications[tile_pos] = TILE_SOURCE[TileType.SAPLING]
		_rpc_sync_tile_change.rpc(tile_pos, TILE_SOURCE[TileType.SAPLING])
		_start_regrowth_timer(tile_pos, TREE_REGROW_PHASE_TIME)
		_trigger_autosave()
	elif current_source == TILE_SOURCE[TileType.SAPLING]:
		# Advance sapling → full tree
		_finish_tree_regrowth(tile_pos)
		_rpc_sync_tile_change.rpc(tile_pos, TILE_SOURCE[TileType.TREE])
		_trigger_autosave()
	else:
		# Something else is here now, cancel regrowth
		_tree_regrowth.erase(tile_pos)


func _finish_tree_regrowth(tile_pos: Vector2i) -> void:
	_tree_regrowth.erase(tile_pos)
	# Natural tree positions: erase modification so procedural gen shows the tree
	# Seed-planted positions: keep as modification so the tree persists
	if get_tile_type(tile_pos.x, tile_pos.y) == TileType.TREE:
		_tile_modifications.erase(tile_pos)
	else:
		_tile_modifications[tile_pos] = TILE_SOURCE[TileType.TREE]


func _cancel_tree_regrowth(tile_pos: Vector2i) -> void:
	if _tree_regrowth.has(tile_pos):
		_tree_regrowth.erase(tile_pos)
	if _tree_regrowth_timers.has(tile_pos):
		_tree_regrowth_timers[tile_pos].queue_free()
		_tree_regrowth_timers.erase(tile_pos)


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
