extends CharacterBody2D

@export var speed: float = 200.0


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

    velocity = input_dir.normalized() * speed
    move_and_slide()
