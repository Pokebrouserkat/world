class_name FurnaceSystem
extends RefCounted

var _world: TileMapLayer

# Furnace state storage: Dictionary[Vector2i, {input_item, output_item, smelt_progress}]
var states: Dictionary = {}


func init(world: TileMapLayer) -> void:
    _world = world


func get_state(furnace_pos: Vector2i) -> Dictionary:
    if not states.has(furnace_pos):
        states[furnace_pos] = {
            "input_item": null,
            "output_item": null,
            "smelt_progress": 0.0,
            "fuel_item": null,
            "fuel_level": 0.0
        }
    return states[furnace_pos]


func set_state(furnace_pos: Vector2i, state: Dictionary) -> void:
    states[furnace_pos] = state


func clear_state(furnace_pos: Vector2i) -> Dictionary:
    var state: Dictionary = {"input_item": null, "output_item": null, "smelt_progress": 0.0, "fuel_item": null, "fuel_level": 0.0}
    if states.has(furnace_pos):
        state = states[furnace_pos]
        states.erase(furnace_pos)
    return state


func tick(delta: float) -> bool:
    ## Returns true if any furnace completed smelting (triggers autosave).
    var any_changed := false
    for pos in states:
        var state: Dictionary = states[pos]
        var input_item = state.get("input_item")
        if input_item == null:
            if state.get("smelt_progress", 0.0) != 0.0:
                state.smelt_progress = 0.0
            continue

        var smelt_output_id: String = Constants.SMELT_RECIPES.get(input_item.item_id, "")
        if smelt_output_id == "":
            if state.get("smelt_progress", 0.0) != 0.0:
                state.smelt_progress = 0.0
            continue

        var output_item = state.get("output_item")
        var can_output = output_item == null or (output_item.item_id == smelt_output_id and output_item.quantity < 99)
        if not can_output:
            continue

        # Try to consume fuel if empty
        if state.get("fuel_level", 0.0) <= 0.0:
            var fuel_item = state.get("fuel_item")
            if fuel_item != null:
                var fuel_value: float = Constants.FUEL_VALUES.get(fuel_item.item_id, 0.0)
                if fuel_value > 0.0:
                    state.fuel_level = fuel_value
                    fuel_item.quantity -= 1
                    if fuel_item.quantity <= 0:
                        state.fuel_item = null

        if state.get("fuel_level", 0.0) <= 0.0:
            continue

        # Consume fuel and advance progress
        state.fuel_level -= delta / Constants.SMELT_TIME
        state.smelt_progress += delta

        if state.smelt_progress >= Constants.SMELT_TIME:
            state.smelt_progress = 0.0
            input_item.quantity -= 1
            if input_item.quantity <= 0:
                state.input_item = null
            if output_item == null:
                state.output_item = Item.create(smelt_output_id, 1)
            else:
                output_item.quantity += 1
            any_changed = true

    return any_changed
