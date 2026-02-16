extends Node

## GameMode - Global singleton tracking current game mode
## Autoload singleton, set before world scene loads

enum Mode { NORMAL, SANDBOX }

var current_mode: Mode = Mode.NORMAL


func is_sandbox() -> bool:
	return current_mode == Mode.SANDBOX


func set_mode(mode: Mode) -> void:
	current_mode = mode
