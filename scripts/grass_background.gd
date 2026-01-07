extends Sprite2D

func _process(_delta: float) -> void:
	var canvas_xform = get_canvas_transform()
	var camera_pos = -canvas_xform.origin / canvas_xform.get_scale()
	# Snap to tile grid to avoid sub-pixel jitter
	position = Vector2(snappedf(camera_pos.x, 16), snappedf(camera_pos.y, 16))
