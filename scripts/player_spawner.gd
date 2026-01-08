extends Node

## PlayerSpawner - handles dynamic player instantiation for multiplayer
## Spawns a player for each connected peer, removes on disconnect

var player_scene: PackedScene = preload("res://scenes/player.tscn")
var players: Dictionary = {}  # peer_id -> Player node

# Spawn positions offset so players don't spawn on top of each other
const SPAWN_OFFSETS: Array[Vector2] = [
	Vector2(0, 0),
	Vector2(48, 0),
	Vector2(0, 48),
	Vector2(48, 48)
]


func _ready() -> void:
	# Connect to NetworkManager signals
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)

	# If we're already hosting or in single-player mode, spawn local player
	# This handles the case where the game starts without explicit networking
	await get_tree().process_frame
	if not NetworkManager.is_connected_to_game():
		# Single player mode - spawn player immediately
		spawn_player(1)


func spawn_player(peer_id: int) -> void:
	if players.has(peer_id):
		return  # Already spawned

	var player = player_scene.instantiate()
	player.peer_id = peer_id
	player.name = "Player_%d" % peer_id

	# Set spawn position based on peer index
	var peer_index = NetworkManager.get_connected_peers().find(peer_id)
	if peer_index < 0:
		peer_index = players.size()
	var spawn_offset = SPAWN_OFFSETS[peer_index % SPAWN_OFFSETS.size()]
	player.global_position = spawn_offset

	players[peer_id] = player
	get_parent().add_child(player)
	print("Spawned player for peer %d" % peer_id)


func remove_player(peer_id: int) -> void:
	if not players.has(peer_id):
		return

	var player = players[peer_id]
	players.erase(peer_id)
	player.queue_free()
	print("Removed player for peer %d" % peer_id)


func get_player(peer_id: int) -> Node:
	return players.get(peer_id)


func get_local_player() -> Node:
	return players.get(NetworkManager.get_local_peer_id())


func _on_player_connected(peer_id: int) -> void:
	# Only host spawns players (authority)
	if NetworkManager.is_host():
		spawn_player(peer_id)
		# Tell all clients to spawn this player
		_rpc_spawn_player.rpc(peer_id)
		# Also send existing players to the new peer
		for existing_peer_id in players.keys():
			if existing_peer_id != peer_id:
				_rpc_spawn_player.rpc_id(peer_id, existing_peer_id)


func _on_player_disconnected(peer_id: int) -> void:
	remove_player(peer_id)
	if NetworkManager.is_host():
		# Tell all clients to remove this player
		_rpc_remove_player.rpc(peer_id)


func _on_connection_succeeded() -> void:
	# Client connected - clean up any single-player state first
	for peer_id in players.keys():
		remove_player(peer_id)
	# Now spawn local player with correct peer_id
	# The host will also tell us about other players via RPC
	spawn_player(NetworkManager.get_local_peer_id())


func _on_server_disconnected() -> void:
	# Clean up all players and return to single-player state
	for peer_id in players.keys():
		remove_player(peer_id)
	# Respawn local player in single-player mode
	spawn_player(1)


@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_player(peer_id: int) -> void:
	spawn_player(peer_id)


@rpc("authority", "call_remote", "reliable")
func _rpc_remove_player(peer_id: int) -> void:
	remove_player(peer_id)
