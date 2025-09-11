class_name BombCharacter
extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var bomb_marker: Marker2D = $BombMarker

# Bomb throwing variables
var held_bomb: Node2D = null
const THROW_HORIZONTAL_VELOCITY = 120.0
const THROW_VERTICAL_VELOCITY = -160.0
@export var throw_variance: float = 20.0

# Animation state tracking for bombs
var is_holding_bomb: bool = false
var is_throwing_bomb: bool = false

# Direction tracking
var facing_left: bool = false

func _ready() -> void:
	# Connect to animation finished signal
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(_delta: float) -> void:
	# Update held bomb position if we have one
	if held_bomb and bomb_marker:
		# Use marker position, adjusting for direction
		var marker_pos = bomb_marker.global_position
		if facing_left:
			# When facing left, add 2x the marker's local x position
			held_bomb.position = marker_pos + Vector2(2 * abs(bomb_marker.position.x), 0)
		else:
			# When facing right, use marker position directly
			held_bomb.position = marker_pos

func create_held_bomb() -> void:
	"""Create a new bomb and hold it"""
	# Check if we have bombs available
	var game_state = get_node("/root/AdvRockyBullwinkle")
	if not game_state or not game_state.use_bomb():
		return  # No bombs available
	
	# Load the bomb scene
	var bomb_scene = preload("res://adv_rocky_bullwinkle/bomb.tscn")
	var new_bomb = bomb_scene.instantiate()
	
	# Add bomb to the Bombs node
	var bombs_node = game_state.get_node("Bombs")
	if bombs_node:
		bombs_node.add_child(new_bomb)
	else:
		# Fallback to game_state if Bombs node not found
		game_state.add_child(new_bomb)
		print("WARNING: Bombs node not found, added bomb to game_state")
	
	# Set bomb position using marker, adjusting for direction
	if bomb_marker:
		var marker_pos = bomb_marker.global_position
		if facing_left:
			# When facing left, subtract 2x the marker's local x position
			new_bomb.position = marker_pos - Vector2(2 * abs(bomb_marker.position.x), 0)
		else:
			# When facing right, use marker position directly
			new_bomb.position = marker_pos
	else:
		# Fallback to character position if marker not found
		new_bomb.position = global_position + Vector2(0, -60)
	
	# Set bomb to armed state
	new_bomb.state = new_bomb.BombState.ARMED
	
	# Mark bomb as being held
	new_bomb.set_held(true)
	
	# Store reference to held bomb
	held_bomb = new_bomb
	
	# Set holding state for animation
	is_holding_bomb = true
	
	print("Created and holding bomb")

func throw_bomb() -> void:
	"""Throw the held bomb"""
	if held_bomb == null:
		return
	
	# Calculate throw direction based on character facing
	var throw_direction = 1 if not animated_sprite.flip_h else -1
	
	# Release the bomb from being held
	held_bomb.set_held(false)
	
	# Set bomb velocity for throwing, adding character's horizontal velocity and random variance
	var horizontal_variance = randf_range(0.0, throw_variance)
	var vertical_variance = randf_range(0.0, throw_variance)
	
	held_bomb.velocity = Vector2(
		THROW_HORIZONTAL_VELOCITY * throw_direction + velocity.x + horizontal_variance,
		THROW_VERTICAL_VELOCITY + vertical_variance
	)
	
	# Clear held bomb reference
	held_bomb = null
	
	# Set throwing state and play throw animation
	is_holding_bomb = false
	is_throwing_bomb = true
	animated_sprite.play("throw_bomb")
	
	print("Threw bomb - is_throwing_bomb set to true, playing throw_bomb animation")

func clear_held_bomb() -> void:
	"""Clear the held bomb reference (called when bomb explodes while held)"""
	if held_bomb:
		held_bomb.set_held(false)
		held_bomb = null
	
	# Clear bomb states and let animation system return to appropriate animation
	is_holding_bomb = false
	is_throwing_bomb = false
	
	print("Cleared held bomb (exploded while held)")

func _on_animation_finished() -> void:
	"""Handle when animation finishes"""
	print("Animation finished")
	if animated_sprite and animated_sprite.animation == "throw_bomb":
		# Throw animation finished, return to normal animation state
		is_throwing_bomb = false
		print("Throw bomb animation finished - is_throwing_bomb set to false")
	else:
		print("Animation finished but not throw_bomb")

