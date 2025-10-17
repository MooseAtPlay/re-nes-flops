extends CanvasLayer

@onready var game_state = get_node("/root/AdvRockyBullwinkle")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Connect the unpause button to the gallery UI's handler
	%UnpauseButton.pressed.connect(%GalleryUI._on_unpause_button_pressed)

# Input handling
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not game_state.success_state:
		if game_state.game_paused:
			# Use the same unpause logic as the button
			%GalleryUI._on_unpause_button_pressed()
		else:
			game_state.pause_game()
			%PauseMenu.visible = true
			%GalleryUI.visible = true
			# Set focus on the UnpauseButton when showing pause menu
			%UnpauseButton.visible = true
			%UnpauseButton.grab_focus()
