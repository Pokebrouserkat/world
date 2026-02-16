class_name TextureCache

# Centralized texture cache for item textures
# Use TextureCache.get_texture(key) and TextureCache.get_key(texture)

static var _cache: Dictionary = {}
static var _initialized: bool = false


static func _ensure_loaded() -> void:
    if _initialized:
        return
    _initialized = true
    _cache["rock_item"] = preload("res://graphics/rock_item.png")
    _cache["wood"] = preload("res://graphics/wood.png")
    _cache["box"] = preload("res://graphics/box.png")
    _cache["wood_wall"] = preload("res://graphics/woodwall.png")
    _cache["stone_wall"] = preload("res://graphics/stonewall.png")
    _cache["axe"] = preload("res://graphics/plasticax.png")
    _cache["wood_pick"] = preload("res://graphics/woodpick.png")
    _cache["wood_axe"] = preload("res://graphics/woodax.png")
    _cache["stone_pick"] = preload("res://graphics/stonepick.png")
    _cache["stone_axe"] = preload("res://graphics/stoneax.png")
    _cache["iron_ore"] = preload("res://graphics/ironore.png")
    _cache["iron"] = preload("res://graphics/iron.png")
    _cache["iron_pick"] = preload("res://graphics/ironpick.png")
    _cache["iron_axe"] = preload("res://graphics/ironax.png")
    _cache["furnace"] = preload("res://graphics/furnace.png")
    _cache["iron_wall"] = preload("res://graphics/ironwall.png")
    _cache["wood_floor"] = preload("res://graphics/woodfloor.png")
    _cache["stone_floor"] = preload("res://graphics/stonefloor.png")
    _cache["gold_ore"] = preload("res://graphics/goldore.png")
    _cache["gold"] = preload("res://graphics/gold.png")
    _cache["gold_pick"] = preload("res://graphics/goldpick.png")
    _cache["gold_axe"] = preload("res://graphics/goldax.png")
    _cache["gold_wall"] = preload("res://graphics/goldwall.png")
    _cache["wood_roof"] = preload("res://graphics/woodroof.png")
    _cache["stone_roof"] = preload("res://graphics/stoneroof.png")
    _cache["iron_roof"] = preload("res://graphics/ironroof.png")
    _cache["gold_roof"] = preload("res://graphics/goldroof.png")
    _cache["mine_entrance"] = preload("res://graphics/mineentrance.png")
    _cache["fallback"] = preload("res://graphics/fallback.png")


static func get_texture(key: String) -> Texture2D:
    _ensure_loaded()
    return _cache.get(key, _cache["fallback"])


static func get_key(texture: Texture2D) -> String:
    _ensure_loaded()
    for key in _cache:
        if _cache[key] == texture:
            return key
    return "fallback"
