extends Label

const TILE_SIZE: int = 16


func _process(_delta: float) -> void:
    var players = get_tree().get_nodes_in_group("player")
    for player in players:
        if player.is_local_player():
            var pos = player.global_position
            var tile_x = floori(pos.x / TILE_SIZE)
            var tile_y = -floori(pos.y / TILE_SIZE)
            text = "X: %d  Y: %d" % [tile_x, tile_y]
            return
    text = ""
