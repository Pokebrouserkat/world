class_name Item
extends Resource

@export var name: String = ""
@export var texture: Texture2D
@export var quantity: int = 1
@export var max_stack: int = 99
@export var stackable: bool = true


static func create(item_name: String, item_texture: Texture2D, item_quantity: int = 1) -> Item:
	var item = Item.new()
	item.name = item_name
	item.texture = item_texture
	item.quantity = item_quantity
	return item


func can_stack_with(other: Item) -> bool:
	return stackable and other.stackable and name == other.name


func add_quantity(amount: int) -> int:
	# Returns leftover that couldn't fit
	var space = max_stack - quantity
	var to_add = mini(amount, space)
	quantity += to_add
	return amount - to_add
