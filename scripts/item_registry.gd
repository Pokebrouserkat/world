class_name ItemRegistry

## Central registry for all item definitions
## Use ItemRegistry.get_item_data(id) to look up item properties

# Item definitions: id -> {texture_key, max_stack, display_name}
# The id is used for saving/loading and internal references
# display_name is what's shown to the player (defaults to id if not specified)
# max_stack of 1 means not stackable
const ITEMS: Dictionary = {
    "rock": {
        "texture_key": "rock_item",
        "max_stack": 99,
        "display_name": "Rock"
    },
    "wood": {
        "texture_key": "wood",
        "max_stack": 99,
        "display_name": "Wood"
    },
    "box": {
        "texture_key": "box",
        "max_stack": 99,
        "display_name": "Box"
    },
    "wood_wall": {
        "texture_key": "wood_wall",
        "max_stack": 99,
        "display_name": "Wood Wall"
    },
    "stone_wall": {
        "texture_key": "stone_wall",
        "max_stack": 99,
        "display_name": "Stone Wall"
    },
    "axe": {
        "texture_key": "axe",
        "max_stack": 1,
        "display_name": "Axe"
    },
    "wood_pick": {
        "texture_key": "wood_pick",
        "max_stack": 1,
        "display_name": "Wood Pick"
    },
    "wood_axe": {
        "texture_key": "wood_axe",
        "max_stack": 1,
        "display_name": "Wood Axe"
    },
    "stone_pick": {
        "texture_key": "stone_pick",
        "max_stack": 1,
        "display_name": "Stone Pick"
    },
    "stone_axe": {
        "texture_key": "stone_axe",
        "max_stack": 1,
        "display_name": "Stone Axe"
    },
    "iron_ore": {
        "texture_key": "iron_ore",
        "max_stack": 99,
        "display_name": "Iron Ore"
    },
    "iron": {
        "texture_key": "iron",
        "max_stack": 99,
        "display_name": "Iron"
    },
    "iron_pick": {
        "texture_key": "iron_pick",
        "max_stack": 1,
        "display_name": "Iron Pick"
    },
    "iron_axe": {
        "texture_key": "iron_axe",
        "max_stack": 1,
        "display_name": "Iron Axe"
    },
    "furnace": {
        "texture_key": "furnace",
        "max_stack": 99,
        "display_name": "Furnace"
    },
    "iron_wall": {
        "texture_key": "iron_wall",
        "max_stack": 99,
        "display_name": "Iron Wall"
    },
    "wood_floor": {
        "texture_key": "wood_floor",
        "max_stack": 99,
        "display_name": "Wood Floor"
    },
    "stone_floor": {
        "texture_key": "stone_floor",
        "max_stack": 99,
        "display_name": "Stone Floor"
    },
    "gold_ore": {
        "texture_key": "gold_ore",
        "max_stack": 99,
        "display_name": "Gold Ore"
    },
    "gold": {
        "texture_key": "gold",
        "max_stack": 99,
        "display_name": "Gold"
    },
    "gold_pick": {
        "texture_key": "gold_pick",
        "max_stack": 1,
        "display_name": "Gold Pick"
    },
    "gold_axe": {
        "texture_key": "gold_axe",
        "max_stack": 1,
        "display_name": "Gold Axe"
    },
    "gold_wall": {
        "texture_key": "gold_wall",
        "max_stack": 99,
        "display_name": "Gold Wall"
    },
    "wood_roof": {
        "texture_key": "wood_roof",
        "max_stack": 99,
        "display_name": "Wood Roof"
    },
    "stone_roof": {
        "texture_key": "stone_roof",
        "max_stack": 99,
        "display_name": "Stone Roof"
    },
    "iron_roof": {
        "texture_key": "iron_roof",
        "max_stack": 99,
        "display_name": "Iron Roof"
    },
    "gold_roof": {
        "texture_key": "gold_roof",
        "max_stack": 99,
        "display_name": "Gold Roof"
    },
    "mine_spawner": {
        "texture_key": "mine_entrance",
        "max_stack": 99,
        "display_name": "Mine Spawner"
    },
    "torch": {
        "texture_key": "torch",
        "max_stack": 99,
        "display_name": "Torch"
    },
    "coal": {
        "texture_key": "coal",
        "max_stack": 99,
        "display_name": "Coal"
    },
    "campfire": {
        "texture_key": "campfire",
        "max_stack": 99,
        "display_name": "Campfire"
    },
    "seed": {
        "texture_key": "seed",
        "max_stack": 99,
        "display_name": "Seed"
    },
}


static func get_item_data(item_id: String) -> Dictionary:
    return ITEMS.get(item_id, {})


static func has_item(item_id: String) -> bool:
    return ITEMS.has(item_id)


static func get_display_name(item_id: String) -> String:
    var data = get_item_data(item_id)
    return data.get("display_name", item_id)


static func get_texture_key(item_id: String) -> String:
    var data = get_item_data(item_id)
    return data.get("texture_key", "fallback")


static func is_stackable(item_id: String) -> bool:
    var data = get_item_data(item_id)
    return data.get("max_stack", 1) > 1
