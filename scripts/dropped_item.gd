class_name DroppedItem
extends Area2D

var item: Item
var can_pickup: bool = false
var being_picked_up: bool = false
var network_id: int = -1  # Network ID for multiplayer sync
var pickup_target: Node2D = null
var pickup_progress: float = 0.0

const PICKUP_DURATION: float = 0.1
const PICKUP_SPEED: float = 300.0


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


func _process(delta: float) -> void:
    if not being_picked_up or pickup_target == null:
        return
    if not is_instance_valid(pickup_target):
        queue_free()
        return

    pickup_progress += delta
    var t = clampf(pickup_progress / PICKUP_DURATION, 0.0, 1.0)

    # Move toward player
    var direction = (pickup_target.global_position - global_position).normalized()
    global_position += direction * PICKUP_SPEED * delta

    # Shrink with easing
    var scale_value = 1.0 - ease(t, 2.0)
    scale = Vector2(scale_value, scale_value)

    # Done when fully shrunk
    if t >= 1.0:
        queue_free()


func start_pickup(target: Node2D) -> void:
    # Note: being_picked_up may already be true on host (set in request_pickup_item)
    # but we still need to set up the animation
    being_picked_up = true
    can_pickup = false
    pickup_target = target
    pickup_progress = 0.0
