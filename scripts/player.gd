extends CharacterBody2D

@export var run_speed: float = 160.0
@export var walk_speed: float = 80.0
@export var peer_id: int = 1  # Network peer ID, set by PlayerSpawner

var hotbar: Node = null
var dropped_item_scene: PackedScene = preload("res://scenes/dropped_item.tscn")
var pickup_sound: AudioStream = preload("res://audio/pickup.wav")

var world: TileMapLayer = null

# Derived from sprite size
var sprite_size: float = 16.0
var pickup_range: float = 32.0

# Tool hit counts for different tiers
const PLASTIC_TOOL_HITS: int = 10
const WOOD_TOOL_HITS: int = 5
const STONE_TOOL_HITS: int = 3

var _pending_left_click: bool = false
var _pending_right_click: bool = false
var box_inventory: Node = null
var furnace_inventory: Node = null
var _last_pickup_sound_frame: int = -1
var _mine_light: PointLight2D = null
var _mine_ambient_light: PointLight2D = null


func is_local_player() -> bool:
	return peer_id == NetworkManager.get_local_peer_id()


func _ready() -> void:
	add_to_group("player")

	# Set multiplayer authority based on peer_id
	set_multiplayer_authority(peer_id)

	# Derive sizes from actual sprite dimensions
	var sprite = $Sprite2D
	if sprite and sprite.texture:
		sprite_size = sprite.texture.get_width()
		pickup_range = sprite_size * 2.0

	# Update collision shape to match sprite (slightly smaller for feel)
	var collision = $CollisionShape2D
	if collision and collision.shape is RectangleShape2D:
		collision.shape.size = Vector2(sprite_size * 0.875, sprite_size * 0.875)

	# Only enable camera for local player
	var camera = $Camera2D
	if camera:
		camera.enabled = is_local_player()
		if is_local_player():
			camera.reset_smoothing()

	# Find world tilemap for rock breaking (sibling node)
	world = get_parent().get_node_or_null("TileMapLayer") as TileMapLayer

	_setup_mine_light()

	# Only local player sets up hotbar and UI connections
	if is_local_player():
		await get_tree().process_frame
		hotbar = get_tree().get_first_node_in_group("hotbar")
		if hotbar == null:
			hotbar = get_node_or_null("/root/Node2D/CanvasLayer/Hotbar")

		if hotbar:
			hotbar.item_dropped.connect(_on_item_dropped)
			# Give player starting tool - just an axe, pick must be crafted
			var axe = Item.create("axe")
			hotbar.set_item(0, axe)

		# Find box inventory and furnace inventory
		box_inventory = get_tree().get_first_node_in_group("box_inventory")
		furnace_inventory = get_tree().get_first_node_in_group("furnace_inventory")


func _is_any_window_open() -> bool:
	if box_inventory and box_inventory.is_open:
		return true
	if furnace_inventory and furnace_inventory.is_open:
		return true
	var crafting = get_tree().get_first_node_in_group("crafting_window")
	if crafting and crafting.is_open:
		return true
	return false


func _physics_process(_delta: float) -> void:
	# Only process input for local player
	if not is_local_player():
		return

	# Block movement when any window is open
	var window_open = _is_any_window_open()

	var input_dir = Vector2.ZERO

	if not window_open:
		if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
			input_dir.x -= 1
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
			input_dir.x += 1
		if Input.is_key_pressed(KEY_UP) or (Input.is_key_pressed(KEY_W) and not Input.is_key_pressed(KEY_META)):
			input_dir.y -= 1
		if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
			input_dir.y += 1

	var current_speed = walk_speed if Input.is_key_pressed(KEY_SHIFT) else run_speed
	velocity = input_dir.normalized() * current_speed
	move_and_slide()

	# Block tile interaction when any window is open
	if _pending_left_click:
		_pending_left_click = false
		if not window_open:
			_handle_left_click()

	if _pending_right_click:
		_pending_right_click = false
		if not window_open:
			_handle_right_click()

	_try_pickup()


func _input(event: InputEvent) -> void:
	# Only process input for local player
	if not is_local_player():
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_pending_left_click = true
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_pending_right_click = true
	elif event.is_action_pressed("use"):
		if not _is_any_window_open():
			_handle_interact()


func _handle_left_click() -> void:
	if not hotbar or not world:
		return

	var selected_item = hotbar.get_selected_item()
	if selected_item == null:
		return

	# Check what item is selected and perform appropriate action
	if selected_item.item_id in ["box", "wood_wall", "stone_wall", "furnace", "iron_wall", "wood_floor", "stone_floor", "gold_wall", "wood_roof", "stone_roof", "iron_roof", "gold_roof", "mine_spawner", "torch"]:
		_try_place_item()
	elif _is_tool(selected_item.item_id):
		_try_use_tool()


func _handle_right_click() -> void:
	if not world:
		return

	# Don't open if any inventory is already open
	if box_inventory and box_inventory.is_open:
		return
	if furnace_inventory and furnace_inventory.is_open:
		return

	# Get mouse position in world coordinates and convert to tile
	var mouse_pos = get_global_mouse_position()
	var tile_pos = world.local_to_map(world.to_local(mouse_pos))

	# Use tile center for distance check
	var tile_center = world.to_global(world.map_to_local(tile_pos))
	var use_range = sprite_size * 2.0
	if global_position.distance_to(tile_center) > use_range:
		return

	var source_id = world.get_cell_source_id(tile_pos)

	# Check if it's a box tile (source_id 3)
	if source_id == 3 and box_inventory:
		box_inventory.open_for_box(tile_pos)
	# Check if it's a furnace tile (source_id 6)
	elif source_id == 6 and furnace_inventory:
		furnace_inventory.open_for_furnace(tile_pos)
	elif source_id == 12:  # Mine entrance
		world.enter_mine(tile_pos)
	elif source_id == 13:  # Mine exit
		world.exit_mine()


func _handle_interact() -> void:
	if not world:
		return

	# Find the nearest interactable tile within 2-tile radius
	# Use visual center (sprite is offset -16 from global_position)
	var visual_center = global_position + Vector2(0, -sprite_size)
	var player_tile = world.local_to_map(world.to_local(visual_center))

	# Check roof layer first for nearest roof tile
	var best_roof_tile: Vector2i
	var best_roof_dist: float = INF
	var has_roof_target: bool = false

	if world.roof_layer:
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var tile_pos = player_tile + Vector2i(dx, dy)
				var roof_source = world.roof_layer.get_cell_source_id(tile_pos)
				if roof_source < 0 or roof_source == world.MINE_DARKNESS_SOURCE:
					continue
				var tile_world_pos = world.to_global(world.map_to_local(tile_pos))
				var dist = visual_center.distance_to(tile_world_pos)
				if dist > sprite_size * 2.0:
					continue
				if dist < best_roof_dist:
					best_roof_dist = dist
					best_roof_tile = tile_pos
					has_roof_target = true

	if has_roof_target:
		if hotbar:
			var selected_item = hotbar.get_selected_item()
			if selected_item and _is_tool(selected_item.item_id):
				world.request_hit_roof.rpc_id(1, best_roof_tile, selected_item.item_id, peer_id)
		return

	# Find nearest ground tile
	var best_tile: Vector2i
	var best_dist: float = INF
	var best_source: int = -1

	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var tile_pos = player_tile + Vector2i(dx, dy)
			var source_id = world.get_cell_source_id(tile_pos)
			if source_id <= 0:
				continue
			var tile_world_pos = world.to_global(world.map_to_local(tile_pos))
			var dist = visual_center.distance_to(tile_world_pos)
			if dist > sprite_size * 2.0:
				continue
			if dist < best_dist:
				best_dist = dist
				best_tile = tile_pos
				best_source = source_id

	if best_source < 0:
		return

	# Containers: open them
	if best_source == 3 and box_inventory:
		box_inventory.open_for_box(best_tile)
		return
	if best_source == 6 and furnace_inventory:
		furnace_inventory.open_for_furnace(best_tile)
		return
	if best_source == 12:  # Mine entrance
		world.enter_mine(best_tile)
		return
	if best_source == 13:  # Mine exit
		world.exit_mine()
		return

	# Breakable tiles: use equipped tool if correct
	if hotbar:
		var selected_item = hotbar.get_selected_item()
		if selected_item and _is_tool(selected_item.item_id):
			world.request_hit_tile.rpc_id(1, best_tile, selected_item.item_id, peer_id)


func _setup_mine_light() -> void:
	# Create radial gradient texture for light falloff
	var gradient = Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color.TRANSPARENT)

	var tex = GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)

	# Main light with shadows - illuminates floors/background, blocked by walls
	_mine_light = PointLight2D.new()
	_mine_light.name = "MineLight"
	_mine_light.position = Vector2(0, -16)
	_mine_light.enabled = false
	_mine_light.texture = tex
	_mine_light.texture_scale = 1.2
	_mine_light.energy = 1.0
	_mine_light.color = Color(1.0, 0.95, 0.85)
	_mine_light.shadow_enabled = true
	_mine_light.shadow_color = Color(0.0, 0.0, 0.0, 0.8)
	_mine_light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	_mine_light.shadow_filter_smooth = 1.0
	add_child(_mine_light)

	# Ambient light without shadows - illuminates nearby walls so occluding
	# tiles are still visible based on proximity to the player
	_mine_ambient_light = PointLight2D.new()
	_mine_ambient_light.name = "MineAmbientLight"
	_mine_ambient_light.position = Vector2(0, -16)
	_mine_ambient_light.enabled = false
	_mine_ambient_light.texture = tex
	_mine_ambient_light.texture_scale = 0.5
	_mine_ambient_light.energy = 0.6
	_mine_ambient_light.color = Color(0.85, 0.9, 1.0)
	_mine_ambient_light.shadow_enabled = false
	add_child(_mine_ambient_light)


func set_mine_light(enabled: bool) -> void:
	if _mine_light:
		_mine_light.enabled = enabled
	if _mine_ambient_light:
		_mine_ambient_light.enabled = enabled


func _is_tool(item_id: String) -> bool:
	return item_id in ["axe", "wood_pick", "wood_axe", "stone_pick", "stone_axe", "iron_pick", "iron_axe", "gold_pick", "gold_axe"]


func _get_tool_hits(item_name: String) -> int:
	if item_name.begins_with("Stone"):
		return STONE_TOOL_HITS
	elif item_name.begins_with("Wood"):
		return WOOD_TOOL_HITS
	else:
		return PLASTIC_TOOL_HITS


func _try_use_tool() -> void:
	if not hotbar or not world:
		return

	var selected_item = hotbar.get_selected_item()
	if selected_item == null:
		return

	var tool_id = selected_item.item_id
	if not _is_tool(tool_id):
		return

	# Get mouse position in world coordinates and convert to tile
	var mouse_pos = get_global_mouse_position()
	var tile_pos = world.local_to_map(world.to_local(mouse_pos))

	# Use tile center for distance check
	var tile_center = world.to_global(world.map_to_local(tile_pos))
	var use_range = sprite_size * 2.0
	if global_position.distance_to(tile_center) > use_range:
		return

	# Check roof layer first - break roofs before ground tiles (skip mine darkness overlay)
	if world.roof_layer:
		var roof_source_id = world.roof_layer.get_cell_source_id(tile_pos)
		if roof_source_id >= 0 and roof_source_id != world.MINE_DARKNESS_SOURCE:
			world.request_hit_roof.rpc_id(1, tile_pos, tool_id, peer_id)
			return

	var source_id = world.get_cell_source_id(tile_pos)

	# Request tile hit through world (host-authoritative)
	if source_id > 0:  # Not grass
		world.request_hit_tile.rpc_id(1, tile_pos, tool_id, peer_id)


func _try_place_item() -> void:
	if not hotbar or not world:
		return

	var selected_item = hotbar.get_selected_item()
	if selected_item == null:
		return

	# Determine which tile to place based on item
	var tile_source_id: int = -1
	var is_roof: bool = false
	match selected_item.item_id:
		"box":
			tile_source_id = 3
		"wood_wall":
			tile_source_id = 4
		"stone_wall":
			tile_source_id = 5
		"furnace":
			tile_source_id = 6
		"iron_wall":
			tile_source_id = 8
		"wood_floor":
			tile_source_id = 9
		"stone_floor":
			tile_source_id = 10
		"gold_wall":
			tile_source_id = 11
		"wood_roof":
			tile_source_id = 0
			is_roof = true
		"stone_roof":
			tile_source_id = 1
			is_roof = true
		"iron_roof":
			tile_source_id = 2
			is_roof = true
		"gold_roof":
			tile_source_id = 3
			is_roof = true
		"mine_spawner":
			tile_source_id = 12
		"torch":
			tile_source_id = 17
		_:
			return

	# Get mouse position in world coordinates and convert to tile
	var mouse_pos = get_global_mouse_position()
	var tile_pos = world.local_to_map(world.to_local(mouse_pos))

	# Use tile center for distance check
	var tile_center = world.to_global(world.map_to_local(tile_pos))
	var use_range = sprite_size * 2.0
	if global_position.distance_to(tile_center) > use_range:
		return

	# Route to appropriate placement RPC
	if is_roof:
		world.request_place_roof.rpc_id(1, tile_pos, tile_source_id, selected_item.item_id, peer_id)
	else:
		world.request_place_tile.rpc_id(1, tile_pos, tile_source_id, selected_item.item_id, peer_id)


func _try_pickup() -> void:
	if not is_local_player():
		return

	var dropped_items = get_tree().get_nodes_in_group("dropped_items")
	var picked_up_any := false

	for item_node in dropped_items:
		var dropped: DroppedItem = item_node as DroppedItem
		if dropped == null or not dropped.can_pickup or dropped.being_picked_up:
			continue

		var dist = global_position.distance_to(dropped.global_position)
		if dist < pickup_range and dropped.item and hotbar:
			# Skip if inventory can't accept this item
			if not hotbar.can_add_item(dropped.item):
				continue

			# Request pickup through world (host-authoritative)
			if dropped.network_id >= 0:
				world.request_pickup_item.rpc_id(1, dropped.network_id, peer_id)
			else:
				# Fallback for items spawned before networking (single player mode)
				if hotbar.add_item(dropped.item):
					dropped.start_pickup(self)
					picked_up_any = true

	if picked_up_any:
		_play_pickup_sound()


func _play_pickup_sound() -> void:
	# Prevent multiple pickup sounds on the same frame
	var current_frame = Engine.get_process_frames()
	if current_frame == _last_pickup_sound_frame:
		return
	_last_pickup_sound_frame = current_frame

	var audio = AudioStreamPlayer.new()
	audio.stream = pickup_sound
	audio.bus = "Master"
	get_tree().root.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)


func _on_item_dropped(item: Item, _slot_index: int) -> void:
	if item == null or not world:
		return

	# Request drop through world (host-authoritative)
	var drop_offset = Vector2(sprite_size, 0).rotated(randf() * TAU)
	var drop_pos = global_position + drop_offset
	world.request_drop_item.rpc_id(1, item.item_id, item.quantity, drop_pos, peer_id)


# Called by world.gd when placement is confirmed
func on_placement_confirmed(item_id: String) -> void:
	if not hotbar:
		return
	var selected_item = hotbar.get_selected_item()
	if selected_item and selected_item.item_id == item_id:
		selected_item.quantity -= 1
		if selected_item.quantity <= 0:
			hotbar.set_item(hotbar.selected_slot, null)
		hotbar._update_item_icons()


# Called by world.gd when pickup is confirmed
func on_pickup_confirmed(item: Item) -> void:
	# Note: inventory capacity is checked before requesting pickup, so this should
	# always succeed. If it fails due to a race condition, the item is lost.
	if hotbar and hotbar.add_item(item):
		_play_pickup_sound()
