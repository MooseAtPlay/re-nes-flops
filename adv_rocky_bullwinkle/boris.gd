extends BombCharacter

const SPEED = 200.0
const JUMP_VELOCITY = -400.0
const MOVE_SPEED = 150.0
const MIN_DISTANCE = 92.0

# Tactical bomb throwing constants
const THROW_LOW_HORIZONTAL_VELOCITY = 180.0  # Faster horizontal for low shots
const THROW_LOW_VERTICAL_VELOCITY = -80.0    # Lower arc for under-platform shots

# Health system
@export var health: int = 6
@export var max_health: int = 6

# Debug options
@export var always_throw_low: bool = false

# Bomb throwing state
var throw_delay_timer: Timer

# Player facing
var player_facing_timer: Timer

# AI Movement state
var target_position: Vector2
var has_target: bool = false
var target_reassessment_timer: Timer

# Jump timer
var jump_timer: Timer

# Semisolid platform state tracking
var was_on_semisolid: bool = false

# Key drop positioning
const HALF_HEIGHT = 15

func _ready() -> void:
	# Call parent _ready first
	super._ready()
	
	# Create a timer for the delay between creating and throwing bomb
	throw_delay_timer = Timer.new()
	throw_delay_timer.wait_time = 1.0  # 1 second delay
	throw_delay_timer.one_shot = true
	throw_delay_timer.timeout.connect(_on_throw_delay_timeout)
	add_child(throw_delay_timer)
	
	# Create a timer for checking player position and facing
	player_facing_timer = Timer.new()
	player_facing_timer.wait_time = 0.25  # 250ms
	player_facing_timer.timeout.connect(_on_player_facing_timeout)
	add_child(player_facing_timer)
	player_facing_timer.start()
	
	# Create a timer for reassessing target position
	target_reassessment_timer = Timer.new()
	target_reassessment_timer.wait_time = 1.0  # 1 second
	target_reassessment_timer.timeout.connect(_on_target_reassessment_timeout)
	add_child(target_reassessment_timer)
	target_reassessment_timer.start()
	
	# Create a timer for jumping
	jump_timer = Timer.new()
	jump_timer.wait_time = 1.0  # 1 second
	jump_timer.timeout.connect(_on_jump_timer_timeout)
	add_child(jump_timer)
	jump_timer.start()

func _physics_process(delta: float) -> void:
	# Handle semisolid platform collision FIRST
	handle_semisolid_collision()
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle movement (only when not throwing bombs)
	if not is_throwing_bomb:
		handle_movement(delta)

	# Handle animations
	handle_animations()

	move_and_slide()
	
	# Update semisolid platform state tracking
	was_on_semisolid = false
	if is_on_floor():
		var bodies = get_slide_collision_count()
		for i in range(bodies):
			var collision = get_slide_collision(i)
			var body = collision.get_collider()
			if body and body.is_in_group("semisolid"):
				was_on_semisolid = true

func handle_animations() -> void:
	"""Handle Boris's animations"""
	if is_throwing_bomb:
		# Don't change animation while throwing - let it finish
		pass
	elif is_holding_bomb:
		# Play hold_bomb animation when holding a bomb
		if animated_sprite.animation != "hold_bomb":
			animated_sprite.play("hold_bomb")
	elif not is_on_floor():
		# Play jump animation when in air
		if animated_sprite.animation != "jump":
			animated_sprite.play("jump")
	else:
		# Play idle animation when not doing anything else
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")

func _on_throw_bomb_timer_timeout() -> void:
	"""Called when the main throw timer times out - start bomb throwing sequence"""
	if not is_holding_bomb and not is_throwing_bomb:
		start_bomb_throw_sequence()

func start_bomb_throw_sequence() -> void:
	"""Start the bomb throwing sequence: create bomb, wait, then throw"""
	# Stop all movement before creating bomb
	velocity = Vector2.ZERO
	
	# Clear current target since we're about to throw
	has_target = false
	
	# Create and hold a bomb
	create_held_bomb()
	
	# Start the delay timer
	throw_delay_timer.start()

func _on_throw_delay_timeout() -> void:
	"""Called when the delay timer times out - throw the bomb"""
	if is_holding_bomb:
		# Check if player is on floor and decide on throw trajectory
		var player = get_node("/root/AdvRockyBullwinkle/Bullwinkle")
		var use_low_trajectory = false
		
		if always_throw_low:
			# Debug mode: always use low trajectory
			use_low_trajectory = true
		elif player and player.is_on_floor():
			# 25% chance to use low trajectory when player is on floor
			use_low_trajectory = randf() < 0.25
		
		if use_low_trajectory:
			# Use tactical low trajectory for under-platform shots
			throw_bomb(THROW_LOW_HORIZONTAL_VELOCITY, THROW_LOW_VERTICAL_VELOCITY)
		else:
			# Use default trajectory
			throw_bomb()

func take_damage(amount: int) -> void:
	"""Take damage and handle death"""
	health = max(0, health - amount)
	
	if health <= 0:
		# Drop a key when Boris dies
		drop_key()
		queue_free()

func drop_key() -> void:
	"""Drop a key at Boris's feet"""
	# Load the key scene
	var key_scene = preload("res://adv_rocky_bullwinkle/key.tscn")
	if key_scene:
		# Create a new key instance
		var key_instance = key_scene.instantiate()
		if key_instance:
			# Add it to the scene tree at Boris's feet
			get_parent().add_child(key_instance)
			key_instance.global_position = global_position + Vector2(0, HALF_HEIGHT)
			print("DEBUG: Boris dropped a key at position: ", key_instance.global_position)
		else:
			print("ERROR: Failed to instantiate key scene")
	else:
		print("ERROR: Failed to load key scene")

func _on_player_facing_timeout() -> void:
	"""Check player position and face them"""
	var player = get_node("/root/AdvRockyBullwinkle/Bullwinkle")
	if player:
		# Check if player is to the left or right of Boris
		if player.global_position.x < global_position.x:
			# Player is to the left, face left
			facing_left = true
			animated_sprite.flip_h = true
		else:
			# Player is to the right, face right
			facing_left = false
			animated_sprite.flip_h = false

func handle_movement(delta: float) -> void:
	"""Handle Boris movement using target-based AI"""
	# Stop moving if holding a bomb
	if is_holding_bomb:
		velocity.x = move_toward(velocity.x, 0, MOVE_SPEED * 2 * delta)
		return
	
	var player = get_node("/root/AdvRockyBullwinkle/Bullwinkle")
	if not player:
		return
	
	# Choose a target position if we don't have one
	if not has_target:
		choose_target_position(player)
	
	# Move toward target if we have one
	if has_target:
		var distance_to_target = global_position.distance_to(target_position)
		
		if distance_to_target > 10:  # Small threshold to avoid jittering
			# Move toward target
			var direction_to_target = (target_position - global_position).normalized()
			velocity.x = direction_to_target.x * MOVE_SPEED
		else:
			# Reached target - stop moving
			velocity.x = move_toward(velocity.x, 0, MOVE_SPEED * 2 * delta)
			has_target = false  # Clear target so we can choose a new one

func choose_target_position(player: CharacterBody2D) -> void:
	"""Choose a strategic target position relative to the player"""
	var player_pos = player.global_position
	var current_pos = global_position
	var distance_to_player = current_pos.distance_to(player_pos)
	
	# Calculate ideal position based on current distance
	if distance_to_player > MIN_DISTANCE * 1.2:  # Too far away
		# Move closer to player, but not too close
		var direction_to_player = (player_pos - current_pos).normalized()
		target_position = player_pos - direction_to_player * MIN_DISTANCE
	elif distance_to_player < MIN_DISTANCE * 0.8:  # Too close
		# Move away from player
		var direction_away_from_player = (current_pos - player_pos).normalized()
		target_position = current_pos + direction_away_from_player * (MIN_DISTANCE - distance_to_player)
	else:
		# At good distance, choose a position slightly to the side
		var side_direction = 1 if randf() > 0.5 else -1
		target_position = player_pos + Vector2(side_direction * MIN_DISTANCE * 0.5, 0)
	
	has_target = true

func _on_target_reassessment_timeout() -> void:
	"""Periodically reassess target position"""
	if not is_holding_bomb and not is_throwing_bomb:
		# Clear current target to force reassessment
		has_target = false

func handle_semisolid_collision() -> void:
	"""Handle semisolid platform collision logic"""
	
	# Enable semisolid collision when:
	# 1. Moving down (falling) - to land on platforms from above
	# 2. Standing on a semisolid platform - to stay on it
	if velocity.y > 0.1 or was_on_semisolid:
		# Enable collision with semisolid platforms (layer 2)
		collision_mask = 3  # 1 (solid) + 2 (semisolid)
	else:
		# Disable collision with semisolid platforms when moving up or horizontally
		collision_mask = 1  # Only solid platforms

func _on_jump_timer_timeout() -> void:
	"""Handle jump timer timeout - make Boris jump if conditions are met"""
	# Only jump if:
	# 1. On the floor
	# 2. Not currently throwing a bomb
	# 3. Not holding a bomb
	if is_on_floor() and not is_throwing_bomb and not is_holding_bomb:
		velocity.y = JUMP_VELOCITY
