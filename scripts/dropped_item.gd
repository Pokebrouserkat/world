class_name DroppedItem
extends Area2D

var item: Item
var can_pickup: bool = false


func _ready() -> void:
	if item and item.texture:
		$Sprite2D.texture = item.texture


func set_item(new_item: Item) -> void:
	item = new_item
	if is_inside_tree() and item and item.texture:
		$Sprite2D.texture = item.texture


func enable_pickup_after_delay(delay: float = 0.5) -> void:
	can_pickup = false
	await get_tree().create_timer(delay).timeout
	can_pickup = true
