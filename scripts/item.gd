class_name Item
extends Resource

const Registry = preload("res://scripts/item_registry.gd")

@export var item_id: String = ""
@export var quantity: int = 1

# Computed properties from registry
var display_name: String:
	get: return Registry.get_display_name(item_id)

var texture: Texture2D:
	get: return TextureCache.get_texture(Registry.get_texture_key(item_id))

var max_stack: int:
	get: return Registry.get_item_data(item_id).get("max_stack", 1)

var stackable: bool:
	get: return max_stack > 1

# Legacy property for compatibility during transition
var name: String:
	get: return display_name
	set(value): pass  # Ignored - use item_id


static func create(id: String, item_quantity: int = 1) -> Item:
	if not Registry.has_item(id):
		push_warning("Unknown item id: %s" % id)
	var item = Item.new()
	item.item_id = id
	item.quantity = item_quantity
	return item


func can_stack_with(other: Item) -> bool:
	return stackable and other.stackable and item_id == other.item_id


func add_quantity(amount: int) -> int:
	# Returns leftover that couldn't fit
	var space = max_stack - quantity
	var to_add = mini(amount, space)
	quantity += to_add
	return amount - to_add
