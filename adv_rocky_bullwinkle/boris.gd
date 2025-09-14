extends BombCharacter

const SPEED = 200.0
const JUMP_VELOCITY = -400.0
const MOVE_SPEED = 150.0
const MIN_DISTANCE = 92.0

# Health system
@export var health: int = 6
@export var max_health: int = 6

# Bomb throwing state
var throw_delay_timer: Timer

# Player facing
var player_facing_timer: Timer

# AI Movement state
var target_position: Vector2
var has_target: bool = false
var target_reassessment_timer: Timer

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

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle movement (only when not throwing bombs)
	if not is_throwing_bomb:
		handle_movement(delta)
	else:
		print("DEBUG: Not moving - is_throwing_bomb: ", is_throwing_bomb)

	# Handle animations
	handle_animations()

	move_and_slide()

func handle_animations() -> void:
	"""Handle Boris's animations"""
	if is_throwing_bomb:
		# Don't change animation while throwing - let it finish
		pass
	elif is_holding_bomb:
		# Play hold_bomb animation when holding a bomb
		if animated_sprite.animation != "hold_bomb":
			animated_sprite.play("hold_bomb")
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
	print("Boris starting bomb throw sequence")
	
	# Stop all movement before creating bomb
	velocity = Vector2.ZERO
	print("DEBUG: Boris velocity zeroed before creating bomb")
	
	# Clear current target since we're about to throw
	has_target = false
	
	# Create and hold a bomb
	create_held_bomb()
	
	# Start the delay timer
	throw_delay_timer.start()
	print("Boris created bomb, waiting to throw...")

func _on_throw_delay_timeout() -> void:
	"""Called when the delay timer times out - throw the bomb"""
	if is_holding_bomb:
		print("Boris throwing bomb after delay")
		throw_bomb()
	else:
		print("Boris delay timeout but no bomb to throw")

func take_damage(amount: int) -> void:
	"""Take damage and handle death"""
	health = max(0, health - amount)
	print("Boris took ", amount, " damage. Health: ", health, "/", max_health)
	
	if health <= 0:
		print("Boris defeated!")
		queue_free()

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
		print("DEBUG: Holding bomb, stopping movement. velocity.x: ", velocity.x)
		return
	
	var player = get_node("/root/AdvRockyBullwinkle/Bullwinkle")
	if not player:
		print("DEBUG: No player found for Boris movement")
		return
	
	# Choose a target position if we don't have one
	if not has_target:
		choose_target_position(player)
	
	# Move toward target if we have one
	if has_target:
		var distance_to_target = global_position.distance_to(target_position)
		print("DEBUG: Distance to target: ", distance_to_target, " Target: ", target_position)
		
		if distance_to_target > 10:  # Small threshold to avoid jittering
			# Move toward target
			var direction_to_target = (target_position - global_position).normalized()
			velocity.x = direction_to_target.x * MOVE_SPEED
			print("DEBUG: Moving toward target, velocity.x: ", velocity.x)
		else:
			# Reached target - stop moving
			velocity.x = move_toward(velocity.x, 0, MOVE_SPEED * 2 * delta)
			print("DEBUG: Reached target, stopping. velocity.x: ", velocity.x)
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
		print("DEBUG: Too far from player, moving closer. Target: ", target_position)
	elif distance_to_player < MIN_DISTANCE * 0.8:  # Too close
		# Move away from player
		var direction_away_from_player = (current_pos - player_pos).normalized()
		target_position = current_pos + direction_away_from_player * (MIN_DISTANCE - distance_to_player)
		print("DEBUG: Too close to player, backing away. Target: ", target_position)
	else:
		# At good distance, choose a position slightly to the side
		var side_direction = 1 if randf() > 0.5 else -1
		target_position = player_pos + Vector2(side_direction * MIN_DISTANCE * 0.5, 0)
		print("DEBUG: Good distance, choosing side position. Target: ", target_position)
	
	has_target = true

func _on_target_reassessment_timeout() -> void:
	"""Periodically reassess target position"""
	if not is_holding_bomb and not is_throwing_bomb:
		# Clear current target to force reassessment
		has_target = false
		print("DEBUG: Target reassessment timeout - clearing current target")
