class_name DroppedItem
extends Area2D

var item: Item
var can_pickup: bool = false


func _ready() -> void:
	if item and item.texture:
		$Sprite2D.texture = item.texture
	_update_collision_from_sprite()


func _update_collision_from_sprite() -> void:
	var sprite = $Sprite2D
	var collision = $CollisionShape2D
	if sprite and sprite.texture and collision and collision.shape is CircleShape2D:
		# Set radius to half the sprite width
		collision.shape.radius = sprite.texture.get_width() / 2.0


func set_item(new_item: Item) -> void:
	item = new_item
	if is_inside_tree() and item and item.texture:
		$Sprite2D.texture = item.texture
		_update_collision_from_sprite()


func enable_pickup_after_delay(delay: float = 0.5) -> void:
	can_pickup = false
	await get_tree().create_timer(delay).timeout
	can_pickup = true
