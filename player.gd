extends CharacterBody2D

@export var run_speed: float = 160.0
@export var walk_speed: float = 80.0


func _physics_process(_delta: float) -> void:
    var input_dir = Vector2.ZERO

    if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
        input_dir.x -= 1
    if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
        input_dir.x += 1
    if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
        input_dir.y -= 1
    if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
        input_dir.y += 1

    var current_speed = walk_speed if Input.is_key_pressed(KEY_SHIFT) else run_speed
    velocity = input_dir.normalized() * current_speed
    move_and_slide()
