extends Node

## SaveManager - Handles game save/load functionality
## Autoload singleton for managing game persistence

const SAVE_PATH: String = "user://save.json"

signal game_saved
signal game_loaded
signal save_failed(reason: String)
signal load_failed(reason: String)

var _last_save_time: int = 0  # Unix timestamp of last save


func get_last_save_time() -> int:
	return _last_save_time


func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var world = _get_world()
	var player = _get_local_player()
	var hotbar = _get_hotbar()

	if not world:
		save_failed.emit("World not found")
		return false

	var save_data: Dictionary = {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"player": _serialize_player(player),
		"hotbar": _serialize_hotbar(hotbar),
		"tile_modifications": _serialize_tile_modifications(world),
		"dropped_items": _serialize_dropped_items(world),
		"box_contents": _serialize_box_contents(world),
	}

	var json_string = JSON.stringify(save_data, "\t")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		save_failed.emit("Could not open save file")
		return false

	file.store_string(json_string)
	file.close()

	_last_save_time = save_data.timestamp
	game_saved.emit()
	return true


func load_game() -> bool:
	if not has_save_file():
		load_failed.emit("No save file found")
		return false

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		load_failed.emit("Could not open save file")
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		load_failed.emit("Invalid save file format")
		return false

	var save_data: Dictionary = json.data
	if not save_data.has("version"):
		load_failed.emit("Save file missing version")
		return false

	var world = _get_world()
	var player = _get_local_player()
	var hotbar = _get_hotbar()

	if not world:
		load_failed.emit("World not found")
		return false

	# Load data
	_deserialize_player(save_data.get("player", {}), player)
	_deserialize_hotbar(save_data.get("hotbar", []), hotbar)
	_deserialize_tile_modifications(save_data.get("tile_modifications", {}), world)
	_deserialize_dropped_items(save_data.get("dropped_items", []), world)
	_deserialize_box_contents(save_data.get("box_contents", {}), world)

	_last_save_time = save_data.get("timestamp", 0)
	game_loaded.emit()
	return true


# === Serialization helpers ===

func _get_world() -> TileMapLayer:
	return get_tree().get_first_node_in_group("world") as TileMapLayer


func _get_local_player() -> CharacterBody2D:
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if player.has_method("is_local_player") and player.is_local_player():
			return player
	return null


func _get_hotbar() -> Node:
	return get_tree().get_first_node_in_group("hotbar")


func _serialize_player(player: CharacterBody2D) -> Dictionary:
	if not player:
		return {}
	return {
		"position": {"x": player.global_position.x, "y": player.global_position.y}
	}


func _serialize_hotbar(hotbar: Node) -> Array:
	if not hotbar:
		return []

	var slots: Array = []
	for i in range(hotbar.slot_count):
		var item = hotbar.get_item(i)
		if item:
			slots.append({
				"slot": i,
				"name": item.name,
				"texture_key": _get_texture_key(item.texture),
				"quantity": item.quantity,
				"stackable": item.stackable
			})
	return slots


func _serialize_tile_modifications(world: TileMapLayer) -> Dictionary:
	var mods: Dictionary = {}
	for pos in world._tile_modifications:
		var key = "%d,%d" % [pos.x, pos.y]
		mods[key] = world._tile_modifications[pos]
	return mods


func _serialize_dropped_items(world: TileMapLayer) -> Array:
	var items: Array = []
	var dropped_nodes = get_tree().get_nodes_in_group("dropped_items")
	for node in dropped_nodes:
		if node.item:
			items.append({
				"name": node.item.name,
				"texture_key": _get_texture_key(node.item.texture),
				"quantity": node.item.quantity,
				"stackable": node.item.stackable,
				"position": {"x": node.global_position.x, "y": node.global_position.y}
			})
	return items


func _serialize_box_contents(world: TileMapLayer) -> Dictionary:
	var boxes: Dictionary = {}
	for pos in world._box_contents:
		var key = "%d,%d" % [pos.x, pos.y]
		var contents: Array = []
		for item in world._box_contents[pos]:
			if item:
				contents.append({
					"name": item.name,
					"texture_key": _get_texture_key(item.texture),
					"quantity": item.quantity,
					"stackable": item.stackable
				})
			else:
				contents.append(null)
		boxes[key] = contents
	return boxes


# === Deserialization helpers ===

func _deserialize_player(data: Dictionary, player: CharacterBody2D) -> void:
	if not player or data.is_empty():
		return
	if data.has("position"):
		player.global_position = Vector2(data.position.x, data.position.y)


func _deserialize_hotbar(data: Array, hotbar: Node) -> void:
	if not hotbar:
		return

	# Clear hotbar first
	for i in range(hotbar.slot_count):
		hotbar.set_item(i, null)

	# Load saved items
	for item_data in data:
		var texture = _get_texture_from_key(item_data.texture_key)
		var item = Item.create(item_data.name, texture, item_data.quantity)
		item.stackable = item_data.stackable
		hotbar.set_item(item_data.slot, item)


func _deserialize_tile_modifications(data: Dictionary, world: TileMapLayer) -> void:
	# Clear existing modifications
	world._tile_modifications.clear()
	world._generated_tiles.clear()

	# Load saved modifications
	for key in data:
		var parts = key.split(",")
		if parts.size() == 2:
			var pos = Vector2i(int(parts[0]), int(parts[1]))
			world._tile_modifications[pos] = data[key]

	# Force tile regeneration
	world._last_rect = Rect2i()


func _deserialize_dropped_items(data: Array, world: TileMapLayer) -> void:
	# Clear existing dropped items
	var existing = get_tree().get_nodes_in_group("dropped_items")
	for node in existing:
		node.queue_free()
	world._dropped_items.clear()
	world._next_item_id = 0

	# Wait a frame for cleanup
	await get_tree().process_frame

	# Spawn saved items
	for item_data in data:
		var pos = Vector2(item_data.position.x, item_data.position.y)
		world._spawn_item_at(item_data.name, item_data.texture_key,
			item_data.quantity, item_data.stackable, pos, 0.0)


func _deserialize_box_contents(data: Dictionary, world: TileMapLayer) -> void:
	# Clear existing box contents
	world._box_contents.clear()

	# Load saved contents
	for key in data:
		var parts = key.split(",")
		if parts.size() == 2:
			var pos = Vector2i(int(parts[0]), int(parts[1]))
			var contents: Array = []
			for item_data in data[key]:
				if item_data:
					var texture = _get_texture_from_key(item_data.texture_key)
					var item = Item.create(item_data.name, texture, item_data.quantity)
					item.stackable = item_data.stackable
					contents.append(item)
				else:
					contents.append(null)
			world._box_contents[pos] = contents


# === Texture key helpers (same as world.gd) ===

var _texture_cache: Dictionary = {}

func _ensure_textures_loaded() -> void:
	if _texture_cache.is_empty():
		_texture_cache["rock_item"] = preload("res://graphics/rock_item.png")
		_texture_cache["wood"] = preload("res://graphics/wood.png")
		_texture_cache["box"] = preload("res://graphics/box.png")
		_texture_cache["wood_wall"] = preload("res://graphics/woodwall.png")
		_texture_cache["stone_wall"] = preload("res://graphics/stonewall.png")
		_texture_cache["pick"] = preload("res://graphics/plasticpick.png")
		_texture_cache["axe"] = preload("res://graphics/plasticax.png")
		_texture_cache["wood_pick"] = preload("res://graphics/woodpick.png")
		_texture_cache["wood_axe"] = preload("res://graphics/woodax.png")
		_texture_cache["stone_pick"] = preload("res://graphics/stonepick.png")
		_texture_cache["stone_axe"] = preload("res://graphics/stoneax.png")


func _get_texture_from_key(key: String) -> Texture2D:
	_ensure_textures_loaded()
	return _texture_cache.get(key, _texture_cache["rock_item"])


func _get_texture_key(texture: Texture2D) -> String:
	_ensure_textures_loaded()
	for key in _texture_cache:
		if _texture_cache[key] == texture:
			return key
	return "rock_item"
