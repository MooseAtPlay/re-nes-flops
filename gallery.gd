extends Control

@onready var intro_panel = $%IntroPanel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Start the splash screen timer
	await get_tree().create_timer(3.0).timeout
	fade_out_intro_panel()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func fade_out_intro_panel():
	if intro_panel:
		# Create a tween for smooth fade-out
		var tween = create_tween()
		tween.tween_property(intro_panel, "modulate:a", 0.0, 1.0)
		# Wait for fade to complete, then remove the node
		await tween.finished
		intro_panel.queue_free()
