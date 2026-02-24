extends Label


func _process(_delta: float) -> void:
    var world = get_tree().get_first_node_in_group("world")
    if not world:
        text = ""
        return

    var time_ratio = world.game_time / Constants.DAY_LENGTH
    if time_ratio < 0.15:
        text = "Dawn"
    elif time_ratio < 0.55:
        text = "Day"
    elif time_ratio < 0.70:
        text = "Dusk"
    else:
        text = "Night"
