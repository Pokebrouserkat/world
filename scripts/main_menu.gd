extends Control

## MainMenu - Entry point with Play and Sandbox mode selection

var button_texture: Texture2D = preload("res://graphics/button.png")

@onready var play_button: Button = $Panel/VBoxContainer/PlayButton
@onready var sandbox_button: Button = $Panel/VBoxContainer/SandboxButton
@onready var quit_button: Button = $Panel/VBoxContainer/QuitButton


func _ready() -> void:
	_style_buttons()


func _make_button_style(modulate_color: Color = Color.WHITE) -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	style.texture = button_texture
	style.texture_margin_left = 4
	style.texture_margin_right = 4
	style.texture_margin_top = 4
	style.texture_margin_bottom = 4
	style.modulate_color = modulate_color
	return style


func _style_buttons() -> void:
	for btn in [play_button, sandbox_button, quit_button]:
		btn.add_theme_stylebox_override("normal", _make_button_style())
		btn.add_theme_stylebox_override("hover", _make_button_style(Color(1.2, 1.2, 1.2)))
		btn.add_theme_stylebox_override("pressed", _make_button_style(Color(0.8, 0.8, 0.8)))


func _on_play_pressed() -> void:
	GameMode.set_mode(GameMode.Mode.NORMAL)
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _on_sandbox_pressed() -> void:
	GameMode.set_mode(GameMode.Mode.SANDBOX)
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_W and event.meta_pressed:
			get_tree().quit()


func _on_quit_pressed() -> void:
	get_tree().quit()
