extends Area2D

# State property to match the bomb system (0 = UNARMED)
@export var state: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Set up the animated sprite if it exists
	var animated_sprite = $AnimatedSprite2D
	if animated_sprite:
		# Connect to animation finished signal if needed
		animated_sprite.animation_finished.connect(_on_animation_finished)
		# Start with default animation
		animated_sprite.play("default")
	
	print("DEBUG: UnarmedBomb created - state: ", state, " groups: ", get_groups())


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Unarmed bombs don't need any processing - they're just pickup items
	pass

func _on_animation_finished() -> void:
	"""Handle when animation finishes"""
	# Unarmed bombs just loop their animation, no special handling needed
	pass
