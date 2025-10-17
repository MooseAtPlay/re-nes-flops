extends Control

@onready var intro_panel = $%IntroPanel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Start the splash screen timer
	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(_on_splash_timeout)

	%Games.get_child(0).grab_focus()

func _on_splash_timeout() -> void:
	fade_out_intro_panel()

func fade_out_intro_panel():
	if intro_panel:
		# Create a tween for smooth fade-out
		var tween = create_tween()
		tween.tween_property(intro_panel, "modulate:a", 0.0, 1.0)
		# Connect to tween completion signal instead of using await
		tween.finished.connect(_on_fade_complete)

func _on_fade_complete() -> void:
	if intro_panel:
		intro_panel.queue_free()


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_rocky_and_bullwinkle_pressed() -> void:
	get_tree().change_scene_to_file("res://adv_rocky_bullwinkle/adv_rocky_bullwinkle.tscn")
