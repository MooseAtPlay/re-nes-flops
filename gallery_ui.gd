extends CanvasLayer

# Signal emitted when the unpause button is pressed
signal game_unpaused

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_back_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://gallery.tscn")


func _on_unpause_button_pressed() -> void:
	# Emit signal for the owning scene to handle unpausing
	game_unpaused.emit()
