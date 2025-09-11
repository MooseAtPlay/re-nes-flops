extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

const MAX_SPEED = 300.0
const ACCELERATION = 800.0
const FRICTION = 1000.0
const JUMP_VELOCITY = -400.0

# Bomb throwing variables
var held_bomb: Node2D = null
const THROW_HORIZONTAL_VELOCITY = 120.0
const THROW_VERTICAL_VELOCITY = -80.0
const BOMB_HOLD_OFFSET = Vector2(0, -60)  # Position bomb above character


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Handle bomb throwing
	handle_bomb_input()

	# Get the input direction and handle movement (works both on ground and in air)
	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		# Apply acceleration in the direction of input (works in air and on ground)
		velocity.x = move_toward(velocity.x, direction * MAX_SPEED, ACCELERATION * delta)
		# Flip sprite when moving left
		animated_sprite.flip_h = direction < 0
	else:
		# Apply friction when no input (only on ground)
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
	
	# Handle animations based on ground state
	if not is_on_floor():
		# Play jump animation when in air
		if animated_sprite.animation != "jump":
			animated_sprite.play("jump")
	else:
		# Ground-based animations
		if direction:
			# Play run animation when moving on ground
			if animated_sprite.animation != "run":
				animated_sprite.play("run")
		else:
			# Play skid animation when slowing down but still moving
			if abs(velocity.x) > 10:  # Small threshold to avoid jittering
				if animated_sprite.animation != "skid":
					animated_sprite.play("skid")
			else:
				# Play idle animation when stopped or nearly stopped
				if animated_sprite.animation != "idle":
					animated_sprite.play("idle")

	move_and_slide()
	
	# Update held bomb position if we have one
	if held_bomb:
		held_bomb.position = global_position + BOMB_HOLD_OFFSET

func handle_bomb_input() -> void:
	"""Handle bomb throwing input"""
	# Check if hold_bomb action is pressed (start holding)
	if Input.is_action_just_pressed("hold_bomb") and held_bomb == null:
		create_held_bomb()
	
	# Check if hold_bomb action is released (throw bomb)
	elif Input.is_action_just_released("hold_bomb") and held_bomb != null:
		throw_bomb()

func create_held_bomb() -> void:
	"""Create a new bomb and hold it"""
	# Check if we have bombs available
	var game_state = get_node("/root/AdvRockyBullwinkle")
	if not game_state or not game_state.use_bomb():
		return  # No bombs available
	
	# Load the bomb scene
	var bomb_scene = preload("res://adv_rocky_bullwinkle/bomb.tscn")
	var new_bomb = bomb_scene.instantiate()
	
	# Add bomb to the game state (root node)
	game_state.add_child(new_bomb)
	
	# Set bomb position above character
	new_bomb.position = global_position + BOMB_HOLD_OFFSET
	
	# Set bomb to armed state
	new_bomb.state = new_bomb.BombState.ARMED
	
	# Mark bomb as being held
	new_bomb.set_held(true)
	
	# Store reference to held bomb
	held_bomb = new_bomb
	
	print("Created and holding bomb")

func throw_bomb() -> void:
	"""Throw the held bomb"""
	if held_bomb == null:
		return
	
	# Calculate throw direction based on character facing
	var throw_direction = 1 if not animated_sprite.flip_h else -1
	
	# Release the bomb from being held
	held_bomb.set_held(false)
	
	# Set bomb velocity for throwing
	held_bomb.velocity = Vector2(
		THROW_HORIZONTAL_VELOCITY * throw_direction,
		THROW_VERTICAL_VELOCITY
	)
	
	# Clear held bomb reference
	held_bomb = null
	
	print("Threw bomb")

func clear_held_bomb() -> void:
	"""Clear the held bomb reference (called when bomb explodes while held)"""
	if held_bomb:
		held_bomb.set_held(false)
		held_bomb = null
	print("Cleared held bomb (exploded while held)")
