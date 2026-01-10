extends Label


func _process(_delta: float) -> void:
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if player.is_local_player():
			var pos = player.global_position
			text = "X: %d  Y: %d" % [int(pos.x), int(pos.y)]
			return
	text = ""
