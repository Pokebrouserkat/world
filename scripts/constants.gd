class_name Constants
extends RefCounted

# Day/night cycle
const DAY_LENGTH: float = 600.0

# Box storage
const BOX_SLOT_COUNT: int = 9

# Roof tiers
const ROOF_ITEMS: Array[String] = ["wood_roof", "stone_roof", "iron_roof", "gold_roof"]
const ROOF_DURABILITY = {
    "wood_roof": 20,
    "stone_roof": 30,
    "iron_roof": 60,
    "gold_roof": 120,
}

# Smelting
const SMELT_TIME: float = 30.0
const SMELT_RECIPES: Dictionary = {
    "iron_ore": "iron",
    "gold_ore": "gold"
}
const FUEL_VALUES: Dictionary = {
    "coal": 5.0,
    "wood": 0.05
}
