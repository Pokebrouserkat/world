extends Control

## MainMenu - Entry point with Play and Sandbox mode selection


func _on_play_pressed() -> void:
    GameMode.set_mode(GameMode.Mode.NORMAL)
    get_tree().change_scene_to_file("res://scenes/world.tscn")


func _on_sandbox_pressed() -> void:
    GameMode.set_mode(GameMode.Mode.SANDBOX)
    get_tree().change_scene_to_file("res://scenes/world.tscn")


func _on_quit_pressed() -> void:
    get_tree().quit()
