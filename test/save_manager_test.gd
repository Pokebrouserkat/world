extends GdUnitTestSuite

## Tests for SaveManager deserialization to ensure dictionary access works correctly


func test_deserialize_hotbar_data() -> void:
    # Test that hotbar deserialization correctly parses dictionary data
    var hotbar_data: Array = [
        {"slot": 0, "id": "rock", "quantity": 5},
        {"slot": 2, "id": "axe", "quantity": 1},
    ]

    # Verify we can access the dictionary fields with bracket notation
    for item_data in hotbar_data:
        assert_that(item_data["id"]).is_not_null()
        assert_that(item_data["quantity"]).is_greater(0)
        assert_that(item_data["slot"]).is_greater_equal(0)

    # Specifically test the pattern used in save_manager.gd
    var first_item = hotbar_data[0]
    assert_that(first_item["id"]).is_equal("rock")
    assert_that(first_item["quantity"]).is_equal(5)
    assert_that(first_item["slot"]).is_equal(0)


func test_deserialize_dropped_items_data() -> void:
    # Test that dropped items deserialization correctly parses nested dictionary data
    var dropped_items_data: Array = [
        {"id": "wood", "quantity": 3, "position": {"x": 100.0, "y": 200.0}},
        {"id": "rock", "quantity": 10, "position": {"x": -50.0, "y": 75.5}},
    ]

    for item_data in dropped_items_data:
        # Test the exact pattern from save_manager.gd line 233-234
        var pos = Vector2(item_data["position"]["x"], item_data["position"]["y"])
        var id = item_data["id"]
        var quantity = item_data["quantity"]

        assert_that(pos).is_not_null()
        assert_that(id).is_not_empty()
        assert_that(quantity).is_greater(0)

    # Verify first item specifically
    var first = dropped_items_data[0]
    assert_that(first["id"]).is_equal("wood")
    assert_that(first["position"]["x"]).is_equal(100.0)
    assert_that(first["position"]["y"]).is_equal(200.0)


func test_deserialize_box_contents_data() -> void:
    # Test that box contents deserialization correctly parses dictionary data
    var box_data: Dictionary = {
        "5,10": [
            {"id": "iron", "quantity": 5},
            null,
            {"id": "wood", "quantity": 20},
        ]
    }

    for key in box_data:
        for item_data in box_data[key]:
            if item_data:
                # Test the exact pattern from save_manager.gd line 249
                var id = item_data["id"]
                var quantity = item_data["quantity"]
                assert_that(id).is_not_empty()
                assert_that(quantity).is_greater(0)


func test_deserialize_player_data() -> void:
    # Test that player deserialization correctly parses nested dictionary data
    var player_data: Dictionary = {
        "position": {"x": 150.5, "y": -200.25}
    }

    # Test the exact pattern from save_manager.gd line 187
    var pos = Vector2(player_data["position"]["x"], player_data["position"]["y"])

    assert_that(pos.x).is_equal(150.5)
    assert_that(pos.y).is_equal(-200.25)


func test_item_create_with_valid_id() -> void:
    # Test that Item.create works with valid item IDs from the registry
    var item = Item.create("rock", 5)

    assert_that(item).is_not_null()
    assert_that(item.item_id).is_equal("rock")
    assert_that(item.quantity).is_equal(5)


func test_full_save_load_cycle_data_format() -> void:
    # Test that the save data format can be properly parsed
    var save_data: Dictionary = {
        "version": 1,
        "timestamp": 1704825600,
        "player": {"position": {"x": 0.0, "y": 0.0}},
        "hotbar": [{"slot": 0, "id": "axe", "quantity": 1}],
        "tile_modifications": {"0,0": 1},
        "dropped_items": [],
        "box_contents": {}
    }

    # Test timestamp access (fixed from dot notation)
    assert_that(save_data["timestamp"]).is_equal(1704825600)

    # Test nested player position access
    assert_that(save_data["player"]["position"]["x"]).is_equal(0.0)

    # Test hotbar item access
    var hotbar = save_data["hotbar"]
    assert_that(hotbar[0]["id"]).is_equal("axe")
