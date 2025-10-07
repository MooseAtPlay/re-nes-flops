extends CanvasLayer


@onready var game_state = get_node("/root/AdvRockyBullwinkle")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Input handling
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not game_state.success_state:
		if game_state.game_paused:
			game_state.unpause_game()
			%PauseMenu.visible = false
		else:
			game_state.pause_game()
			%PauseMenu.visible = true
