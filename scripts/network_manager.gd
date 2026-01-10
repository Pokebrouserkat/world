extends Node

## NetworkManager autoload - manages LAN multiplayer connections
## Usage: NetworkManager.host_game() or NetworkManager.join_game("192.168.1.x")

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_succeeded()
signal connection_failed()
signal server_disconnected()

const DEFAULT_PORT: int = 8903
const MAX_PLAYERS: int = 4

var peer: ENetMultiplayerPeer = null
var connected_peers: Array[int] = []


func _ready() -> void:
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected_to_server)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_game(port: int = DEFAULT_PORT) -> Error:
    peer = ENetMultiplayerPeer.new()
    var error = peer.create_server(port, MAX_PLAYERS - 1)  # -1 because host is also a player
    if error != OK:
        push_error("Failed to create server: %s" % error_string(error))
        return error

    multiplayer.multiplayer_peer = peer
    connected_peers.append(1)  # Host is always peer 1
    print("Hosting game on port %d" % port)
    return OK


func join_game(ip: String, port: int = DEFAULT_PORT) -> Error:
    peer = ENetMultiplayerPeer.new()
    var error = peer.create_client(ip, port)
    if error != OK:
        push_error("Failed to create client: %s" % error_string(error))
        return error

    multiplayer.multiplayer_peer = peer
    print("Connecting to %s:%d" % [ip, port])
    return OK


func disconnect_game() -> void:
    if peer:
        peer.close()
        peer = null
    multiplayer.multiplayer_peer = null
    connected_peers.clear()
    print("Disconnected from game")


func is_host() -> bool:
    return multiplayer.is_server()


func is_connected_to_game() -> bool:
    return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func get_local_peer_id() -> int:
    if peer == null:
        return 1  # Default for single player / offline
    return multiplayer.get_unique_id()


func get_connected_peers() -> Array[int]:
    return connected_peers.duplicate()


func _on_peer_connected(id: int) -> void:
    print("Peer connected: %d" % id)
    if not connected_peers.has(id):
        connected_peers.append(id)
    player_connected.emit(id)


func _on_peer_disconnected(id: int) -> void:
    print("Peer disconnected: %d" % id)
    connected_peers.erase(id)
    player_disconnected.emit(id)


func _on_connected_to_server() -> void:
    print("Connected to server as peer %d" % multiplayer.get_unique_id())
    connected_peers.append(multiplayer.get_unique_id())
    connection_succeeded.emit()


func _on_connection_failed() -> void:
    print("Connection to server failed")
    peer = null
    multiplayer.multiplayer_peer = null
    connection_failed.emit()


func _on_server_disconnected() -> void:
    print("Server disconnected")
    connected_peers.clear()
    peer = null
    multiplayer.multiplayer_peer = null
    server_disconnected.emit()
