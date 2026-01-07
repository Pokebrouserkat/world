class_name Item
extends Resource

@export var name: String = ""
@export var texture: Texture2D


static func create(item_name: String, item_texture: Texture2D) -> Item:
	var item = Item.new()
	item.name = item_name
	item.texture = item_texture
	return item
