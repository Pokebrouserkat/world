class_name MineGenerator

## Generates mine layouts deterministically based on entrance position.
## Mines exist at far-negative Y coordinates in the same world space.

const MINE_Y_BASE: int = -100_000
const MINE_SPREAD: int = 200  # Tiles between mine origins
const MINE_SIZE: int = 60  # Width/height of mine area
const MIN_ROOMS: int = 5
const MAX_ROOMS: int = 7
const MIN_ROOM_SIZE: int = 5
const MAX_ROOM_SIZE: int = 10
const CORRIDOR_WIDTH: int = 2

# Tile source IDs (must match world.gd)
const CAVE_WALL_SOURCE: int = 14
const CAVE_FLOOR_SOURCE: int = 16
const ROCK_SOURCE: int = 1
const IRON_ORE_SOURCE: int = 7
const GOLD_ORE_SOURCE: int = 15
const COAL_ORE_SOURCE: int = 18
const MINE_EXIT_SOURCE: int = 13


static func get_mine_origin(entrance_pos: Vector2i, level: int = 1) -> Vector2i:
	var h = _entrance_hash(entrance_pos)
	var offset = absi(h) % 1000
	return Vector2i(entrance_pos.x, MINE_Y_BASE - (level - 1) * 100_000 - offset * MINE_SPREAD)


static func generate(entrance_pos: Vector2i, level: int = 1) -> Dictionary:
	var origin = get_mine_origin(entrance_pos, level)
	var rng = RandomNumberGenerator.new()
	rng.seed = _entrance_hash(entrance_pos)

	var tiles: Dictionary = {}  # Vector2i -> source_id

	# 1 in 10 chance for a stone cave (breakable rock walls instead of unbreakable cave walls)
	var is_stone_cave = (rng.randi() % 10) == 0
	var wall_source = ROCK_SOURCE if is_stone_cave else CAVE_WALL_SOURCE

	# Fill area with walls
	for x in range(MINE_SIZE):
		for y in range(MINE_SIZE):
			tiles[origin + Vector2i(x, y)] = wall_source

	# Generate rooms
	var rooms: Array = []  # Array of Rect2i
	var room_count = rng.randi_range(MIN_ROOMS, MAX_ROOMS)

	for i in range(room_count):
		var room = _try_place_room(rng, rooms, MINE_SIZE)
		if room != Rect2i():
			rooms.append(room)

	# Carve rooms as stone floor
	for room in rooms:
		for x in range(room.position.x, room.end.x):
			for y in range(room.position.y, room.end.y):
				tiles[origin + Vector2i(x, y)] = CAVE_FLOOR_SOURCE

	# Connect rooms with corridors (connect each room to the next)
	for i in range(rooms.size() - 1):
		_carve_corridor(tiles, origin, rooms[i], rooms[i + 1])

	# Scatter resources inside rooms
	for room in rooms:
		for x in range(room.position.x + 1, room.end.x - 1):
			for y in range(room.position.y + 1, room.end.y - 1):
				var pos = origin + Vector2i(x, y)
				if tiles[pos] != CAVE_FLOOR_SOURCE:
					continue
				var r = rng.randf()
				if r < 0.03:
					tiles[pos] = GOLD_ORE_SOURCE
				elif r < 0.08:
					tiles[pos] = IRON_ORE_SOURCE
				elif r < 0.16:
					tiles[pos] = COAL_ORE_SOURCE
				elif r < 0.26:
					tiles[pos] = ROCK_SOURCE

	# Place exit in center of first room
	var exit_pos: Vector2i
	if rooms.size() > 0:
		var first = rooms[0]
		@warning_ignore("integer_division")
		var center = Vector2i(first.position.x + first.size.x / 2, first.position.y + first.size.y / 2)
		exit_pos = origin + center
	else:
		@warning_ignore("integer_division")
		exit_pos = origin + Vector2i(MINE_SIZE / 2, MINE_SIZE / 2)

	# Make sure exit tile and surrounding tiles are floor
	tiles[exit_pos] = MINE_EXIT_SOURCE
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var adj = exit_pos + offset
		if tiles.has(adj) and tiles[adj] != CAVE_FLOOR_SOURCE:
			tiles[adj] = CAVE_FLOOR_SOURCE

	return {"tiles": tiles, "exit_pos": exit_pos}


static func _try_place_room(rng: RandomNumberGenerator, existing: Array, area_size: int) -> Rect2i:
	# Try up to 20 times to place a non-overlapping room
	for _attempt in range(20):
		var w = rng.randi_range(MIN_ROOM_SIZE, MAX_ROOM_SIZE)
		var h = rng.randi_range(MIN_ROOM_SIZE, MAX_ROOM_SIZE)
		var x = rng.randi_range(2, area_size - w - 2)
		var y = rng.randi_range(2, area_size - h - 2)
		var candidate = Rect2i(x, y, w, h)

		var overlaps = false
		for room in existing:
			# Add 1-tile buffer between rooms
			var expanded = Rect2i(room.position - Vector2i(1, 1), room.size + Vector2i(2, 2))
			if expanded.intersects(candidate):
				overlaps = true
				break

		if not overlaps:
			return candidate

	return Rect2i()


static func _carve_corridor(tiles: Dictionary, origin: Vector2i, room_a: Rect2i, room_b: Rect2i) -> void:
	# Connect centers of two rooms with an L-shaped corridor
	@warning_ignore("integer_division")
	var a_center = Vector2i(room_a.position.x + room_a.size.x / 2, room_a.position.y + room_a.size.y / 2)
	@warning_ignore("integer_division")
	var b_center = Vector2i(room_b.position.x + room_b.size.x / 2, room_b.position.y + room_b.size.y / 2)

	# Horizontal then vertical
	var x_start = mini(a_center.x, b_center.x)
	var x_end = maxi(a_center.x, b_center.x)
	for x in range(x_start, x_end + 1):
		for w in range(CORRIDOR_WIDTH):
			var pos = origin + Vector2i(x, a_center.y + w)
			if tiles.has(pos):
				tiles[pos] = CAVE_FLOOR_SOURCE

	var y_start = mini(a_center.y, b_center.y)
	var y_end = maxi(a_center.y, b_center.y)
	for y in range(y_start, y_end + 1):
		for w in range(CORRIDOR_WIDTH):
			var pos = origin + Vector2i(b_center.x + w, y)
			if tiles.has(pos):
				tiles[pos] = CAVE_FLOOR_SOURCE


static func _entrance_hash(entrance_pos: Vector2i) -> int:
	# Deterministic hash from entrance position
	var n = sin(entrance_pos.x * 73.156 + entrance_pos.y * 91.713) * 43758.5453
	return absi(int(n * 10000))
