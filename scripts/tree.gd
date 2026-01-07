class_name WorldTree
extends StaticBody2D

signal destroyed(tree_position: Vector2)

@export var max_health: int = 10
var health: int = max_health


func _ready() -> void:
    _update_collision_from_sprite()


func _update_collision_from_sprite() -> void:
    var sprite = $Sprite2D
    var collision = $CollisionShape2D
    if sprite and sprite.texture and collision and collision.shape is RectangleShape2D:
        var tex_size = sprite.texture.get_size()
        # Use lower portion of tree for collision (trunk area)
        collision.shape.size = Vector2(tex_size.x * 0.5, tex_size.y * 0.3)
        collision.position = Vector2(0, tex_size.y * 0.35)


func take_damage(amount: int = 1) -> void:
    health -= amount
    # Visual feedback - quick flash/shake
    _hit_feedback()
    if health <= 0:
        destroyed.emit(global_position)
        queue_free()


func _hit_feedback() -> void:
    var sprite = $Sprite2D
    if sprite:
        # Quick shake effect
        var original_pos = sprite.position
        var tween = create_tween()
        tween.tween_property(sprite, "position", original_pos + Vector2(2, 0), 0.05)
        tween.tween_property(sprite, "position", original_pos + Vector2(-2, 0), 0.05)
        tween.tween_property(sprite, "position", original_pos, 0.05)
